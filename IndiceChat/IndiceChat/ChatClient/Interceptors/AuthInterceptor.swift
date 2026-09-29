//
//  AuthInterceptor.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 29/9/26.
//

import Foundation
import IdentityClient
import NetworkClient
import NetworkUtilities
// TODO: Expose NetworkUtilities via the NetworkClient import.


final class AuthInterceptor: NetworkClient.Interceptor {
    
    private let tokenProvider: @Sendable () async -> String?
    private let authProvider : @Sendable () async -> IdentityClient.Authorization?
    
    init(
        tokenProvider: @Sendable @escaping () async -> String?,
        authProvider: @Sendable @escaping () async -> IdentityClient.Authorization?
    ) {
        self.tokenProvider = tokenProvider
        self.authProvider = authProvider
    }
    
    func process<T>(_ request: URLRequest, next: @concurrent (URLRequest) async throws -> NetworkClient.Response<T>) async throws -> NetworkClient.Response<T> where T : Sendable {
        var request = request
        if let authorization = await tokenProvider() {
            request.set(header: .authorization(auth: authorization))
        }
        
        do {
            return try await next(request)
        } catch {
            guard
                let error = error as? NetworkClient.Error,
                error.statusCode == 401,
                let provider = await authProvider()
            else { throw error }
            
            try await provider.refreshTokens()
            
            guard let newAuth = await tokenProvider() else {
                throw error
            }
            
            return try await next(request.setting(header: .authorization(auth: newAuth)))
        }
    }
    
}


