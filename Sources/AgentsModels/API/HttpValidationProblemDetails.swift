import Foundation

/// Raw API payload from agents.json: `HttpValidationProblemDetails`.
public struct HttpValidationProblemDetails: APIModel, Hashable {
    public var type: String?
    public var title: String?
    public var status: Int?
    public var detail: String?
    public var instance: String?
    public var errors: [String: [String]]?

    public init(
        type: String? = nil,
        title: String? = nil,
        status: Int? = nil,
        detail: String? = nil,
        instance: String? = nil,
        errors: [String: [String]]? = nil
    ) {
        self.type = type
        self.title = title
        self.status = status
        self.detail = detail
        self.instance = instance
        self.errors = errors
    }

    private enum CodingKeys: String, CodingKey {
        case type, title, status, detail, instance, errors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        status = try container.decodeAPINumberIfPresent(Int.self, forKey: .status)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
        instance = try container.decodeIfPresent(String.self, forKey: .instance)
        errors = try container.decodeIfPresent([String: [String]].self, forKey: .errors)
    }
}
