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
                    
                    if isThinking {
                        ThinkingBubble(message: viewModel.progressLabel ?? "Thinking...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("bubble_indicator")
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
            // .onChange(of: viewModel.messages.last, { _, _ in
            //     guard let id = viewModel.messages.last?.id else { return }
            // 
            //     withAnimation {
            //         if isThinking {
            //             scroll.scrollTo("bubble_indicator", anchor: .bottom)
            //         } else {
            //             scroll.scrollTo(id, anchor: .bottom)
            //         }
            //     }
            // })
        }
        .safeAreaBar(edge: .bottom, content: {
            MessageBox(
                message: $message,
                isSending: viewModel.isSending,
                canSend: canSendMessage,
                send: {
                    viewModel.post(message: message)
                    message = ""
                },
                stop: { viewModel.stop() })
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
        
        let isSending: Bool
        let canSend  : Bool
        
        let send: () -> Void
        let stop: () -> Void
        
        var body: some View {
            HStack {
                TextField("What's on your mind?", text: $message, axis: .vertical)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focused($focus)
                    .padding(.horizontal)
                
                if isSending {
                    StopButton()
                } else {
                    SendButton()
                }
            }
            .padding(4)
            .glassEffect(.clear.interactive(), in: .rect(cornerRadius: 32))
            .onTapGesture { focus = true }
        }
        
        @ViewBuilder
        private func SendButton() -> some View {
            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
            }
            .buttonStyle(.glassProminent)
            .transition(.opacity)
            .disabled(!canSend)
            .id("action_button")
        }
        
        @ViewBuilder
        private func StopButton() -> some View {
            Button(action: stop) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.glassProminent)
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


import Combine

private final class ChatSessionViewModel: ViewModel, ChatSelectionResponder {
    @Published private(set) var messages: [ChatSessionService.Message] = []
    @Published private(set) var isSending = false
    @Published private(set) var isReady = false
    @Published private(set) var progressLabel: String?
    @Published private(set) var streamError: String?
    @Published var talkingToMySelf = false

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

struct MessageItemView: View {
    let message: ChatSessionService.Message
    
    private var isUser: Bool {
        message.value.role == .user
    }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
            ForEach(message.items) { item in
                ChatContentItemView(
                    item: item,
                    isStreaming: message.delivery == .streaming)
                .equatable()
                .modifier(BackgroundApplier(isUser: isUser))
            }
            
            if message.delivery == .cancelled {
                Text("Stopped — partial reply")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
            } else if message.delivery == .interrupted {
                Text("Incomplete reply")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .padding(isUser ? .leading : .trailing)
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
    
    private struct BackgroundApplier: ViewModifier {
        let isUser: Bool
        
        private let userColor: Color = .accentColor.opacity(0.5)
        private let agentColor: Color = .clear
        
        private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        
        private var color: Color {
            isUser ? userColor : agentColor
        }
        
        func body(content: Content) -> some View {
            if isUser {
                if #available(iOS 26, *) {
                    content
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .glassEffect(.regular.tint(color), in: shape)
                } else {
                    content
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .background(color, in: shape)
                }
            } else {
                content
                    .padding(.vertical)
            }
        }
    }
    
}

struct ThinkingBubble: View {
    
    private let dotSize: CGFloat = 8
    private let offset : CGFloat = .pi * 0.25
    
    private var corners: (large: CGFloat, small: CGFloat) {
        let large = dotSize * 1.5
        let small = dotSize * 0.5
        
        return (large, small)
    }
    
    private var shape: UnevenRoundedRectangle {
        let corners = self.corners
        
        return .init(
            topLeadingRadius: corners.large,
            bottomLeadingRadius: corners.large,
            bottomTrailingRadius: corners.small,
            topTrailingRadius: corners.large,
            style: .continuous)
    }
    
    let message: String?
    
    var body: some View {
        TimelineView(.animation) { context in
            let progress = context
                .date
                .timeIntervalSince1970
            
            HStack(spacing: 2) {
                ForEach(0 ..< 3) { index in
                    
                    let phase = sin(progress * (CGFloat.pi * 2) + (CGFloat(index) * offset))
                    
                    Circle()
                        .fill(Color.blue)
                        .frame(width: dotSize, height: dotSize)
                        .transformEffect(.init(
                            translationX: 0,
                            y: (dotSize / 2) * phase))
                }
                
                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: dotSize * 2)
        }
        .padding(dotSize)
        // .modifier(BackgroundApplier(shape: shape))
        .transition(
            .move(edge: .top)
            .combined(with: .opacity))
    }
 
    private struct BackgroundApplier<S: Shape>: ViewModifier {
        let shape: S
        func body(content: Self.Content) -> some View {
            if #available(iOS 26, *) {
                content.glassEffect(.clear.interactive(), in: shape)
            } else {
                content.background(.thinMaterial, in: shape)
            }
        }
    }
    
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
