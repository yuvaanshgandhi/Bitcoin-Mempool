import Foundation
import Combine
import SwiftUI

@MainActor
class ExploreViewModel: ObservableObject {
    // Core explore stats
    @Published var recommendedFees: RecommendedFees?
    @Published var projectedBlocks: [ProjectedBlock] = []
    @Published var confirmedBlocks: [MempoolBlock] = []
    @Published var price: BitcoinPrice?
    @Published var mempoolStats: NetworkMempoolStats?
    
    // Mining stats
    @Published var pools: [MiningPool] = []
    @Published var hashrate: [Hashrate] = []
    @Published var difficulty: DifficultyAdjustment?
    @Published var rewardStats: MiningRewardStats?
    @Published var tipHeight: Int?
    
    // State
    @Published var isLoading = false
    @Published var error: String?
    @Published var newBlockArrived = false
    
    private let service = MempoolService.shared
    private let wsService = MempoolWebSocketService.shared
    private var cancellables = Set<AnyCancellable>()
    private var projectedBlocksSubject = PassthroughSubject<[ProjectedBlock], Never>()
    
    init() {
        startPolling()
        subscribeToWebSocket()
        
        projectedBlocksSubject
            .throttle(for: .seconds(3), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] blocks in
                withAnimation { self?.projectedBlocks = blocks }
            }
            .store(in: &cancellables)
    }
    
    func startPolling() {
        Task { await fetchData() }
        
        // General Data Polling (10s)
        // Reduced since WebSocket handles blocks, but will soon replace more with WS
        Timer.publish(every: 10, on: .main, in: .common)
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
    
    private func subscribeToWebSocket() {
        wsService.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .newBlock(let blockData):
                    self?.handleNewBlock(blockData)
                case .projectedBlocks(let blocks):
                    self?.projectedBlocksSubject.send(blocks)
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
            
            let (fetchedFees, fetchedBlocks, fetchedConfirmed, fetchedPrice, fetchedDiff, fetchedPools, fetchedHashrate, fetchedTip, fetchedStats) = try await (fees, blocks, confirmed, btcPrice, diff, p, h, t, s)
            
            self.recommendedFees = fetchedFees
            self.projectedBlocks = fetchedBlocks
            self.confirmedBlocks = fetchedConfirmed
            self.price = fetchedPrice
            self.difficulty = fetchedDiff
            self.pools = fetchedPools
            self.hashrate = fetchedHashrate
            self.tipHeight = fetchedTip
            self.rewardStats = fetchedStats
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
