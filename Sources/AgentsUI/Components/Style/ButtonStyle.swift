//
//  ButtonStyle.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 2/10/26.
//

import SwiftUI


struct ButtonStylePreference: ViewModifier {
    
    @Environment(\.useGlassStyleIfAvailable) var useGlass
    @Environment(\.agentsUITheme) private var theme
    
    let tint: Color?
    
    private var resolvedColor: Color {
        tint ?? theme.primaryColor
    }
    
    func body(content: Content) -> some View {
        if useGlass, #available(iOS 26, macOS 26, *) {
            content
                .foregroundStyle(.foreground)
                .buttonStyle(.glassProminent)
                .tint(resolvedColor)
        } else {
            content.buttonStyle(FallbackButtonStyle(tint: resolvedColor))
        }
    }
    
}

public extension View {
    func buttonStyleGlassOrFallback(_ tint: Color? = nil) -> some View {
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
                .foregroundStyle(.foreground)
                .opacity(isEnabled ? 1 : 0.750)
        }
        .buttonStyle(.plain)
    }
    
}
