import Foundation
import Combine

@MainActor
class AddressDetailViewModel: ObservableObject {
    @Published var addressStats: AddressStats?
    @Published var transactions: [Transaction] = []
    @Published var price: BitcoinPrice?
    @Published var isWatched: Bool = false
    @Published var isLoading = false
    @Published var error: String?
    
    private let service = MempoolService.shared
    private let watchlistStorage = WatchlistStorage()
    private let address: String
    
    init(address: String) {
        self.address = address
        self.isWatched = watchlistStorage.contains(identifier: address)
    }
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let stats = service.getAddress(address: address)
            async let txs = service.getAddressTransactions(address: address)
            async let btcPrice = service.getPrice()
            
            let (fetchedStats, fetchedTxs, fetchedPrice) = try await (stats, txs, btcPrice)
            
            self.addressStats = fetchedStats
            self.transactions = fetchedTxs
            self.price = fetchedPrice
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func toggleWatchlist() {
        if isWatched {
            let items = watchlistStorage.load()
            if let id = items.first(where: { $0.identifier == address })?.id {
                watchlistStorage.remove(id: id)
                isWatched = false
            }
        } else {
            _ = watchlistStorage.addAddress(address: address, label: nil)
            isWatched = true
        }
    }
}
