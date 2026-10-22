//
//  MessageScore.swift
//  AgentsClient
//
//  Created by Nikolas Konstantakopoulos on 29/9/26.
//

import Foundation

public enum MessageScore: APIModel {
    case positive
    case negative
    case neutral
}

public extension MessageScore {
    var isPositive: Bool {
        self == .positive
    }
    
    var asValue: Bool? {
        switch self {
        case .positive: true
        case .negative: false
        case .neutral : nil
        }
    }
}
