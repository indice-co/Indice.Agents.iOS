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
    
    private var client: AgentsClient
    private var chat: ChatSessionService?
    private var sendTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()
    
    init(_ client: AgentsClient, chatId: UUID?) {
        self.client = client
        
        super.init()
        
        guard let chatId else {
            isReady = true
            return
        }
        
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
}



// MARK: Operations


extension SessionModel: ChatSelectionResponder {
    
    func response(withMessage message: String) {
        self.post(message: message)
    }
    
    func post(message: String) {
        guard isReady, !isSending else { return }
        
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
                    session = await self.client.chatsService.newChat()
                    setup(chat: session)
                }
                try Task.checkCancellation()
                try await session.sendStream(message: message)
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
