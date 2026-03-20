import SwiftUI

@main
struct MempoolApp: App {
    @State private var currencySettings = CurrencySettings()
    @State private var webSocketService = MempoolWebSocketService.shared
    
    init() {
        // Connect WebSocket on launch for real-time updates
        MempoolWebSocketService.shared.connect()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(currencySettings)
                .environment(webSocketService)
        }
    }
}
