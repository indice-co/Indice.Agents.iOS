//
//  UIText.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 2/10/26.
//

import SwiftUI

public enum UIText {
    public typealias Localized = String.LocalizationValue
    
    case screen(Screen)
    
    public var localizationKey: Localized {
        get {
            switch self {
            case .screen(let value): value.value
            }
        }
    }
    
    public enum Screen {
        case history(History)
        case session(Session)

        fileprivate var value: Localized {
            switch self {
            case .history(let value): value.rawValue
            case .session(let value): value.rawValue
            }
        }
        
        public enum History: Localized {
            case navTitle = "screen.history.nav_title"
            case unnamed  = "screen.history.session.unnamed"
        }
        
        public enum Session: Localized {
            case navTitle = "screen.session.nav_title"
            case thinking = "screen.session.thinking"
            case inputPrompt = "screen.session.input.prompt"
            
            case emptySessionPrefix  = "screen.session.empty_prefix"
            case emptySessionMessage = "screen.session.empty_message"
        }
    }
}


public extension String {
    init(_ uiText: UIText) {
        self.init(localized: uiText.localizationKey)
    }
}
