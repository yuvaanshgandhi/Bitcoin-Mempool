import Foundation

enum FeeMultipleError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
}

actor FeeMultipleService {
    static let shared = FeeMultipleService()
    private let baseURL = "https://feemultiple.bullbitcoin.com/api/v1"
    private let session = URLSession.shared
    
    private init() {}
    
    func getFeeMultipleIndex() async throws -> FeeMultipleIndexResponse {
        return try await fetch(endpoint: "/index")
    }
    
    func getFeeMultipleHistory() async throws -> [FeeMultipleHistoryItem] {
        return try await fetch(endpoint: "/history")
    }
    
    private func fetch<T: Decodable>(endpoint: String) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw FeeMultipleError.invalidURL
        }
        
        do {
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse, 
                  (200...299).contains(httpResponse.statusCode) else {
                throw FeeMultipleError.apiError("Status code: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            }
            
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw FeeMultipleError.networkError(error)
        }
    }
}
