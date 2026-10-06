//
//  HistoryModel.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 2/10/26.
//

import Foundation
import Combine

import class  AgentsClient.AgentsClient
import struct AgentsModels.ConversationListItem

@MainActor
final class HistoryModel: ObservableObject {
    
    public struct Section: Hashable {
        var date: Date
        var list: [ConversationListItem]
    
        public init(date: Date, list: [ConversationListItem]) {
            self.date = date
            self.list = list
        }
    }
    
    @Published
    private(set)
    var history: [Section]?
    
    private let client: AgentsClient
    
    private var refreshTask: Task<Void, Never>?
    private var deleteTask : Task<Void, Never>?
    
    @Published
    private(set)
    var error: Error?
    
    @Published
    private(set)
    var isLoading: Bool = false
    
    @Published
    private(set)
    var fetchingNextPage: Bool = false
    
    func clearError(_ callback: (() -> Void)? = nil) {
        error = nil
        callback?()
    }
    
    init(client: AgentsClient) {
        self.client = client
        
        client.chatsService
            .history.publisher(transformation: { $0?.sections() })
            .assign(to: &$history)
    }
    
    func refreshHistory(force: Bool) {
        refreshTask = .init(operation: { [weak self] in
            guard let self else { return }
            self.isLoading = true
            
            defer {
                self.refreshTask = nil
                self.isLoading = false
            }
            
            do {
                if force {
                    await self.client.chatsService.resetHistory()
                }
                
                try await self.client.chatsService.updateHistory(after: nil)
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.error = error
                }
            }
        })
    }
    
    func fetchHistory(after item: ConversationListItem) {
        guard refreshTask == nil else { return }
        
        refreshTask = .init(operation: { [weak self] in
            guard let self else { return }
            self.fetchingNextPage = true
            
            defer {
                self.refreshTask = nil
                self.fetchingNextPage = false
            }
            
            do {
                try await self.client
                    .chatsService
                    .updateHistory(after: item)
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.error = error
                }
            }
        })
    }
    
    func delete(item: borrowing ConversationListItem) {
        guard deleteTask == nil else { return }
        guard let id = item.id  else { return }
        
        deleteTask = .init(operation: { [weak self] in
            guard let self else { return }
            self.isLoading = true
            
            defer {
                self.deleteTask = nil
                self.isLoading = false
            }
            
            do {
                try await self.client
                    .chatsService
                    .delete(chatID: id)
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.error = error
                }
            }
        })
    }
    
}



// MARK: Helpers extensions

private extension ConversationListItem {
    var orderDate: Date {
        self.lastActivityAt ?? .distantPast
    }
}


private nonisolated extension Array where Element == ConversationListItem {
    
    func sections() -> [HistoryModel.Section]  {
        let grouped = Dictionary(
            grouping: self,
            by: { $0.orderDate.removingTimeStamp() })
        
        let keys = grouped.keys.sorted(by: >)
        
        return keys.compactMap { key in
            guard let section = grouped[key] else {
                return nil
            }
            
            let sorted = section.sorted(by: { $0.orderDate > $1.orderDate })
            
            return .init(date: key, list: sorted)
        }
    }
}


private extension Array where Element == HistoryModel.Section {
    
    mutating
    func remove(chatID: ConversationListItem.ID) {
        let sectionIndex = self.firstIndex(where: {
            $0
                .list
                .contains(where: { item in item.id == chatID })
        })
        
        guard let sectionIndex else { return }
        
        var section = self[sectionIndex]
        section.list.removeAll(where: { $0.id == chatID })
        
        if section.list.isEmpty {
            self.remove(at: sectionIndex)
        } else {
            self[sectionIndex] = section
        }
    }
    
}
