//
//  PageOptions.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 7/7/26.
//

public struct PagingOptions: Sendable, Hashable, Equatable {
    public var page: Int
    public var size: Int
    public var sort: String? = nil
    
    public init(page: Int, size: Int = 10, sort: String? = nil) {
        self.page = page
        self.size = size
        self.sort = sort
    }
}

public extension PagingOptions {
    func next() -> PagingOptions {
        .init(
            page: page + 1,
            size: size,
            sort: sort)
    }
}
