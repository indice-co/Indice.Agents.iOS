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
    case utility(Utility)
    
    
    
    public var localizationKey: Localized {
        get {
            switch self {
            case .screen (let value): value.value
            case .utility(let value): value.rawValue
            }
        }
    }
    
    
    public enum Utility: Localized {
        case openAgents = "utility.agents.open"
        case closeAgents = "utility.agents.close"

        case dateToday = "utility.date.today"
        case dateYesterday = "utility.date.yesterday"
        
        case mediaTypeUnavailable = "utility.media_type.unavailable"
        case mediaTypeLoading = "utility.media_type.loading"
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
            case navTitle = "screen.history.nav.title"
            case unnamed  = "screen.history.session.title.unnamed"
            case newChat  = "screen.history.action.new_chat"
        }
        
        public enum Session: Localized {
            case navTitle = "screen.session.nav.title.unnamed"
            case thinking = "screen.session.thinking"
            case inputPrompt = "screen.session.input.prompt"
            
            case citationsCollapse = "screen.session.citations.collapse"
            case multipleChoiceCTA = "screen.session.multiple_choice.continue"
            
            case greetingsTitlePrefix = "screen.session.greetings.title_prefix"
            case greetingsDescription = "screen.session.greetings.description"
            
            case messageStatusStoppedPartialReply = "screen.session.message.status.stopped_partial"
            case messageStatusIncompleteReply = "screen.session.message.status.incomplete"
            
            case emptySessionPrefix  = "screen.session.empty_prefix"
            case emptySessionMessage = "screen.session.empty_message"
            
            case erroneousAgentDisclaimer = "screen.session.erroneous_agent.disclaimer"
            
            case accessibilityOpenHistory = "screen.session.open_history.accessibility"
            case accessibilityDismissChat = "screen.session.dismiss_chat.accessibility"
            case accessibilityOpenNewChat = "screen.session.open_new_chat.accessibility"
        }
    }
}


public extension String {
    init(_ uiText: UIText, ) {
        self.init(localized: uiText.localizationKey, bundle: .module)
    }
}
