//
//  LandingScreen.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 5/10/26.
//

import SwiftUI

struct LandingScreen: View {
    var body: some View {
        VStack {
            
            Button("Start guest session", action: {
                //navigator.presetn(AgentsUIHost(viewModel.agent))
            })
            
            Button("Start login session", action: {
                
            })

        }
    }
}


import Combine
import AgentsClient
import NetworkClient


//final class ViewModel2: ViewModel {
//        
//    var agent = AgentsClient(
//        configuration: .init(
//            baseURL: URL(string: "https://agents.indice.gr")!,
//            userContext: .accessToken({ "" }),
//        processorBuilder: { NetworkClient() })
//    
//    @Published
//    private(set)
//    var agentsHandle: Any?
//    
//    func startGuest() {
//        
//        // agents/kavataza/guestAccessToken
//        
//        loadAsync {
//            let handle = try await $0
//                .agent
//                .create(.userProvider)
//            
//            let handle = try await $0
//                .agent
//                .create(.guest) // throw active instance
//            
//            try await handle.migrate(from: self.guestHandle)
//            
//        } onSuccess: { handle in
//            
//            
//            // User
//            agentsHandle = handle
//        }
//    }
//
//    
//    func startLogin() {
//        
//    }
//    
//}
//
//
//
//
//#Preview {
//    LandingScreen()
//}
