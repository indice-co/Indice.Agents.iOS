//
//  HistorySectionHeader.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 21/10/26.
//

import SwiftUI


public struct HistorySectionHeader: View {
    
    let date: Date
    
    public var body: some View {
        Text(date.formatted(.contextual(date: .abbreviated, time: .omitted)))
    }
}
