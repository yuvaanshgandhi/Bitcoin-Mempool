import SwiftUI
import Charts

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()
    @EnvironmentObject var currencySettings: CurrencySettings
    @State private var selectedHashrate: Hashrate?
    
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
                    HStack {
                        Text("Block Stream")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        if viewModel.newBlockArrived {
                            Text("NEW BLOCK")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.green)
                                )
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal)
                    
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                // Projected (Future) blocks - descending order
                                // Next block is last (closest to separator)
                                let reversedBlocks = Array(viewModel.projectedBlocks.enumerated()).reversed()
                                ForEach(Array(reversedBlocks), id: \.element.id) { index, block in
                                    NavigationLink(value: block) {
                                        ProjectedBlockCard(block: block, index: index)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 20)
                                                    .stroke(getMedianFeeColor(block.medianFee).opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5]))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                // Separator
                                ZStack {
                                    if viewModel.newBlockArrived {
                                        Circle()
                                            .fill(Color.green.opacity(0.3))
                                            .frame(width: 60, height: 60)
                                            .scaleEffect(viewModel.newBlockArrived ? 1.5 : 0.5)
                                            .opacity(viewModel.newBlockArrived ? 0 : 1)
                                            .animation(.easeOut(duration: 1.5).repeatCount(2, autoreverses: false), value: viewModel.newBlockArrived)
                                    }
                                    
                                    Rectangle()
                                        .fill(LinearGradient(colors: viewModel.newBlockArrived ? [.green, .green.opacity(0.6)] : [.orange, .blue], startPoint: .top, endPoint: .bottom))
                                        .frame(width: viewModel.newBlockArrived ? 4 : 2, height: 100)
                                        .animation(.spring(response: 0.4), value: viewModel.newBlockArrived)
                                }
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
                                                
                                                if let extras = block.extras {
                                                    VStack {
                                                        Text("~\(String(format: "%.1f", extras.medianFee)) sat/vB")
                                                            .font(.caption.bold())
                                                            .foregroundStyle(getMedianFeeColor(extras.medianFee))
                                                        if let minFee = extras.feeRange.first, let maxFee = extras.feeRange.last {
                                                            Text("\(Int(minFee)) - \(Int(maxFee)) sat/vB")
                                                                .font(.caption2)
                                                                .foregroundStyle(.white.opacity(0.6))
                                                        }
                                                    }
                                                } else {
                                                    VStack(alignment: .leading) {
                                                        Text("Size")
                                                            .font(.caption2).foregroundStyle(.white.opacity(0.6))
                                                        Text("\((Double(block.size) / 1_000_000).formatted(.number.precision(.fractionLength(2)))) MB")
                                                            .font(.caption.bold()).foregroundStyle(.white)
                                                    }
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
                                        .background((block.extras != nil ? getMedianFeeColor(block.extras!.medianFee) : Color.blue).opacity(0.1).cornerRadius(20)) 
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
                
                // Mining Stats Integration
                
                // 1. Difficulty Adjustment
                if let diff = viewModel.difficulty {
                    MiningCard(title: "DIFFICULTY ADJUSTMENT") {
                        VStack(spacing: 20) {
                            // Progress Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color(white: 0.2))
                                        .frame(height: 20)
                                    
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: geo.size.width * (diff.progressPercent / 100.0), height: 20)
                                    
                                    // Change indicator
                                    Rectangle()
                                        .fill(diff.difficultyChange >= 0 ? Color.green : Color.red)
                                        .frame(width: 10, height: 20)
                                        .offset(x: geo.size.width * (diff.progressPercent / 100.0))
                                }
                                .cornerRadius(4)
                            }
                            .frame(height: 20)
                            
                            HStack(alignment: .top) {
                                VStack(alignment: .center, spacing: 4) {
                                    Text(String(format: "%.1f mins", Double(diff.timeAvg) / 60000.0))
                                        .font(.title3.bold()).foregroundStyle(.white)
                                    Text("Avg block time")
                                        .font(.caption).foregroundStyle(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                                
                                VStack(alignment: .center, spacing: 4) {
                                    Text(String(format: "%.2f%%", diff.difficultyChange))
                                        .font(.title2.bold())
                                        .foregroundStyle(diff.difficultyChange >= 0 ? .green : .red)
                                    Text("Prev: \(String(format: "%.2f", diff.previousRetarget))%")
                                        .font(.caption2).foregroundStyle(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                                
                                VStack(alignment: .center, spacing: 4) {
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text("\(diff.remainingBlocks)")
                                            .font(.title2.bold()).foregroundStyle(.white)
                                        Text("Blks")
                                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                                    }
                                    
                                    let timeRemainingSecs = Double(diff.remainingTime) / 1000.0
                                    let days = Int(timeRemainingSecs / 86400)
                                    let hours = Int((timeRemainingSecs.truncatingRemainder(dividingBy: 86400)) / 3600)
                                    let timeString = days > 0 ? "~\(days)d \(hours)h" : "~\(hours)h"
                                    
                                    Text(timeString)
                                        .font(.caption.bold()).foregroundStyle(.orange)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 1.5 Halving Countdown
                if let tip = viewModel.tipHeight {
                    let epoch = (tip / 210_000) + 1
                    let nextHalvingBlock = epoch * 210_000
                    let blocksRemaining = nextHalvingBlock - tip
                    let progress = Double(210_000 - blocksRemaining) / 210_000.0
                    let nextSubsidy = 50.0 / pow(2.0, Double(epoch))
                    
                    MiningCard(title: "HALVING COUNTDOWN") {
                        VStack(spacing: 20) {
                            // Progress Bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Rectangle()
                                        .fill(Color(white: 0.2))
                                        .frame(height: 20)
                                    
                                    Rectangle()
                                        .fill(Color.orange)
                                        .frame(width: geo.size.width * progress, height: 20)
                                }
                                .cornerRadius(4)
                            }
                            .frame(height: 20)
                            
                            HStack(alignment: .top) {
                                VStack(alignment: .center, spacing: 4) {
                                    Text(String(format: "%.3f", nextSubsidy) + " BTC")
                                        .font(.title3.bold()).foregroundStyle(.white)
                                    Text("New subsidy")
                                        .font(.caption).foregroundStyle(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                                
                                VStack(alignment: .center, spacing: 4) {
                                    Text("\(blocksRemaining)")
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)
                                    Text("Blocks remaining")
                                        .font(.caption2).foregroundStyle(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                                
                                VStack(alignment: .center, spacing: 4) {
                                    // Estimate time. 10 mins per block
                                    let daysRemaining = Double(blocksRemaining) * 10.0 / 60.0 / 24.0
                                    let years = Int(daysRemaining / 365)
                                    let days = Int(daysRemaining.truncatingRemainder(dividingBy: 365))
                                    Text("~" + (years > 0 ? "\(years)y " : "") + "\(days)d")
                                        .font(.title2.bold()).foregroundStyle(.orange)
                                    Text("Estimate")
                                        .font(.caption).foregroundStyle(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 2. Hashrate Chart
                if !viewModel.hashrate.isEmpty {
                    MiningCard(title: "HASHRATE (3M)") {
                        VStack(alignment: .leading) {
                            if let selected = selectedHashrate {
                                Text("\(String(format: "%.2f", selected.avgHashrate / 1_000_000_000_000_000_000)) EH/s")
                                    .font(.headline.bold())
                                    .foregroundStyle(.yellow)
                                Text(selectedHashrateDate(selected.timestamp))
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            } else if let last = viewModel.hashrate.last {
                                Text("\(String(format: "%.2f", last.avgHashrate / 1_000_000_000_000_000_000)) EH/s")
                                    .font(.headline.bold())
                                    .foregroundStyle(.yellow)
                                Text("Current")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            
                            Chart {
                                ForEach(viewModel.hashrate) { item in
                                    LineMark(
                                        x: .value("Date", Date(timeIntervalSince1970: TimeInterval(item.timestamp))),
                                        y: .value("Hashrate", item.avgHashrate)
                                    )
                                    .foregroundStyle(.yellow)
                                    .interpolationMethod(.catmullRom)
                                }
                                
                                if let selected = selectedHashrate {
                                    RuleMark(x: .value("Date", Date(timeIntervalSince1970: TimeInterval(selected.timestamp))))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            .chartYAxis { AxisMarks(position: .leading) { _ in AxisValueLabel().foregroundStyle(.white.opacity(0.5)) } }
                            .chartXAxis { AxisMarks(position: .bottom) { _ in AxisValueLabel().foregroundStyle(.white.opacity(0.5)) } }
                            .chartOverlay { proxy in
                                GeometryReader { geometry in
                                    Rectangle().fill(.clear).contentShape(Rectangle())
                                        .gesture(
                                            DragGesture()
                                                .onChanged { value in
                                                    let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                                    if let date: Date = proxy.value(atX: x) {
                                                        let timestamp = Int64(date.timeIntervalSince1970)
                                                        if let closest = viewModel.hashrate.min(by: { abs($0.timestamp - timestamp) < abs($1.timestamp - timestamp) }) {
                                                            selectedHashrate = closest
                                                        }
                                                    }
                                                }
                                                .onEnded { _ in selectedHashrate = nil }
                                        )
                                }
                            }
                            .frame(height: 150)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 3. Mining Pools
                if !viewModel.pools.isEmpty {
                    MiningCard(title: "POOLS DISTRIBUTION") {
                        HStack {
                            Chart(viewModel.pools.prefix(10)) { pool in
                                SectorMark(
                                    angle: .value("Blocks", pool.blockCount),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 1.5
                                )
                                .cornerRadius(5)
                                .foregroundStyle(by: .value("Pool", pool.name))
                            }
                            .frame(height: 150)
                            .chartLegend(.hidden)
                            
                            Spacer()
                            
                            VStack(alignment: .leading, spacing: 5) {
                                let totalBlocks = viewModel.pools.reduce(0) { $0 + $1.blockCount }
                                ForEach(viewModel.pools.prefix(6)) { pool in
                                    HStack(spacing: 4) {
                                        Circle().fill(Color.gray).frame(width: 6, height: 6)
                                        let percent = (Double(pool.blockCount) / Double(max(totalBlocks, 1))) * 100.0
                                        Text("\(pool.name) (\(String(format: "%.1f", percent))%)")
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.7))
                                            .lineLimit(1)
                                    }
                                }
                            }
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
    
    // Helpers
    func timeAgo(timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    func selectedHashrateDate(_ ts: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
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
