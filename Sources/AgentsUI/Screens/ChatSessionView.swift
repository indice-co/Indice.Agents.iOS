//
//  ChatSessionView.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 9/7/26.
//

import SwiftUI
import AgentsClient
import AgentsModels

public struct SessionScreen: View {
    
    @StateObject private var model: SessionModel
    
    @State private var message: String = ""
    @FocusState private var focus
    
    
    private var canSendMessage: Bool {
        let hasMessage = !message
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        
        return hasMessage && model.isReady
    }
    
    private var isThinking: Bool {
        model.isLoading || model.isSending
    }
    
    public init(_ client: AgentsClient, chatID: UUID?) {
        self._model = StateObject(wrappedValue: .init(client, chatId: chatID))
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
        .modifier(ScrollToBottom(lastID: model.messages.last?.id))
        .withChatResponder(model)
        .background(content: {
            if model.messages.isEmpty, model.isReady {
                VStack {
                    HStack(alignment: .lastTextBaseline) {
                        Text("I am")
                        Dex.Name()
                    }
                    
                    Text("What can I help you with?")
                }
                
            }
        })
        .animation(.easeInOut, value: model.isLoading)
        .modifier(SafeAreaOrInset {
            VStack(spacing: 8) {
                ThinkingBubble(message: model.progressLabel ?? "Thinking...")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("bubble_indicator")
                    .opacity(isThinking ? 1 : 0)
                    .animation(.easeInOut, value: isThinking)
                
                MessageBox(
                    message: $message,
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
        })
        .navigationTitle(model.metadata.title ?? String(localized: "New chat"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.stop() }
    }
}


// MARK: Components

extension SessionScreen {
    
    struct MessageBox: View {
        @Binding var message: String
        @FocusState private var focus
        
        let usage: DexChatUsage?
        
        let isSending: Bool
        let canSend  : Bool
        
        let send: () -> Void
        let stop: () -> Void
        
        @ViewBuilder
        private func TextInput() -> some View {
            if #available(iOS 16, macOS 14, *) {
                TextField(String(.screen(.session(.inputPrompt))), text: $message, axis: .vertical)
            } else {
                // TextField(String(.screen(.session(.inputPrompt))), text: $message)
                TextEditor(text: $message)
                    .overlay(content: {
                        if message.isEmpty {
                            Text(String(.screen(.session(.inputPrompt))))
                        }
                    })
                
            }
        }
        
        var body: some View {
            VStack {
                HStack(alignment: .firstTextBaseline) {
                    TextInput()
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
                    if let usage, let maxLimit = usage.questionsLimitCount {
                        HStack(spacing: 2) {
                            Text(usage.questionsUsedCount?.formatted() ?? "—")
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
                .padding(.leading, 8)
            }
            .padding(4)
            .modifier(InputBackground(cornerRadius: 16))
            
        }
        
        private func SendButton() -> some View {
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .padding(8)
                    .background(Color.accentColor, in: .circle)
                    .shadow(radius: 4)
            }
            .modifier(ContentShapeConcentricOrRounded(fallbackCornerRadius: 14))
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
            .modifier(ContentShapeConcentricOrRounded(fallbackCornerRadius: 14))
            .buttonStyle(.plain)
            .tint(.red)
            .transition(.opacity)
            .id("action_button")
        }
    }
    
}

private struct InputBackground: ViewModifier {
    
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content.background(.thinMaterial, in: .rect(cornerRadius: cornerRadius))
        }
    }
}

private struct ContentShapeConcentricOrRounded: ViewModifier {
    
    let fallbackCornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content.contentShape(.rect(corners: .concentric))
        } else {
            content.contentShape(.rect(cornerRadius: fallbackCornerRadius))
        }
    }
}

private struct ScrollToBottom<T: Hashable>: ViewModifier {
    
    let lastID: T?
    
    func body(content: Content) -> some View {
        if false, #available(iOS 17, *) {
            content.defaultScrollAnchor(.bottom)
        } else {
            ScrollViewReader { proxy in
                content
                    .onChange(of: lastID) { value in
                        guard let value else { return }
                        withAnimation { proxy.scrollTo(value) }
                    }
            }
        }
    }
}

private struct SafeAreaOrInset<Label: View>: ViewModifier {
    
    var edge: VerticalEdge = .bottom
    let label: () -> Label
    
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content.safeAreaBar(edge: edge) {
                label()
            }
        } else {
            content.safeAreaInset(edge: edge) {
                label()
                    .shadow(radius: 8)
                    .background(.thinMaterial)
            }
        }
    }
    
}




//public struct ChatSessionView: View {
//    
//    // @EnvironmentObject private var state: AppState
//    
//    // @StateObject private var viewModel: ChatSessionViewModel
//    @State private var message: String = ""
//    
//    @FocusState private var focus
//    
//    init(chatId: UUID?/*, service: ChatService*/) {
//        // self._viewModel = .init(wrappedValue: .init(
//        //     service: service, chatId: chatId
//        // ))
//    }
//    
//    private var canSendMessage: Bool {
//        let hasMessage = !message
//            .trimmingCharacters(in: .whitespacesAndNewlines)
//            .isEmpty
//        
//        return hasMessage // && viewModel.isReady
//    }
//    
//    private var isThinking: Bool {
//        false
//        // viewModel.isLoading || viewModel.isSending
//    }
//    
//    var body: some View {
//        ScrollViewReader { scroll in
//            ScrollView {
//                LazyVStack(spacing: 24) {
//                    ForEach(viewModel.messages) { message in
//                        let isLastMessage = message.id == viewModel.messages.last?.id
//                        
//                        MessageItemView(
//                            message: message,
//                            canUseResponderForChoices: isLastMessage)
//                        .id(message.id)
//                    }
//                }
//                .padding()
//                
//                if let error = viewModel.streamError {
//                    Text(error)
//                        .foregroundStyle(.red)
//                        .font(.callout)
//                        .padding()
//                }
//            }
//            .environment(\.chatResponder, viewModel)
//            .background(content: {
//                if viewModel.messages.isEmpty, viewModel.isReady {
//                    VStack {
//                        HStack(alignment: .lastTextBaseline) {
//                            Text("I am")
//                            Dex.Name()
//                        }
//                        
//                        Text("What can I help you with?")
//                    }
//                    
//                }
//            })
//            .defaultScrollAnchor(.bottom)
//            .animation(.easeInOut, value: viewModel.isLoading)
//        }
//        .safeAreaBar(edge: .bottom, content: {
//            VStack(spacing: 8) {
//                ThinkingBubble(message: viewModel.progressLabel ?? "Thinking...")
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .id("bubble_indicator")
//                    .opacity(isThinking ? 1 : 0)
//                    .animation(.easeInOut, value: isThinking)
//                
//                MessageBox(
//                    message: $message,
//                    usage: viewModel.metadata.usage,
//                    isSending: viewModel.isSending,
//                    canSend: canSendMessage,
//                    send: {
//                        viewModel.post(message: message)
//                        message = ""
//                    },
//                    stop: { viewModel.stop() })
//            }
//            .padding()
//        })
//        .navigationTitle(viewModel.metadata.title ?? String(localized: "New chat"))
//        .navigationBarTitleDisplayMode(.inline)
//        .onDisappear {
//            viewModel.stop()
//            state.refreshChats(force: true)
//        }
//    }
//    
//    // MARK: Components
//    
//    struct MessageBox: View {
//        @Binding var message: String
//        @FocusState private var focus
//        
//        let usage: DexChatUsage?
//        
//        let isSending: Bool
//        let canSend  : Bool
//        
//        let send: () -> Void
//        let stop: () -> Void
//        
//        var body: some View {
//            VStack {
//                HStack(alignment: .firstTextBaseline) {
//                    TextField("What's on your mind?", text: $message, axis: .vertical)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .focused($focus)
//                    
//                    if false, !message.isEmpty {
//                        Button(action: { message = "" }) {
//                            Image(systemName: "xmark.circle.fill")
//                        }
//                        .buttonStyle(.plain)
//                    }
//                }
//                .padding(.horizontal, 8)
//                .padding(.top,     8)
//                .padding(.bottom,  4)
//                .onTapGesture { focus = true }
//                
//                HStack {
//                    if let usage, let maxLimit = usage.questionsLimitCount {
//                        HStack(spacing: 2) {
//                            Text(usage.questionsUsedCount?.formatted() ?? "—")
//                            Text("of")
//                            Text(maxLimit.formatted())
//                        }
//                        .font(.caption2)
//                        .foregroundStyle(.secondary)
//                    }
//                    
//                    Spacer()
//                    
//                    if isSending {
//                        StopButton()
//                    } else {
//                        SendButton()
//                    }
//                }
//                .padding(.leading, 8)
//            }
//            .padding(4)
//            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
//            
//        }
//        
//        private func SendButton() -> some View {
//            Button(action: send) {
//                Image(systemName: "arrow.up")
//                    .padding(8)
//                    .background(Color.accentColor, in: .circle)
//                    .shadow(radius: 4)
//            }
//            .contentShape(.rect(corners: .concentric))
//            .buttonStyle(.plain)
//            .transition(.opacity)
//            .disabled(!canSend)
//            .id("action_button")
//        }
//        
//        private func StopButton() -> some View {
//            Button(action: stop) {
//                Image(systemName: "stop.fill")
//                    .padding(8)
//                    .background(.red, in: .circle)
//                    .shadow(radius: 4)
//            }
//            .contentShape(.rect(corners: .concentric))
//            .buttonStyle(.plain)
//            .tint(.red)
//            .transition(.opacity)
//            .id("action_button")
//        }
//    }
//}
//
//
//protocol ChatSelectionResponder: AnyObject {
//    func response(withMessage message: String)
//    func score(_ score: MessageScore, messageId: DexChatMessage.ID)
//}
//
//extension EnvironmentValues {
//    @Entry
//    // fileprivate(set)
//    var chatResponder: ChatSelectionResponder?
//}
//
//
//#Preview {
//    
//    @Previewable
//    @State var message: String = """
//        asdf ljka
//        """
//    
//    @Previewable
//    @State var isSending: Bool = false
//    
//    
//    ScrollView {
//        ForEach(0 ..< 100) { index in
//            Text(index.formatted())
//        }
//    }
//    .safeAreaInset(edge: .bottom) {
//        ChatSessionView.MessageBox(
//            message: $message,
//            usage: .init(questionsUsedCount: 2, questionsLimitCount: 5),
//            isSending: isSending,
//            canSend: !message.isEmpty,
//            send: { Task {
//                isSending = true
//                try? await Task.sleep(for: .seconds(2))
//                isSending = false
//            } },
//            stop: { })
//        .animation(.interactiveSpring, value: isSending)
//        .padding()
//    }
//}
