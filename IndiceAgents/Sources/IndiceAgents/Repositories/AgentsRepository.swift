import Foundation
import AgentsModels

internal struct AgentsRepository: Sendable {
    let endpoint: URL
    let client: AgentsClient.NetworkProcessor

    func agents() async throws -> [AgentInfo] {
        try await client.fetch(request: .builder()
            .get(url: endpoint.appendingPathComponent("api/agents"))
            .build()).item
    }
}
