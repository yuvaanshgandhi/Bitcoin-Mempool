import SwiftUI

@main
struct MempoolApp: App {
    @StateObject private var currencySettings = CurrencySettings()
    @StateObject private var webSocketService = MempoolWebSocketService.shared
    
    init() {
        // Connect WebSocket on launch for real-time updates
        MempoolWebSocketService.shared.connect()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(currencySettings)
                .environmentObject(webSocketService)
        }
    }
}
