import Foundation
import AgentsModels
import NetworkClient

/// Uses only NetworkClient's public decoder contract. Binary source endpoints
/// return their bytes directly; JSON endpoints share the Agents date handling.
struct AgentsResponseDecoder: DecoderProtocol, Sendable {
    func decode<T: Decodable>(data: Data) throws -> T {
        if T.self == Data.self { return data as! T }
        return try APIJSON.decoder().decode(T.self, from: data)
    }
}
