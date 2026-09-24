import SwiftUI
import UIKit
import IndiceAgents

/// The showcase's dispatch point. A host app can switch over the same enum and
/// provide different native components without changing the API/network layers.
struct ChatContentItemView: View, Equatable {
    
    let item: ChatContentItem
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch item.content {
            case .text(let text):
                ChatItem.RawText(value: text)
                
            case .markdown(let markdown):
                ChatItem.Markdown(value: markdown)
                
            case .html(let html):
                ChatHTMLView(html: html)
                
            case .imageData(let data, let mediaType):
                ChatItem.Image(
                    data: data,
                    mediaType: mediaType,
                    caption: item.caption,
                    isStreaming: isStreaming)
                
            case .imageURL(let url):
                ChatItem.AsyncImage(
                    url: url,
                    caption: item.caption,
                    isStreaming: isStreaming)
                
            case .multipleChoice(let data):
                ChatItem.MultipleChoices(
                    options: data.options)
                
            case .callout(let data):
                ChatItem.Callout(
                    data.severity,
                    title: data.title,
                    content: data.text)
                
            case .confirmation(let data):
                ChatItem.Confirmation(
                    prompt: data.prompt,
                    positive: data.confirmText,
                    negative: data.cancelText)
                
            case .unsupported(let mediaType):
                ChatItem.UnavailableType(
                    isLoading: false,
                    mediaType: mediaType)
                
            case .unavailable(let mediaType):
                ChatItem.UnavailableType(
                    isLoading: false,
                    mediaType: mediaType)
            }
            
            if let caption = item.caption {
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}


// MARK: Components

enum ChatItem {
    
    struct UnavailableType: View {
        let isLoading: Bool
        let mediaType: String?
        
        var body: some View {
            if isLoading {
                ProgressView("Loading content…").font(.caption)
            } else {
                Label("Unavailable Mmedia Type \(mediaType ?? "-")", systemImage: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.red.secondary, in: .capsule)
            }
        }
    }
    
    struct RawText: View {
        let value: String
        var body: some View {
            Text(value)
                .textSelection(.enabled)
        }
    }
    
    struct Markdown: View {
        let value: String
        
        private var resolved: AttributedString {
            (try? AttributedString(
                markdown: value,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(value)
        }
        
        var body: some View {
            Text(resolved)
                .textSelection(.enabled)
        }
    }
    
    struct Image: View {
        let data: Data
        let mediaType: String
        let caption: String?
        let isStreaming: Bool
        
        var body: some View {
            if mediaType == "image/svg+xml" {
                // UIKit does not decode SVG. In an <img>, WebKit renders SVG
                // as an image; the embedded document's scripts stay disabled.
                ChatHTMLView(html: "<img alt=\"\" src=\"data:image/svg+xml;base64,\(data.base64EncodedString())\">")
            } else if let image = UIImage(data: data) {
                SwiftUI.Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(caption ?? "Image")
            } else {
                UnavailableType(
                    isLoading: isStreaming,
                    mediaType: mediaType)
            }
        }
    }
    
    struct AsyncImage: View {
        let url: URL
        let caption: String?
        let isStreaming: Bool
        
        var body: some View {
            SwiftUI.AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 60)
                    
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel(caption ?? "Image")
                    
                case .failure: UnavailableType(isLoading: isStreaming, mediaType: nil)
                @unknown default: UnavailableType(isLoading: isStreaming, mediaType: nil)
                }
            }
        }
    }
    
    struct Callout: View {
        
        typealias Severity = AgentsModels::Callout.Severity
        
        let severity: Severity
        let title: String?
        let content: String
        
        init(_ severity: Severity = .info, title: String?, content: String) {
            self.severity = .error //severity
            self.title = title
            self.content = content
        }
        
        private var shape: RoundedRectangle {
            .init(cornerRadius: 8)
        }
        
        private var foreground: Color {
            switch severity {
            case .info:
                Color.primary
            case .success:
                Color.green
            case .warning:
                Color.orange
            case .error:
                Color.red
            }
        }
        
        private var background: AnyShapeStyle {
            severity == .info
            ? AnyShapeStyle(.gray.opacity(0.1))
            : AnyShapeStyle(foreground.quaternary)
        }
        
        private var imageName: String {
            switch severity {
            case .info:
                "info.circle"
            case .success:
                "checkmark.circle.fill"
            case .warning:
                "exclamationmark.triangle.fill"
            case .error:
                "exclamationmark.triangle.fill"
            }
        }
        
        var body: some View {
            
            HStack(alignment: .top, spacing: 16) {
                SwiftUI
                    .Image(systemName: imageName)
                    .resizable()
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 12) {
                    if let title {
                        Text(title)
                            .font(.callout.bold())
                    }
                    
                    Text(content)
                        .font(.callout)
                }
            }
            .foregroundStyle(foreground)
            .padding(12)
            .background(background, in: shape)
        }
    }
    
    struct Confirmation: View {
        enum Choice {
            case positive
            case negative
        }
        
        @Environment(\.chatResponder) var chatResponder
        
        let prompt: String?
        let positive: String
        let negative: String
        
        var body: some View {
            
            VStack {
             
                if let prompt {
                    Text(prompt)
                }
                
                HStack {
                    Button(role: .confirm, action: {
                        chatResponder?.response(withMessage: positive)
                    }) {
                        Text(positive)
                            .frame(maxWidth: .infinity)
                        // .padding()
                        // .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(role: .destructive, action: {
                        chatResponder?.response(withMessage: negative)
                    }) {
                        Text(negative)
                            .frame(maxWidth: .infinity)
                        // .padding()
                        // .glassEffect(.regular.interactive().tint(.red.opacity(0.5)), in: .capsule)
                    }
                    .buttonStyle(.bordered)
                }
                .disabled(chatResponder == nil)
            }
        }
    }
    
    struct MultipleChoices: View {
        
        @Environment(\.chatResponder) var chatResponder
        
        let options: [String]
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button(option, action: { chatResponder?.response(withMessage: option) })
                        .buttonStyle(.borderedProminent)
                }
            }
            .disabled(chatResponder == nil)
        }
    }
}


import Combine
import AgentsModels

struct Showcase: View {
    private final class VM: ObservableObject {
        let items: [ChatSessionService.Message]
        
        init() {
            self.items = (Mocks.response().messages ?? [])
                .map { .init(value: $0) }
        }
        
    }
    
    @StateObject private var model = VM()
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(model.items) { item in
                    MessageItemView(message: item)
                }
            }
            .padding()
        }
    }
}


#Preview {
    Showcase()
}
