import Foundation

struct MempoolBlock: Codable, Identifiable, Hashable, Sendable {
    let id: String // The hash is returned as "id" in block details
    let height: Int
    let version: Int
    let timestamp: Int
    let tx_count: Int
    let size: Int
    let weight: Int
    let merkle_root: String
    let previousblockhash: String
    let mediantime: Int
    let nonce: Int
    let bits: Int
    let difficulty: Double
    
    // Additional fields for projected blocks
    let blockSize: Double?
    let blockVSize: Double?
    let nTx: Int?
    let totalFees: Int?
    let medianFee: Double?
    let feeRange: [Double]?
    
    // Natively retrieved from blocks endpoint
    let extras: BlockExtras?
}


struct ProjectedBlock: Codable, Identifiable, Hashable, Sendable {
    var id: UUID { UUID() }
    let blockSize: Double
    let blockVSize: Double
    let nTx: Int
    let totalFees: Int
    let medianFee: Double
    let feeRange: [Double]
}

struct BlockDetail: Codable, Identifiable, Sendable {
    var id: String { id_val }
    let id_val: String // API returns "id" which is the hash
    let height: Int
    let version: Int
    let timestamp: Int
    let tx_count: Int
    let size: Int
    let weight: Int
    let merkle_root: String
    let previousblockhash: String
    let mediantime: Int
    let nonce: Int
    let bits: Int
    let difficulty: Double
    let extras: BlockExtras?
    
    enum CodingKeys: String, CodingKey {
        case id_val = "id"
        case height, version, timestamp, tx_count, size, weight, merkle_root, previousblockhash, mediantime, nonce, bits, difficulty
        case extras
    }
}

struct BlockExtras: Codable, Hashable, Sendable {
    let totalFees: Int
    let medianFee: Double
    let feeRange: [Double]
    let reward: Int
    let pool: PoolInfo
}

struct PoolInfo: Codable, Hashable, Sendable {
    let id: Int
    let name: String
    let slug: String
}
