//
//  HistoryScreen.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 21/10/26.
//

import SwiftUI
import AgentsClient
import AgentsModels

struct HistoryScreen: View {
    
    @Environment(\.eventBus) private var eventBus
    @StateObject private var model: HistoryModel
    
    public init(_ client: AgentsClient) {
        self._model = .init(wrappedValue: .init(client: client))
    }
    
    private var history: [HistoryModel.Section] {
        model.history ?? []
    }
    
    var body: some View {
        List {
            Text(.screen(.history(.navTitle)))
                .font(.largeTitle)
                .listRowBackground(Color.clear)
            
            if model.history == nil, model.isLoading {
                ProgressView()
                    .padding()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
            
            ForEach(history, id: \.date) { section in
                Section {
                    ForEach(section.list) { item in
                        ItemRow(item)
                            .onAppear(perform: { fetch(after: item) })
                    }
                } header: {
                    HistorySectionHeader(date: section.date)
                }
            }
        }
        .historyItemPresentAsNavigation()
        .refreshableWithTrigger { model.refreshHistory(force: $0.fromRefreshable) }
        .safeAreaOrInset(safeAreaStyle: .clear, content: {
            Button(action: requestFreshSession) {
                // Text(String(.screen(.history(.newChat))))
                Image(systemName: "plus")
                    .imageScale(.large)
                    .padding(8)
            }
            .foregroundStyle(.white)
            .buttonStyleGlassOrFallback()
            .shadow(radius: 12)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .trailing)
        })
    }
    
    private func ItemRow(_ chat: ConversationListItem) -> some View {
        Button(action: { select(item: chat) }) {
            HistoryItem(chat: chat)
        }
        .buttonStyle(.plain)
        .swipeActions(content: { DeleteAction(chat) })
        
    }
    
    @ViewBuilder
    private func DeleteAction(_ chat: ConversationListItem) -> some View {
        Button(
            role: .destructive,
            action: {
                model.delete(
                    item: chat,
                    onSuccess: { eventBus.sendEvent(.deleted(chatId: chat.id)) })
            },
            label: { Image(systemName: "trash") })
        .buttonStyle(.automatic)
    }
}



// MARK: Actions

private extension HistoryScreen {
    
    func fetch(after item: ConversationListItem) {
        model.fetchHistory(after: item)
    }
    
    func delete(_ item: ConversationListItem) {
        model.delete(item: item)
    }
    
    func select(item: ConversationListItem) {
        eventBus.sendRequest(.chat(id: item.id))
    }
    
    func requestFreshSession() {
        eventBus.sendRequest(.newChat)
    }
}
