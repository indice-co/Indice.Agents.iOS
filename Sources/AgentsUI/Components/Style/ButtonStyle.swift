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
    let foreground: Color?
    
    private var resolvedColor: Color {
        tint ?? theme.primaryColor
    }
    
    private var resolvedForeground: Color {
        foreground ?? theme.onPrimaryColor
    }
    
    func body(content: Content) -> some View {
        if useGlass, #available(iOS 26, macOS 26, *) {
            content
                .foregroundStyle(resolvedForeground)
                .buttonStyle(.glassProminent)
                .tint(resolvedColor)
        } else {
            content.buttonStyle(FallbackButtonStyle(
                tint: resolvedColor,
                foreground: resolvedForeground))
        }
    }
    
}

public extension View {
    func buttonStyleGlassOrFallback(_ tint: Color? = nil, foreground: Color? = nil) -> some View {
        modifier(ButtonStylePreference(tint: tint, foreground: foreground))
    }
}


private struct FallbackButtonStyle: PrimitiveButtonStyle {
    
    @Environment(\.isEnabled) var isEnabled
    
    let tint: Color
    let foreground: Color
    
    func makeBody(configuration: Configuration) -> some View {
        Button(action: configuration.trigger) {
            configuration
                .label
                .padding()
                .foregroundStyle(foreground)
                .background(tint, in: .capsule)
                .opacity(isEnabled ? 1 : 0.750)
        }
        .buttonStyle(.plain)
    }
    
}
