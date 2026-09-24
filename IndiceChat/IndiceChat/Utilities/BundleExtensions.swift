//
//  BundleExtensions.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 24/9/26.
//

import Foundation


extension Bundle {
    
    static var clientId: String {
        guard let clientId = main.infoDictionary?["clientId"] as? String else {
            fatalError("Client Id is not set in Info plist")
        }

        return clientId
    }
    
    static var clientSecret: String? {
        guard let clientSecret = main.infoDictionary?["clientSecret"] as? String else {
            fatalError("Client Secret is not set in Info plist")
        }

        return clientSecret
    }
    
}
