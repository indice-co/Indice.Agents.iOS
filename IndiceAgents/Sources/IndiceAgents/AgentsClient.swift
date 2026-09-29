//
//  AgentsClient.swift
//  IndiceAgents
//
//  Created by Nikolas Konstantakopoulos on 7/7/26.
//

import Foundation
import AgentsModels
import NetworkUtilities


public final class AgentsClient: @unchecked Sendable {
    
    public typealias NetworkProcessor = NetworkUtilities::RequestProcessor & StreamProcessor
    
    public struct Configuration {
        let baseURL: URL
        
        public init(baseURL: URL) {
            self.baseURL = baseURL
        }
    }
    
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
        self.processorBuilder = processorBuilder
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

//    public var canQuickLogin: Bool {
//        tokenStorage.refreshToken != nil
//    }
//    
//    public func refreshLogin() async throws {
//        try await identityClient.authService.refreshTokens()
//    }
//    
//    public func createLoginURL(for pkce: PKCE) -> URL {
//        try! identityClient
//            .authService
//            .authorizationUrl(withPkce: pkce)
//            .appendingQueryItems([.init(name: "acr_values", value: AcrValues.microsoft.value)])
//    }
//    
//    public func login(code: String, verifier: String) async throws {
//        try await identityClient.authService.login(withGrant: .authCode(
//            code: code,
//            codeVerifier: verifier,
//            redirectUri: identityClientURLS.authorization!))
//    }
}
