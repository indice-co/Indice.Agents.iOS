//
//  AppState.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 8/7/26.
//

import Foundation
import Combine
import AgentsClient
import AgentsModels
import IdentityClient
import NetworkUtilities


final class AppState: ViewModel {
    
    struct LoginData: Hashable, Identifiable {
        let url: URL
        let verifier: String
        let pkce: PKCE
        
        var id: Int { hashValue }
    }
    
    let client = ChatClient()
            
    @Published
    var loginData: LoginData?
    
    
    var canQuickLogin: Bool {
        client.tokens.refreshToken != nil
    }
        
    func tryRefreshLogin(_ onSuccess: @escaping () -> Void) {
        loadAsync {
            try await $0.client
                .identity
                .authService
                .refreshTokens()
        } onSuccess: {
            onSuccess()
        }
    }
    
    func logout(_ onCompletion: @escaping () -> Void) {
        onCompletion()
    }
    
    func initializeLogin() {
        let pkceData = PKCE.generateData()
        let verifier = pkceData.verifier
        let url = client.createLoginURL(for: pkceData.pkce)
        
        self.loginData = .init(url: url, verifier: verifier, pkce: pkceData.pkce)
    }
    
    func completeLogin(returnURL: URL, onSuccess: @escaping () -> Void) {
        guard
            let code = returnURL.queryParameters?["code"],
            let data = loginData
        else { return }
        
        loginData = nil
        
        loadAsync {
            try await $0.client.login(
                code: code,
                verifier: data.verifier)
        } onSuccess: {
            onSuccess()
        }
    }
}
