import Foundation

struct MiningPool: Codable, Identifiable, Sendable {
    var id: Int { poolId }
    let poolId: Int
    let name: String
    let slug: String
    let rank: Int
    let blockCount: Int
    let emptyBlockCount: Int? // API sometimes omits this
    let avgMatchRate: Double?
    let expectedBlockCount: Double?
    let totalReward: Int?
}

struct PoolHashrate: Codable, Identifiable, Sendable {
    var id: Int64 { timestamp }
    let timestamp: Int64
    let avgHashrate: Double
    let share: Double
    let poolName: String
}

struct DifficultyAdjustment: Codable, Sendable {
    let progressPercent: Double
    let difficultyChange: Double
    let estimatedRetargetDate: Int
    let remainingBlocks: Int
    let remainingTime: Int
    let previousRetarget: Double
    let previousTime: Int
    let nextRetargetHeight: Int
    let timeAvg: Int
    let adjustedTimeAvg: Int
    let timeOffset: Int
}

struct Hashrate: Codable, Identifiable, Sendable {
     var id: Int64 { timestamp }
     let timestamp: Int64
     let avgHashrate: Double
}

struct MiningRewardStats: Codable, Sendable {
    let startBlock: Int
    let endBlock: Int
    let totalReward: String
    let totalFee: String
    let totalTx: String
}
