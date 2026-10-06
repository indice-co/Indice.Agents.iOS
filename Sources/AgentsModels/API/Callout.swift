import Foundation

/// JSON payload of an `application/vnd.indice.callout+json` part.
public struct Callout: APIModel, Hashable {
    public enum Severity: String, APIModel, Hashable, CaseIterable {
        case info
        case success
        case warning
        case error

        /// Future server values use the same fallback as the web client.
        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            self = Self(rawValue: try container.decode(String.self)) ?? .info
        }
    }

    public var severity: Severity
    public var title: String?
    /// Plain text, with line breaks preserved; not Markdown.
    public var text: String

    public init(severity: Severity = .info, title: String? = nil, text: String) {
        self.severity = severity
        self.title = title
        self.text = text
    }
}
