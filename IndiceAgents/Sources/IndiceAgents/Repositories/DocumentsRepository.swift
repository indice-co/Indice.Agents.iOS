import Foundation
import AgentsModels
import NetworkClient

internal struct DocumentsRepository: Sendable {
    let endpoint: URL
    let client: NetworkClient

    func ingest(request model: DocumentIngestRequest) async throws -> IngestionReport {
        guard let file = model.markdownSourceFile, file.fileURL.isFileURL else {
            throw AgentsError.invalidRequest("A local markdown source file is required.")
        }
        guard model.actualSourceFile == nil || model.actualSourceUrl == nil else {
            throw AgentsError.invalidRequest("Specify an actual source file or URL, not both.")
        }
        if let actual = model.actualSourceFile, !actual.fileURL.isFileURL {
            throw AgentsError.invalidRequest("The actual source file must be a local file.")
        }
        let request: URLRequest = try .builder()
            .post(url: endpoint.appendingPathComponent("api/documents/ingest"))
            .bodyMultipart { builder in
                _ = try builder.add(key: "markdownSourceFile", file: .init(file: file.fileURL, filename: file.fileName, mimeType: .type(mimeType: file.contentType)))
                if let value = model.documentType { _ = builder.add(key: "documentType", value: value.rawValue) }
                if let value = model.category { _ = builder.add(key: "category", value: value) }
                if let value = model.language { _ = builder.add(key: "language", value: value) }
                if let value = model.isPrivate { _ = builder.add(key: "isPrivate", value: String(value)) }
                if let value = model.actualSourceUrl { _ = builder.add(key: "actualSourceUrl", value: value) }
                if let actual = model.actualSourceFile {
                    _ = try builder.add(key: "actualSourceFile", file: .init(file: actual.fileURL, filename: actual.fileName, mimeType: .type(mimeType: actual.contentType)))
                }
            }
            .build()
        return try await client.fetch(request: request).item
    }

    func clear() async throws {
        try await client.fetch(request: .builder()
            .post(url: endpoint.appendingPathComponent("api/documents/clear"))
            .noBody()
            .build()).item
    }
}
