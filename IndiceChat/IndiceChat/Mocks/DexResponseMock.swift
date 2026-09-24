//
//  DexResponseMock.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 23/9/26.
//

import Foundation
import AgentsModels

enum Mocks {
    
    static func response() -> DexConversation {
        let url  = Bundle.main.url(forResource: "DexResponseMock", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        let model = try! APIJSON.decoder().decode(DexConversation.self, from: data)
        
        return model
    }    
}
