import SwiftUI

struct FeeMultipleSectionView: View {
    let indexData: FeeMultipleIndexResponse
    
    var body: some View {
        MiningCard(title: "BULL BITCOIN FEE MULTIPLE") {
            HStack(alignment: .top, spacing: 10) {
                // 365 Days
                FeeGaugeView(
                    title: "LAST 365 DAYS",
                    multiple: indexData.feeEstimateMovingAverageRatio.last365Days,
                    currentFee: indexData.currentFeeEstimate.satsPerByte,
                    averageFee: indexData.movingAverage.last365Days
                )
                
                // 30 Days
                FeeGaugeView(
                    title: "LAST 30 DAYS",
                    multiple: indexData.feeEstimateMovingAverageRatio.last30Days,
                    currentFee: indexData.currentFeeEstimate.satsPerByte,
                    averageFee: indexData.movingAverage.last30Days
                )
            }
        }
    }
}

struct FeeGaugeView: View {
    let title: String
    let multiple: Double
    let currentFee: Int
    let averageFee: Double
    
    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.headline.bold())
                .foregroundStyle(.white)
            
            VStack(spacing: 4) {
                Text(String(format: "Fee Multiple: %.2f", multiple))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                
                Text(String(format: "Current Fee: %d sats/vb", currentFee))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                
                Text(String(format: "Average Fee: %.2f sats/vb", averageFee))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
    }
}


