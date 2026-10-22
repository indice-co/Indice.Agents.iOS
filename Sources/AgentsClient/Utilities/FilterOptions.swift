//
//  FilterOptions.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 7/7/26.
//

import Foundation

public struct FilterOptions: Sendable, Hashable, Equatable {
    public var search: String?
    public var start : Date?
    public var end   : Date?
    public var custom: [String: String]
    
    public init(
        search: String? = nil,
        start: Date? = nil,
        end: Date? = nil,
        custom: [String: String] = [:]
    ) {
        self.search = search
        self.start = start
        self.end = end
        self.custom = custom
    }
}

public extension FilterOptions {
    
    mutating
    func addOption(name: String, value: String?) {
        self.custom[name] = value
    }
    
    func addingOption(name: String, value: String?) -> Self {
        var copy = self
        copy.addOption(name: name, value: value)
        return copy
    }
}
