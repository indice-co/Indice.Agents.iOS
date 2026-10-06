//
//  AgentsError.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 30/9/26.
//

import Foundation


public enum AgentsError: Error, LocalizedError, Sendable {
    case notSignedIn
    case invalidRequest(String)
    case invalidStream(String)
    case streamFailed(String)
    case incompleteStream
    case turnInProgress
    case missingConversationID

    public var errorDescription: String? {
        switch self {
        case .notSignedIn: "Sign in before using the Agents API."
            
        case .invalidRequest(let reason),
             .invalidStream(let reason),
             .streamFailed(let reason): reason
            
        case .incompleteStream: "The connection ended before the reply was complete."
            
        case .turnInProgress: "Wait for the current reply or stop it before sending another message."
            
        case .missingConversationID: "The server did not supply a conversation ID."
        }
    }
}
