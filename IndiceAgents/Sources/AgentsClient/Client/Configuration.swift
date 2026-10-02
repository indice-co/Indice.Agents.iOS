//
//  Configuration.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 2/10/26.
//

import Foundation

extension AgentsClient {
    
    public struct Configuration: Sendable {
        let baseURL: URL
        // let accessTokenProvider: @Sendable () -> String?
        
        public init(
            baseURL: URL,
            // accessTokenProvider: @Sendable @escaping () -> String?
        ) {
            self.baseURL = baseURL
            // self.accessTokenProvider = accessTokenProvider
        }
    }
    
}
