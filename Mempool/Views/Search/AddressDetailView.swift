import SwiftUI

struct AddressDetailView: View {
    @StateObject private var viewModel: AddressDetailViewModel
    @EnvironmentObject var currencySettings: CurrencySettings
    
    init(address: String) {
        _viewModel = StateObject(wrappedValue: AddressDetailViewModel(address: address))
    }
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView().tint(.white).padding(.top, 50)
            } else if let error = viewModel.error {
                Text("Error: \(error)")
                    .foregroundStyle(.red)
                    .padding()
            } else if let stats = viewModel.addressStats, let price = viewModel.price {
                VStack(spacing: 30) {
                    
                    // 1. Header with QR/Actions (Simplified)
                    HStack {
                        Text("Address")
                            .font(.largeTitle).bold().foregroundStyle(.white)
                        Spacer()
                        
                        Button {
                            viewModel.toggleWatchlist()
                        } label: {
                            Image(systemName: viewModel.isWatched ? "star.fill" : "star")
                                .foregroundStyle(.yellow)
                                .font(.title3)
                        }
                        .padding(.trailing, 8)
                        
                        Text(stats.address.prefix(6) + "..." + stats.address.suffix(6))
                            .font(.headline.monospaced())
                            .foregroundStyle(.blue)
                        Button {
                            UIPasteboard.general.string = stats.address
                        } label: {
                            Image(systemName: "doc.on.doc").font(.caption).foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal)
                    
                    // 2. Stats Grid (Navy Cards)
                        let fiatPrice = currencySettings.price(from: price)
                        HStack(spacing: 20) {
                         // Confirmed Column
                        VStack(spacing: 15) {
                            StatCard(title: "Confirmed balance", 
                                     btcValue: formatBTC(stats.chain_stats.funded_txo_sum - stats.chain_stats.spent_txo_sum),
                                     usdValue: formatFiat(stats.chain_stats.funded_txo_sum - stats.chain_stats.spent_txo_sum, price: fiatPrice),
                                     highlight: true)
                            
                            StatCardSimple(title: "Confirmed UTXOs", value: "\(stats.chain_stats.tx_count - stats.chain_stats.spent_txo_count)") // Approx logic
                            
                            StatCardSimple(title: "Total received", value: formatBTC(stats.chain_stats.funded_txo_sum))
                        }
                        
                        // Pending Column
                        VStack(spacing: 15) {
                            StatCard(title: "Pending", 
                                     btcValue: "+\(formatBTC(stats.mempool_stats.funded_txo_sum - stats.mempool_stats.spent_txo_sum))",
                                     usdValue: formatFiat(stats.mempool_stats.funded_txo_sum - stats.mempool_stats.spent_txo_sum, price: fiatPrice),
                                     highlight: true,
                                     isPending: true)
                            
                            StatCardSimple(title: "Pending UTXOs", value: "\(stats.mempool_stats.tx_count)")
                            
                            HStack {
                                Text("Type")
                                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Text("P2WPKH") // Placeholder type logic, would need decoding script
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .cornerRadius(4)
                                    .foregroundStyle(.white)
                            }
                            .padding()
                            .background(Color(white: 0.08)) // Dark card
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 3. Transactions List Header
                    HStack {
                        Text("\(viewModel.transactions.count) of \(stats.chain_stats.tx_count + stats.mempool_stats.tx_count) transactions")
                            .font(.title2).bold().foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // 4. Transactions List
                    VStack(spacing: 15) {
                        ForEach(viewModel.transactions) { tx in
                            NavigationLink(destination: TransactionDetailView(txid: tx.txid)) {
                                TransactionCard(tx: tx, currentAddress: stats.address, price: fiatPrice, currencySymbol: currencySettings.currencySymbol, isJPY: currencySettings.selectedCurrency == "JPY")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 50)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .task { await viewModel.loadData() }
    }
    
    // Helpers
    func formatBTC(_ sats: Int) -> String {
        return String(format: "%.8f BTC", Double(sats) / 100_000_000)
    }
    
    func formatFiat(_ sats: Int, price: Double) -> String {
        let btc = Double(sats) / 100_000_000
        return currencySettings.formatFiat(btc * price)
    }
}

// Subviews
struct StatCard: View {
    let title: String
    let btcValue: String
    let usdValue: String
    var highlight: Bool = false
    var isPending: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption).bold().foregroundStyle(.white.opacity(0.7))
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(btcValue)
                    .font(.callout.bold()) // Scaled down slightly
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                Text(usdValue)
                    .font(.caption)
                    .foregroundStyle(isPending ? .green : .green)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.08)) // Dark card
        .cornerRadius(8)
    }
}

struct StatCardSimple: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption).foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.white)
        }
        .padding()
        .background(Color(white: 0.08)) // Dark card
        .cornerRadius(8)
    }
}

struct TransactionCard: View {
    let tx: Transaction
    let currentAddress: String
    let price: Double
    var currencySymbol: String = "$"
    var isJPY: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header: ID + Time
            HStack {
                Text(tx.txid)
                    .font(.caption.monospaced())
                    .foregroundStyle(.blue)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                // Fake time or real if available in Transaction model?
                // Assuming Transaction model has `status.block_time`
                if let ts = tx.status.block_time {
                    Text(formatDate(ts))
                        .font(.caption2).foregroundStyle(.white.opacity(0.6))
                } else {
                     Text("Unconfirmed")
                        .font(.caption2).foregroundStyle(.yellow)
                }
            }
            .padding()
            .background(Color(white: 0.1)) // Darker header
            
            Divider().background(.white.opacity(0.1))
            
            // IO Flow
            HStack(alignment: .top) {
                // Inputs
                IOColumn(items: tx.vin, isInput: true, currentAddr: currentAddress, price: price, currencySymbol: currencySymbol, isJPY: isJPY)
                
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.green)
                    .padding(.top, 20)
                
                // Outputs
                IOColumn(items: tx.vout, isInput: false, currentAddr: currentAddress, price: price, currencySymbol: currencySymbol, isJPY: isJPY)
            }
            .padding()
            
            Divider().background(.white.opacity(0.1))
            
            // Footer: Fee + Status
            HStack {
                VStack(alignment: .leading) {
                    Text("\(String(format: "%.1f", Double(tx.fee) / (Double(tx.weight)/4.0))) sat/vB")
                        .font(.caption.bold()).foregroundStyle(.white)
                    Text("\(tx.fee) sats")
                        .font(.caption2).foregroundStyle(.white.opacity(0.6))
                    Text(formatFiat(tx.fee))
                         .font(.caption2).foregroundStyle(.green)
                }
                Spacer()
                
                if tx.status.confirmed {
                    Text("1 confirmation") // Simplify for mock, requires tip height for real confs
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green)
                        .foregroundStyle(.white)
                        .cornerRadius(5)
                } else {
                    Text("Unconfirmed")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .cornerRadius(5)
                }
                
                // Net change pill (Fake logic for now, calculating real net change requires complex input matching)
                Text("- $10.00") 
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .cornerRadius(5)
            }
            .padding()
            .background(Color(white: 0.1))
        }
        .background(Color(white: 0.08))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
    
    func formatDate(_ ts: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    func formatFiat(_ sats: Int) -> String {
        let btc = Double(sats) / 100_000_000
        let val = btc * price
        if isJPY {
            return "\(currencySymbol)\(val.formatted(.number.precision(.fractionLength(0))))"
        }
        return "\(currencySymbol)\(val.formatted(.number.precision(.fractionLength(2))))"
    }
}

// ... IOColumn and IORow reused ...
struct IOColumn: View {
    let items: [Any] // Abstracted for mixed inputs/outputs
    let isInput: Bool
    let currentAddr: String
    let price: Double
    var currencySymbol: String = "$"
    var isJPY: Bool = false
    
    var body: some View {
        VStack(alignment: isInput ? .leading : .trailing, spacing: 10) {
            if isInput {
               if let inputs = items as? [TxInput] {
                   ForEach(inputs.prefix(3)) { input in
                        IORow(addr: input.prevout?.scriptpubkey_address, 
                              val: input.prevout?.value ?? 0, 
                              isInput: true, 
                              currentAddr: currentAddr,
                              price: price,
                              currencySymbol: currencySymbol,
                              isJPY: isJPY)
                   }
                   if inputs.count > 3 { Text("...").font(.caption).foregroundStyle(.gray) }
               }
            } else {
                if let outputs = items as? [TxOutput] {
                    ForEach(outputs.prefix(3)) { output in
                        IORow(addr: output.scriptpubkey_address, 
                              val: output.value, 
                              isInput: false, 
                              currentAddr: currentAddr,
                              price: price,
                              currencySymbol: currencySymbol,
                              isJPY: isJPY)
                    }
                    if outputs.count > 3 { Text("...").font(.caption).foregroundStyle(.gray) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: isInput ? .leading : .trailing)
    }
}


struct IORow: View {
    let addr: String?
    let val: Int
    let isInput: Bool
    let currentAddr: String
    let price: Double
    var currencySymbol: String = "$"
    var isJPY: Bool = false
    
    var body: some View {
        VStack(alignment: isInput ? .leading : .trailing, spacing: 2) {
             HStack {
                 if !isInput { Spacer() }
                 Text(addr?.prefix(6) ?? "Unknown") // Shorten for UI
                     .font(.caption.monospaced())
                     .foregroundStyle(addr == currentAddr ? .white : .blue) // Simplified Highlight
                 if let addr = addr {
                     Text("..." + addr.suffix(4))
                        .font(.caption.monospaced())
                        .foregroundStyle(addr == currentAddr ? .white : .blue)
                 }
                 if isInput { Spacer() }
             }
             
             Text(formatFiat(val))
                 .font(.caption2).foregroundStyle(.white.opacity(0.8))
        }
    }
    
    func formatFiat(_ sats: Int) -> String {
        let btc = Double(sats) / 100_000_000
        let val = btc * price
        if isJPY {
            return "\(currencySymbol)\(val.formatted(.number.precision(.fractionLength(0))))"
        }
        return "\(currencySymbol)\(val.formatted(.number.precision(.fractionLength(2))))"
    }
}
