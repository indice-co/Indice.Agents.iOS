//
//  AppState.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 8/7/26.
//

import Foundation
import Combine
import IndiceAgents
import AgentsModels
import IdentityClient
import NetworkUtilities


final class AppState: ViewModel {
    
    struct LoginData: Hashable, Identifiable {
        let url: URL
        let verifier: String
        let pkce: PKCE
        
        var id: Int { hashValue }
    }
    
    struct ChatHistorySection: Hashable {
        var date: Date
        var list: [ConversationListItem]
    }
    
    private let api = AgentsClient()
    
    var chatService: ChatService { api.chatsService }
    
    @Published
    var loginData: LoginData?
    
    @Published
    private(set)
    var chatSections: [ChatHistorySection] = []
    
    
    var canQuickLogin: Bool {
        api.canQuickLogin
    }
    
    func tryRefreshLogin(_ onSuccess: @escaping () -> Void) {
        loadAsync {
            try await $0.api.refreshLogin()
        } onSuccess: {
            onSuccess()
        }
    }
    
    func logout(_ onCompletion: @escaping () -> Void) {
        onCompletion()
    }
    
    func initializeLogin() {
        let pkceData = PKCE.generateData()
        let verifier = pkceData.verifier
        let url = api.createLoginURL(for: pkceData.pkce)
        
        self.loginData = .init(url: url, verifier: verifier, pkce: pkceData.pkce)
    }
    
    func completeLogin(returnURL: URL, onSuccess: @escaping () -> Void) {
        guard
            let code = returnURL.queryParameters?["code"],
            let data = loginData
        else { return }
        
        loginData = nil
        
        loadAsync {
            try await $0.api.login(
                code: code,
                verifier: data.verifier)
        } onSuccess: {
            onSuccess()
        }
    }
    
    
    func refreshChats(force: Bool, onSuccess: (() -> Void)? = nil) {
        guard force || chatSections.isEmpty else { return }
        
        loadAsync {
            try await $0.api.chatsService.chats()
        } onSuccess: { [weak self] result in
            self?.chatSections = (result.items ?? []).sections()
            onSuccess?()
        }
    }
    
    func delete(chatID: UUID) {
        loadAsync {
            try await $0.api
                .chatsService
                .delete(chatID: chatID)
            
        } onSuccess: { [weak self] in
            self?
                .chatSections
                .remove(chatID: chatID)
        }
    }
}


private extension ConversationListItem {
    var orderDate: Date {
        self.lastActivityAt ?? .distantPast
    }
}

private extension Array where Element == ConversationListItem {
    func sections() -> [AppState.ChatHistorySection]  {
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


private extension Array where Element == AppState.ChatHistorySection {
    
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
