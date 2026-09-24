//
//  DexName.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 24/9/26.
//


import SwiftUI


enum Dex {
    
    enum Size: CaseIterable {
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
    
    struct Name: View {
        
        var size: Size = .medium
        
        var body: some View {
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
    
    
    struct Image: View {
      
        var size: Size = .medium
        
        var body: some View {
            SwiftUI.Image(size.asset)
                .resizable()
                .frame(width: size.size, height: size.size)
        }
    }
    
    
    struct ImageAndName: View {
        
        enum Orientation {
            case vertical  (positioning: Positioning = .iconName)
            case horizontal(positioning: Positioning = .iconName)

            static let vertical  : Self = .vertical  (positioning: .iconName)
            static let horizontal: Self = .horizontal(positioning: .iconName)
            
            fileprivate var positioning: Positioning {
                switch self {
                case .horizontal(let positioning): positioning
                case .vertical  (let positioning): positioning
                }
            }
            
            enum Positioning {
                case nameIcon
                case iconName
            }
        }
        
        private let orientation: Orientation
        private let size: Size
        
        private var positioning: Orientation.Positioning {
            orientation.positioning
        }
        
        init(_ orientation: Orientation = .horizontal, size: Size = .medium) {
            self.orientation = orientation
            self.size = size
        }
        
        private var layout: AnyLayout {
            switch orientation {
            case .horizontal: AnyLayout(HStackLayout())
            case .vertical  : AnyLayout(VStackLayout())
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
        
        var body: some View {
            layout { Content() }
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
