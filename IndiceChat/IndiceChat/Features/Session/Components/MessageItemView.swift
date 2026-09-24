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


struct Citation: View {
    
    let message: ChatSessionService.Message
    
    var body: some View {
        if let citations = message.value.citations {
            
        }
        
        
    }
    
}
