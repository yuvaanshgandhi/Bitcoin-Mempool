import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var recommendedFees: RecommendedFees?
    @Published var projectedBlocks: [ProjectedBlock] = []
    @Published var confirmedBlocks: [MempoolBlock] = []
    @Published var price: BitcoinPrice?
    @Published var initialRecentTransactions: [RecentTransaction] = []
    @Published var difficulty: DifficultyAdjustment?
    @Published var isLoading = false
    @Published var error: String?
    
    private let service = MempoolService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        startPolling()
    }
    
    func startPolling() {
        Task { await fetchData() }
        
        // General Data Polling (5s as requested)
        Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in await self?.fetchData() }
            }
            .store(in: &cancellables)
            
        // Price Polling (2s)
        Timer.publish(every: 2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in await self?.fetchPrice() }
            }
            .store(in: &cancellables)
    }
    
    func fetchPrice() async {
        do {
            let p = try await service.getPrice()
            self.price = p
        } catch {
            print("Price fetch error: \(error)")
        }
    }
    
    func fetchData() async {
        // Don't set isLoading on refreshing, only initial logic if needed, 
        // to avoid screen flicker. But for now keep simple.
        if confirmedBlocks.isEmpty { isLoading = true }
        defer { isLoading = false }
        
        do {
            async let fees = service.getRecommendedFees()
            async let blocks = service.getMempoolBlocks()
            async let confirmed = service.getBlocks()
            async let btcPrice = service.getPrice()
            async let recentTxs = service.getRecentTransactions()
            async let diff = service.getDifficultyAdjustment()
            
            let (fetchedFees, fetchedBlocks, fetchedConfirmed, fetchedPrice, fetchedTxs, fetchedDiff) = try await (fees, blocks, confirmed, btcPrice, recentTxs, diff)
            
            self.recommendedFees = fetchedFees
            self.projectedBlocks = fetchedBlocks
            self.confirmedBlocks = fetchedConfirmed
            self.price = fetchedPrice
            self.initialRecentTransactions = fetchedTxs
            self.difficulty = fetchedDiff
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
