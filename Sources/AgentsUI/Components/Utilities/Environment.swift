//
//  Environment.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 2/10/26.
//

import SwiftUI

extension EnvironmentValues {
    @Entry
    fileprivate(set)
    var chatResponder: ChatSelectionResponder?
}

extension View {
    func withChatResponder(_ object: ChatSelectionResponder?) -> some View {
        self.environment(\.chatResponder, object)
    }
}


extension EnvironmentValues {
    @Entry
    var useGlassStyleIfAvailable = true
}


import AgentsModels

protocol ChatSelectionResponder: AnyObject {
    func response(withMessage message: String)
    func score(_ score: MessageScore, messageId: DexChatMessage.ID)
}


