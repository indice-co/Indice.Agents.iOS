import Foundation
import NetworkClient

/// Binary response plus HTTP metadata, not a JSON API model.
public struct SourceResource: Sendable {
    public let data: Data
    public let contentType: String?
    public let suggestedFileName: String?
    public let url: URL?
}

internal struct SourcesRepository: Sendable {
    let endpoint: URL
    let client: NetworkClient

    func source(path: String, download: Bool = false) async throws -> SourceResource {
        // This endpoint has a catch-all path: preserve directory separators while
        // encoding reserved URL characters. Do not resolve `..` outside /sources.
        guard !path.isEmpty, !path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else {
            throw AgentsError.invalidRequest("Invalid source path.")
        }
        let url = path.split(separator: "/").reduce(endpoint.appendingPathComponent("api/sources")) {
            $0.appendingPathComponent(String($1))
        }
        return try await resource(request: .builder()
            .get(url: url)
            .add(query: "download", value: String(download))
            .build())
    }

    func favicon(sourceID: UUID) async throws -> SourceResource {
        try await resource(request: .builder()
            .get(url: endpoint.appendingPathComponent("api/sources/\(sourceID)/favicon"))
            .build())
    }

    func favicon(domain: String?) async throws -> SourceResource {
        try await resource(request: .builder()
            .get(url: endpoint.appendingPathComponent("api/favicons"))
            .add(query: "domain", value: domain)
            .build())
    }

    private func resource(request: URLRequest) async throws -> SourceResource {
        let result: NetworkClient.Response<Data> = try await client.fetch(request: request)
        return .init(data: result.item, contentType: result.value(forHeaderKey: "Content-Type"),
                     suggestedFileName: result.httpResponse.suggestedFilename, url: result.httpResponse.url)
    }
}
