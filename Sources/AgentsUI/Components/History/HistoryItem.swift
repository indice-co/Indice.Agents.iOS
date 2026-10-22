//
//  HistoryItem.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 21/10/26.
//

import SwiftUI
import struct AgentsModels.ConversationListItem


public struct HistoryItem: View {

    @Environment(\.historyItemPresentAsNavigation)
    private var showNavigationImage
    
    let chat: ConversationListItem
    
    public var body: some View {
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
            
            if showNavigationImage {
                Spacer()
                Image.forward
            }
        }
        .contentShape(.rect)
    }
    
}


public extension EnvironmentValues {
    @Entry
    fileprivate(set)
    var historyItemPresentAsNavigation: Bool = false
}

public extension View {
    
    func historyItemPresentAsNavigation(_ value: Bool = true) -> some View {
        environment(\.historyItemPresentAsNavigation, value)
    }
    
}
