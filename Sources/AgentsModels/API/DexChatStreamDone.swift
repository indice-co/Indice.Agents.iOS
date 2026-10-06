import Foundation

public struct DexChatStreamDone: APIModel, Hashable {
    public let type: String = "done"

    public init() {
    }

    private enum CodingKeys: String, CodingKey {
        case type
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let type = try container.decodeIfPresent(String.self, forKey: .type), type != "done" {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unexpected stream discriminator")
        }
    }
}

/// OpenAPI schema spelling; the shorter name mirrors the backend payload type.
public typealias DexChatResponseUpdateDexChatStreamDone = DexChatStreamDone
