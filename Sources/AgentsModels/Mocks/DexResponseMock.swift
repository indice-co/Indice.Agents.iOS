//
//  DexResponseMock.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 23/9/26.
//

import Foundation

public enum Mocks {
    
    public static func response() -> DexConversation {
        let url  = Bundle.module.url(forResource: "DexResponseMock", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        let model = try! APIJSON.decoder().decode(DexConversation.self, from: data)
        
        return model
    }    
}
