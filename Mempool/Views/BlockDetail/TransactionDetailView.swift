import SwiftUI

struct TransactionDetailView: View {
    @StateObject private var viewModel: TransactionDetailViewModel
    @EnvironmentObject var currencySettings: CurrencySettings
    
    init(txid: String) {
        _viewModel = StateObject(wrappedValue: TransactionDetailViewModel(txid: txid))
    }
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView().tint(.white).padding(.top, 50)
            } else if let error = viewModel.error {
                Text("Error: \(error)").foregroundStyle(.red).padding()
            } else if let tx = viewModel.transaction, let price = viewModel.price {
                let fiatPrice = currencySettings.price(from: price)
                
                VStack(spacing: 20) {
                    
                    // Header: Transaction ID + Status
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Transaction")
                                .font(.title2).bold().foregroundStyle(.white)
                            Spacer()
                            if tx.status.confirmed {
                                Text("Confirmed")
                                    .font(.caption).bold()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green)
                                    .foregroundStyle(.white)
                                    .cornerRadius(4)
                            } else {
                                Text("Unconfirmed")
                                    .font(.caption).bold()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red)
                                    .foregroundStyle(.white)
                                    .cornerRadius(4)
                            }
                        }
                        
                        HStack {
                            Text(tx.txid)
                                .font(.subheadline).monospaced()
                                .foregroundStyle(.blue)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        
                        // Notify When Confirmed button for unconfirmed transactions
                        if !tx.status.confirmed {
                            if viewModel.notificationScheduled {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Confirmed! Notification sent.")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.green)
                                }
                                .padding(.top, 4)
                            } else if viewModel.isWatchingForConfirmation {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .tint(.orange)
                                        .scaleEffect(0.8)
                                    Text("Watching for confirmation...")
                                        .font(.subheadline)
                                        .foregroundStyle(.orange)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(8)
                                .padding(.top, 4)
                            } else {
                                Button {
                                    viewModel.watchForConfirmation()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "bell.badge")
                                            .font(.subheadline)
                                        Text("Notify When Confirmed")
                                            .font(.subheadline.bold())
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 16)
                                    .background(Color.orange)
                                    .cornerRadius(8)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Top Info Card
                    VStack(spacing: 0) {
                        // Row 1: Timestamp & Fee
                        HStack(alignment: .top) {
                            if tx.status.confirmed, let blockTime = tx.status.block_time {
                                let date = Date(timeIntervalSince1970: TimeInterval(blockTime))
                                let formatter = RelativeDateTimeFormatter()
                                DetailRow(label: "Confirmed", value: formatter.localizedString(for: date, relativeTo: Date()))
                            } else {
                                DetailRow(label: "Status", value: "Unconfirmed")
                            }
                            Spacer()
                            let feeFiat = (Double(tx.fee) / 100_000_000) * fiatPrice
                            DetailRow(label: "Fee", value: "\(tx.fee) sats \(currencySettings.formatFiat(feeFiat))")
                        }
                        .padding()
                        Divider().background(.white.opacity(0.1))
                        
                        // Row 2: Block Height & Fee Rate
                        HStack(alignment: .top) {
                            if tx.status.confirmed, let height = tx.status.block_height {
                                DetailRow(label: "Block", value: "#\(height)")
                            } else {
                                DetailRow(label: "ETA", value: "Pending")
                            }
                            Spacer()
                            DetailRow(label: "Fee rate", value: String(format: "%.1f sat/vB", Double(tx.fee) / Double(tx.weight / 4)))
                        }
                        .padding()
                        Divider().background(.white.opacity(0.1))
                        
                        // Row 3: Features (detect from transaction data)
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Features").font(.subheadline).foregroundStyle(.white)
                                HStack {
                                    // SegWit: check if any input has witness data
                                    if tx.vin.contains(where: { $0.witness != nil && !($0.witness?.isEmpty ?? true) }) {
                                        Text("SegWit").font(.caption).padding(4).background(Color.green.opacity(0.7)).cornerRadius(4)
                                    }
                                    // RBF: check if any input has sequence < 0xfffffffe
                                    if tx.vin.contains(where: { $0.sequence < 0xfffffffe }) {
                                        Text("RBF").font(.caption).padding(4).background(Color.red.opacity(0.7)).cornerRadius(4)
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding()
                    }
                    .background(Color(white: 0.08))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    
                    // Flow Visualization (Dynamic)
                    VStack(alignment: .leading) {
                        Text("Flow").font(.headline).foregroundStyle(.white)
                        FlowDiagramView(inputs: tx.vin.count, outputs: tx.vout.count)
                            .frame(height: 150) // Increased height for better visualization
                            .background(Color(white: 0.05))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Inputs & Outputs List
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Inputs & Outputs").font(.headline).foregroundStyle(.white)
                        
                        HStack(alignment: .top, spacing: 20) {
                            // Inputs
                            VStack(spacing: 10) {
                                ForEach(tx.vin.prefix(5)) { input in
                                    InputRow(input: input, price: fiatPrice, currencySymbol: currencySettings.currencySymbol, isJPY: currencySettings.selectedCurrency == "JPY")
                                }
                                if tx.vin.count > 5 {
                                    Text("+ \(tx.vin.count - 5) more inputs")
                                        .font(.caption).foregroundStyle(.gray)
                                }
                            }
                            
                            // Outputs
                            VStack(spacing: 10) {
                                ForEach(tx.vout.prefix(5)) { output in
                                    OutputRow(output: output, price: fiatPrice, currencySymbol: currencySettings.currencySymbol, isJPY: currencySettings.selectedCurrency == "JPY")
                                }
                                if tx.vout.count > 5 {
                                    Text("+ \(tx.vout.count - 5) more outputs")
                                        .font(.caption).foregroundStyle(.gray)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Tech Details Grid
                    VStack(spacing: 0) {
                        HStack {
                            DetailRow(label: "Size", value: "\(tx.size) B")
                            Spacer()
                            DetailRow(label: "Version", value: "\(tx.version)")
                        }
                        .padding()
                        Divider().background(.white.opacity(0.1))
                        
                        HStack {
                            DetailRow(label: "Virtual size", value: "\(tx.weight / 4) vB")
                            Spacer()
                            DetailRow(label: "Locktime", value: "\(tx.locktime)")
                        }
                        .padding()
                        Divider().background(.white.opacity(0.1))
                         
                         HStack {
                            DetailRow(label: "Weight", value: "\(tx.weight) WU")
                            Spacer()
                            Link(destination: URL(string: "https://mempool.space/tx/\(tx.txid)")!) {
                                Text("Transaction hex")
                                    .font(.subheadline).foregroundStyle(.blue)
                                Image(systemName: "arrow.up.right.square").font(.subheadline).foregroundStyle(.blue)
                            }
                        }
                        .padding()
                    }
                    .background(Color(white: 0.08))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .task { await viewModel.loadData() }
    }
}

// Subviews
struct InputRow: View {
    let input: TxInput
    let price: Double
    var currencySymbol: String = "$"
    var isJPY: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(.red)
            VStack(alignment: .leading) {
                if let addr = input.prevout?.scriptpubkey_address {
                    NavigationLink(destination: AddressDetailView(address: addr)) {
                        Text(addr.prefix(8) + "...")
                            .font(.caption.monospaced()).foregroundStyle(.blue)
                    }
                } else {
                    Text(input.txid.prefix(8) + "...")
                        .font(.caption.monospaced()).foregroundStyle(.blue)
                }
                
                if let val = input.prevout?.value {
                    let btc = Double(val) / 100_000_000
                    Text("\(val) sats")
                        .font(.caption).foregroundStyle(.white)
                    Text("\(currencySymbol)\(formatFiatValue(btc * price))")
                         .font(.caption2).foregroundStyle(.white.opacity(0.5))
                }
            }
            Spacer()
        }
        .padding(8)
        .background(Color(white: 0.1))
        .cornerRadius(8)
    }
    
    private func formatFiatValue(_ value: Double) -> String {
        if isJPY {
            return value.formatted(.number.precision(.fractionLength(0)))
        }
        return value.formatted(.number.precision(.fractionLength(2)))
    }
}

struct OutputRow: View {
    let output: TxOutput
    let price: Double
    var currencySymbol: String = "$"
    var isJPY: Bool = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                if let addr = output.scriptpubkey_address {
                    NavigationLink(destination: AddressDetailView(address: addr)) {
                        Text(addr.prefix(10) ?? "Unknown")
                            .font(.caption.monospaced()).foregroundStyle(.blue)
                    }
                } else {
                    Text("Unknown")
                        .font(.caption.monospaced()).foregroundStyle(.blue)
                }
                
                let btc = Double(output.value) / 100_000_000
                Text("\(output.value) sats")
                    .font(.caption).foregroundStyle(.white)
                Text("\(currencySymbol)\(formatFiatValue(btc * price))")
                     .font(.caption2).foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "arrow.left.circle.fill")
                .foregroundStyle(.green)
        }
        .padding(8)
        .background(Color(white: 0.1))
        .cornerRadius(8)
    }
    
    private func formatFiatValue(_ value: Double) -> String {
        if isJPY {
            return value.formatted(.number.precision(.fractionLength(0)))
        }
        return value.formatted(.number.precision(.fractionLength(2)))
    }
}

struct FlowDiagramView: View {
    let inputs: Int
    let outputs: Int
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let centerX = w / 2
            let centerY = h / 2
            
            // Draw Inputs (Left to Center)
            ForEach(0..<min(inputs, 10), id: \.self) { i in
                Path { path in
                    let y = h * (Double(i) + 0.5) / Double(min(inputs, 10))
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addCurve(to: CGPoint(x: centerX, y: centerY),
                                  control1: CGPoint(x: w * 0.25, y: y),
                                  control2: CGPoint(x: w * 0.25, y: centerY))
                }
                .stroke(
                    LinearGradient(colors: [.red.opacity(0.6), .purple.opacity(0.6)], startPoint: .leading, endPoint: .trailing),
                    lineWidth: 3
                )
            }
            
            // Draw Outputs (Center to Right)
            ForEach(0..<min(outputs, 10), id: \.self) { i in
                Path { path in
                    let y = h * (Double(i) + 0.5) / Double(min(outputs, 10))
                    path.move(to: CGPoint(x: centerX, y: centerY))
                    path.addCurve(to: CGPoint(x: w, y: y),
                                  control1: CGPoint(x: w * 0.75, y: centerY),
                                  control2: CGPoint(x: w * 0.75, y: y))
                }
                .stroke(
                    LinearGradient(colors: [.purple.opacity(0.6), .green.opacity(0.6)], startPoint: .leading, endPoint: .trailing),
                    lineWidth: 3
                )
            }
            
            // Central Node
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
                .position(x: centerX, y: centerY)
                .shadow(color: .purple, radius: 5)
        }
    }
}
