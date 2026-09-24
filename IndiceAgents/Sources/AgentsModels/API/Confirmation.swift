import Foundation

/// JSON payload of an `application/vnd.indice.confirm+json` part.
public struct Confirmation: APIModel, Hashable {
    public var prompt: String?
    /// Button labels are also the verbatim user messages sent when selected.
    public var confirmText: String
    public var cancelText: String

    public init(prompt: String? = nil, confirmText: String = "Yes", cancelText: String = "No") {
        self.prompt = prompt
        self.confirmText = confirmText
        self.cancelText = cancelText
    }
}
