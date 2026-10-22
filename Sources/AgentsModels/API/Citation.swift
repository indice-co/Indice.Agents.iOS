import Foundation

/// Raw API payload from agents.json: `Citation`.
public struct Citation: APIModel, Hashable {
    public var chunkId: UUID?
    public var documentId: UUID?
    public var title: String?
    public var snippet: String?
    public var sourceUrl: String?
    public var headingPath: String?
    public var number: Int?
    public var score: Double?

    public init(
        chunkId: UUID? = nil,
        documentId: UUID? = nil,
        title: String? = nil,
        snippet: String? = nil,
        sourceUrl: String? = nil,
        headingPath: String? = nil,
        number: Int? = nil,
        score: Double? = nil
    ) {
        self.chunkId = chunkId
        self.documentId = documentId
        self.title = title
        self.snippet = snippet
        self.sourceUrl = sourceUrl
        self.headingPath = headingPath
        self.number = number
        self.score = score
    }

    private enum CodingKeys: String, CodingKey {
        case chunkId, documentId, title, snippet, sourceUrl, headingPath, number, score
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        chunkId = try container.decodeIfPresent(UUID.self, forKey: .chunkId)
        documentId = try container.decodeIfPresent(UUID.self, forKey: .documentId)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        snippet = try container.decodeIfPresent(String.self, forKey: .snippet)
        sourceUrl = try container.decodeIfPresent(String.self, forKey: .sourceUrl)
        headingPath = try container.decodeIfPresent(String.self, forKey: .headingPath)
        number = try container.decodeAPINumberIfPresent(Int.self, forKey: .number)
        score = try container.decodeAPINumberIfPresent(Double.self, forKey: .score)
    }
}
