import SwiftUI
import Charts

struct ExploreView: View {
    @State private var viewModel = ExploreViewModel()
    @Environment(CurrencySettings.self) var currencySettings
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Modern Header: Block Height | Price
                HStack(alignment: .center) {
                    VStack(alignment: .leading) {
                        Text("Block Height")
                            .font(.caption).foregroundStyle(.white.opacity(0.6))
                        if let lastBlock = viewModel.confirmedBlocks.first {
                            Text("\(lastBlock.height)")
                                .font(.title2.bold().monospaced())
                                .foregroundStyle(.white)
                        } else {
                            Text("---")
                                .font(.title2.bold().monospaced())
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Bitcoin Price")
                            .font(.caption).foregroundStyle(.white.opacity(0.6))
                        if let price = viewModel.price {
                            Text(currencySettings.formatFiat(currencySettings.price(from: price), fractionDigits: 0))
                                .font(.title2.bold().monospaced())
                                .foregroundStyle(.green)
                        } else {
                            Text("---")
                                .font(.title2.bold().monospaced())
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Fee Ticker (Fast | Medium | Slow)
                if let fees = viewModel.recommendedFees {
                    GlassCard {
                        HStack(spacing: 0) {
                            FeeItem(title: "Fast", fee: fees.fastestFee, color: .red)
                            Divider().background(.white.opacity(0.2))
                            FeeItem(title: "Medium", fee: fees.halfHourFee, color: .orange)
                            Divider().background(.white.opacity(0.2))
                            FeeItem(title: "Slow", fee: fees.hourFee, color: .yellow)
                        }
                        .padding(.vertical, 10)
                    }
                    .padding(.horizontal)
                }
                
                // Unified Block Stream (Projected + Confirmed)
                BlockStreamView(
                    projectedBlocks: viewModel.projectedBlocks,
                    confirmedBlocks: viewModel.confirmedBlocks,
                    newBlockArrived: viewModel.newBlockArrived
                )
                
                // Mining Stats Integration
                
                // 1. Difficulty Adjustment
                if let diff = viewModel.difficulty {
                    DifficultyAdjustmentView(diff: diff)
                        .padding(.horizontal)
                }
                
                // 1.5 Halving Countdown
                if let tip = viewModel.tipHeight {
                    HalvingCountdownView(tipHeight: tip)
                        .padding(.horizontal)
                }
                
                // 2. Hashrate Chart
                if !viewModel.hashrate.isEmpty {
                    HashrateChartView(hashrate: viewModel.hashrate)
                        .padding(.horizontal)
                }
                
                // 3. Mining Pools
                if !viewModel.pools.isEmpty {
                    PoolsDistributionView(pools: viewModel.pools)
                        .padding(.horizontal)
                }
                
                // 4. Fee Multiple
                if let index = viewModel.feeMultipleIndex {
                    FeeMultipleSectionView(
                        indexData: index
                    )
                    .padding(.horizontal)
                }
                
            }
            .padding(.bottom, 50)
        }
        .refreshable {
             await viewModel.fetchData()
        }
    }
}

// Mining Components
struct MiningCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.caption2)
                .bold()
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
            
            content
        }
        .padding()
        .background(Color(white: 0.08))
        .cornerRadius(10)
    }
}

struct FeeItem: View {
    let title: String
    let fee: Int
    let color: Color
    
    var body: some View {
        VStack {
            Text("\(fee)")
                .font(.title3.bold())
                .foregroundStyle(color)
            Text("sat/vB")
                .font(.caption2).foregroundStyle(.white.opacity(0.6))
            Text(title)
                .font(.caption.bold()).foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }
}

struct ProjectedBlockCard: View {
    let block: ProjectedBlock
    let index: Int
    
    var body: some View {
        GlassCard {
            VStack(spacing: 10) {
                Text("~\(Int(block.blockSize / 1000000)) MB")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                // ETA
                Text("In ~\( (index + 1) * 10 ) mins")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                
                Divider()
                    .background(.white.opacity(0.3))
                
                if let minFee = block.feeRange.first, let maxFee = block.feeRange.last {
                    VStack(alignment: .leading) {
                        Text("Fee Range")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                        Text("\(Int(minFee)) - \(Int(maxFee)) sat/vB")
                            .font(.caption.bold())
                            .foregroundStyle(getMedianFeeColor(block.medianFee))
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Transactions")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                    Text("\(block.nTx)")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
            }
            .padding()
            .frame(width: 140, height: 180)
        }
    }
}

func getMedianFeeColor(_ fee: Double) -> Color {
    switch fee {
    case ..<5: return .cyan
    case 5..<20: return .green
    case 20..<50: return .yellow
    case 50..<100: return .orange
    default: return .red
    }
}
