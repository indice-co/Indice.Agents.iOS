//
//  BackgroundStyle.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 2/10/26.
//


import SwiftUI

extension ShapeStyle {
    func secondaryOrSelf() -> AnyShapeStyle {
        if #available(iOS 17, macOS 14, *) {
            AnyShapeStyle(self.secondary)
        } else {
            AnyShapeStyle(self)
        }
    }
    
    func tertiaryOrSelf() -> AnyShapeStyle {
        if #available(iOS 17, macOS 14, *) {
            AnyShapeStyle(self.secondary)
        } else {
            AnyShapeStyle(self)
        }
    }
    
    func quaternaryOrSelf() -> AnyShapeStyle {
        if #available(iOS 17, macOS 14, *) {
            AnyShapeStyle(self.quaternary)
        } else {
            AnyShapeStyle(self)
        }
    }

    
    func quinaryOrSelf() -> AnyShapeStyle {
        if #available(iOS 17, macOS 14, *) {
            AnyShapeStyle(self.quinary)
        } else {
            AnyShapeStyle(self)
        }
    }
}
