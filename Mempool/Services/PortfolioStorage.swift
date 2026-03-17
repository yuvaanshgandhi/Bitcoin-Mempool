import Foundation

class PortfolioStorage {
    private let key = "saved_portfolio_addresses"
    private let defaults = UserDefaults.standard
    
    func load() -> [PortfolioAddress] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PortfolioAddress].self, from: data)) ?? []
    }
    
    func save(_ addresses: [PortfolioAddress]) {
        if let data = try? JSONEncoder().encode(addresses) {
            defaults.set(data, forKey: key)
        }
    }
    
    func add(address: String, label: String?) -> PortfolioAddress {
        var list = load()
        let entry = PortfolioAddress(address: address, label: label)
        list.append(entry)
        save(list)
        return entry
    }
    
    func remove(id: UUID) {
        var list = load()
        list.removeAll { $0.id == id }
        save(list)
    }
}
