import SwiftUI
import Playgrounds

@main
struct IndiceChatApp: App {
    
    @StateObject private var state = AppState()
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                LoginView()
            }
            .presentPropagatedErrors()
            .applyLoadingState()
            .environmentObject(state)
        }
    }
}
