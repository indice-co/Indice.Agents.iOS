import Foundation

/// Raw API payload from agents.json: `DocumentIngestRequest`.
public struct DocumentIngestRequest: APIModel, Hashable {
    public var documentType: DocumentType?
    public var category: String?
    public var language: String?
    public var markdownSourceFile: FileParam?
    public var actualSourceFile: FileParam?
    public var actualSourceUrl: String?
    public var isPrivate: Bool?

    public init(
        documentType: DocumentType? = nil,
        category: String? = nil,
        language: String? = nil,
        markdownSourceFile: FileParam? = nil,
        actualSourceFile: FileParam? = nil,
        actualSourceUrl: String? = nil,
        isPrivate: Bool? = nil
    ) {
        self.documentType = documentType
        self.category = category
        self.language = language
        self.markdownSourceFile = markdownSourceFile
        self.actualSourceFile = actualSourceFile
        self.actualSourceUrl = actualSourceUrl
        self.isPrivate = isPrivate
    }

    private enum CodingKeys: String, CodingKey {
        case documentType, category, language, markdownSourceFile, actualSourceFile, actualSourceUrl, isPrivate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        documentType = try container.decodeIfPresent(DocumentType.self, forKey: .documentType)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        markdownSourceFile = try container.decodeIfPresent(FileParam.self, forKey: .markdownSourceFile)
        actualSourceFile = try container.decodeIfPresent(FileParam.self, forKey: .actualSourceFile)
        actualSourceUrl = try container.decodeIfPresent(String.self, forKey: .actualSourceUrl)
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate)
    }
}
