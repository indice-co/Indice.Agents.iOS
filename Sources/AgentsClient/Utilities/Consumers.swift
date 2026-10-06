//
//  Consumers.swift
//  NetworkClient
//
//  Created by Nikolas Konstantakopoulos on 7/7/26.
//

import NetworkUtilities

public extension URLRequestQueryBuilder {
    func add(paging: PagingOptions?) -> URLRequestQueryBuilder {
        self
            .add(query: "page", value: paging.map { String($0.page) })
            .add(query: "size", value: paging.map { String($0.size) })
            .add(query: "sort", value: paging?.sort)
    }
    
    func add(filter: FilterOptions?) -> URLRequestQueryBuilder {
        self
            .add(query: "search", value: filter?.search)
            .add(query: "from",   value: filter?.start?.formatted(.iso8601))
            .add(query: "to",     value: filter?.end?.formatted(.iso8601))
            .add(queryItems: filter?.custom ?? [:])
    }
}
