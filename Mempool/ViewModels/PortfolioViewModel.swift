import Foundation
import SwiftUI
import Combine

@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var addresses: [PortfolioAddress] = []
    @Published var balances: [String: (confirmed: Int, mempool: Int)] = [:]
    @Published var balanceHistory: [BalanceDataPoint] = []
    @Published var priceHistory: [PriceDataPoint] = []
    @Published var portfolioValueHistory: [PriceDataPoint] = []
    @Published var price: BitcoinPrice?
    
    // Sorted historical prices for interpolation
    private var sortedHistoricalPrices: [(time: TimeInterval, usd: Double)] = []
    @Published var isLoading = false
    @Published var isAddingAddress = false
    @Published var error: String?
    
    private let service = MempoolService.shared
    private let storage = PortfolioStorage()
    
    var totalBalanceSats: Int {
        balances.values.reduce(0) { $0 + $1.confirmed + $1.mempool }
    }
    
    var totalBalanceBTC: Double {
        Double(totalBalanceSats) / 100_000_000
    }
    
    var totalBalanceUSD: Double {
        guard let usdPrice = price?.USD else { return 0 }
        return totalBalanceBTC * usdPrice
    }
    
    init() {
        addresses = storage.load()
    }
    
    func loadPortfolio(currency: String = "USD") async {
        guard !isLoading else { return } // Prevent cancellation/overlap fetch errors
        isLoading = true
        defer { isLoading = false }
        
        // Fetch current price
        self.price = try? await service.getPrice()
        
        // Fetch historical price
        do {
            let histResponse = try await service.getHistoricalPrice(currency: currency)
            self.priceHistory = buildPriceHistory(from: histResponse)
            // Store sorted prices for portfolio value interpolation
            self.sortedHistoricalPrices = histResponse.prices
                .map { (time: TimeInterval($0.time), usd: $0.price) }
                .sorted { $0.time < $1.time }
        } catch {
            print("Historical price fetch error: \(error)")
        }
        
        // Fetch balances for all addresses concurrently
        await withTaskGroup(of: (String, AddressStats?).self) { group in
            for addr in addresses {
                group.addTask { [service] in
                    let stats = try? await service.getAddress(address: addr.address)
                    return (addr.address, stats)
                }
            }
            
            for await (address, stats) in group {
                if let stats = stats {
                    let confirmed = stats.chain_stats.funded_txo_sum - stats.chain_stats.spent_txo_sum
                    let mempool = stats.mempool_stats.funded_txo_sum - stats.mempool_stats.spent_txo_sum
                    self.balances[address] = (confirmed: confirmed, mempool: mempool)
                }
            }
        }
        
        // Build balance history from transactions
        await buildBalanceHistory()
        
        // Build portfolio value history (balance × price over time)
        buildPortfolioValueHistory()
    }
    
    func addAddress(address: String, label: String?) async {
        isAddingAddress = true
        defer { isAddingAddress = false }
        
        // Basic validation
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "Address cannot be empty"
            return
        }
        
        // Check for duplicates
        if addresses.contains(where: { $0.address == trimmed }) {
            error = "Address already in portfolio"
            return
        }
        
        // Validate by trying to fetch from API
        do {
            let _ = try await service.getAddress(address: trimmed)
        } catch {
            self.error = "Invalid address or network error"
            return
        }
        
        let entry = storage.add(address: trimmed, label: label)
        addresses.append(entry)
        self.error = nil
        
        await loadPortfolio()
    }
    
    func removeAddress(at offsets: IndexSet) {
        for index in offsets {
            storage.remove(id: addresses[index].id)
        }
        addresses.remove(atOffsets: offsets)
        
        // Remove balances for deleted addresses
        let currentAddresses = Set(addresses.map(\.address))
        balances = balances.filter { currentAddresses.contains($0.key) }
        
        // Rebuild history
        Task { await buildBalanceHistory() }
    }
    
    func removeAddress(id: UUID) {
        storage.remove(id: id)
        if let idx = addresses.firstIndex(where: { $0.id == id }) {
            let addr = addresses[idx].address
            addresses.remove(at: idx)
            balances.removeValue(forKey: addr)
        }
        Task { await buildBalanceHistory() }
    }
    
    func renameAddress(id: UUID, newLabel: String) {
        if let idx = addresses.firstIndex(where: { $0.id == id }) {
            addresses[idx].label = newLabel.isEmpty ? nil : newLabel
            storage.save(addresses)
        }
    }
    
    private func buildBalanceHistory() async {
        guard !addresses.isEmpty else {
            balanceHistory = []
            return
        }
        
        // Collect all transactions across all portfolio addresses with their balance contributions
        // Collect all transactions across all portfolio addresses
        var allEvents: [(date: Date, deltaSats: Int)] = []
        var hasNetworkError = false
        
        await withTaskGroup(of: [(Date, Int)]?.self) { group in
            for addr in addresses {
                group.addTask { [service] in
                    guard let txs = try? await service.getAllAddressTransactions(address: addr.address) else {
                        return nil // Signals failure
                    }
                    return self.computeBalanceDeltas(for: addr.address, transactions: txs)
                }
            }
            
            for await events in group {
                if let events = events {
                    allEvents.append(contentsOf: events)
                } else {
                    hasNetworkError = true
                }
            }
        }
        
        if hasNetworkError && allEvents.isEmpty {
            // Retain existing balanceHistory on complete network failure to avoid chart flashing
            return
        }
        
        // Sort by date (oldest first)
        allEvents.sort { $0.date < $1.date }
        
        guard !allEvents.isEmpty else {
            if !hasNetworkError {
                balanceHistory = []
            }
            return
        }
        
        // Walk through events accumulating balance
        var runningBalance: Int = 0
        var points: [BalanceDataPoint] = []
        
        for event in allEvents {
            runningBalance += event.deltaSats
            let btc = Double(runningBalance) / 100_000_000.0
            points.append(BalanceDataPoint(date: event.date, balance: btc))
        }
        
        // Add current point
        points.append(BalanceDataPoint(date: Date(), balance: totalBalanceBTC))
        
        // Downsample if too many points (keep max ~100 for chart performance)
        if points.count > 100 {
            let step = points.count / 100
            var sampled: [BalanceDataPoint] = []
            for i in stride(from: 0, to: points.count, by: step) {
                sampled.append(points[i])
            }
            // Always include the last point
            if let last = points.last, sampled.last?.date != last.date {
                sampled.append(last)
            }
            self.balanceHistory = sampled
        } else {
            self.balanceHistory = points
        }
    }
    
    /// Compute the satoshi delta for each confirmed transaction for a given address
    nonisolated private func computeBalanceDeltas(for address: String, transactions: [Transaction]) -> [(Date, Int)] {
        var deltas: [(Date, Int)] = []
        
        for tx in transactions {
            guard let blockTime = tx.status.block_time else { continue }
            let date = Date(timeIntervalSince1970: TimeInterval(blockTime))
            
            var delta: Int = 0
            
            // Outputs that send TO this address (received)
            for output in tx.vout {
                if output.scriptpubkey_address == address {
                    delta += output.value
                }
            }
            
            // Inputs that spend FROM this address (sent)
            for input in tx.vin {
                if let prevout = input.prevout, prevout.scriptpubkey_address == address {
                    delta -= prevout.value
                }
            }
            
            if delta != 0 {
                deltas.append((date, delta))
            }
        }
        
        return deltas
    }
    
    private func buildPriceHistory(from response: HistoricalPriceResponse) -> [PriceDataPoint] {
        let entries = response.prices.sorted { $0.time < $1.time }
        
        guard !entries.isEmpty else { return [] }
        
        var points = entries.map { entry in
            PriceDataPoint(
                date: Date(timeIntervalSince1970: TimeInterval(entry.time)),
                price: Double(entry.price)
            )
        }
        
        // Downsample if too many points
        if points.count > 150 {
            let step = points.count / 150
            var sampled: [PriceDataPoint] = []
            for i in stride(from: 0, to: points.count, by: step) {
                sampled.append(points[i])
            }
            if let last = points.last {
                sampled.append(last)
            }
            points = sampled
        }
        
        return points
    }
    
    private func buildPortfolioValueHistory() {
        guard !balanceHistory.isEmpty, !sortedHistoricalPrices.isEmpty else {
            portfolioValueHistory = []
            return
        }
        
        var points: [PriceDataPoint] = []
        
        // 1. Iterate daily from the first balance date to today
        let firstDate = balanceHistory.first!.date
        let now = Date()
        let oneDay: TimeInterval = 24 * 60 * 60
        var currentDate = firstDate
        
        // Helper to grab instantaneous balance snapshot
        func getBalance(at date: Date) -> Double {
            var current: Double = 0
            for bp in balanceHistory {
                if bp.date <= date {
                    current = bp.balance
                } else {
                    break
                }
            }
            return current
        }
        
        while currentDate <= now {
            let bal = getBalance(at: currentDate)
            let btcPrice = lookupPrice(at: currentDate)
            points.append(PriceDataPoint(date: currentDate, price: bal * btcPrice))
            
            currentDate.addTimeInterval(oneDay)
        }
        
        // 2. Firmly anchor "Right Now" using exact lookups
        let currentBal = getBalance(at: now)
        let currentBtcPrice = lookupPrice(at: now)
        points.append(PriceDataPoint(date: now, price: currentBal * currentBtcPrice))
        
        // 3. Smooth UI chart render payload via decimation (> 150 points lags SwiftUI Charts)
        if points.count > 150 {
            let step = points.count / 150
            var sampled: [PriceDataPoint] = []
            for i in stride(from: 0, to: points.count, by: step) {
                sampled.append(points[i])
            }
            if let last = points.last, sampled.last?.date != last.date {
                sampled.append(last)
            }
            self.portfolioValueHistory = sampled
        } else {
            self.portfolioValueHistory = points
        }
    }
    
    /// Binary search for the nearest historical price at a given date
    private func lookupPrice(at date: Date) -> Double {
        let timestamp = date.timeIntervalSince1970
        let prices = sortedHistoricalPrices
        
        guard !prices.isEmpty else { return 0 }
        
        // Binary search for nearest timestamp
        var low = 0
        var high = prices.count - 1
        
        while low < high {
            let mid = (low + high) / 2
            if prices[mid].time < timestamp {
                low = mid + 1
            } else {
                high = mid
            }
        }
        
        // Pick the closest between low and low-1
        if low > 0 {
            let diffPrev = abs(prices[low - 1].time - timestamp)
            let diffCurr = abs(prices[low].time - timestamp)
            return diffPrev < diffCurr ? prices[low - 1].usd : prices[low].usd
        }
        
        return prices[low].usd
    }
}
