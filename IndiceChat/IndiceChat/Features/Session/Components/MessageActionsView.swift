//
//  MessageActionsView.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 29/9/26.
//

import SwiftUI
import enum AgentsModels.MessageScore

struct MessageActionsView: View {
    
    let onScore: ((MessageScore) -> Void)?
    let currentScore: MessageScore?
    
    var body: some View {
        HStack {
            ScoreButtons()
        }
    }
    
    private func scoreColor(for score: MessageScore) -> Color {
        currentScore == score
        ? Color.brand
        : Color.primary.opacity(0.65)
    }
    
    private func symbolVariant(for score: MessageScore) -> SymbolVariants {
        currentScore == score ? .fill : .none
    }
    
    private func scale(for score: MessageScore) -> CGSize {
        guard let currentScore else {
            return .init(width: 1, height: 1)
        }
        
        let factor: CGFloat = currentScore == score ? 1 : 0.75
        
        return .init(width: factor, height: factor)
    }
    
    @ViewBuilder
    private func ScoreButtons() -> some View {
        if let onScore {
            Group {
                Button(action: { onScore(.positive) }) {
                    Image(systemName: "hand.thumbsup")
                        .animation(.default, body: { view in
                            view
                                .symbolVariant(symbolVariant(for: .positive))
                                .foregroundStyle(scoreColor(for: .positive))
                                .scaleEffect(scale(for: .positive), anchor: .center)
                        })
                }
                
                Button(action: { onScore(.negative) }) {
                    Image(systemName: "hand.thumbsdown")
                        .animation(.default, body: { view in
                            view
                                .symbolVariant(symbolVariant(for: .negative))
                                .foregroundStyle(scoreColor(for: .negative))
                                .scaleEffect(scale(for: .negative), anchor: .center)
                        })
                }
            }
            .buttonStyle(.plain)
        }
    }
    
}
