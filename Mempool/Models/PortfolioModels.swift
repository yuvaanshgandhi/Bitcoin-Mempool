import Foundation

struct PortfolioAddress: Codable, Identifiable, Hashable {
    let id: UUID
    var address: String
    var label: String?
    let dateAdded: Date
    
    init(address: String, label: String? = nil) {
        self.id = UUID()
        self.address = address
        self.label = label
        self.dateAdded = Date()
    }
}

struct BalanceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let balance: Double // in BTC
}

struct PriceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let price: Double // USD
}

// API response models for /v1/historical-price
struct HistoricalPriceResponse: Codable {
    let prices: [HistoricalPriceEntry]
}

struct HistoricalPriceEntry: Codable {
    let time: Int
    let USD: Double
}
