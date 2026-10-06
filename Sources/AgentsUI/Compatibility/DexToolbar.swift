//
//  DexToolbar.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 2/10/26.
//

import SwiftUI

struct DEXToolbarModifier: ViewModifier {
    
    let onSelection: (UUID?) -> Void
    
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content.toolbar(content: {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { onSelection(nil) }) {
                        Image.NewChat()
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Dex.ImageAndName(size: .small)
                }
                .sharedBackgroundVisibility(.hidden)
            })
        } else {
            content.toolbar(content: {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { onSelection(nil) }) {
                        Image.NewChat()
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Dex.ImageAndName(size: .small)
                }
            })
        }
        
    }
}
