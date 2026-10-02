//
//  AgentsClient.swift
//  AgentsClient
//
//  Created by Nikolas Konstantakopoulos on 7/7/26.
//

import Foundation
import AgentsModels
import NetworkUtilities


public final class AgentsClient: @unchecked Sendable {
    
    
    public typealias Error = AgentsError
    public typealias NetworkProcessor = RequestProcessor & StreamProcessor
    
    private let servicesLock = ReentrantSectionLock()
    private let configuration: Configuration
    private let processorBuilder: () -> NetworkProcessor
    

    /// Opt into the administrative document scope only when the identity client
    /// registration and the signed-in user are allowed to ingest/clear documents.
    public init(
        configuration: Configuration,
        processorBuilder: @escaping () -> NetworkProcessor
    ) {
        self.configuration    = configuration
        self.processorBuilder = { ProcessorWrapper(actor: processorBuilder()) }
    }
    
    private lazy var networkClient: NetworkProcessor = processorBuilder()
    
    
    private var chatsServiceInstance: ChatService?
    public var chatsService: ChatService {
        servicesLock.withLock {
            if let chatsServiceInstance {
                return chatsServiceInstance
            }
            
            let service = ChatService(repository: .init(
                endpoint: self.configuration.baseURL,
                client: networkClient))
            chatsServiceInstance = service
            return service
        }
    }

    private var agentsServiceInstance: AgentsService?
    public var agentsService: AgentsService {
        servicesLock.withLock {
            if let agentsServiceInstance {
                return agentsServiceInstance
            }
            
            let service = AgentsService(repository: .init(
                endpoint: self.configuration.baseURL,
                client: networkClient))
            
            agentsServiceInstance = service
            return service
        }
    }

    private var profileServiceInstance: ProfileService?
    public var profileService: ProfileService {
        servicesLock.withLock {
            if let profileServiceInstance {
                return profileServiceInstance
            }
            
            let service = ProfileService(repository: .init(
                endpoint: self.configuration.baseURL,
                client: networkClient))
            
            profileServiceInstance = service
            return service
        }
    }

    private var documentsServiceInstance: DocumentsService?
    public var documentsService: DocumentsService {
        servicesLock.withLock {
            if let documentsServiceInstance {
                return documentsServiceInstance
            }
            
            let service = DocumentsService(repository: .init(
                endpoint: self.configuration.baseURL,
                client: networkClient))
            
            documentsServiceInstance = service
            return service
        }
    }

    private var sourcesServiceInstance: SourcesService?
    public var sourcesService: SourcesService {
        servicesLock.withLock {
            if let sourcesServiceInstance {
                return sourcesServiceInstance
            }
            
            let service = SourcesService(repository: .init(
                endpoint: self.configuration.baseURL,
                client: networkClient))
            
            sourcesServiceInstance = service
            return service
        }
    }
}

private final class ProcessorWrapper: AgentsClient.NetworkProcessor {
    
    // TODO: use guest session if no other access token is present
    
    let actor: AgentsClient.NetworkProcessor
    
    init(actor: AgentsClient.NetworkProcessor) { self.actor = actor }
    
    func fetch(request: URLRequest) async throws -> Response<()> {
        try await actor.fetch(request: request)
    }
    
    func fetch<D: Decodable>(request: URLRequest) async throws -> Response<D> {
        try await actor.fetch(request: request)
    }
    
    func openSSEStream<Payload: Decodable & Sendable>(request: URLRequest) async throws -> StreamResponse<Payload> {
        try await actor.openSSEStream(request: request)
    }
    
}

