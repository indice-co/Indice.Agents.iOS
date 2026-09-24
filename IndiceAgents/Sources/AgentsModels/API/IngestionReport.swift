import Foundation

/// Raw API payload from agents.json: `IngestionReport`.
public struct IngestionReport: APIModel, Hashable {
    public var documentId: UUID?
    public var source: String?
    public var chunksCreated: Int?
    public var skipped: Bool?
    public var skippedReason: String?
    public var replaced: Bool?

    public init(
        documentId: UUID? = nil,
        source: String? = nil,
        chunksCreated: Int? = nil,
        skipped: Bool? = nil,
        skippedReason: String? = nil,
        replaced: Bool? = nil
    ) {
        self.documentId = documentId
        self.source = source
        self.chunksCreated = chunksCreated
        self.skipped = skipped
        self.skippedReason = skippedReason
        self.replaced = replaced
    }

    private enum CodingKeys: String, CodingKey {
        case documentId, source, chunksCreated, skipped, skippedReason, replaced
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        documentId = try container.decodeIfPresent(UUID.self, forKey: .documentId)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        chunksCreated = try container.decodeAPINumberIfPresent(Int.self, forKey: .chunksCreated)
        skipped = try container.decodeIfPresent(Bool.self, forKey: .skipped)
        skippedReason = try container.decodeIfPresent(String.self, forKey: .skippedReason)
        replaced = try container.decodeIfPresent(Bool.self, forKey: .replaced)
    }
}
