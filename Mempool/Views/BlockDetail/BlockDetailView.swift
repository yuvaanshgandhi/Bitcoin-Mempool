import SwiftUI

struct BlockDetailView: View {
    @StateObject private var viewModel: BlockDetailViewModel
    
    init(identifier: String, projectedBlock: ProjectedBlock? = nil) {
        _viewModel = StateObject(wrappedValue: BlockDetailViewModel(identifier: identifier, projectedBlock: projectedBlock))
    }
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView().tint(.white).padding(.top, 50)
            } else if let error = viewModel.error {
                Text("Error: \(error)").foregroundStyle(.red).padding()
            } else if let block = viewModel.block {
                VStack(spacing: 20) {
                    
                    // Header: Block <Height>
                    HStack {
                        Text("Block")
                            .font(.largeTitle).bold().foregroundStyle(.white)
                        Image(systemName: "chevron.left").foregroundStyle(.gray)
                        Text(viewModel.isProjected ? "Projected" : "\(block.height)")
                            .font(.largeTitle).bold().foregroundStyle(.blue)
                        Image(systemName: "chevron.right").foregroundStyle(.blue)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Main Info Card
                    VStack(spacing: 0) {
                        // Row 1: Hash & Fee Span
                        HStack(alignment: .top) {
                            if viewModel.isProjected {
                                DetailRow(label: "Status", value: "Unconfirmed")
                            } else {
                                DetailRow(label: "Hash", value: block.id_val.prefix(12) + "..." + block.id_val.suffix(8), isCopyable: true)
                            }
                            Spacer()
                            if let extras = block.extras, let firstFee = extras.feeRange.first, let lastFee = extras.feeRange.last {
                                DetailRow(label: "Fee span", value: "\(Int(firstFee)) - \(Int(lastFee)) sat/vB")
                            } else {
                                DetailRow(label: "Fee span", value: "Unknown")
                            }
                        }
                        .padding()
                        Divider().background(.white.opacity(0.1))
                        
                        // Row 2: Timestamp & Median Fee
                        HStack(alignment: .top) {
                            DetailRow(label: "Timestamp", value: formatDate(block.timestamp))
                            Spacer()
                            if let extras = block.extras {
                                DetailRow(label: "Median fee", value: "~ \(String(format: "%.1f", extras.medianFee)) sat/vB")
                            } else {
                                DetailRow(label: "Median fee", value: "Unknown")
                            }
                        }
                        .padding()
                        Divider().background(.white.opacity(0.1))
                        
                        // Row 3: Size & Total Fees
                        HStack(alignment: .top) {
                            DetailRow(label: "Size", value: String(format: "%.2f MB", Double(block.size)/1_000_000))
                            Spacer()
                            if let extras = block.extras {
                                DetailRow(label: "Total fees", value: String(format: "%.4f BTC", Double(extras.totalFees)/100_000_000))
                            } else {
                                DetailRow(label: "Total fees", value: "Unknown")
                            }
                        }
                        .padding()
                        Divider().background(.white.opacity(0.1))
                        
                        // Row 4: Weight & Subsidy+Fees
                        HStack(alignment: .top) {
                            DetailRow(label: "Weight", value: String(format: "%.2f MWU", Double(block.weight)/1_000_000))
                            Spacer()
                            if let extras = block.extras {
                                DetailRow(label: "Subsidy + fees", value: String(format: "%.4f BTC", Double(extras.reward)/100_000_000))
                            } else {
                                DetailRow(label: "Subsidy + fees", value: "Unknown")
                            }
                        }
                        .padding()
                        Divider().background(.white.opacity(0.1))
                        
                        // Row 5: Health & Miner
                        HStack(alignment: .top) {
                            VStack(alignment: .leading) {
                                Text("Health").font(.subheadline).foregroundStyle(.white)
                                Capsule().fill(Color.purple).frame(width: 50, height: 8)
                            }
                            Spacer()
                            DetailRow(label: "Miner", value: block.extras?.pool.name ?? "Unknown")
                        }
                        .padding()
                    }
                    .background(Color(white: 0.08))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Transaction Visualizer
                    TransactionVisualizer(transactions: viewModel.transactions)
                        .padding(.horizontal)
                    
                    // Transactions List
                    if !viewModel.transactions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(viewModel.transactions.count) of \(block.tx_count) Transactions")
                                .font(.headline).foregroundStyle(.white)
                                .padding(.horizontal)
                            
                            // Headers
                            HStack {
                                Text("ID").frame(maxWidth: .infinity, alignment: .leading)
                                Text("Sat/vB").frame(width: 60, alignment: .trailing)
                                Text("Amount").frame(width: 80, alignment: .trailing)
                            }
                            .font(.caption).bold().foregroundStyle(.gray)
                            .padding(.horizontal)
                            
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.transactions) { tx in
                                    NavigationLink(destination: TransactionDetailView(txid: tx.txid)) {
                                        BlockTransactionRow(tx: tx)
                                    }
                                    .buttonStyle(.plain)
                                    Divider().background(.white.opacity(0.1))
                                }
                            }
                            
                            // Load More button
                            if viewModel.transactions.count < block.tx_count {
                                Button {
                                    Task {
                                        await viewModel.loadMoreTransactions()
                                    }
                                } label: {
                                    HStack {
                                        if viewModel.isLoadingMore {
                                            ProgressView().tint(.white)
                                        }
                                        Text("Load More Transactions")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(.orange)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(white: 0.08))
                                    .cornerRadius(10)
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.bottom)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .task { await viewModel.loadData() }
    }
    
    func formatDate(_ ts: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-mm-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct BlockTransactionRow: View {
    let tx: Transaction
    
    var body: some View {
        HStack {
            // ID + IO flow
            VStack(alignment: .leading, spacing: 4) {
                Text(tx.txid.prefix(8) + "..." + tx.txid.suffix(8))
                    .font(.subheadline).monospaced()
                    .foregroundStyle(.blue)
                
                HStack(spacing: 2) {
                    Text("\(tx.vin.count) inputs")
                    Image(systemName: "arrow.right")
                    Text("\(tx.vout.count) outputs")
                }
                .font(.caption2).foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            // Fee Rate
            // FeeRate = Fee / (Weight / 4)
            let feeRate = Double(tx.fee) / (Double(tx.weight) / 4.0)
            Text(String(format: "%.1f", feeRate))
                .font(.subheadline).monospaced()
                .foregroundStyle(.white)
                .frame(width: 60, alignment: .trailing)
            
            // Total Output Value
            let totalOut = tx.vout.reduce(0) { $0 + $1.value }
            let btc = Double(totalOut) / 100_000_000.0
            Text(String(format: "%.4f BTC", btc))
                .font(.subheadline).monospaced()
                .foregroundStyle(.white)
                .frame(width: 80, alignment: .trailing)
        }
        .padding()
        .background(Color(white: 0.05)) // Slightly darker for rows
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var isCopyable: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white)
            HStack {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(label == "Hash" ? .blue : .white.opacity(0.7))
                    .monospaced()
                if isCopyable {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
