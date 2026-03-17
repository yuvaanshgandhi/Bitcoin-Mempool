import Foundation

struct Transaction: Codable, Identifiable, Sendable {
    var id: String { txid }
    let txid: String
    let version: Int
    let locktime: Int
    let vin: [TxInput]
    let vout: [TxOutput]
    let size: Int
    let weight: Int
    let fee: Int
    let status: TxStatus
}

struct TxInput: Codable, Identifiable, Sendable {
    var id: String { txid + String(vout ?? 0) } // Composite ID
    let txid: String
    let vout: Int?
    let prevout: TxOutput?
    let scriptsig: String?
    let scriptsig_asm: String?
    let witness: [String]?
    let is_coinbase: Bool
    let sequence: Int
}

struct TxOutput: Codable, Identifiable, Sendable {
    var id: UUID { UUID() } // Outputs need a unique ID, usually txid:vout but here it's nested
    let scriptpubkey: String
    let scriptpubkey_asm: String
    let scriptpubkey_type: String
    let scriptpubkey_address: String?
    let value: Int
}

struct TxStatus: Codable, Sendable {
    let confirmed: Bool
    let block_height: Int?
    let block_hash: String?
    let block_time: Int?
}

struct AddressStats: Codable, Sendable {
    let address: String
    let chain_stats: ChainStats
    let mempool_stats: MempoolStats
}

struct ChainStats: Codable, Sendable {
    let funded_txo_count: Int
    let funded_txo_sum: Int
    let spent_txo_count: Int
    let spent_txo_sum: Int
    let tx_count: Int
}

struct MempoolStats: Codable, Sendable {
    let funded_txo_count: Int
    let funded_txo_sum: Int
    let spent_txo_count: Int
    let spent_txo_sum: Int
    let tx_count: Int
}

struct RecentTransaction: Codable, Identifiable, Hashable, Sendable {
    let txid: String
    let fee: Int
    let vsize: Int
    let value: Int
    
    var id: String { txid }
}
