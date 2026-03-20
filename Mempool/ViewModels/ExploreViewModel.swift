import Foundation
import Combine
import SwiftUI

@Observable
@MainActor
class ExploreViewModel {
    // Core explore stats
    var recommendedFees: RecommendedFees?
    var projectedBlocks: [ProjectedBlock] = []
    var confirmedBlocks: [MempoolBlock] = []
    var price: BitcoinPrice?
    var mempoolStats: NetworkMempoolStats?
    
    // Mining stats
    var pools: [MiningPool] = []
    var hashrate: [Hashrate] = []
    var difficulty: DifficultyAdjustment?
    var rewardStats: MiningRewardStats?
    var tipHeight: Int?
    
    // Fee Multiple stats
    var feeMultipleIndex: FeeMultipleIndexResponse?
    
    // State
    var isLoading = false
    var error: String?
    var newBlockArrived = false
    
    private let service = MempoolService.shared
    private let feeMultipleService = FeeMultipleService.shared
    private let wsService = MempoolWebSocketService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        startPolling()
        subscribeToWebSocket()
    }
    
    func startPolling() {
        Task { await fetchData() }
        
        // General Data Polling (30s)
        // Reduced since WebSocket handles blocks, but will soon replace more with WS
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in await self?.fetchData() }
            }
            .store(in: &cancellables)
            
        // Projected Blocks Polling (5s)
        Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { [weak self] in await self?.fetchProjectedBlocks() }
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
    
    private func subscribeToWebSocket() {
        wsService.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .newBlock(let blockData):
                    self?.handleNewBlock(blockData)
                case .stats(let stats):
                    withAnimation { self?.mempoolStats = stats }
                case .hashrate(let rates):
                    // Keep the API fetched ones if WS ones are empty or just replace
                    if !rates.isEmpty {
                        withAnimation { self?.hashrate = rates }
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleNewBlock(_ blockData: NewBlockData) {
        // Haptic feedback for new block
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        // Trigger animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            newBlockArrived = true
        }
        
        // Reset animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            withAnimation {
                self?.newBlockArrived = false
            }
        }
        
        // Refresh data from REST API to get full block details, mining stats, etc
        Task { await fetchData() }
    }
    
    func fetchPrice() async {
        do {
            let p = try await service.getPrice()
            self.price = p
        } catch {
            print("Price fetch error: \(error)")
        }
    }
    
    func fetchProjectedBlocks() async {
        do {
            let blocks = try await service.getMempoolBlocks()
            withAnimation {
                self.projectedBlocks = blocks
            }
        } catch {
            print("Projected blocks fetch error: \(error)")
        }
    }
    
    func fetchData() async {
        if confirmedBlocks.isEmpty { isLoading = true }
        defer { isLoading = false }
        
        do {
            async let fees = service.getRecommendedFees()
            async let blocks = service.getMempoolBlocks()
            async let confirmed = service.getBlocks()
            async let btcPrice = service.getPrice()
            
            // Mining specific
            async let diff = service.getDifficultyAdjustment()
            async let p = service.getMiningPools(period: "1w")
            async let h = service.getHashrate(period: "3m")
            async let t = service.getTipHeight()
            async let s = service.getMiningRewardStats()
            
            // Fee Multiple
            async let fmIndex = try? feeMultipleService.getFeeMultipleIndex()
            
            let (fetchedFees, fetchedBlocks, fetchedConfirmed, fetchedPrice, fetchedDiff, fetchedPools, fetchedHashrate, fetchedTip, fetchedStats) = try await (fees, blocks, confirmed, btcPrice, diff, p, h, t, s)
            let fetchedFmIndex = await fmIndex
            
            self.recommendedFees = fetchedFees
            self.projectedBlocks = fetchedBlocks
            self.confirmedBlocks = fetchedConfirmed
            self.price = fetchedPrice
            self.difficulty = fetchedDiff
            self.pools = fetchedPools
            self.hashrate = fetchedHashrate
            self.tipHeight = fetchedTip
            self.rewardStats = fetchedStats
            
            if let index = fetchedFmIndex {
                self.feeMultipleIndex = index
            }
            
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
