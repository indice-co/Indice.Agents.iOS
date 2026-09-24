import Foundation

/// Raw API payload from agents.json: `SourceDocumentLink`.
public struct SourceDocumentLink: APIModel, Hashable {
    public var id: UUID?
    public var contentHash: String?
    public var contentType: String?
    public var length: Int64?
    public var fileName: String?
    public var sourceTitle: String?
    public var sourceUrl: String?
    public var isPrivate: Bool?

    public init(
        id: UUID? = nil,
        contentHash: String? = nil,
        contentType: String? = nil,
        length: Int64? = nil,
        fileName: String? = nil,
        sourceTitle: String? = nil,
        sourceUrl: String? = nil,
        isPrivate: Bool? = nil
    ) {
        self.id = id
        self.contentHash = contentHash
        self.contentType = contentType
        self.length = length
        self.fileName = fileName
        self.sourceTitle = sourceTitle
        self.sourceUrl = sourceUrl
        self.isPrivate = isPrivate
    }

    private enum CodingKeys: String, CodingKey {
        case id, contentHash, contentType, length, fileName, sourceTitle, sourceUrl, isPrivate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        contentHash = try container.decodeIfPresent(String.self, forKey: .contentHash)
        contentType = try container.decodeIfPresent(String.self, forKey: .contentType)
        length = try container.decodeAPINumberIfPresent(Int64.self, forKey: .length)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        sourceTitle = try container.decodeIfPresent(String.self, forKey: .sourceTitle)
        sourceUrl = try container.decodeIfPresent(String.self, forKey: .sourceUrl)
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate)
    }
}
