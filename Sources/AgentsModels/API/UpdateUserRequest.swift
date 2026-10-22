import Foundation

/// Raw API payload from agents.json: `UpdateUserRequest`.
public struct UpdateUserRequest: APIModel, Hashable {
    public var preferredLanguage: String?
    public var responseStyle: String?
    public var preferredCategories: [String]?

    public init(
        preferredLanguage: String? = nil,
        responseStyle: String? = nil,
        preferredCategories: [String]? = nil
    ) {
        self.preferredLanguage = preferredLanguage
        self.responseStyle = responseStyle
        self.preferredCategories = preferredCategories
    }

    private enum CodingKeys: String, CodingKey {
        case preferredLanguage, responseStyle, preferredCategories
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferredLanguage = try container.decodeIfPresent(String.self, forKey: .preferredLanguage)
        responseStyle = try container.decodeIfPresent(String.self, forKey: .responseStyle)
        preferredCategories = try container.decodeIfPresent([String].self, forKey: .preferredCategories)
    }
}
