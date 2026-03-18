import Foundation

struct FeeMultipleIndexResponse: Codable {
    let time: String
    let feeEstimateMovingAverageRatio: FeeMultipleRatios
    let currentFeeEstimate: CurrentFeeEstimate
    let movingAverage: FeeMultipleMovingAverages
}

struct FeeMultipleRatios: Codable {
    let last365Days: Double
    let last30Days: Double
}

struct CurrentFeeEstimate: Codable {
    let time: String
    let satsPerByte: Int
}

struct FeeMultipleMovingAverages: Codable {
    let day: String
    let last365Days: Double
    let last30Days: Double
}

struct FeeMultipleHistoryItem: Codable {
    let time: String
    let feeEstimateMovingAverageRatio: FeeMultipleRatios
    let currentFeeEstimate: CurrentFeeEstimate
    let movingAverage: FeeMultipleMovingAverages
}
