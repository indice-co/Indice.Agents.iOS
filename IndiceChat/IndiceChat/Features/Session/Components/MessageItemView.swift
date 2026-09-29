//
//  MessageItemView.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 24/9/26.
//

import SwiftUI
import IndiceAgents
import AgentsModels

struct MessageItemView: View {
    
    @Environment(\.chatResponder) var chatResponder
    
    let message: ChatSessionService.Message
    let canUseResponderForChoices: Bool
    
    private var isUser: Bool {
        message.value.role == .user
    }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 0) {
            if !isUser {
                Dex.ImageAndName(size: .small)
                    .padding(.top, 12)
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                ForEach(message.items) { item in
                    ChatContentItemView(
                        item: item,
                        isStreaming: message.delivery == .streaming)
                    .equatable()
                    .modifier(BackgroundApplier(isUser: isUser))
                    .environment(\.chatResponder, canUseResponderForChoices ? chatResponder : nil)
                }
                
                if !isUser {
                    CitationView(message: message)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let chatResponder, message.delivery == .complete {
                        MessageActionsView(
                            onScore: { chatResponder.score($0, messageId: message.value.messageId) },
                            currentScore: message.value.liked.map { $0 ? .positive : .negative })
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                    }
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
        }
        .padding(isUser ? .leading : .trailing)
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
    
    private struct BackgroundApplier: ViewModifier {
        let isUser: Bool
        
        private let userColor: Color = Color.brand
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
