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

    private let accessTokenProvider: AccessTokenProvider
    private let servicesLock = ReentrantSectionLock()
    private let processorBuilder: () -> NetworkProcessor
    
    public let configuration: Configuration

    public func supports(_ option: Options) -> Bool {
        configuration.options.contains(option)
    }
    
    public init(
        configuration: Configuration,
        processorBuilder: @escaping () -> NetworkProcessor
    ) {
        let accessTokenProvider = configuration.userContext.createAccessTokenProvider()

        self.configuration       = configuration
        self.accessTokenProvider = accessTokenProvider
        
        self.processorBuilder = { ProcessorWrapper(actor: processorBuilder(), provider: accessTokenProvider) }
    }
    
    private lazy var networkClient: NetworkProcessor = processorBuilder()
    
    
    private var chatsServiceInstance: ChatService?
    public var chatsService: ChatService {
        servicesLock.withLock {
            if let chatsServiceInstance {
                return chatsServiceInstance
            }
            
            let service = ChatService(
                sessionStore: accessTokenProvider as? SessionStorageProxy,
                repository: .init(
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
    let provider: AccessTokenProvider
    
    init(actor: AgentsClient.NetworkProcessor, provider: AccessTokenProvider) {
        self.actor    = actor
        self.provider = provider
    }
    
    func fetch(request: URLRequest) async throws -> Response<()> {
        try await actor.fetch(request: try await provider.inject(into: request))
    }
    
    func fetch<D: Decodable>(request: URLRequest) async throws -> Response<D> {
        try await actor.fetch(request: try await provider.inject(into: request))
    }
    
    func openSSEStream<Payload: Decodable & Sendable>(request: URLRequest) async throws -> StreamResponse<Payload> {
        try await actor.openSSEStream(request: try await provider.inject(into: request))
    }
    
}
