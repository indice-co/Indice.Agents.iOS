import Foundation

/// Raw API payload from agents.json: `LikeRequest`.
public struct LikeRequest: APIModel, Hashable {
    public var like: Bool?

    public init(
        like: Bool? = nil
    ) {
        self.like = like
    }

    private enum CodingKeys: String, CodingKey {
        case like
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        like = try container.decodeIfPresent(Bool.self, forKey: .like)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Explicit null clears previous feedback; false is a dislike.
        try container.encode(like, forKey: .like)
    }
}
