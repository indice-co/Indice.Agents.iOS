//
//  Citation.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 29/9/26.
//

import SwiftUI
import Foundation
import AgentsClient
import AgentsModels

public struct CitationView: View {
    
    @State private var isExpanded = false
    
    @Environment(\.openURL) var openURL
    
    let message: ChatSessionService.Message
    let previewCitationsCount: Int
    
    public init(message: ChatSessionService.Message, previewCitationsCount: Int = 3) {
        self.message = message
        self.previewCitationsCount = previewCitationsCount
    }
    
    public var body: some View {
        if let citations = message.value.citations, !citations.isEmpty {
            VStack(alignment: .leading) {
                HStack(spacing: -10) {
                    if isExpanded {
                        Text("Collapse \(Image(systemName: "chevron.up"))")
                            .frame(minHeight: 20)
                            .padding(.horizontal, 8)
                    } else {
                        ForEach(Array(citations.prefix(previewCitationsCount).enumerated()), id: \.offset) { item in
                            if let fav = faviconUrl(item.element.sourceUrl) {
                                AsyncImage(url: fav) {
                                    $0.image?
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 16, height: 16)
                                        .padding(4)
                                }
                                .background(.background.secondaryOrSelf())
                                .clipShape(.circle)
                                .overlay {
                                    Circle()
                                        .strokeBorder(.background.tertiaryOrSelf(), lineWidth: 1)
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
                .background(.background.secondaryOrSelf(), in: .capsule)
                .onTapGesture {
                    withAnimation(.interactiveSpring) {
                        isExpanded.toggle()
                    }
                }
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(citations.enumerated()), id: \.offset) { item in
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
            Button(action: { openURL.open(url, prefersInApp: true) }) {
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
            let domain = URL(string: url)?.host,
            let fav = URL(string: "https://www.google.com/s2/favicons?sz=64&domain=\(domain)")
        else { return nil }
        
        return fav
    }
}
