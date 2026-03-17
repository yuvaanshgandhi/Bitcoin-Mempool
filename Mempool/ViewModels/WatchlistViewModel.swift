import Foundation
import Combine
import SwiftUI

@MainActor
class WatchlistViewModel: ObservableObject {
    @Published var watchedItems: [WatchlistItem] = []
    @Published var isAddingItem = false
    @Published var newItemInput = ""
    @Published var newLabelInput = ""
    @Published var error: String?
    @Published var recentlyConfirmedTxid: String?
    @Published var selectedType: WatchlistType = .transaction
    
    private let storage = WatchlistStorage()
    private let wsService = MempoolWebSocketService.shared
    private let apiService = MempoolService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadItems()
        subscribeToWebSocket()
        
        NotificationCenter.default.publisher(for: WatchlistStorage.DID_UPDATE_NOTIFICATION)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadItems()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    func loadItems() {
        watchedItems = storage.load()
        
        let unconfirmedTxs = watchedItems.filter { $0.type == .transaction && !$0.isConfirmed }.map { $0.identifier }
        let addresses = watchedItems.filter { $0.type == .address }.map { $0.identifier }
        
        if !unconfirmedTxs.isEmpty {
            wsService.trackTransactions(unconfirmedTxs)
        }
        if !addresses.isEmpty {
            wsService.trackAddresses(addresses)
        }
    }
    
    func addItem(type: WatchlistType, identifier: String, label: String?) {
        let cleanId = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else { return }
        guard !storage.contains(identifier: cleanId) else {
            error = "Item already in watchlist"
            return
        }
        
        if type == .transaction {
            let entry = storage.addTransaction(txid: cleanId, label: label?.isEmpty == true ? nil : label)
            watchedItems.append(entry)
            Task { await checkTransactionStatus(txid: cleanId) }
            wsService.trackTransaction(cleanId)
        } else {
            let entry = storage.addAddress(address: cleanId, label: label?.isEmpty == true ? nil : label)
            watchedItems.append(entry)
            Task { await fetchAddressStats(address: cleanId) }
            wsService.trackAddress(cleanId)
        }
        
        newItemInput = ""
        newLabelInput = ""
        isAddingItem = false
        error = nil
    }
    
    func removeItem(id: UUID) {
        if let item = watchedItems.first(where: { $0.id == id }) {
            if item.type == .transaction {
                wsService.untrackTransaction(item.identifier)
            }
        }
        storage.remove(id: id)
        watchedItems.removeAll { $0.id == id }
    }
    
    func refreshStatuses() async {
        for item in watchedItems {
            if item.type == .transaction && !item.isConfirmed {
                await checkTransactionStatus(txid: item.identifier)
            } else if item.type == .address {
                await fetchAddressStats(address: item.identifier)
            }
        }
    }
    
    func isInWatchlist(identifier: String) -> Bool {
        return storage.contains(identifier: identifier)
    }
    
    // MARK: - Private
    
    private func subscribeToWebSocket() {
        wsService.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .transactionConfirmed(let txid, let blockHeight):
                    self?.handleConfirmation(txid: txid, blockHeight: blockHeight)
                case .connected:
                    self?.loadItems()
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleConfirmation(txid: String, blockHeight: Int?) {
        storage.markConfirmed(txid: txid, blockHeight: blockHeight)
        
        if let index = watchedItems.firstIndex(where: { $0.type == .transaction && $0.identifier == txid }) {
            watchedItems[index].isConfirmed = true
            watchedItems[index].blockHeight = blockHeight
            watchedItems[index].confirmedAt = Date()
            
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            recentlyConfirmedTxid = txid
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                if self?.recentlyConfirmedTxid == txid {
                    self?.recentlyConfirmedTxid = nil
                }
            }
        }
    }
    
    private func checkTransactionStatus(txid: String) async {
        do {
            let tx = try await apiService.getTransaction(txid: txid)
            if tx.status.confirmed {
                handleConfirmation(txid: txid, blockHeight: tx.status.block_height)
            }
        } catch {
            print("Failed to check tx status: \(error)")
        }
    }
    
    private func fetchAddressStats(address: String) async {
        do {
            let stats = try await apiService.getAddress(address: address)
            let funded = stats.chain_stats.funded_txo_sum + stats.mempool_stats.funded_txo_sum
            let spent = stats.chain_stats.spent_txo_sum + stats.mempool_stats.spent_txo_sum
            let count = stats.chain_stats.tx_count + stats.mempool_stats.tx_count
            
            storage.updateAddressStats(address: address, fundedSum: funded, spentSum: spent, txCount: count)
            if let index = watchedItems.firstIndex(where: { $0.type == .address && $0.identifier == address }) {
                watchedItems[index].fundedTxoSum = funded
                watchedItems[index].spentTxoSum = spent
                watchedItems[index].txCount = count
            }
        } catch {
            print("Failed to fetch address stats: \(error)")
        }
    }
}
