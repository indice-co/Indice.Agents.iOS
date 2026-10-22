//
//  asdf.swift
//  Indice.Agents
//
//  Created by Nikolas Konstantakopoulos on 2/10/26.
//


import SwiftUI


extension OpenURLAction {
    func open(_ url: URL, prefersInApp: Bool) {
        if #available(iOS 26, macOS 26, *) {
            self.callAsFunction(url, prefersInApp: prefersInApp)
        } else {
            self.callAsFunction(url)
        }
    }
}
