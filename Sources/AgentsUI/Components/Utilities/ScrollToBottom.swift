//
//  ScrollToBottom.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 21/10/26.
//

import SwiftUI


private struct ScrollToBottom<T: Hashable>: ViewModifier {
    
    let lastID: T?
    
    func body(content: Content) -> some View {
        if false, #available(iOS 17, *) {
            content.defaultScrollAnchor(.bottom)
        } else {
            ScrollViewReader { proxy in
                content
                    .onChange(of: lastID) { value in
                        guard let value else { return }
                        withAnimation { proxy.scrollTo(value) }
                    }
            }
        }
    }
}


extension View {
    
    func scrollToBottom<T: Hashable>(trigger: T?) -> some View {
        modifier(ScrollToBottom(lastID: trigger))
    }
    
}
