//
//  AttributedStringOptions.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 20/10/26.
//


import SwiftUI

enum SuperscriptAttribute:
    CodableAttributedStringKey,
    MarkdownDecodableAttributedStringKey
{
    typealias Value = Bool
    static let name = "superscript"
}

struct CitationAttributes: AttributeScope {
    let superscript: SuperscriptAttribute
    let swiftUI: AttributeScopes.SwiftUIAttributes
}


extension AttributedString {
    enum MarkdownFallback {
        case plainText
    }
    
    init(markdown: String) throws {
        self = try parseMarkdown(markdown
            .replacingOccurrences(of: "<sup>",  with: "^[[")
            .replacingOccurrences(of: "</sup>", with: "]](superscript: true)")
        )
    }
    
    init(markdown: String, fallback: MarkdownFallback) {
        do {
            try self.init(markdown: markdown)
        } catch {
            switch fallback {
            case .plainText: self.init(markdown)
            }
        }
    }
}


func parseMarkdown(_ markdown: String) throws -> AttributedString {
    var text = try AttributedString(
        markdown: markdown,
        including: CitationAttributes.self,
        options: .init(
            allowsExtendedAttributes: true,
            interpretedSyntax: .inlineOnlyPreservingWhitespace))

    // Collect ranges before modifying the attributes.
    let superscriptRanges = text.runs.compactMap { run in
        run[SuperscriptAttribute.self] == true ? run.range : nil
    }

    for range in superscriptRanges {
        text[range].font = .footnote.bold()
        text[range].baselineOffset = 6
    }

    return text
}
