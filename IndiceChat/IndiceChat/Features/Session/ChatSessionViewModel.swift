//
//  ChatSessionViewModel.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 24/9/26.
//



import Foundation
import Combine
import IndiceAgents
import AgentsModels

final class ChatSessionViewModel: ViewModel, ChatSelectionResponder {
    @Published private(set) var messages: [ChatSessionService.Message] = []
    @Published private(set) var isSending = false
    @Published private(set) var isReady = false
    @Published private(set) var progressLabel: String?
    @Published private(set) var streamError: String?
    @Published var talkingToMySelf = false

    @Published private(set) var title: String?
    
    private var chat: ChatSessionService?
    private let service: ChatService
    private var sendTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    init(service: ChatService, chatId: UUID?) {
        self.service = service
        super.init()
        guard let chatId else {
            isReady = true
            return
        }
        loadAsync {
            try await $0.service.chat(id: chatId)
        } onSuccess: { [weak self] chat in
            self?.setup(chat: chat)
            self?.isReady = true
        }
    }

    private func setup(chat: ChatSessionService) {
        self.chat = chat
        
        subscriptions.removeAll()
        
        chat.messages
            .sink { [weak self] in self?.messages = $0 }
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
    
    func response(withMessage message: String) {
        self.post(message: message)
    }

    func post(message: String) {
        guard isReady, !isSending else { return }
        if talkingToMySelf {
            messages.append(.init(value: .init(role: .user, content: .init(parts: [.init(value: message, contentType: "text/plain")]))))
            return
        }
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
                if let chat { session = chat }
                else {
                    session = await service.newChat()
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
    
    deinit { sendTask?.cancel() }
}


