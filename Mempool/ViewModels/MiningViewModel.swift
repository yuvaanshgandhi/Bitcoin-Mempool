import Foundation
import Combine

@MainActor
class MiningViewModel: ObservableObject {
    @Published var pools: [MiningPool] = []
    @Published var hashrate: [Hashrate] = []
    @Published var difficulty: DifficultyAdjustment?
    @Published var tipHeight: Int?
    @Published var rewardStats: MiningRewardStats?
    @Published var price: BitcoinPrice?
    @Published var isLoading = false
    @Published var error: String?
    
    private let service = MempoolService.shared
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            print("MiningViewModel: Starting fetch...")
            async let poolsList = service.getMiningPools(period: "1w")
            async let hashrateList = service.getHashrate(period: "3m")
            async let diff = service.getDifficultyAdjustment()
            async let tip = service.getTipHeight()
            async let stats = service.getMiningRewardStats()
            async let btcPrice = service.getPrice()
            
            let (p, h, d, t, s, pr) = try await (poolsList, hashrateList, diff, tip, stats, btcPrice)
            
            print("MiningViewModel: Fetch success. Pools: \(p.count), Hashrate: \(h.count)")
            
            self.pools = p
            self.hashrate = h
            self.difficulty = d
            self.tipHeight = t
            self.rewardStats = s
            self.price = pr
        } catch {
            print("MiningViewModel: Fetch failed: \(error)")
            self.error = error.localizedDescription
        }
    }
}
