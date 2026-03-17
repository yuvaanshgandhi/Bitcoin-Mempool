import SwiftUI

struct TransactionVisualizer: View {
    let transactions: [Transaction]
    
    // Grid layout
    let columns = [
        GridItem(.adaptive(minimum: 15, maximum: 20), spacing: 2)
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Visualizer")
                .font(.headline).foregroundStyle(.white)
                .padding(.bottom, 5)
            
            LazyVGrid(columns: columns, spacing: 2) {
                // If we have transactions from block details, show them.
                // Note: BlockDetail endpoint might not return ALL txs unless we paginate. 
                // We'll visualize what we have.
                ForEach(transactions.prefix(250)) { tx in // Limit to 250 for performance in this view
                    Rectangle()
                        .fill(colorForTx(tx))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Rectangle()
                                .stroke(.black.opacity(0.1), lineWidth: 0.5)
                        )
                }
            }
            .frame(maxHeight: 300)
            .clipped()
            .background(Color.black.opacity(0.2))
            .cornerRadius(5)
            
            HStack {
                Text("Low Fee")
                Spacer()
                Text("High Fee")
            }
            .font(.caption2).foregroundStyle(.white.opacity(0.5))
            .background(
                LinearGradient(colors: [.blue, .purple, .red], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 4)
                    .offset(y: 10)
            )
        }
    }
    
    func colorForTx(_ tx: Transaction) -> Color {
        // Calculate fee rate (sat/vB)
        let feeRate = Double(tx.fee) / Double(tx.weight / 4)
        
        // Color gradient: Blue (Low) -> Purple (Med) -> Red (High)
        // Adjust thresholds based on network conditions (static for now)
        if feeRate < 5 { return .blue }
        if feeRate < 20 { return .purple }
        return .red
    }
}
