//
//  SessionModel.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 2/10/26.
//

import Foundation
import Combine
import AgentsClient
import AgentsModels


@MainActor
final class SessionModel: ProcessorObject {
    
    @Published
    private(set)
    var messages: [ChatSessionService.Message] = []

    @Published
    private(set)
    var agents: [AgentInfo] = []

    @Published
    var selectedAgent: AgentInfo?
    
    @Published
    private(set)
    var metadata = ChatSessionMetadata()
    
    @Published
    private(set)
    var isSending = false
    
    @Published
    private(set)
    var isReady = false
    
    @Published
    private(set)
    var progressLabel: String?
    
    @Published
    private(set)
    var streamError: String?
    
    var agentName: String {
        client.configuration.agentName
    }
    
    private var client: AgentsClient
    private var chat: ChatSessionService?
    private var sendTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()
    
    init(_ client: AgentsClient, chatId: UUID?) {
        self.client = client
        
        super.init()
        
        self.client.agentsService
            .infoValue.publisher()
            .replaceNil(with: [])
            .assign(to: &$agents)
        
        guard let chatId else {
            isReady = true
            return
        }
        
        self.initializeChat(withID: chatId)
    }

    private func initializeChat(withID chatId: UUID) {
        self.execute {
            try await $0.client
                .chatsService
                .chat(id: chatId)
        } onSuccess: { (self, chatHandle) in
            self.setup(chat: chatHandle)
            self.isReady = true
        }
    }
    
    deinit { sendTask?.cancel() }
    
    /// Call this when the current chat session might have been deleted
    /// in order to check and assume a 'nil' chatId if the deleted session is the current one.
    func deleted(chatId: UUID?) {
        execute {
            await $0.chat?.chatID
        } onSuccess: { receiver, id in
            guard id != nil, chatId == id else {
                return
            }
            
            receiver.assume(chatId: nil)
        }
    }
    
    func assume(chatId: UUID?) {
        cancelAllTasks()
        
        chat = nil
        sendTask?.cancel()
        subscriptions.removeAll(keepingCapacity: true)
        
        messages    = []
        metadata    = .init()
        streamError = nil
        
        if let chatId {
            initializeChat(withID: chatId)
        }
    }
    
    
    func updateAgentInfo(force: Bool) {
        execute {
            try await $0.client
                .agentsService
                .refreshAgentsInfo(force: force)
        } onSuccess: { receiver, list in
            if let current = receiver.selectedAgent, list.contains(current) {
                return
            }
            
            receiver.selectedAgent = list.first
        }
    }
}



// MARK: Operations


extension SessionModel: ChatSelectionResponder {
    
    func response(withMessage message: String) {
        self.post(message: message)
    }
    
    func post(message: String) {
        guard isReady, !isSending else { return }
        
        let request = ChatRequest(
            text: message,
            agentName: selectedAgent?.name)
        
        isSending = true
        streamError = nil
        sendTask = Task { [weak self] in
            guard let self else { return }
            defer {
                isSending = false
                sendTask = nil
            }
            do {
                // Subscribe before sending, so the first reply is progressive too.
                let session: ChatSessionService
                if let chat {
                    session = chat
                } else {
                    session = await self.client
                        .chatsService
                        .newChat()
                    setup(chat: session)
                }
                try Task.checkCancellation()
                try await session.sendStream(request: request)
            } catch is CancellationError {
                // The service keeps partial text and labels it as stopped.
            } catch {
                streamError = error.localizedDescription
            }
        }
    }
    
    func stop() { sendTask?.cancel() }
    
    func score(_ score: MessageScore, messageId: DexChatMessage.ID) {
        Task { [weak self] in
            try? await self?
                .chat?
                .score(score, messageID: messageId)
        }
    }
    
}


// MARK: Setup

private extension SessionModel {
    
    func setup(chat: ChatSessionService) {
        self.chat = chat
        
        subscriptions.removeAll()
        
        chat.messages
            .sink { [weak self] in self?.messages = $0 }
            .store(in: &subscriptions)

        chat.metadata
            .sink { [weak self] in self?.metadata = $0 }
            .store(in: &subscriptions)
        
        chat.streamState
            .sink { [weak self] state in
                if case .receiving(let label) = state {
                    self?.progressLabel = label
                } else {
                    self?.progressLabel = nil
                }
            }
            .store(in: &subscriptions)
    }
    
}
