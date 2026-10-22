//
//  EventBus.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 21/10/26.
//

import Combine
import struct AgentsModels.ConversationListItem

public final class EventBus {
    
    public enum Request {
        case newChat
        case chat(id: ConversationListItem.ID)
    }
    
    public enum Event {
        case deleted(chatId: ConversationListItem.ID)
    }
    
    private let requestChannel = PassthroughSubject<Request, Never>()
    private let eventChannel   = PassthroughSubject<Event,   Never>()
    public  var requests: AnyPublisher<Request, Never> { requestChannel.eraseToAnyPublisher() }
    public  var events  : AnyPublisher<Event,   Never> { eventChannel  .eraseToAnyPublisher() }

    @MainActor
    public func sendRequest(_ request: Request) {
        requestChannel.send(request)
    }
    
    @MainActor
    public func sendEvent(_ event: Event) {
        eventChannel.send(event)
    }
}
