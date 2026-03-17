import Foundation

class WatchlistStorage {
    private let key = "watched_transactions"
    private let defaults = UserDefaults.standard
    
    static let DID_UPDATE_NOTIFICATION = Notification.Name("WatchlistDidUpdate")
    
    func load() -> [WatchlistItem] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([WatchlistItem].self, from: data)) ?? []
    }
    
    func save(_ items: [WatchlistItem]) {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
            NotificationCenter.default.post(name: WatchlistStorage.DID_UPDATE_NOTIFICATION, object: nil)
        }
    }
    
    func addTransaction(txid: String, label: String?) -> WatchlistItem {
        var list = load()
        let entry = WatchlistItem(type: .transaction, identifier: txid, label: label)
        list.append(entry)
        save(list)
        return entry
    }
    
    func addAddress(address: String, label: String?) -> WatchlistItem {
        var list = load()
        let entry = WatchlistItem(type: .address, identifier: address, label: label)
        list.append(entry)
        save(list)
        return entry
    }
    
    func remove(id: UUID) {
        var list = load()
        list.removeAll { $0.id == id }
        save(list)
    }
    
    func markConfirmed(txid: String, blockHeight: Int?) {
        var list = load()
        if let index = list.firstIndex(where: { $0.type == .transaction && $0.identifier == txid }) {
            list[index].isConfirmed = true
            list[index].blockHeight = blockHeight
            list[index].confirmedAt = Date()
            save(list)
        }
    }
    
    func updateAddressStats(address: String, fundedSum: Int, spentSum: Int, txCount: Int) {
        var list = load()
        if let index = list.firstIndex(where: { $0.type == .address && $0.identifier == address }) {
            list[index].fundedTxoSum = fundedSum
            list[index].spentTxoSum = spentSum
            list[index].txCount = txCount
            save(list)
        }
    }
    
    func contains(identifier: String) -> Bool {
        return load().contains { $0.identifier == identifier }
    }
}
