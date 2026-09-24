//
//  LoginView.swift
//  IndiceChat
//
//  Created by Nikolas Konstantakopoulos on 8/7/26.
//

import SwiftUI
import IdentityClient

struct LoginView: View {
    
    enum LoginState {
        case login
        case resume
    }
    
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var state: AppState
    
    @State private var url: URL?
    @State private var delegate: SafariViewDelegate = .init()
    
    @State private var loginState: LoginState? = nil
    
    @State private var days: Int = .random(in: 0 ... 100)
    
    var body: some View {
        
        VStack {
            
            Spacer()
            
            Dex
                .ImageAndName(.vertical, size: .hero)
                .padding(.bottom)
            
            Text("Lets talk about it.")
                .font(.system(size: 36).bold())
            
            Spacer()
            
            VStack(spacing: 12) {
                Button("Login", action: { state.initializeLogin() })
                    .buttonStyle(.glass(.regular.tint(.brand)))
                    .buttonSizing(.flexible)
                
                if state.canQuickLogin {
                    Button(action: { state.tryRefreshLogin({ loginState = .resume }) }) {
                        HStack {
                            Text("Resume your previous session \(Image.Forward())")
                                .underline()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .buttonSizing(.flexible)
                }
            }
            .padding()
            .padding(.bottom)
            
            Text("Days since leaking private API keys... \(days.formatted())")
                .font(.caption)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: Double(days)))
                .animation(.bouncy, value: days)
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
        .onOpenURL(perform: handleCallbackURL(_:))
        .navigationDestination(
            item: $loginState,
            destination: { state in ChatListView(navigateToRecentChat: state == .resume) })
    }

    private func handleCallbackURL(_ url: URL) {
        guard url.scheme == "indice.mobile" else {
            return
        }
        
        state.completeLogin(returnURL: url, onSuccess: {
            loginState = .login
        })
    }
    
}

extension URL: @retroactive Identifiable {
    public var id: String { self.absoluteString }
}

#Preview {
    LoginView()
        .environmentObject(AppState())
}


