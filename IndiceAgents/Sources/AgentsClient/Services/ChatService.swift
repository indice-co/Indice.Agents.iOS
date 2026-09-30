import Foundation
import AgentsModels
import Combine

public actor ChatService {
    
    private let repository: ChatRepository
    private let historyPager: Pager<ConversationListItem>
    
    nonisolated
    public let history: ValueState<[ConversationListItem]?> = .init()
    

    init(repository: ChatRepository) {
        self.repository = repository
        self.historyPager = .init(
            items: history,
            itemsGetter: { try await repository.chats(paging: $0, filter: $1).items ?? [] })
    }

    public func updateHistory(after item: borrowing ConversationListItem?) async throws {
        try await historyPager
            .provideNextPage(from: item)?
            .callAsFunction()
    }
    
    public func resetHistory() async {
        await historyPager.resetPager()
    }

    public func delete(chatID: UUID) async throws {
        try await repository.delete(chatId: chatID)
        
        await historyPager.resetPager()
        try? await updateHistory(after: nil)
    }

    public func like(chatID: UUID, messageID: DexChatMessage.ID, like: Bool?) async throws {
        try await repository.like(chatID: chatID, messageID: messageID, request: .init(like: like))
    }

    public func chat(id: UUID) async throws -> ChatSessionService {
        let conversation = try await repository.session(forChatId: id)
        
        let service = ChatSessionService(
            repository: repository,
            chatID: id,
            conversation: conversation)
        
        await service.publishHistory()
        await service.publishMetadata()
        
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
