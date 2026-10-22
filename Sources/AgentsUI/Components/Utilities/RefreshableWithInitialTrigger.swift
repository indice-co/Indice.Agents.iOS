//
//  RefreshableWithInitialTrigger.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 21/10/26.
//

import SwiftUI

enum RefreshTriggerOrigin {
    case taskTrigger
    case refreshable
    
    var fromTask: Bool {
        switch self {
        case .taskTrigger: true
        case .refreshable: false
        }
    }
    
    var fromRefreshable: Bool {
        switch self {
        case .taskTrigger: false
        case .refreshable: true
        }
    }
}

private struct RefreshableWithInitialTrigger<Trigger: Equatable>: ViewModifier {
    
    let triggerId: Trigger?
    let operation: (RefreshTriggerOrigin) async -> Void
    
    func body(content: Content) -> some View {
        content
            .task(id: triggerId, { await operation(.taskTrigger) })
            .refreshable(action: { await operation(.refreshable) })
    }
}

extension View {
    
    func refreshableWithTrigger<Trigger: Equatable>(id: Trigger? = absentTrigger(), operation: @escaping (RefreshTriggerOrigin) async -> Void) -> some View {
        modifier(RefreshableWithInitialTrigger(triggerId: id, operation: operation))
    }
}

nonisolated
func absentTrigger() -> UUID? { nil }
