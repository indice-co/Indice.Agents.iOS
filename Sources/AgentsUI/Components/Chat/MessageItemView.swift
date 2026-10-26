//
//  MessageItemView.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 24/9/26.
//

import SwiftUI
import AgentsClient
import AgentsModels

public struct MessageItemView: View {
    
    @Environment(\.chatResponder) var chatResponder
    
    let message: ChatSessionService.Message
    let canUseResponderForChoices: Bool
    
    public init(message: ChatSessionService.Message, canUseResponderForChoices: Bool) {
        self.message = message
        self.canUseResponderForChoices = canUseResponderForChoices
    }
    
    private var isUser: Bool {
        message.value.role == .user
    }
    
    public var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
            ForEach(message.items) { item in
                ChatContentItemView(
                    item: item,
                    isStreaming: message.delivery == .streaming)
                .equatable()
                .modifier(BackgroundApplier(isUser: isUser))
                .withChatResponder(canUseResponderForChoices ? chatResponder : nil)
                .transition(.opacity)
                .animation(.default, value: item)
            }
            
            if !isUser {
                CitationView(message: message)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let chatResponder, message.delivery == .complete {
                    MessageActionsView(
                        onScore: { chatResponder.score($0, messageId: message.value.messageId) },
                        currentScore: message.value.liked.map { $0 ? .positive : .negative })
                    .padding(.top)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
                }
            }
            
            if message.delivery == .cancelled {
                Text(.screen(.session(.messageStatusStoppedPartialReply)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
            } else if message.delivery == .interrupted {
                Text(.screen(.session(.messageStatusIncompleteReply)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private struct BackgroundApplier: ViewModifier {
        
        @Environment(\.useGlassStyleIfAvailable) var useGlass
        @Environment(\.agentsUITheme) private var theme
        
        let isUser: Bool
        
        private var userColor: Color { theme.primaryColor }
        private var userTextColor: Color { theme.onPrimaryColor }
        
        private let agentColor: Color = .clear
        
        private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        
        private var color: Color {
            isUser ? userColor : agentColor
        }
        
        func body(content: Content) -> some View {
            if isUser {
                if useGlass, #available(iOS 26, macOS 26, *) {
                    content
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .foregroundStyle(userTextColor)
                        .glassEffect(.regular.tint(color), in: shape)
                } else {
                    content
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .foregroundStyle(userTextColor)
                        .background(color, in: shape)
                }
            } else {
                content
                    .padding(.vertical)
            }
        }
    }
}
