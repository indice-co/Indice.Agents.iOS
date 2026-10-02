//
//  ChatClient.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 29/9/26.
//

import Foundation
import NetworkClient
import NetworkStream
import IdentityClient
import AgentsClient


final class ChatClient: @unchecked Sendable {
    
    private let client: IdentityClient::Client
    
    private(set) var tokens: PersistentTokenStorage!
    private(set) var identity: IdentityClient!
    private(set) var network: NetworkClient!
    private(set) var agents: AgentsClient!
    
    init() {
        self.client = .init(
            id: Bundle.clientId,
            secret: Bundle.clientSecret,
            userScope: .defaultUserScopes + ["agents", "chat"],
            appScope: [.identity],
            urls: .init(commonForRedirectScheme: "indice.mobile"))
        
        let tokenStorage = PersistentTokenStorage()
        
        let tokenProvider: @Sendable () async -> String? = { tokenStorage.authorization }
        let authProvider : @Sendable () async -> IdentityClient.Authorization? = { [weak self] in
            await self?.identity.authService
        }
        
        let interceptors: [NetworkClient.Interceptor] = [
            AuthInterceptor(
                tokenProvider: tokenProvider,
                authProvider: authProvider)
        ]
        
        let network = NetworkClient(
            interceptors: interceptors,
            decoder: AgentsResponseDecoder(),
            transport: .shared)
        
        let identity = IdentityClient.init(
            client: client,
            configuration: .init(baseUrl: URL(string: "https://my.indice.gr")!),
            currentDeviceInfoProvider: .dummy,
            tokenStorage: tokenStorage,
            networkOptions: .init(
                processorBuilder: { network },
                errorParser: .identityErrorParser))
        
        let agents = AgentsClient(
            configuration: .init(baseURL: URL(string: "https://agents.indice.gr")!),
            processorBuilder: { network })
        
        self.tokens = tokenStorage
        self.network  = network
        self.identity = identity
        self.agents = agents
    }
    
    
    public func createLoginURL(for pkce: PKCE) -> URL {
        try! identity
            .authService
            .authorizationUrl(withPkce: pkce)
            .appendingQueryItems([.init(name: "acr_values", value: AcrValues.microsoft.value)])
    }
    
    public func login(code: String, verifier: String) async throws {
        try await identity.authService.login(withGrant: .authCode(
            code: code,
            codeVerifier: verifier,
            redirectUri: client.urls!.authorization!))
    }

}


import NetworkUtilities

extension NetworkClient: @retroactive IdentityClient::RequestProcessor {
    public func process(request: URLRequest) async throws {
        try await self.fetch(request: request).item
    }
    
    public func process<T>(request: URLRequest) async throws -> T where T : Decodable, T : Sendable {
        try await self.fetch(request: request).item
    }
}


