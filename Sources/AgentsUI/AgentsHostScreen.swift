//
//  AgentsHostScreen.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 29/9/26.
//


import SwiftUI
import AgentsClient



public struct AgentsHostScreen: View {
    
    @State var agent: AgentsClient!
    
    public enum Mode {
        case full
        case singleChat(UUID?)
    }
    
    let configuration: String
    
    public var body: some View {
        
        VStack {
            
        }
        .task {
            // agent.start(with: configuration)
        }
        
    }
    
}
