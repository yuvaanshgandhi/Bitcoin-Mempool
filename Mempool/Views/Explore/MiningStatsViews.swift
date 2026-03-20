import SwiftUI
import Charts

struct DifficultyAdjustmentView: View {
    let diff: DifficultyAdjustment
    
    var body: some View {
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
    }
}

struct HalvingCountdownView: View {
    let tipHeight: Int
    
    var body: some View {
        let epoch = (tipHeight / 210_000) + 1
        let nextHalvingBlock = epoch * 210_000
        let blocksRemaining = nextHalvingBlock - tipHeight
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
    }
}

struct HashrateChartView: View {
    let hashrate: [Hashrate]
    @State private var selectedHashrate: Hashrate?
    
    var body: some View {
        MiningCard(title: "HASHRATE (3M)") {
            VStack(alignment: .leading) {
                if let selected = selectedHashrate {
                    Text("\(String(format: "%.2f", selected.avgHashrate / 1_000_000_000_000_000_000)) EH/s")
                        .font(.headline.bold())
                        .foregroundStyle(.yellow)
                    Text(selectedHashrateDate(selected.timestamp))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                } else if let last = hashrate.last {
                    Text("\(String(format: "%.2f", last.avgHashrate / 1_000_000_000_000_000_000)) EH/s")
                        .font(.headline.bold())
                        .foregroundStyle(.yellow)
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                
                Chart {
                    ForEach(hashrate) { item in
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
                                            if let closest = hashrate.min(by: { abs($0.timestamp - timestamp) < abs($1.timestamp - timestamp) }) {
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
    
    func selectedHashrateDate(_ ts: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct PoolsDistributionView: View {
    let pools: [MiningPool]
    
    var body: some View {
        MiningCard(title: "POOLS DISTRIBUTION") {
            HStack {
                Chart(pools.prefix(10)) { pool in
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
                    let totalBlocks = pools.reduce(0) { $0 + $1.blockCount }
                    ForEach(pools.prefix(6)) { pool in
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
    }
}
