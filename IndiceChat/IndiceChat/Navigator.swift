//
//  Navigator.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 2/10/26.
//


import SwiftUI

struct NavigatorWrapper<Content: View>: View {
    
    @StateObject private var router = Router()
    
    let content: () -> Content
    
    var body: some View {
        NavigationStack(path: $router.path) {
            content()
        }
        .environmentObject(router)
    }
}



enum Destinations: Hashable {
    case chat(UUID?)
    case list
}



import Combine

@MainActor
final class Router: ObservableObject {
    
    @Published
    var path = NavigationPath()
    
    func navigate(to destination: Destinations) {
        path.append(destination)
    }
}
