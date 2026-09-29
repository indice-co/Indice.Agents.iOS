//
//  MessageScore.swift
//  IndiceAgents
//
//  Created by Nikolas Konstantakopoulos on 29/9/26.
//

import Foundation

public enum MessageScore: APIModel {
    case positive
    case negative
}

public extension MessageScore {
    var isPositive: Bool {
        self == .positive
    }
}
