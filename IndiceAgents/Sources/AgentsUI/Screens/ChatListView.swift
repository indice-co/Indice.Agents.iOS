//
//  ChatListView.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 9/7/26.
//

import SwiftUI
import class AgentsClient.AgentsClient
import struct AgentsModels.ConversationListItem


public struct HistoryScreen: View {
    
    @StateObject private var model: HistoryModel
    
    let onSelection: (_ chat: ConversationListItem.ID) -> Void
    
    public init(_ client: AgentsClient, onSelection: @escaping (_ chat: ConversationListItem.ID) -> Void) {
        self._model = StateObject(wrappedValue: .init(client: client))
        self.onSelection = onSelection
    }
    
    
    public var body: some View {
        VStack {
            if let history = model.history, !history.isEmpty {
                List(history, id: \.date) { section in
                    Section {
                        ForEach(section.list) { chat in
                            ChatButtonRow(chat)
                        }
                    } header: {
                        ChatSectionHeader(section.date)
                            .padding(.top)
                    }
                }
                .listStyle(.plain)
            }
        }
        .refreshable { model.refreshHistory(force: true) }
        .task { model.refreshHistory(force: false) }
        .modifier(DEXToolbarModifier(onSelection: onSelection))
    }
    
    
    // MARK: Components
    
    @ViewBuilder
    private func ChatSectionHeader(_ date: borrowing Date) -> some View {
        Text(date.formatted(.contextual(date: .abbreviated, time: .omitted)))
        
    }
    
    private func ChatButtonRow(_ chat: ConversationListItem) -> some View {
        Button(
            action: { onSelection(chat.id) },
            label: { ChatRow(chat) })
        .buttonStyle(.plain)
        .swipeActions(content: { DeleteAction(chat) })
        .onAppear(perform: { model.fetchHistory(after: chat) })
    }
    
    @ViewBuilder
    private func ChatRow(_ chat: ConversationListItem) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(chat.title ?? String(.screen(.history(.unnamed))))
                    .font(.subheadline)
                    .lineLimit(2)
                    .truncationMode(.tail)
                
                if let date = chat.lastActivityAt {
                    HStack {
                        DateView(date,
                                 dateFormat: .omitted,
                                 timeFormat: .shortened)
                        
                        // Maybe show the X/5 responses left - not available here yet.
                    }
                    .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Image.Forward()
        }
        .contentShape(.rect)
    }
    
    @ViewBuilder
    private func DeleteAction(_ chat: ConversationListItem) -> some View {
        Button(
            role: .destructive,
            action: { model.delete(item: chat) },
            label: { Image(systemName: "trash") })
        .buttonStyle(.automatic)
    }
}
