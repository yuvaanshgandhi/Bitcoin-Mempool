import SwiftUI

struct ProjectedBlockDetailView: View {
    let block: ProjectedBlock
    @EnvironmentObject var currencySettings: CurrencySettings
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    
                    VStack(alignment: .leading) {
                        Text("Projected Block")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        
                        Text("ETA: ~10 mins")
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding()
                .background(Color(white: 0.1))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    statCard(
                        title: "FEE RANGE",
                        value: "\(Int(block.feeRange.first ?? 0))-\(Int(block.feeRange.last ?? 0)) sat/vB",
                        icon: "fuelpump.fill"
                    )
                    
                    statCard(
                        title: "MEDIAN FEE",
                        value: "\(Int(block.medianFee)) sat/vB",
                        icon: "hare.fill"
                    )
                    
                    statCard(
                        title: "TRANSACTIONS",
                        value: "\(block.nTx)",
                        icon: "list.bullet"
                    )
                    
                    statCard(
                        title: "SIZE",
                        value: formatSize(Int(block.blockSize)),
                        icon: "memorychip"
                    )
                    
                    statCard(
                        title: "TOTAL FEES",
                        value: "\((Double(block.totalFees) / 100_000_000).formatted(.number.precision(.fractionLength(4)))) BTC",
                        icon: "bitcoinsign.circle.fill"
                    )
                    
                    statCard(
                        title: "AVERAGE FEE",
                        value: "\((Double(block.totalFees) / Double(block.nTx)).formatted(.number.precision(.fractionLength(0)))) sats",
                        icon: "chart.bar.fill"
                    )
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Unconfirmed Block")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.orange.opacity(0.8))
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Helpers
    
    private func formatSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
