import Foundation

enum MempoolError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
}

actor MempoolService {
    static let shared = MempoolService()
    private let baseURL = "https://mempool.space/api"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - General
    func getRecommendedFees() async throws -> RecommendedFees {
        return try await fetch(endpoint: "/v1/fees/recommended")
    }
    
    func getPrice() async throws -> BitcoinPrice {
        return try await fetch(endpoint: "/v1/prices")
    }
    
    func getHistoricalPrice(currency: String = "USD") async throws -> HistoricalPriceResponse {
        return try await fetch(endpoint: "/v1/historical-price?currency=\(currency)")
    }
    
    func getBlocks() async throws -> [MempoolBlock] {
        return try await fetch(endpoint: "/v1/blocks")
    }
    
    func getMempoolBlocks() async throws -> [ProjectedBlock] {
        return try await fetch(endpoint: "/v1/fees/mempool-blocks")
    }
    
    func getRecentTransactions() async throws -> [RecentTransaction] {
        return try await fetch(endpoint: "/mempool/recent")
    }
    
    func getTipHeight() async throws -> Int {
        let heightString: String = try await fetchString(endpoint: "/blocks/tip/height")
        if let height = Int(heightString) {
            return height
        }
        throw MempoolError.decodingError(NSError(domain: "Invalid Height", code: 0))
    }
    
    // MARK: - Blocks
    func getBlock(hash: String) async throws -> BlockDetail {
        return try await fetch(endpoint: "/v1/block/\(hash)")
    }
    
    func getBlockStatus(hash: String) async throws -> TxStatus { // Reusing TxStatus struct or create BlockStatus? The API returns {in_best_chain, height, next_best}
        // Let's create a struct for this if needed, but often block object has enough.
        // Actually /block/:hash returns full details.
        return try await fetch(endpoint: "/block/\(hash)/status")
    }
    
    func getBlockTransactions(hash: String, startIndex: Int = 0) async throws -> [Transaction] {
         return try await fetch(endpoint: "/block/\(hash)/txs/\(startIndex)")
    }
    
    // MARK: - Transactions
    func getTransaction(txid: String) async throws -> Transaction {
        return try await fetch(endpoint: "/tx/\(txid)")
    }
    
    // MARK: - Address
    func getAddress(address: String) async throws -> AddressStats {
        return try await fetch(endpoint: "/address/\(address)")
    }
    
    func getAddressTransactions(address: String) async throws -> [Transaction] {
        return try await fetch(endpoint: "/address/\(address)/txs")
    }
    
    func getAddressTransactionsChain(address: String, afterTxid: String? = nil) async throws -> [Transaction] {
        if let afterTxid = afterTxid {
            return try await fetch(endpoint: "/address/\(address)/txs/chain/\(afterTxid)")
        }
        return try await fetch(endpoint: "/address/\(address)/txs/chain")
    }
    
    /// Fetches ALL confirmed transactions for an address by paginating through the chain endpoint
    func getAllAddressTransactions(address: String) async throws -> [Transaction] {
        var allTxs: [Transaction] = []
        var lastTxid: String? = nil
        
        while true {
            let page = try await getAddressTransactionsChain(address: address, afterTxid: lastTxid)
            if page.isEmpty { break }
            allTxs.append(contentsOf: page)
            lastTxid = page.last?.txid
            // API returns 25 per page; if fewer, we've reached the end
            if page.count < 25 { break }
        }
        
        return allTxs
    }
    
    // MARK: - Mining
    func getMiningPools(period: String = "1w") async throws -> [MiningPool] {
         // The API returns an object { "pools": [ ... ] } usually?
         // Checking documentation: GET /api/v1/mining/pools/:timePeriod returns { pools: [{ poolId, name, ... }] }
         // Actually, let's assume it returns a list or a wrapper wrapper.
         // Let's fetch as Any first or map correctly. 
         // Most likely it returns a wrapper `{"pools": [...]}`.
         // Let's create a wrapper struct locally.
         struct PoolResponse: Codable {
             let pools: [MiningPool]
         }
         let response: PoolResponse = try await fetch(endpoint: "/v1/mining/pools/\(period)")
         return response.pools
    }
    
    func getHashrate(period: String = "3m") async throws -> [Hashrate] {
        struct HashrateResponse: Codable {
            let hashrates: [Hashrate]
        }
        // The endpoint returns {"hashrates": [...], "difficulty": [...]}
        // We only care about hashrates for now based on return type.
        let response: HashrateResponse = try await fetch(endpoint: "/v1/mining/hashrate/\(period)")
        return response.hashrates
    }
    
    func getDifficultyAdjustment() async throws -> DifficultyAdjustment {
        return try await fetch(endpoint: "/v1/difficulty-adjustment")
    }
    
    func getMiningRewardStats(blocks: Int = 144) async throws -> MiningRewardStats {
        return try await fetch(endpoint: "/v1/mining/reward-stats/\(blocks)")
    }
    
    // MARK: - Helpers
    private func fetch<T: Decodable>(endpoint: String) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw MempoolError.invalidURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, 
                  (200...299).contains(httpResponse.statusCode) else {
                throw MempoolError.apiError("Status code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            }
            
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw MempoolError.networkError(error)
        }
    }
    
    private func fetchString(endpoint: String) async throws -> String {
        guard let url = URL(string: baseURL + endpoint) else {
            throw MempoolError.invalidURL
        }
         do {
            let (data, _) = try await session.data(from: url)
            guard let string = String(data: data, encoding: .utf8) else {
                throw MempoolError.decodingError(NSError(domain: "Invalid String", code: 0))
            }
            return string
        } catch {
             throw MempoolError.networkError(error)
        }
    }
}
