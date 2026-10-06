//
//  DexName.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 24/9/26.
//


import SwiftUI

public enum Dex {
    
    public enum Size: CaseIterable {
        /// Suitable for chat avatar, buttons, inputs
        case small
        
        /// Suitable for section type content. Prominent enough to show some detail.
        case medium
        
        /// Suitable for screen title image on views with content
        case large
        
        /// Suitable for Hero image i.e. the image is the center piece of the screen
        case hero
        
        
        fileprivate var size: CGFloat {
            switch self {
            case .small :  24
            case .medium:  42
            case .large : 128
            case .hero  : 256
            }
        }
        
        fileprivate var asset: ImageResource {
            switch self {
            case .small : .dexAvatar
            case .medium: .dexAvatar
            case .large : .dexLogo256
            case .hero  : .dexLogo512
            }
        }
        
        fileprivate var font: Font {
            switch self {
            case .small : .title3
            case .medium: .title2
            case .large : .title
            case .hero  : .system(size: 48, weight: .semibold)
            }
        }
        
        fileprivate var dotSize: CGFloat {
            switch self {
            case .small :  5
            case .medium:  6
            case .large :  7
            case .hero  : 10
            }
        }
    }
    
    public struct Name: View {
        
        var size: Size = .medium
        
        public init(size: Size = .medium) {
            self.size = size
        }
        
        public var body: some View {
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(verbatim: "dex")
                    .font(size.font)
                
                Circle()
                    .frame(width: size.dotSize, height: size.dotSize)
                    .foregroundStyle(Color.brand)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }
    
    
    public struct Image: View {
      
        var size: Size = .medium
        
        public init(size: Size = .medium) {
            self.size = size
        }
        
        public var body: some View {
            SwiftUI.Image(size.asset)
                .resizable()
                .frame(width: size.size, height: size.size)
        }
    }
    
    
    public struct ImageAndName: View {
        
        public enum Orientation: Sendable {
            case vertical  (positioning: Positioning = .iconName)
            case horizontal(positioning: Positioning = .iconName)

            public static let vertical  : Self = .vertical  (positioning: .iconName)
            public static let horizontal: Self = .horizontal(positioning: .iconName)
            
            fileprivate var positioning: Positioning {
                switch self {
                case .horizontal(let positioning): positioning
                case .vertical  (let positioning): positioning
                }
            }
            
            public enum Positioning: Sendable {
                case nameIcon
                case iconName
            }
        }
        
        private let orientation: Orientation
        private let size: Size
        
        private var positioning: Orientation.Positioning {
            orientation.positioning
        }
        
        public init(_ orientation: Orientation = .horizontal, size: Size = .medium) {
            self.orientation = orientation
            self.size = size
        }
        
        
        @ViewBuilder
        private func Layout(_ content: () -> some View) -> some View {
            switch orientation {
            case .horizontal: HStack(content: content)
            case .vertical  : VStack(content: content)
            }
        }
        
        @ViewBuilder
        private func Content() -> some View {
            switch positioning {
            case .nameIcon:
                Dex.Name (size: size)
                Dex.Image(size: size)
            case .iconName:
                Dex.Image(size: size)
                Dex.Name (size: size)
            }
        }
        
        public var body: some View {
            Layout { Content() }
                .fixedSize(
                    horizontal: true,
                    vertical: false)
        }
    }
    
}



#Preview {
    
    VStack {
        ForEach(Dex.Size.allCases, id: \.self) { size in
            HStack {
                Dex.Image(size: size)
                Dex.Name (size: size)
            }
        }
        .padding(.vertical)
    }
    .padding()
    
}
