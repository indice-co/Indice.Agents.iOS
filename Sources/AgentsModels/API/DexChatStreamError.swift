import Foundation

public struct DexChatStreamError: APIModel, Hashable {
    public let type: String = "error"
    public var reason: String

    public init(reason: String) {
        self.reason = reason
    }

    private enum CodingKeys: String, CodingKey {
        case type, reason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let type = try container.decodeIfPresent(String.self, forKey: .type), type != "error" {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unexpected stream discriminator")
        }
        reason = try container.decode(String.self, forKey: .reason)
    }
}

/// OpenAPI schema spelling; the shorter name mirrors the backend payload type.
public typealias DexChatResponseUpdateDexChatStreamError = DexChatStreamError
