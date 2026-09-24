import Foundation

/// Raw API payload from agents.json: `DocumentType`.
public enum DocumentType: String, APIModel, Hashable, CaseIterable {
    case markdownFAQ = "MarkdownFaq"
    case markdown = "Markdown"
}
