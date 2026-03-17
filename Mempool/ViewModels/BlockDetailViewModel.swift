import Foundation
import Combine

@MainActor
class BlockDetailViewModel: ObservableObject {
    @Published var block: BlockDetail?
    @Published var transactions: [Transaction] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var error: String?
    
    private let service = MempoolService.shared
    private let identifier: String // Hash or Height
    
    init(identifier: String) {
        self.identifier = identifier
    }
    
    func loadData() async {
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
