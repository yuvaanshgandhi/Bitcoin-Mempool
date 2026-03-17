import SwiftUI
import UserNotifications

@main
struct MempoolApp: App {
    @StateObject private var currencySettings = CurrencySettings()
    
    init() {
        // Request notification permissions on launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(currencySettings)
        }
    }
}
