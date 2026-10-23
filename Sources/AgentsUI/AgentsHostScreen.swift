//
//  AgentsHostScreen.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 21/10/26.
//

import SwiftUI
import AgentsClient

public struct AgentsHostScreen: View {
    
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    
    @FocusState private var focus
    
    @State private var eventBus = EventBus()
    @State private var sidebarOpen = false
    
    let theme : Theme
    let agents: AgentsClient
    
    public init(client: AgentsClient, theme: Theme = .default) {
        self.theme  = theme
        self.agents = client
    }
    
    private var hasHistory: Bool {
        agents.supports(.history)
    }
    
    private var sidebarAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.9)
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let sidebarWidth = min(380, geometry.size.width * 0.85)
            
            ZStack(alignment: .leading) {
                if hasHistory {
                    HistoryScreen(agents)
                        .frame(width: sidebarWidth)
                        .background(.background, ignoresSafeAreaEdges: .vertical)
                        .allowsHitTesting(sidebarOpen)
                        .accessibilityHidden(!sidebarOpen)
                        .onReceive(eventBus.requests, perform: { _ in sidebarOpen = false })
                        .onChange(of: sidebarOpen) { isOpen in
                            if isOpen, focus { focus = false }
                        }
                }
                
                NavigationView {
                    SessionScreen(agents)
                        .focused($focus)
                        .modifier(ToolbarActionsModifier(
                            hasHistory: hasHistory,
                            historyAction: { sidebarOpen = true },
                            newChatAction: { eventBus.sendRequest(.newChat) }))
                }
                .navigationViewStyle(.stack)
                .frame(width: geometry.size.width)
                .background(.background)
                .accessibilityHidden(sidebarOpen)
                .overlay {
                    if sidebarOpen {
                        Color.black.opacity(0.15)
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture { sidebarOpen = false }
                    }
                }
                .offset(x: sidebarOpen ? sidebarWidth : 0)
            }
            .animation(sidebarAnimation, value: sidebarOpen)
            .accessibilityAction(.escape) { sidebarOpen = false }
        }
        .withAgentsUITheme(theme)
        .environment(\.eventBus, eventBus)
        .environment(\.useGlassStyleIfAvailable, true)
    }
}




private struct ToolbarActionsModifier: ViewModifier {
    
    @Environment(\.agentsUITheme) private var theme
    
    let hasHistory: Bool
    let historyAction: () -> Void
    let newChatAction: () -> Void
    
    func body(content: Content) -> some View {
        if hasHistory {
            content.toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: historyAction) {
                        Image(systemName: "sidebar.left")
                            .foregroundStyle(theme.primaryColor)
                    }
                    .accessibilityLabel(String(.screen(
                        .session(
                        .accessibilityOpenHistory))))
                }
            }
        } else {
            content.toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: newChatAction) {
                        Image(systemName: "plus")
                            .foregroundStyle(theme.primaryColor)
                    }
                    .accessibilityLabel(String(.screen(
                        .session(
                        .accessibilityOpenNewChat))))
                }
            }
        }
    }
}





extension EnvironmentValues {
    @Entry
    var eventBus = EventBus()
}


