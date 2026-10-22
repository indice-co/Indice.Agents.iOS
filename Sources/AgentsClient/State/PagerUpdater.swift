//
//  PagerUpdater.swift
//  KiteNetwork
//
//  Created by Nikolas Konstantakopoulos on 22/4/26.
//


import Foundation
import NetworkUtilities

public struct PagerUpdater: Equatable, Sendable {
    public static func == (
        lhs: Self,
        rhs: Self
    ) -> Bool { lhs.id == rhs.id }
    
    let id: Int
    let update: @Sendable () async throws -> ()
    
    public func callAsFunction() async throws {
        try await self.update()
    }
}

public final actor Pager<ITEM> where ITEM: Identifiable & Sendable {
    
    typealias Getter = @Sendable (PagingOptions, FilterOptions?) async throws -> [ITEM]
    public typealias Updater = PagerUpdater

    private let items: ValueState<[ITEM]?>
    private let itemsGetter: Getter
    
    private var endReached: Bool = false
    private var isLoading: Bool = false
    private var currentPageInfo: PagingOptions?
    private var pageSize: Int
    private var initialPage: Int
    
    init(pageSize: Int = 20,
         initialPage: Int = 1,
         items: ValueState<[ITEM]?>,
         itemsGetter: @escaping Getter
    ) {
        self.items        = items
        self.itemsGetter  = itemsGetter
        self.pageSize     = pageSize
        self.initialPage  = initialPage
    }
    
    
    // MARK: Internal operations
    
    private var pageInfo: PagingOptions {
        currentPageInfo ?? .init(page: initialPage, size: pageSize, sort: nil)
    }
    

    private func update(isLoading: Bool) {
        self.isLoading = isLoading
    }
    
    private func append(_ items: [ITEM]) async {
        let value = (self.items.value ?? []) + items
        self.items.set(value)
    }
    
    private func canFetch(after lastItem: ITEM?) -> Bool {
        // Check self state
        guard !isLoading, !endReached else {
            return false
        }
        
        // Check parent state
        guard let items = items.value else {
            return true
        }
        
        guard let index = items.lastIndex(where: { $0.id == lastItem?.id }) else {
            return false
        }
        
        return index == (items.endIndex - 1)
    }
        
    private func failResult() {
        self.currentPageInfo = nil
        self.endReached = true
        self.isLoading = false
    }
    
    private func successResult(_ items: [ITEM]) async {
        self.currentPageInfo = self.pageInfo.next()
        await self.append(items)
        self.isLoading = false
    }
    
    // MARK: Handles
    
    public func resetPager() async {
        items.set(nil)
        currentPageInfo = nil
        endReached = false
    }
    
    public func provideNextPage(from item: borrowing ITEM?, filter: FilterOptions? = nil) async -> Updater? {
        guard canFetch(after: item) else {
            return nil
        }
        
        return .init(id: self.pageInfo.page, update: { [weak self] in
            guard let self = self else { return }
            await self.update(isLoading: true)
            let result: [ITEM] = try await {
                do {
                    return try await self
                        .itemsGetter(self.pageInfo, filter)
                } catch {
                    await self.update(isLoading: false)
                    throw error
                }
            }()

            guard !result.isEmpty else {
                await self.failResult()
                return
            }
        
            await self.successResult(result)
        })
    }
}
