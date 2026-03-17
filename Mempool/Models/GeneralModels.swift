import Foundation

struct RecommendedFees: Codable, Sendable {
    let fastestFee: Int
    let halfHourFee: Int
    let hourFee: Int
    let economyFee: Int
    let minimumFee: Int
}

struct MempoolInfo: Codable, Sendable {
    let size: Int
    let bytes: Int
    let usage: Int
    let total_fee: Double
}

// Search result wrapper
enum SearchResultType: Hashable, Sendable {
    case block
    case transaction
    case address
    case unknown
}

struct SearchResult: Identifiable, Hashable, Sendable {
    let id = UUID()
    let type: SearchResultType
    let key: String // The search term (hash, address)
}

struct BitcoinPrice: Codable, Sendable {
    let USD: Double
    let EUR: Double?
    let GBP: Double?
    let CAD: Double?
    let CHF: Double?
    let AUD: Double?
    let JPY: Double?
}
