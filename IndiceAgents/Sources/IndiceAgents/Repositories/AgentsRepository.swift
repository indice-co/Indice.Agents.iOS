import Foundation
import AgentsModels
import NetworkClient

internal struct AgentsRepository: Sendable {
    let endpoint: URL
    let client: NetworkClient

    func agents() async throws -> [AgentInfo] {
        try await client.fetch(request: .builder()
            .get(url: endpoint.appendingPathComponent("api/agents"))
            .build()).item
    }
}
