//
//  ProfileRepository.swift
//  IndiceAgents
//
//  Created by Nikolas Konstantakopoulos on 7/7/26.
//

import Foundation
import AgentsModels
import NetworkClient

internal struct ProfileRepository: Sendable {
    
    let endpoint: URL
    let client: NetworkClient
    
    func profile() async throws -> Profile {
        try await client.fetch(request: .builder()
            .get(url: endpoint.appendingPathComponent("api/my/profile"))
            .build())
        .item
    }
 
    
    func profile(updateRequest: UpdateUserRequest) async throws -> Profile {
        try await client.fetch(request: .builder()
            .put(url: endpoint.appendingPathComponent("api/my/profile"))
            .bodyJson(of: updateRequest)
            .build())
        .item
    }
    
}
