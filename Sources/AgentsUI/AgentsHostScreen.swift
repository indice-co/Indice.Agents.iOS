//
//  AgentsHostScreen.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 21/10/26.
//

import SwiftUI
import AgentsClient

public struct AgentsHostConfiguration {
    
    public enum DismissBehavior {
        case invalid
        case custom(dismissRequested: () -> Void)
    }
    
    let theme: Theme
    let disclaimer: String?
    let dismissBehavior: DismissBehavior
    
    public init(
        theme: Theme = .default,
        disclaimer: String? = String(.screen(.session(.erroneousAgentDisclaimer))),
        dismissBehavior: DismissBehavior = .invalid
    ) {
        self.theme = theme
        self.disclaimer = disclaimer
        self.dismissBehavior = dismissBehavior
    }
}

public struct AgentsHostScreen<
    AgentAvatar: View,
    EmptySessionContent: View,
>: View {
    
    public typealias Configuration = AgentsHostConfiguration
    
    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion
    
    @FocusState private var focus
    
    @State private var eventBus = EventBus()
    @State private var sidebarOpen = false
    
    private let configuration: Configuration
    private let agents: AgentsClient
    private let agentAvatar: () -> AgentAvatar
    private let emptySessionContent: () -> EmptySessionContent
    
    private let contentDisclaimer: String?
    
    public init(
        client: AgentsClient,
        configuration: Configuration = .init(),
        contentDisclaimer: String? = nil,
        agentAvatar: @escaping () -> AgentAvatar = { Dex.ImageAndName(size: .small) },
        emptySessionContent: @escaping () -> EmptySessionContent = { EmptySessionPrompt() }
    ) {
        self.configuration       = configuration
        self.agents              = client
        self.agentAvatar         = agentAvatar
        self.emptySessionContent = emptySessionContent
        self.contentDisclaimer   = contentDisclaimer
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
                    SessionScreen(
                        agents,
                        contentDisclaimer: contentDisclaimer,
                        agentAvatar: agentAvatar,
                        emptySessionContent: emptySessionContent)
                    .focused($focus)
                    .modifier(ToolbarActionsModifier(
                        hasHistory: hasHistory,
                        dismissBehavior: configuration.dismissBehavior,
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
        .withAgentsUITheme(configuration.theme)
        .environment(\.eventBus, eventBus)
        .environment(\.useGlassStyleIfAvailable, true)
    }
}




private struct ToolbarActionsModifier: ViewModifier {
    
    @Environment(\.agentsUITheme) private var theme
    
    let hasHistory: Bool
    let dismissBehavior: AgentsHostConfiguration.DismissBehavior
    
    let historyAction: () -> Void
    let newChatAction: () -> Void
    
    func body(content: Content) -> some View {
        
        content.toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if hasHistory {
                    Button(action: historyAction) {
                        Image(systemName: "sidebar.left")
                            .foregroundStyle(theme.primaryColor)
                    }
                    .accessibilityLabel(String(.screen(.session(.accessibilityOpenHistory))))
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                if !hasHistory {
                    Button(action: newChatAction) {
                        Image(systemName: "plus")
                            .foregroundStyle(theme.primaryColor)
                    }
                    .accessibilityLabel(String(.screen(.session(.accessibilityOpenNewChat))))
                }
                
                if case .custom(let dismissRequested) = dismissBehavior {
                    Button(action: dismissRequested) {
                        Image(systemName: "xmark")
                            .foregroundStyle(theme.primaryColor)
                    }
                    .accessibilityLabel(String(.screen(.session(.accessibilityDismissChat))))
                }
            }
        }
    }
}





extension EnvironmentValues {
    @Entry
    var eventBus = EventBus()
}


