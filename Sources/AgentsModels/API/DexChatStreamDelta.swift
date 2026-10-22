import Foundation

public struct DexChatStreamDelta: APIModel, Hashable {
    public let type: String = "delta"
    public var path: String?
    public var op: DexChatPatchOp?
    public var value: JSONValue?

    public init(path: String? = nil, op: DexChatPatchOp? = nil, value: JSONValue? = nil) {
        self.path = path
        self.op = op
        self.value = value
    }

    private enum CodingKeys: String, CodingKey {
        case type, path, op, value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let type = try container.decodeIfPresent(String.self, forKey: .type), type != "delta" {
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unexpected stream discriminator")
        }
        path = try container.decodeIfPresent(String.self, forKey: .path)
        op = try container.decodeIfPresent(DexChatPatchOp.self, forKey: .op)
        value = try container.decodeIfPresent(JSONValue.self, forKey: .value)
    }
}

/// OpenAPI schema spelling; the shorter name mirrors the backend payload type.
public typealias DexChatResponseUpdateDexChatStreamDelta = DexChatStreamDelta
