import Foundation

/// JSON payload of an `application/vnd.indice.multiple-choice+json` part.
public struct MultipleChoice: APIModel, Hashable {
    /// Options in display order. A selection is posted verbatim as a user message.
    public var options: [String]

    public init(options: [String] = []) {
        self.options = options
    }
}
