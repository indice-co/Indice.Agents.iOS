//
//  ThinkingBubble.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 24/9/26.
//

import SwiftUI

struct ThinkingBubble: View {
    
    private let dotSize: CGFloat = 4
    private let offset : CGFloat = .pi * 0.125
    
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
    
    @State private var animationState: CGFloat = 0
    
    var body: some View {
        HStack {
            // MovingBalls()
            Message()
        }
        .mask(alignment: .leading) {
            GeometryReader { proxy in
                let size     = proxy.size.height * 4
                let movement = proxy.size.width * 1
                let start    = proxy.size.width * -0.25
                
                Color.white.opacity(0.35)
                
                Circle()
                    .fill(.white)
                    .blur(radius: size / 2)
                    .frame(width: size, height: size)
                    .offset(x: start + animationState * movement)
            }
        }
        .onAppear(perform: {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animationState = 1
            }
        })
        .padding(dotSize)
        // .modifier(BackgroundApplier(shape: shape))
        .transition(
            .move(edge: .top)
            .combined(with: .opacity))
    }
 
    @ViewBuilder
    private func Message() -> some View {
        if let message {
            VStack(spacing: 2) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Color.brand
                    .frame(height: 2)
                    .clipShape(.capsule)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }
    
    private func MovingBalls() -> some View {
        TimelineView(.animation) { context in
            let progress = context
                .date
                .timeIntervalSince1970
            
            HStack(spacing: 4) {
                ForEach(0 ..< 3) { index in
                    
                    let phase = sin(progress * (CGFloat.pi * 2) + (CGFloat(index) * offset))
                    
                    Circle()
                        .fill(Color.blue)
                        .frame(width: dotSize, height: dotSize)
                        .transformEffect(.init(
                            translationX: 0,
                            y: (dotSize / 2) * phase))
                }
            }
            .frame(height: dotSize * 2)
        }
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


#Preview {
    ThinkingBubble(message: "Thinking hard")
}
