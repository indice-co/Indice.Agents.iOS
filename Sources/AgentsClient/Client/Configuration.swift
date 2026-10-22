//
//  Configuration.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 2/10/26.
//

import Foundation
import AgentsModels

extension AgentsClient {

    public struct Options: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        public static let history: Options = Options(rawValue: 1 << 0)
        public static let all    : Options = [Options.history]
        
    }
    
    /// Configure the guest session behavior.
    public enum GuestSessionPolicy: Sendable {
        
        /// Create a new guest session that its lifecycle is tied to the `AgentsClient` instance.
        case standard
        
        /// Provide a storage that as a delegate of the guest session's lifecycle.
        /// Save the session on a persistent storage to extend the session's lifecycle beyond the `AgentsClient` instance.
        case persistent(_ storage: GuestSessionStore)
        
        package func initializeStorage() -> GuestSessionStore {
            switch self {
            case .standard: EphemeralGuestSessionStore()
            case .persistent(let storage): storage
            }
        }
    }
    
    /// Defines the user context for the `AgentsClient` instance lifecycle.
    public enum UserContext: Sendable {
        /// Use a guest session, regardless of any other existing authentication context.
        ///
        /// - parameter policy: define the Guest session lifecycle policy.
        case guestSession(_ policy: GuestSessionPolicy = .standard)
        
        /// Use an explicit authentication context.
        case accessToken(_ provider: @Sendable () async -> String?)
        
        /// This mode will not alter any request's authentication context.
        /// If the host app injects some authentication it will be used.
        /// If at some point, a new chat provides a `GuestSession`, it will then be used as an ephemeral session.
        case implicit
        
        
        /// Use a guest session, with the standard lifecycle policy i.e. same as the client's instance life.
        public static var guestSession: Self {
            .guestSession(.standard)
        }
        
        
        package func createAccessTokenProvider() -> AccessTokenProvider {
            switch self {
            case .accessToken(let provider): ExternalTokenProvider(provider: provider)
            case .guestSession(let policy) : SessionStorageProxy(storage: policy.initializeStorage())
            case .implicit: SessionStorageProxy(storage: EphemeralGuestSessionStore())
            }
        }
    }
    
    public struct Configuration: Sendable {
        let baseURL: URL
        let userContext: UserContext
        let options: Options
        
        public init(
            baseURL: URL,
            userContext: UserContext = .implicit,
            options: Options = .all
        ) {
            self.baseURL = baseURL
            self.userContext = userContext
            self.options = options
        }
    }
}


public protocol GuestSessionStore: Sendable {
    func load() async throws -> GuestSession?
    func save(_ session: GuestSession) async throws
    func clear() async throws
}

public protocol AccessTokenProvider: Sendable {
    func authorizationHeader() async throws -> String?
}

internal extension AccessTokenProvider {
    func inject(into request: URLRequest) async throws -> URLRequest {
        guard let value = try await authorizationHeader() else {
            return request
        }
        
        return request.setting(header: .authorization(auth: value))
    }
}

internal final actor ExternalTokenProvider: AccessTokenProvider {
    
    private let provider: () async throws -> String?
    
    init(provider: @escaping () async throws -> String?) {
        self.provider = provider
    }
    
    func authorizationHeader() async throws -> String? {
        try await provider()
    }
}

internal final actor EphemeralGuestSessionStore: GuestSessionStore {
    
    private var session: GuestSession?
    
    func load() async throws -> GuestSession? { session }
    func save(_ session: GuestSession) async throws { self.session = session }
    func clear() async throws { self.session = nil }
}

