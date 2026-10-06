import Foundation

/// Common contract for values crossing the Agents API boundary.
public protocol APIModel: Codable, Sendable {}

/// Fresh coders avoid sharing mutable Foundation coders between concurrent requests.
public enum APIJSON {
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid API date: \(value)")
        }
        return decoder
    }

    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }
}

extension KeyedDecodingContainer {
    /// ASP.NET's contract allows both JSON numbers and quoted numbers. Keep public
    /// properties numeric and accept either spelling without silently discarding bad data.
    func decodeAPINumberIfPresent<T: Decodable & LosslessStringConvertible>(
        _ type: T.Type, forKey key: Key
    ) throws -> T? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let value = try? decode(type, forKey: key) { return value }
        let string = try decode(String.self, forKey: key)
        guard let value = T(string), (value as? Double)?.isFinite != false else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Invalid numeric value: \(string)")
        }
        return value
    }
}
