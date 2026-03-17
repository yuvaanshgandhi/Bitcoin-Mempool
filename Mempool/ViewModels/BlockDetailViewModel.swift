import Foundation
import Combine

@MainActor
class BlockDetailViewModel: ObservableObject {
    @Published var block: BlockDetail?
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?
    
    @Published var isProjected: Bool = false
    private let service = MempoolService.shared
    private let identifier: String // Hash or Height
    
    init(identifier: String, projectedBlock: ProjectedBlock? = nil) {
        self.identifier = identifier
        if let pb = projectedBlock {
            self.isProjected = true
            // Map ProjectedBlock explicitly to a dummy BlockDetail for UI
            self.block = BlockDetail(
                id_val: pb.id.uuidString,
                height: 0, // Unused for projected
                version: 0,
                timestamp: Int(Date().timeIntervalSince1970),
                tx_count: pb.nTx,
                size: Int(pb.blockSize),
                weight: Int(pb.blockVSize * 4), 
                merkle_root: "Projected",
                previousblockhash: "",
                mediantime: Int(Date().timeIntervalSince1970),
                nonce: 0,
                bits: 0,
                difficulty: 0,
                extras: BlockExtras(
                    totalFees: pb.totalFees,
                    medianFee: pb.medianFee,
                    feeRange: pb.feeRange,
                    reward: 312500000 + pb.totalFees,
                    pool: PoolInfo(id: 0, name: "Unknown", slug: "")
                )
            )
        }
    }
    
    func loadData() async {
        guard !isProjected else { return } // Do not fetch network for projected
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let fetchedBlock = service.getBlock(hash: identifier)
            async let fetchedTxs = service.getBlockTransactions(hash: identifier)
            
            let (block, txs) = try await (fetchedBlock, fetchedTxs)
            
            self.block = block
            self.transactions = txs
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func loadMoreTransactions() async {
        guard let block = block, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        do {
            let moreTxs = try await service.getBlockTransactions(
                hash: block.id_val,
                startIndex: transactions.count
            )
            transactions.append(contentsOf: moreTxs)
        } catch {
            // Silently fail on pagination
        }
    }
}
