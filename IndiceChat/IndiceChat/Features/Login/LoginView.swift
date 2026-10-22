//
//  LoginView.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 8/7/26.
//

import SwiftUI
import IdentityClient
import AgentsUI

struct LoginView: View {
        
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var state: AppState
    // @EnvironmentObject var route: Router
    
    @State private var url: URL?
    @State private var delegate: SafariViewDelegate = .init()

    @State private var days: Int = .random(in: 0 ... 100)
    
    @State private var showAgent = false
    
    var body: some View {
        VStack {
            VStack {
                Dex
                    .ImageAndName(.vertical(positioning: .nameIcon), size: .hero)
                    .padding(.bottom)
                
                Text("Lets talk about it.")
                    .font(.system(size: 36).bold())
            }
            .frame(maxHeight: .infinity)
            
            VStack(spacing: 12) {
                Button(action: { state.initializeLogin() }) {
                    Text("Login").frame(maxWidth: .infinity)
                }
                .buttonStyleGlassOrFallback()
                
                if state.canQuickLogin {
                    Button(action: { state.tryRefreshLogin({ showAgent = true }) }) {
                        Text("Resume your previous session \(Image.forward)")
                            .underline()
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .padding(.bottom)
            
            Text("Days since leaking private API keys... \(days.formatted())")
                .font(.caption)
                .foregroundStyle(.secondary)
                .modifier(ContentNumericModifier(value: Double(days)))
                .task {
                    while !Task.isCancelled {
                        let delay = Duration.seconds(Double.random(in: 0.2 ... 1.5))
                        try? await Task.sleep(for: delay)
                        
                        if !Task.isCancelled {
                            days = .random(in: 0 ... 100)
                        }
                    }
                }
        }
        .fullScreenCover(item: $state.loginData, content: { data in
            SafariView(url: data.url)
        })
        .observeState(on: state)
        .onOpenURL(perform: handleCallbackURL(_:))
        .fullScreenCover(isPresented: $showAgent, content: {
            AgentsHostScreen(client: state.client.agents)
                .interactiveDismissDisabled()
        })
    }
    
     
    private func handleCallbackURL(_ url: URL) {
        guard url.scheme == "indice.mobile" else {
            return
        }
        
        state.completeLogin(
            returnURL: url,
            onSuccess: { showAgent = true })
    }
    
}

extension URL: @retroactive Identifiable {
    public var id: String { self.absoluteString }
}


private struct ContentNumericModifier: ViewModifier {
    
    let value: Double
    
    func body(content: Content) -> some View {
        if #available(iOS 17, *) {
            content.contentTransition(.numericText(value: value))
        } else {
            content.animation(.default, value: value)
        }
    }
}



#Preview {
    LoginView()
        .environmentObject(AppState())
}



