import Foundation

/// The JSON `data:` payload of an SSE event. SSE framing is handled by the service
/// target; this enum knows only about the API's `type` discriminator.
public enum DexChatResponseUpdate: APIModel, Hashable {
    case start(DexChatStreamStart)
    case status(DexChatStreamStatus)
    case delta(DexChatStreamDelta)
    case error(DexChatStreamError)
    case done(DexChatStreamDone)
    /// Future frame types must be ignored by consumers, but remain round-trippable.
    case unknown(type: String, payload: JSONValue)

    private enum CodingKeys: String, CodingKey { case type }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "start": self = .start(try .init(from: decoder))
        case "status": self = .status(try .init(from: decoder))
        case "delta": self = .delta(try .init(from: decoder))
        case "error": self = .error(try .init(from: decoder))
        case "done": self = .done(try .init(from: decoder))
        default: self = .unknown(type: type, payload: try .init(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .start(let value): try value.encode(to: encoder)
        case .status(let value): try value.encode(to: encoder)
        case .delta(let value): try value.encode(to: encoder)
        case .error(let value): try value.encode(to: encoder)
        case .done(let value): try value.encode(to: encoder)
        case .unknown(let type, let payload):
            guard case .object(var object) = payload else {
                throw EncodingError.invalidValue(payload, .init(codingPath: encoder.codingPath, debugDescription: "A stream payload must be an object"))
            }
            object["type"] = .string(type)
            try JSONValue.object(object).encode(to: encoder)
        }
    }
}
