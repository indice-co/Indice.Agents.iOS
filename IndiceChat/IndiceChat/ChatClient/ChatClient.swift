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
    
    let tokens: any TokenStorage
    let identity: IdentityClient
    let network: NetworkClient
    let agents: AgentsClient
    
    init() {
        let client = IdentityClient::Client(
            id: Bundle.clientId,
            secret: Bundle.clientSecret,
            userScope: .defaultUserScopes + ["agents", "chat"],
            appScope: [.identity],
            urls: .init(commonForRedirectScheme: "indice.mobile"))
        
        let tokenStorage  = /*EphemeralTokenStorage.ephemeral*/ PersistentTokenStorage()
        let tokenProvider = ProviderWrapper<String>()
        let authProvider = ProviderWrapper<IdentityClient.Authorization>()
        
        let interceptors: [NetworkClient.Interceptor] = [
            AuthInterceptor(
                tokenProvider: tokenProvider,
                authProvider : authProvider)
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
            configuration: .init(
                baseURL: URL(string: "https://agents.indice.gr")!,
                // userContext: .accessToken({ tokenStorage.authorization }),
                userContext: .implicit,
                options: .all,
            ),
            processorBuilder: { network })
        
        self.client = client
        self.tokens = tokenStorage
        self.network  = network
        self.identity = identity
        self.agents = agents
        
        // After init
        
        tokenProvider.operation = { tokenStorage.authorization }
        authProvider.operation  = { [weak identity] in identity?.authService }
    }
    
    
    public func createLoginURL(for pkce: PKCE) -> URL {
        try! identity
            .authService
            .authorizationUrl(withPkce: pkce)
            .appending(queryItems: [.init(name: "acr_values", value: AcrValues.microsoft.value)])
            // .appendingQueryItems([.init(name: "acr_values", value: AcrValues.microsoft.value)])
    }
    
    public func login(code: String, verifier: String) async throws {
        try await identity.authService.login(withGrant: .authCode(
            code: code,
            codeVerifier: verifier,
            redirectUri: client.urls!.authorization!))
    }
}
