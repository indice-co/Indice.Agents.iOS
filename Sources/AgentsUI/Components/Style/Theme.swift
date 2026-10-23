//
//  Theme.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 22/10/26.
//

import SwiftUI


public struct Theme: Sendable {
    
    public let primaryColor: Color
    public let secondaryColor: Color
    public let onPrimaryColor: Color
    public let onSecondaryColor: Color
    
    public init(
        primaryColor: Color,
        secondaryColor: Color,
        onPrimaryColor: Color,
        onSecondaryColor: Color,
    ) {
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.onPrimaryColor = onPrimaryColor
        self.onSecondaryColor = onSecondaryColor
    }
    
    public static let `default` = Theme(
        primaryColor: .brand,
        secondaryColor: .brandSecondary,
        onPrimaryColor: .white,
        onSecondaryColor: .white)
}


internal extension EnvironmentValues {
    @Entry
    fileprivate(set)
    var agentsUITheme: Theme = .default
}

public extension View {
    
    func withAgentsUITheme(_ theme: Theme) -> some View {
        environment(\.agentsUITheme, theme)
    }
    
}
