import Foundation
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var searchResult: SearchResult?
    @Published var isSearching = false
    @Published var error: String?
    
    private let service = MempoolService.shared
    
    func performSearch() async {
        guard !query.isEmpty else { return }
        isSearching = true
        error = nil
        defer { isSearching = false }
        
        // Simple heuristic search
        // If query length is 64 hex chars -> Block Hash or TxID
        // If query length is 26-35 alphanumeric -> Address
        // If query is integer -> Block Height
        
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let height = Int(trimmedQuery) {
            searchResult = SearchResult(type: .block, key: trimmedQuery)
            return
        }
        
        if trimmedQuery.count == 64 {
            if trimmedQuery.hasPrefix("0000") {
                 searchResult = SearchResult(type: .block, key: trimmedQuery)
            } else {
                 searchResult = SearchResult(type: .transaction, key: trimmedQuery)
            }
            return
        }
        
        searchResult = SearchResult(type: .address, key: trimmedQuery)
    }
}
