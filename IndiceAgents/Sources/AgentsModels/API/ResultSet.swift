import Foundation

/// Shared paged API result. The contract permits count as a number or numeric string.
public struct ResultSet<Item: APIModel>: APIModel {
    public var count: Int?
    public var items: [Item]?

    public init(count: Int? = nil, items: [Item]? = nil) {
        self.count = count
        self.items = items
    }

    private enum CodingKeys: String, CodingKey { case count, items }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        count = try container.decodeAPINumberIfPresent(Int.self, forKey: .count)
        items = try container.decodeIfPresent([Item].self, forKey: .items)
    }
}

extension ResultSet: Equatable where Item: Equatable {}
extension ResultSet: Hashable where Item: Hashable {}
