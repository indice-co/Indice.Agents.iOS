import Foundation

/// Raw API payload from agents.json: `GuestSession`.
public struct GuestSession: APIModel, Hashable {
    public var accessToken: String
    public var tokenType: String?
    public var expiresIn: Int?
    public var subject: String?
    public var refreshToken: String?

    public init(
        accessToken: String,
        tokenType: String? = nil,
        expiresIn: Int? = nil,
        subject: String? = nil,
        refreshToken: String? = nil
    ) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.subject = subject
        self.refreshToken = refreshToken
    }

    private enum CodingKeys: String, CodingKey {
        case accessToken, tokenType, expiresIn, subject, refreshToken
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        tokenType = try container.decodeIfPresent(String.self, forKey: .tokenType)
        expiresIn = try container.decodeAPINumberIfPresent(Int.self, forKey: .expiresIn)
        subject = try container.decodeIfPresent(String.self, forKey: .subject)
        refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
    }
}
