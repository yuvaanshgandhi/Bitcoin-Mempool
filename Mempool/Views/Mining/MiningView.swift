//```
import SwiftUI
import Charts

struct MiningView: View {
    @ObservedObject private var viewModel = MiningViewModel()
    @EnvironmentObject var currencySettings: CurrencySettings
    @State private var selectedHashrate: Hashrate?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                if viewModel.isLoading {
                    ProgressView().tint(.white).padding(.top, 50)
                } else if let error = viewModel.error {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text("Error loading data")
                            .font(.headline).foregroundStyle(.white)
                        Text(error)
                            .font(.caption).foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button("Retry") {
                            Task { await viewModel.loadData() }
                        }
                        .buttonStyle(.bordered)
                        .tint(.white)
                        .padding(.top)
                    }
                    .padding()
                }
                
                // Vertical Stack Layout
                VStack(spacing: 20) {
                    
                    // 1. Rewards Stats
                    if let stats = viewModel.rewardStats, let price = viewModel.price {
                        let fiatPrice = currencySettings.price(from: price)
                        MiningCard(title: "REWARD STATS (144 BLOCKS)") {
                            HStack(spacing: 15) {
                                StatColumn(
                                    title: "Miners Reward",
                                    btcValue: formatStringBTC(stats.totalReward),
                                    usdValue: formatStringFiat(stats.totalReward, price: fiatPrice)
                                )
                                Divider().background(.white.opacity(0.1))
                                StatColumn(
                                    title: "Avg Block Fees",
                                    btcValue: formatAvgBlockFee(stats.totalFee),
                                    usdValue: formatAvgBlockFeeFiat(stats.totalFee, price: fiatPrice)
                                )
                                Divider().background(.white.opacity(0.1))
                                StatColumn(
                                    title: "Avg Tx Fee",
                                    btcValue: formatAvgTxFee(totalFee: stats.totalFee, totalTx: stats.totalTx),
                                    usdValue: formatAvgTxFeeFiat(totalFee: stats.totalFee, totalTx: stats.totalTx, price: fiatPrice)
                                )
                            }
                        }
                    }
                    
                    // 2. Difficulty Adjustment (Split)
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
                                        
                                        // Change indicator (Green/Red tip) - Simplified visualization
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
                                        Text("~9.2 minutes") // Placeholder for avg block time, need real calc
                                            .font(.title3.bold()).foregroundStyle(.white)
                                        Text("Average block time")
                                            .font(.caption).foregroundStyle(.white.opacity(0.5))
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    VStack(alignment: .center, spacing: 4) {
                                        Text(String(format: "%.2f%%", diff.difficultyChange))
                                            .font(.title2.bold())
                                            .foregroundStyle(diff.difficultyChange >= 0 ? .green : .red)
                                        Text("Previous: \(String(format: "%.2f", diff.previousRetarget))%")
                                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    VStack(alignment: .center, spacing: 4) {
                                        Text("In ~\(diff.remainingBlocks / 144) days") // Approx
                                            .font(.title2.bold()).foregroundStyle(.white)
                                        Text("Retarget Date")
                                            .font(.caption).foregroundStyle(.white.opacity(0.5))
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        
                        // 3. Halving Countdown (Split)
                        MiningCard(title: "HALVING COUNTDOWN") {
                             VStack(spacing: 20) {
                                // Progress Bar (Manually set for now as API doesn't give halving progress directly usually)
                                // Standard Halving is every 210,000 blocks. 
                                // Current era start: 840,000. Next: 1,050,000.
                                let currentHeight = viewModel.tipHeight ?? 0
                                let cycleStart = 840000
                                let cycleEnd = 1050000
                                let progress = Double(currentHeight - cycleStart) / Double(cycleEnd - cycleStart)
                                
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Rectangle()
                                            .fill(Color(white: 0.2))
                                            .frame(height: 20)
                                        
                                        Rectangle()
                                            .fill(Color.blue)
                                            .frame(width: geo.size.width * CGFloat(progress), height: 20)
                                        
                                        Text("\(String(format: "%.2f", progress * 100))%")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 5)
                                            .frame(width: geo.size.width, alignment: .center)
                                    }
                                    .cornerRadius(4)
                                }
                                .frame(height: 20)
                                
                                HStack(alignment: .top) {
                                    VStack(alignment: .center, spacing: 4) {
                                        Text("1.563 BTC")
                                            .font(.title2.bold()).foregroundStyle(.white)
                                        Text("New subsidy")
                                            .font(.caption).foregroundStyle(.white.opacity(0.5))
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    VStack(alignment: .center, spacing: 4) {
                                        Text("\(cycleEnd - currentHeight)")
                                            .font(.title2.bold()).foregroundStyle(.white)
                                        Text("Blocks remaining")
                                            .font(.caption).foregroundStyle(.white.opacity(0.5))
                                    }
                                    .frame(maxWidth: .infinity)
                                    
                                    VStack(alignment: .center, spacing: 4) {
                                        Text("Apr 2028")
                                            .font(.title2.bold()).foregroundStyle(.white)
                                        Text("Estimate")
                                            .font(.caption).foregroundStyle(.white.opacity(0.5))
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                    
                    // 4. Mining Pools
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
                                
                                // Legend
                                VStack(alignment: .leading, spacing: 5) {
                                    ForEach(viewModel.pools.prefix(6)) { pool in
                                        HStack(spacing: 4) {
                                            Circle().fill(Color.gray).frame(width: 6, height: 6)
                                            Text(pool.name)
                                                .font(.caption2)
                                                .foregroundStyle(.white.opacity(0.7))
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // 5. Hashrate (Interactive)
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
                                                            // Find closest data point
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
                    }
                }
                .padding()
                
                // Full Pool List
                if !viewModel.pools.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("All Mining Pools")
                            .font(.headline).foregroundStyle(.white)
                            .padding(.horizontal)
                        
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.pools) { pool in
                                HStack {
                                    Text(pool.name)
                                        .font(.subheadline).bold().foregroundStyle(.white)
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("\(pool.blockCount) Blocks")
                                            .font(.caption).foregroundStyle(.white)
                                        Text(String(format: "%.2f%%", (Double(pool.blockCount) / 1008.0) * 100.0)) // Assuming 1w ~ 1008 blocks
                                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                                    }
                                }
                                .padding()
                                .background(Color(white: 0.08))
                                .cornerRadius(0) // List style
                                Divider().background(.white.opacity(0.1))
                            }
                        }
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color.black.ignoresSafeArea())
        .task { await viewModel.loadData() }
    }
    
    // Helpers
    func formatStringBTC(_ val: String) -> String {
        guard let doubleVal = Double(val) else { return "0 BTC" }
        return String(format: "%.2f BTC", doubleVal / 100_000_000)
    }
    
    func formatStringFiat(_ val: String, price: Double) -> String {
        guard let doubleVal = Double(val) else { return "\(currencySettings.currencySymbol)0" }
        let btc = doubleVal / 100_000_000
        return currencySettings.formatFiat(btc * price, fractionDigits: 0)
    }
    
    func formatAvgBlockFee(_ totalFee: String) -> String {
        guard let fee = Double(totalFee) else { return "0" }
        let avg = fee / 144.0
        return String(format: "%.4f BTC", avg / 100_000_000)
    }
    
    func formatAvgBlockFeeFiat(_ totalFee: String, price: Double) -> String {
        guard let fee = Double(totalFee) else { return "\(currencySettings.currencySymbol)0" }
        let avgBtc = (fee / 144.0) / 100_000_000
        return currencySettings.formatFiat(avgBtc * price, fractionDigits: 0)
    }
    
    func formatAvgTxFee(totalFee: String, totalTx: String) -> String {
        guard let fee = Double(totalFee), let tx = Double(totalTx), tx > 0 else { return "0 sats" }
        let avgSats = fee / tx
        return String(format: "%.0f sats", avgSats)
    }
    
    func formatAvgTxFeeFiat(totalFee: String, totalTx: String, price: Double) -> String {
        guard let fee = Double(totalFee), let tx = Double(totalTx), tx > 0 else { return "\(currencySettings.currencySymbol)0" }
        let avgBtc = (fee / tx) / 100_000_000
        return currencySettings.formatFiat(avgBtc * price)
    }
    
    func selectedHashrateDate(_ ts: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// ... Card and StatColumn structs ...
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
        .background(Color(white: 0.08)) // Dark card background
        .cornerRadius(10)
    }
}

struct StatColumn: View {
    let title: String
    let btcValue: String
    let usdValue: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption).foregroundStyle(.blue)
            Text(btcValue)
                .font(.headline).bold().foregroundStyle(.white)
            Text(usdValue)
                .font(.caption).foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity)
    }
}
