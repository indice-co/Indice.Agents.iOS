//
//  SessionStorage.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 19/10/26.
//

import AgentsModels
import NetworkUtilities

final actor SessionStorageProxy: AccessTokenProvider, GuestSessionStore {
    
    private let storage: GuestSessionStore
    
    init(storage: GuestSessionStore) {
        self.storage = storage
    }
    
    func save(_ guestSession: GuestSession) async throws {
        try await storage.save(guestSession)
    }
    
    func load() async throws -> GuestSession? {
        try await storage.load()
    }
    
    func clear() async throws {
        try await storage.clear()
    }
    
    func authorizationHeader() async throws -> String? {
        if let session = try await storage.load(), let type = session.tokenType {
            return "\(type) \(session.accessToken)"
        }
        
        return nil
    }
}


