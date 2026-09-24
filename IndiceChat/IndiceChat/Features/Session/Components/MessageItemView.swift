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
            
            Citation(message: message)
                .frame(maxWidth: .infinity, alignment: .leading)
            
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
    
    @State private var isExpanded = false
    
    @Environment(\.openURL) var openURL
    
    let message: ChatSessionService.Message
    let previewCitationsCount = 3
    
    var body: some View {
        if let citations = message.value.citations, !citations.isEmpty {
            VStack(alignment: .leading) {
                HStack(spacing: -10) {
                    if isExpanded {
                        Text("Collapse \(Image(systemName: "chevron.up"))")
                            .frame(minHeight: 20)
                            .padding(.horizontal, 8)
                    } else {
                        ForEach(citations.prefix(previewCitationsCount).enumerated(), id: \.offset) { item in
                            if let fav = faviconUrl(item.element.sourceUrl) {
                                AsyncImage(url: fav) {
                                    $0.image?
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 16, height: 16)
                                        .padding(4)
                                }
                                .background(.background.secondary)
                                .clipShape(.circle)
                                .overlay {
                                    Circle()
                                        .strokeBorder(.background.tertiary, lineWidth: 1)
                                }
                            }
                        }
                        
                        if citations.count > previewCitationsCount {
                            Text(verbatim: "+" + (citations.count - previewCitationsCount).formatted())
                                .padding(.leading, 18)
                                .padding(.trailing, 8)
                        }
                        
                        Image(systemName: "chevron.down")
                            .padding(.leading, 18)
                            .padding(.trailing, 8)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(4)
                .background(.background.secondary, in: .capsule)
                .onTapGesture {
                    withAnimation(.interactiveSpring) {
                        isExpanded.toggle()
                    }
                }
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(citations.enumerated(), id: \.offset) { item in
                            CitationDetails(item.element, offset: item.offset)
                        }
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            }
            .animation(.interactiveSpring, value: isExpanded)
        }
    }
    
    @ViewBuilder
    private func CitationDetails(_ citation: AgentsModels::Citation, offset: Int) -> some View {
        if let url = URL(string: citation.sourceUrl ?? "")  {
            Button(action: { openURL.callAsFunction(url, prefersInApp: true) }) {
                VStack {
                    HStack {
                        HStack(spacing: 2) {
                            Text((citation.number ?? offset + 1).formatted())
                                .frame(minWidth: 16)
                            
                            Text(citation.title ?? citation.sourceUrl ?? "")
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.forward.square")
                    }
                    
                    Color.secondary.opacity(0.5).frame(height: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    
    private func faviconUrl(_ url: String?) -> URL? {
        guard
            let url,
            let domain = URL(string: url)?.host(),
            let fav = URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(domain)")
        else { return nil }
        
        return fav
    }

    
    
}
