//
//  ImagerExtensions.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 24/9/26.
//

import SwiftUI


extension Image {
    
    static func Forward () -> Image { Image(systemName: "chevron.forward")  }
    static func Backward() -> Image { Image(systemName: "chevron.backward") }
    
    static func NewChat()  -> Image { Image(systemName: "square.and.pencil") }
    
}
