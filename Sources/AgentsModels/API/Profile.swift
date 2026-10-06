import Foundation

/// Raw API payload from agents.json: `Profile`.
public struct Profile: APIModel, Hashable {
    public var id: UUID?
    public var displayName: String?
    public var email: String?
    public var locale: String?
    public var preferredLanguage: String?
    public var preferredCategories: [String]?
    public var responseStyle: String?
    public var createdAt: Date?
    public var updatedAt: Date?
    public var lastSeenAt: Date?
    public var reasoningTokensLast7Days: Int64?

    public init(
        id: UUID? = nil,
        displayName: String? = nil,
        email: String? = nil,
        locale: String? = nil,
        preferredLanguage: String? = nil,
        preferredCategories: [String]? = nil,
        responseStyle: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        lastSeenAt: Date? = nil,
        reasoningTokensLast7Days: Int64? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.locale = locale
        self.preferredLanguage = preferredLanguage
        self.preferredCategories = preferredCategories
        self.responseStyle = responseStyle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastSeenAt = lastSeenAt
        self.reasoningTokensLast7Days = reasoningTokensLast7Days
    }

    private enum CodingKeys: String, CodingKey {
        case id, displayName, email, locale, preferredLanguage, preferredCategories, responseStyle, createdAt, updatedAt, lastSeenAt, reasoningTokensLast7Days
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        locale = try container.decodeIfPresent(String.self, forKey: .locale)
        preferredLanguage = try container.decodeIfPresent(String.self, forKey: .preferredLanguage)
        preferredCategories = try container.decodeIfPresent([String].self, forKey: .preferredCategories)
        responseStyle = try container.decodeIfPresent(String.self, forKey: .responseStyle)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        lastSeenAt = try container.decodeIfPresent(Date.self, forKey: .lastSeenAt)
        reasoningTokensLast7Days = try container.decodeAPINumberIfPresent(Int64.self, forKey: .reasoningTokensLast7Days)
    }
}
