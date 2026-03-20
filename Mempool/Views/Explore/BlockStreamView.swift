import SwiftUI

struct BlockStreamView: View {
    let projectedBlocks: [ProjectedBlock]
    let confirmedBlocks: [MempoolBlock]
    let newBlockArrived: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Block Stream")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
                
                if newBlockArrived {
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
                        // Projected blocks
                        let reversedBlocks = Array(projectedBlocks.enumerated()).reversed()
                        ForEach(Array(reversedBlocks), id: \.offset) { offset, element in
                            let index = offset
                            let block = element
                            
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
                            if newBlockArrived {
                                Circle()
                                    .fill(Color.green.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .scaleEffect(newBlockArrived ? 1.5 : 0.5)
                                    .opacity(newBlockArrived ? 0 : 1)
                                    .animation(.easeOut(duration: 1.5).repeatCount(2, autoreverses: false), value: newBlockArrived)
                            }
                            
                            Rectangle()
                                .fill(LinearGradient(colors: newBlockArrived ? [.green, .green.opacity(0.6)] : [.orange, .blue], startPoint: .top, endPoint: .bottom))
                                .frame(width: newBlockArrived ? 4 : 2, height: 100)
                                .animation(.spring(response: 0.4), value: newBlockArrived)
                        }
                        .id("blockSeparator")
                        
                        // Confirmed blocks
                        ForEach(confirmedBlocks) { block in
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
                                .background((block.extras != nil ? getMedianFeeColor(block.extras!.medianFee) : Color.blue).opacity(0.1).cornerRadius(20)) 
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation { proxy.scrollTo("blockSeparator", anchor: .center) }
                    }
                }
                .onChange(of: confirmedBlocks.first?.id) { _, _ in
                    withAnimation { proxy.scrollTo("blockSeparator", anchor: .center) }
                }
            }
        }
    }
    
    func timeAgo(timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
