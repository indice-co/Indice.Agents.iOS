import Foundation
import AgentsModels
import Combine

public actor ChatService {
    private let repository: ChatRepository

    init(repository: ChatRepository) { self.repository = repository }

    public func chats(paging: PagingOptions = .init(page: 1, size: 100), filter: FilterOptions? = nil) async throws -> ConversationListItemResultSet {
        try await repository.chats(paging: paging, filter: filter)
    }

    public func delete(chatID: UUID) async throws { try await repository.delete(chatId: chatID) }

    public func like(chatID: UUID, messageID: UUID, like: Bool?) async throws {
        try await repository.like(chatID: chatID, messageID: messageID, request: .init(like: like))
    }

    public func chat(id: UUID) async throws -> ChatSessionService {
        let conversation = try await repository.session(forChatId: id)
        let service = ChatSessionService(repository: repository, chatID: id, history: conversation.messages ?? [])
        await service.publishHistory()
        return service
    }

    /// Create a local session before sending. Its conversation ID arrives with
    /// the first REST response or SSE start frame, allowing the first turn to stream.
    public func newChat() -> ChatSessionService {
        ChatSessionService(repository: repository, chatID: nil)
    }

    public func createNewChat(message: String) async throws -> ChatSessionService {
        let service = newChat()
        try await service.send(message: message)
        return service
    }
}

public actor ChatSessionService {
    public struct Message: Sendable, Identifiable, Equatable {
        public enum Delivery: Sendable, Equatable {
            case complete
            case streaming
            case cancelled
            case interrupted
        }

        /// Local display identity stays fixed as streaming metadata arrives. A
        /// server messageId is optional, a string, and absent for limit replies.
        public let id: UUID
        public var value: DexChatMessage {
            didSet {
                items = ChatContentMapper.items(for: value.content,
                    previousParts: oldValue.content?.parts ?? [], previousItems: items)
            }
        }
        public var delivery: Delivery
        public private(set) var items: [ChatContentItem]

        /// Prose-only convenience for previews/search. Render `items` in the UI:
        /// joining raw API parts would expose HTML and base64 as ordinary text.
        public var text: String {
            items.compactMap { item -> String? in
                switch item.content {
                case .text(let value), .markdown(let value): value
                default: nil
                }
            }.joined()
        }

        public init(id: UUID = UUID(), value: DexChatMessage, delivery: Delivery = .complete) {
            self.id = id
            self.value = value
            self.delivery = delivery
            self.items = ChatContentMapper.items(for: value.content)
        }
    }

    public enum StreamState: Sendable, Equatable {
        case idle
        case receiving(status: String?)
        case completed
        case cancelled
        case interrupted(String)
        case failed(String)
    }

    @MainActor public let messages = CurrentValueSubject<[Message], Never>([])
    @MainActor public let streamState = CurrentValueSubject<StreamState, Never>(.idle)
    public private(set) var chatID: UUID?
    public private(set) var lastResponse: DexChatResponse?

    private let repository: ChatRepository
    private var history: [Message]
    private var isSending = false
    private var responseIDs: [UUID] = []
    private let streamUpdateInterval: Duration

    init(repository: ChatRepository, chatID: UUID?, history: [DexChatMessage] = [],
         streamUpdateInterval: Duration = .milliseconds(75)) {
        self.repository = repository
        self.chatID = chatID
        self.history = history.map { Message(value: $0) }
        self.streamUpdateInterval = streamUpdateInterval
    }

    public func send(message: String) async throws { try await send(request: .init(text: message)) }

    public func send(request: ChatRequest) async throws {
        try beginTurn(request)
        defer { isSending = false }
        await publishHistory()
        let response: DexChatResponse
        
        if let chatID {
            response = try await repository.send(message: request, onChatId: chatID)
        } else {
            response = try await repository.create(chatRequest: request)
        }
        
        guard let id = response.conversationId else {
            throw AgentsError.missingConversationID
        }
        
        if let chatID, chatID != id {
            throw AgentsError.invalidStream("Unexpected conversation ID.")
        }
        
        chatID = id
        lastResponse = response
        
        await present(response, delivery: .complete)
    }

    public func sendStream(message: String) async throws { try await sendStream(request: .init(text: message)) }

    /// Suspends until `done` or failure. Observe messages/streamState for progress.
    /// Cancel the calling Task to stop both the consumer and its URLSession task.
    public func sendStream(request: ChatRequest) async throws {
        try beginTurn(request)
        defer { isSending = false }
        await publishHistory()
        await publishState(.receiving(status: nil))
        let accumulator = ChatStreamAccumulator()
        do {
            let stream: MessageStream
            if let chatID {
                stream = try await repository.streamOnMessage(message: request, onChatId: chatID)
            } else {
                stream = try await repository.createOnStream(chatRequest: request)
            }
            
            // `done` usually arrives before the HTTP connection closes. Always
            // release it when leaving this method, including early return/error.
            defer { stream.cancel() }
            
            let response = try await withThrowingTaskGroup(of: DexChatResponse.self) { group in
                group.addTask { try await self.receive(stream, into: accumulator) }
                group.addTask { try await self.publishProgress(from: accumulator) }
                // Completion or failure cancels the other child. The group joins
                // both before any terminal publication, preventing stale updates
                // from a suspended UI publication or from a previous turn.
                defer { group.cancelAll() }
                return try await group.next()!
            }
            try Task.checkCancellation()
            lastResponse = response
            await present(response, delivery: .complete)
            await publishState(.completed)
        } catch {
            if Task.isCancelled || error is CancellationError {
                await finishPartial(from: accumulator, delivery: .cancelled)
                await publishState(.cancelled)
                throw CancellationError()
            }
            if case AgentsError.streamFailed = error {
                // An API error frame means the answer was abandoned server-side.
                history.removeAll { responseIDs.contains($0.id) }
                await publishHistory()
                await publishState(.failed(error.localizedDescription))
            } else {
                // Preserve partial text for the reader, clearly marked incomplete.
                // It must not become lastResponse or be mistaken for persisted history.
                await finishPartial(from: accumulator, delivery: .interrupted)
                await publishState(.interrupted(error.localizedDescription))
            }
            throw error
        }
    }

    private func receive(_ stream: MessageStream, into accumulator: ChatStreamAccumulator) async throws -> DexChatResponse {
        for try await event in stream {
            try Task.checkCancellation()
            switch try await accumulator.consume(event.data) {
            case .started(let id):
                if let chatID, chatID != id {
                    throw AgentsError.invalidStream("Unexpected conversation ID.")
                }
                chatID = id
            case .completed(let response): return response
            default: break
            }
        }
        try Task.checkCancellation()
        throw AgentsError.incompleteStream
    }

    private func publishProgress(from accumulator: ChatStreamAccumulator) async throws -> DexChatResponse {
        while true {
            // A timer, rather than a check on the next delta, also flushes the
            // last batch when the server pauses. There is only one publisher;
            // if the main actor is busy, newer changes remain in the accumulator.
            try await Task.sleep(for: streamUpdateInterval)
            let snapshot = try await accumulator.snapshot()
            try Task.checkCancellation()
            if let response = snapshot.response { await present(response, delivery: .streaming) }
            try Task.checkCancellation()
            if let status = snapshot.status { await publishState(.receiving(status: status)) }
            await accumulator.didPublish(snapshot)
        }
    }

    private func finishPartial(from accumulator: ChatStreamAccumulator, delivery: Message.Delivery) async {
        // A malformed pending document must not mask the original failure or
        // replace the last successfully displayed partial response.
        if let snapshot = try? await accumulator.snapshot(), let response = snapshot.response {
            await present(response, delivery: delivery)
        } else {
            await markPartial(delivery)
        }
    }

    private func beginTurn(_ request: ChatRequest) throws {
        guard !isSending else { throw AgentsError.turnInProgress }
        guard let text = request.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentsError.invalidRequest("A message cannot be empty.")
        }
        isSending = true // Set before any await; actors are reentrant at suspension points.
        responseIDs = []
        history.append(.init(value: .init(authorName: request.authorName, role: .user,
                                          content: .init(parts: [.init(value: text, contentType: "text/markdown")]))))
    }

    private func present(_ response: DexChatResponse, delivery: Message.Delivery) async {
        let values = response.messages ?? []
        
        while responseIDs.count < values.count {
            responseIDs.append(UUID())
        }
        
        let previous = Dictionary(
            uniqueKeysWithValues: history
                .filter { responseIDs.contains($0.id) }
                .map { ($0.id, $0) })
        
        history.removeAll { responseIDs.contains($0.id) }
        
        history += values.enumerated().map { index, value in
            if var message = previous[responseIDs[index]] {
                message.value = value
                message.delivery = delivery
                return message
            }
            return Message(id: responseIDs[index], value: value, delivery: delivery)
        }
        await publishHistory()
    }

    private func markPartial(_ delivery: Message.Delivery) async {
        for index in history.indices where responseIDs.contains(history[index].id) {
            history[index].delivery = delivery
        }
        await publishHistory()
    }

    fileprivate func publishHistory() async {
        let snapshot = history
        await MainActor.run { messages.send(snapshot) }
    }

    private func publishState(_ state: StreamState) async {
        await MainActor.run { streamState.send(state) }
    }
}
