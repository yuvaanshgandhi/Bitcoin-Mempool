import Foundation
import Combine
import UserNotifications

@MainActor
class TransactionDetailViewModel: ObservableObject {
    @Published var transaction: Transaction?
    @Published var price: BitcoinPrice?
    @Published var isLoading = false
    @Published var error: String?
    @Published var isWatchingForConfirmation = false
    @Published var notificationScheduled = false
    
    private let service = MempoolService.shared
    private let txid: String
    private var watchTimer: AnyCancellable?
    
    init(txid: String) {
        self.txid = txid
    }
    
    deinit {
        watchTimer?.cancel()
    }
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let tx = service.getTransaction(txid: txid)
            async let p = service.getPrice()
            let (fetchedTx, fetchedPrice) = try await (tx, p)
            self.transaction = fetchedTx
            self.price = fetchedPrice
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func watchForConfirmation() {
        guard !isWatchingForConfirmation else { return }
        isWatchingForConfirmation = true
        
        // Poll every 30 seconds
        watchTimer = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.checkConfirmation()
                }
            }
    }
    
    private func checkConfirmation() async {
        do {
            let tx = try await service.getTransaction(txid: txid)
            self.transaction = tx
            
            if tx.status.confirmed {
                // Transaction confirmed! Send notification
                watchTimer?.cancel()
                watchTimer = nil
                isWatchingForConfirmation = false
                notificationScheduled = true
                
                sendConfirmationNotification(txid: txid, blockHeight: tx.status.block_height)
            }
        } catch {
            print("Watch poll error: \(error)")
        }
    }
    
    private func sendConfirmationNotification(txid: String, blockHeight: Int?) {
        let content = UNMutableNotificationContent()
        content.title = "Transaction Confirmed ✅"
        content.body = "Transaction \(txid.prefix(12))... has been confirmed" + (blockHeight != nil ? " in block #\(blockHeight!)" : "")
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "tx-confirmed-\(txid)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }
}
