import Foundation
import Combine

@MainActor
class TransactionDetailViewModel: ObservableObject {
    @Published var transaction: Transaction?
    @Published var price: BitcoinPrice?
    @Published var isLoading = false
    @Published var error: String?
    @Published var isInWatchlist = false
    @Published var addedToWatchlist = false
    
    private let service = MempoolService.shared
    private let watchlistStorage = WatchlistStorage()
    private let txid: String
    
    init(txid: String) {
        self.txid = txid
        self.isInWatchlist = watchlistStorage.contains(identifier: txid)
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
    
    func addToWatchlist(label: String? = nil) {
        guard !isInWatchlist else { return }
        _ = watchlistStorage.addTransaction(txid: txid, label: label)
        isInWatchlist = true
        addedToWatchlist = true
        
        // Track via WebSocket
        MempoolWebSocketService.shared.trackTransaction(txid)
    }
}
