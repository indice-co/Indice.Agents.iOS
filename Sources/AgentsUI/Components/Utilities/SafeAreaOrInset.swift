//
//  SafeAreaOrInset.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 21/10/26.
//

import SwiftUI


private struct SafeAreaOrInset<AreaContent: View>: ViewModifier {
    
    var edge: VerticalEdge = .bottom
    var fallback: SafeAreaFallbackStyle = .material
    
    let label: () -> AreaContent
    
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content.safeAreaBar(edge: edge) {
                label()
            }
        } else {
            content.safeAreaInset(edge: edge) {
                switch fallback {
                case .material:
                    label()
                        .shadow(color: Color.black.opacity(0.125), radius: 16)
                        .background(.ultraThinMaterial)
                case .clear:
                    label()
                        .shadow(color: Color.black.opacity(0.125), radius: 16)
                        .background(.clear)
                }
            }
        }
    }
}


enum SafeAreaFallbackStyle {
    case material
    case clear
}



extension View {
    
    func safeAreaOrInset<Content: View>(
        edge: VerticalEdge = .bottom,
        safeAreaStyle fallback: SafeAreaFallbackStyle = .material,
        content: @escaping () -> Content
    ) -> some View {
        modifier(SafeAreaOrInset(edge: edge, fallback: fallback, label: content))
    }
    
}
