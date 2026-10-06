//
//  ButtonStyle.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 2/10/26.
//

import SwiftUI


struct ButtonStylePreference: ViewModifier {
    
    let tint: Color?
    
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            if let tint {
                content
                    .buttonStyle(.glassProminent)
                    .tint(tint)
            } else {
                content
                    .buttonStyle(.glass)
            }
        } else {
            content.buttonStyle(FallbackButtonStyle(tint: tint ?? .clear))
        }
    }
    
}

public extension View {
    func buttonStyleGlassOrFallback(_ tint: Color?) -> some View {
        modifier(ButtonStylePreference(tint: tint))
    }
}


private struct FallbackButtonStyle: PrimitiveButtonStyle {
    
    @Environment(\.isEnabled) var isEnabled
    
    let tint: Color
    
    func makeBody(configuration: Configuration) -> some View {
        Button(action: configuration.trigger) {
            configuration
                .label
                .padding()
                .background(tint, in: .capsule)
                .opacity(isEnabled ? 1 : 0.750)
        }
        .buttonStyle(.plain)
    }
    
}
