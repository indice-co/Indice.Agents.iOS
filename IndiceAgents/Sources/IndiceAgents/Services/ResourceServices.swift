import Foundation
import AgentsModels

public actor AgentsService {
    private let repository: AgentsRepository
    init(repository: AgentsRepository) { self.repository = repository }
    public func agents() async throws -> [AgentInfo] { try await repository.agents() }
}

public actor ProfileService {
    private let repository: ProfileRepository
    init(repository: ProfileRepository) { self.repository = repository }
    public func profile() async throws -> Profile { try await repository.profile() }
    public func update(_ request: UpdateUserRequest) async throws -> Profile {
        try await repository.profile(updateRequest: request)
    }
}

public actor DocumentsService {
    private let repository: DocumentsRepository
    init(repository: DocumentsRepository) { self.repository = repository }
    public func ingest(_ request: DocumentIngestRequest) async throws -> IngestionReport {
        try await repository.ingest(request: request)
    }
    public func ingest(fileURL: URL, documentType: DocumentType, category: String = "", language: String = Locale.current.language.languageCode?.identifier ?? "en") async throws -> IngestionReport {
        try await ingest(.init(documentType: documentType, category: category, language: language,
                               markdownSourceFile: .init(fileURL: fileURL, contentType: "text/markdown")))
    }
    public func clear() async throws { try await repository.clear() }
}

public actor SourcesService {
    private let repository: SourcesRepository
    init(repository: SourcesRepository) { self.repository = repository }
    public func source(path: String, download: Bool = false) async throws -> SourceResource {
        try await repository.source(path: path, download: download)
    }
    public func favicon(sourceID: UUID) async throws -> SourceResource { try await repository.favicon(sourceID: sourceID) }
    public func favicon(domain: String? = nil) async throws -> SourceResource { try await repository.favicon(domain: domain) }
}
