//
//  ChatSessionView.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 9/7/26.
//

import SwiftUI
import IndiceAgents
import AgentsModels

struct ChatSessionView: View {
    
    @EnvironmentObject private var state: AppState
    
    @StateObject private var viewModel: ChatSessionViewModel
    @State private var message: String = ""
    
    @FocusState private var focus
    
    init(chatId: UUID?, service: ChatService) {
        self._viewModel = .init(wrappedValue: .init(
            service: service, chatId: chatId
        ))
    }
    
    private var canSendMessage: Bool {
        let hasMessage = !message
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        
        return hasMessage && viewModel.isReady
    }
    
    private var isThinking: Bool {
        viewModel.isLoading || viewModel.isSending
    }
    
    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                LazyVStack(spacing: 24) {
                    ForEach(viewModel.messages) { message in
                        let isLastMessage = message.id == viewModel.messages.last?.id
                        
                        MessageItemView(message: message)
                            .id(message.id)
                            .environment(\.chatResponder, isLastMessage ? viewModel : nil)
                    }
                }
                .padding()
                
                if let error = viewModel.streamError {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                        .padding()
                }
            }
            .background(content: {
                if viewModel.messages.isEmpty, viewModel.isReady {
                    VStack {
                        HStack(alignment: .lastTextBaseline) {
                            Text("I am")
                            Dex.Name()
                        }
                        
                        Text("What can I help you with?")
                    }
                    
                }
            })
            .defaultScrollAnchor(.bottom)
            .animation(.easeInOut, value: viewModel.isLoading)
        }
        .safeAreaBar(edge: .bottom, content: {
            VStack(spacing: 8) {
                ThinkingBubble(message: viewModel.progressLabel ?? "Thinking...")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("bubble_indicator")
                    .opacity(isThinking ? 1 : 0)
                    .animation(.easeInOut, value: isThinking)
                
                MessageBox(
                    message: $message,
                    response: nil, // viewModel.messages.last?.value,
                    isSending: viewModel.isSending,
                    canSend: canSendMessage,
                    send: {
                        viewModel.post(message: message)
                        message = ""
                    },
                    stop: { viewModel.stop() })
            }
            .padding()
        })
        .onDisappear {
            viewModel.stop()
            state.refreshChats(force: true)
        }
    }
    
    // MARK: Components
    
    struct MessageBox: View {
        @Binding var message: String
        @FocusState private var focus
        
        let response: DexChatResponse?
        
        let isSending: Bool
        let canSend  : Bool
        
        let send: () -> Void
        let stop: () -> Void
        
        var body: some View {
            VStack {
                HStack(alignment: .firstTextBaseline) {
                    TextField("What's on your mind?", text: $message, axis: .vertical)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .focused($focus)
                    
                    if false, !message.isEmpty {
                        Button(action: { message = "" }) {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top,     8)
                .padding(.bottom,  4)
                .onTapGesture { focus = true }
                
                HStack {
                    if let usage = response?.usage, let maxLimit = usage.questionsLimitCount {
                        HStack(spacing: 2) {
                            Text((usage.questionsUsedCount ?? 0).formatted())
                            Text("of")
                            Text(maxLimit.formatted())
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if isSending {
                        StopButton()
                    } else {
                        SendButton()
                    }
                }
            }
            .padding(4)
            .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 16))
            
        }
        
        private func SendButton() -> some View {
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .padding(8)
                    .background(Color.accentColor, in: .circle)
                    .shadow(radius: 4)
            }
            .contentShape(.rect(corners: .concentric))
            .buttonStyle(.plain)
            .transition(.opacity)
            .disabled(!canSend)
            .id("action_button")
        }
        
        private func StopButton() -> some View {
            Button(action: stop) {
                Image(systemName: "stop.fill")
                    .padding(8)
                    .background(.red, in: .circle)
                    .shadow(radius: 4)
            }
            .contentShape(.rect(corners: .concentric))
            .buttonStyle(.plain)
            .tint(.red)
            .transition(.opacity)
            .id("action_button")
        }
    }
}


protocol ChatSelectionResponder: AnyObject {
    func response(withMessage message: String)
}

extension EnvironmentValues {
    @Entry
    fileprivate(set)
    var chatResponder: ChatSelectionResponder?
}


#Preview {
    
    @Previewable
    @State var message: String = """
        asdf ljka
        """
    
    @Previewable
    @State var isSending: Bool = false
    
    
    ScrollView {
        ForEach(0 ..< 100) { index in
            Text(index.formatted())
        }
    }
    .safeAreaInset(edge: .bottom) {
        ChatSessionView.MessageBox(
            message: $message,
            response: nil,
            isSending: isSending,
            canSend: !message.isEmpty,
            send: { Task {
                isSending = true
                try? await Task.sleep(for: .seconds(2))
                isSending = false
            } },
            stop: { })
        .animation(.interactiveSpring, value: isSending)
        .padding()
    }
}
