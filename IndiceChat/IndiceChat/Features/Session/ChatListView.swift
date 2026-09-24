//
//  ChatListView.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 9/7/26.
//

import SwiftUI
import AgentsModels
import IndiceAgents

struct ChatListView: View {
    
    enum Target: Hashable {
        case newChat
        case existing(chatID: UUID)
        
        var chatID: UUID? {
            switch self {
            case .newChat: nil
            case .existing(let id): id
            }
        }
    }
    
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    
    let navigateToRecentChat: Bool
    
    @State private var showChat: Target?
    
    var body: some View {
        
        List(state.chatSections, id: \.date) { section in
            Section {
                ForEach(section.list) { chat in
                    Button(action: { open(chatId: chat.id) }) {
                        ChatRow(chat)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(content: {
                        DeleteAction(chat)
                    })
                }
            } header: {
                ChatSectionHeader(section.date)
                    .padding(.top)
            }
        }
        .listStyle(.plain)
        .observeState(on: state)
        .refreshable { state.refreshChats(force: true) }
        .task {
            state.refreshChats(force: false) {
                guard navigateToRecentChat else { return }
                guard let recent  = state.chatSections.first else { return }
                guard let session = recent.list.first else { return }
                
                open(chatId: session.id)
            }
        }
        .toolbar(content: {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showChat = .newChat }) {
                    Image.NewChat()
                }
            }
            
            ToolbarItem(placement: .topBarLeading) {
                Dex.ImageAndName(size: .small)
            }
            .sharedBackgroundVisibility(.hidden)
        })
        .navigationTitle("Chats")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $showChat, destination: { target in
            ChatSessionView(chatId: target.chatID, service: state.chatService)
        })
    }
    
    
    @ViewBuilder
    private func ChatSectionHeader(_ date: Date) -> some View {
        Text(date.formatted(.contextual(date: .abbreviated, time: .omitted)))
            
    }
    
    @ViewBuilder
    private func ChatRow(_ chat: ConversationListItem) -> some View {
        
        HStack {
            VStack(alignment: .leading) {
                Text(chat.title ?? String(localized: "Unnamed session"))
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
    private func DeleteAction(_ chat: borrowing ConversationListItem) -> some View {
        if let id = chat.id {
            Button(
                role: .destructive,
                action: { state.delete(chatID: id) },
                label: { Image(systemName: "trash") })
            .buttonStyle(.automatic)
        }
    }
    
    
    // MARK: Actions
    
    private func open(chatId: ConversationListItem.ID) {
        guard let chatId else { return }
        
        showChat = .existing(chatID: chatId)
    }
}
