//
//  SessionScreen.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 21/10/26.
//

import SwiftUI
import AgentsClient
import AgentsModels


public struct SessionScreen<
    EmptySessionContent: View
>: View {
    
    @Environment(\.eventBus) private var eventBus
    @Environment(\.agentsUITheme) private var theme
    
    @StateObject private var model: SessionModel
    
    @State private var message: String = ""
    @FocusState private var focus
     
    private let emptySessionContent: () -> EmptySessionContent
    
    private var canSendMessage: Bool {
        let hasMessage = !message
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        
        return hasMessage && model.isReady
    }
    
    private var isThinking: Bool {
        model.isLoading || model.isSending
    }
    
    public init(
        _ client: AgentsClient,
        emptySessionContent: @escaping () -> EmptySessionContent = { EmptySessionPrompt() }
    ) {
        self._model = StateObject(wrappedValue: .init(client, chatId: nil))
        self.emptySessionContent = emptySessionContent
    }
    
    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 24) {
                ForEach(model.messages) { message in
                    let isLastMessage = message.id == model.messages.last?.id
                    
                    MessageItemView(
                        message: message,
                        canUseResponderForChoices: isLastMessage)
                    .id(message.id)
                }
            }
            .padding()
            
            if let error = model.streamError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .padding()
            }
        }
        .onReceive(eventBus.requests, perform: handle(request:))
        .onReceive(eventBus.events,   perform: handle(event:))
        .scrollToBottom(trigger: model.messages.last?.id)
        .withChatResponder(model)
        .background(content: EmptyBackgroundPrompt)
        .safeAreaOrInset(content: InputBoxAndState)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.stop() }
        .task { model.updateAgentInfo(force: false) }
    }
    
    private var navigationTitle: String {
        model.metadata.title ?? String(.screen(.session(.navTitle)))
    }
    
}

// MARK: Actions

private extension SessionScreen {
    
    func handle(request: EventBus.Request) {
        switch request {
        case .chat(let id):
            model.assume(chatId: id)
            
        case .newChat:
            model.assume(chatId: nil)
        }
    }
    
    func handle(event: EventBus.Event) {
        switch event {
        case .deleted(let chatId):
            model.deleted(chatId: chatId)
        }
    }
    
}



// MARK: Components

private extension SessionScreen {
    
    private var thinkingMessage: String {
        model.progressLabel ?? String(.screen(.session(.thinking)))
    }
    
    @ViewBuilder
    func InputBoxAndState() -> some View {
        VStack(spacing: 8) {
            if isThinking {
                ThinkingBubble(message: thinkingMessage)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("bubble_indicator")
            }
            
            MessageInputBox(
                message: $message,
                selectedAgent: $model.selectedAgent,
                agentsList: model.agents,
                usage: model.metadata.usage,
                isSending: model.isSending,
                canSend: canSendMessage,
                send: {
                    model.post(message: message)
                    message = ""
                },
                stop: { model.stop() })
        }
        .padding()
    }
    
    @ViewBuilder
    func EmptyBackgroundPrompt() -> some View {
        if model.messages.isEmpty, model.isReady {
            emptySessionContent()
        }
    }
    
}

public struct EmptySessionPrompt: View {
    
    public init() { }
    
    public var body: some View {
        VStack {
            HStack(alignment: .lastTextBaseline) {
                Text(.screen(.session(.emptySessionPrefix)))
                Dex.Name()
            }
            
            Text(.screen(.session(.emptySessionMessage)))
        }
    }
}
