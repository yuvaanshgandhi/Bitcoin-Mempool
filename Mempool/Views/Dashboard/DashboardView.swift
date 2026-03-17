import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var currencySettings: CurrencySettings
    
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
                VStack(alignment: .leading) {
                    Text("Block Stream")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal)
                    
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                // Projected (Future) blocks - descending order
                                // Next block is last (closest to separator)
                                let reversedBlocks = Array(viewModel.projectedBlocks.enumerated()).reversed()
                                ForEach(Array(reversedBlocks), id: \.element.id) { index, block in
                                    ProjectedBlockCard(block: block, index: index)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.orange.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5]))
                                        )
                                }
                                
                                // Separator
                                Rectangle()
                                    .fill(LinearGradient(colors: [.orange, .blue], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 2, height: 100)
                                    .id("blockSeparator")
                                
                                // Confirmed (Past) blocks
                                ForEach(viewModel.confirmedBlocks) { block in
                                    NavigationLink(destination: BlockDetailView(identifier: block.id)) {
                                        GlassCard {
                                            VStack(spacing: 10) {
                                                Text("#\(block.height)")
                                                    .font(.headline)
                                                    .foregroundStyle(.white)
                                                
                                                // Time Ago
                                                Text(timeAgo(timestamp: block.timestamp))
                                                    .font(.caption2)
                                                    .foregroundStyle(.white.opacity(0.6))
                                                
                                                Divider().background(.white.opacity(0.3))
                                                
                                                VStack(alignment: .leading) {
                                                    Text("Size")
                                                        .font(.caption2).foregroundStyle(.white.opacity(0.6))
                                                    Text("\((Double(block.size) / 1_000_000).formatted(.number.precision(.fractionLength(2)))) MB")
                                                        .font(.caption.bold()).foregroundStyle(.white)
                                                }
                                                
                                                VStack(alignment: .leading) {
                                                    Text("Transactions")
                                                        .font(.caption2).foregroundStyle(.white.opacity(0.6))
                                                    Text("\(block.tx_count)")
                                                        .font(.caption.bold()).foregroundStyle(.white)
                                                }
                                            }
                                            .padding()
                                            .frame(width: 140, height: 180)
                                        }
                                        // Tint effect for confirmed blocks
                                        .background(Color.blue.opacity(0.1).cornerRadius(20)) 
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .onAppear {
                            // Center on the separator between projected and confirmed blocks
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation {
                                    proxy.scrollTo("blockSeparator", anchor: .center)
                                }
                            }
                        }
                        .onChange(of: viewModel.confirmedBlocks.first?.id) { _, _ in
                            withAnimation {
                                proxy.scrollTo("blockSeparator", anchor: .center)
                            }
                        }
                    }
                }
                
                // Recent Transactions List (Mini)
                VStack(alignment: .leading) {
                    Text("Recent Transactions")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal)
                    
                    VStack(spacing: 10) {
                        ForEach(viewModel.initialRecentTransactions.prefix(5)) { tx in
                            NavigationLink(destination: TransactionDetailView(txid: tx.txid)) {
                                GlassCard {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(tx.txid.prefix(8) + "...")
                                                .font(.system(.body, design: .monospaced))
                                                .foregroundStyle(.white)
                                            Text("\(tx.vsize) vB")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.6))
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            Text("\(tx.fee) sats")
                                                .font(.headline)
                                                .foregroundStyle(.orange)
                                            Text("\((Double(tx.value) / 100_000_000).formatted(.number.precision(.fractionLength(4)))) BTC")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.6))
                                        }
                                    }
                                    .padding()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 50)
        }
        .refreshable {
             await viewModel.fetchData()
        }
    }
    
    func timeAgo(timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
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
                            .foregroundStyle(.white)
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
