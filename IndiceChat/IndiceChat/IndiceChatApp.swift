import SwiftUI
import AgentsUI

@main
struct IndiceChatApp: App {
    
    @StateObject private var state = AppState()
    
    var body: some Scene {
        WindowGroup {
            NavigatorWrapper {
                //LoginView()
                AgentsHostScreen(client: state.client.agents)
            }
            .presentPropagatedErrors()
            .applyLoadingState()
            .environmentObject(state)
        }
    }
}
