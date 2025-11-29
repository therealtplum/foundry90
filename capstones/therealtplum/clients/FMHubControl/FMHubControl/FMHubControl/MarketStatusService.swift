import Foundation

// MARK: - Service Protocol

protocol MarketStatusServiceType {
    func fetchMarketStatus() async throws -> MarketStatus
}

// MARK: - Default Service Implementation

struct MarketStatusService: MarketStatusServiceType {
    /// Base URL for the Rust API market status endpoint.
    /// For local dev, this matches:
    ///   curl http://127.0.0.1:3000/market/status
    let baseURL: URL
    
    init(baseURL: URL = URL(string: "http://127.0.0.1:3000")!) {
        self.baseURL = baseURL
    }
    
    func fetchMarketStatus() async throws -> MarketStatus {
        let url = baseURL.appendingPathComponent("market/status")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(MarketStatus.self, from: data)
    }
}

