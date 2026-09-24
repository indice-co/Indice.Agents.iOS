//
//  ThinkingBubble.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 24/9/26.
//

import SwiftUI

struct ThinkingBubble: View {
    
    private let dotSize: CGFloat = 8
    private let offset : CGFloat = .pi * 0.25
    
    private var corners: (large: CGFloat, small: CGFloat) {
        let large = dotSize * 1.5
        let small = dotSize * 0.5
        
        return (large, small)
    }
    
    private var shape: UnevenRoundedRectangle {
        let corners = self.corners
        
        return .init(
            topLeadingRadius: corners.large,
            bottomLeadingRadius: corners.large,
            bottomTrailingRadius: corners.small,
            topTrailingRadius: corners.large,
            style: .continuous)
    }
    
    let message: String?
    
    var body: some View {
        TimelineView(.animation) { context in
            let progress = context
                .date
                .timeIntervalSince1970
            
            HStack(spacing: 2) {
                ForEach(0 ..< 3) { index in
                    
                    let phase = sin(progress * (CGFloat.pi * 2) + (CGFloat(index) * offset))
                    
                    Circle()
                        .fill(Color.blue)
                        .frame(width: dotSize, height: dotSize)
                        .transformEffect(.init(
                            translationX: 0,
                            y: (dotSize / 2) * phase))
                }
                
                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: dotSize * 2)
        }
        .padding(dotSize)
        // .modifier(BackgroundApplier(shape: shape))
        .transition(
            .move(edge: .top)
            .combined(with: .opacity))
    }
 
    private struct BackgroundApplier<S: Shape>: ViewModifier {
        let shape: S
        func body(content: Self.Content) -> some View {
            if #available(iOS 26, *) {
                content.glassEffect(.clear.interactive(), in: shape)
            } else {
                content.background(.thinMaterial, in: shape)
            }
        }
    }
    
}
