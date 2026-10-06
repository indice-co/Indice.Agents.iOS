//
//  Configuration.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 2/10/26.
//

import Foundation
import AgentsModels

extension AgentsClient {
    
    /// Configure the guest session behavior.
    public enum GuestSessionPolicy: Sendable {
        
        /// Create a new guest session that its lifecycle is tied to the `AgentsClient` instance.
        case standard
        
        /// Provide a storage that as a delegate of the guest session's lifecycle.
        /// Save the session on a persistent storage to extend the session's lifecycle beyond the `AgentsClient` instance.
        case persistent(_ storage: GuestSessionStore)
    }
    
    /// Defines the user context for the `AgentsClient` instance lifecycle.
    public enum UserContext: Sendable {
        /// Use a guest session, regardless of any other existing authentication context.
        ///
        /// - parameter policy: define the Guest session lifecycle policy.
        case guestSession(_ policy: GuestSessionPolicy = .standard)
        
        /// Use an explicit authentication context.
        case accessToken(_ provider: @Sendable () -> String?)
        
        
        /// Use a guest session, with the standard lifecycle policy i.e. same as the client's instance life.
        public static var guestSession: Self {
            .guestSession(.standard)
        }
    }
    
    public struct Configuration: Sendable {
        let baseURL: URL
        let userContext: UserContext
        
        public init(
            baseURL: URL,
            userContext: UserContext = .guestSession
        ) {
            self.baseURL = baseURL
            self.userContext = userContext
        }
    }
}


public protocol GuestSessionStore: Sendable {
    func load() async throws -> GuestSession?
    func save(_ session: GuestSession) async throws
    func clear() async throws
}
