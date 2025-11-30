import Foundation

// MARK: - Service Protocol

protocol KalshiServiceType {
    func fetchMarkets(category: String?, status: String?, limit: Int?, offset: Int?, search: String?) async throws -> [KalshiMarketSummary]
    func fetchMarket(ticker: String) async throws -> KalshiMarketDetail
    func fetchUserAccount(userId: String) async throws -> KalshiUserAccount
    func fetchUserBalance(userId: String) async throws -> KalshiUserBalance
    func fetchUserPositions(userId: String) async throws -> [KalshiPosition]
    func storeCredentials(userId: String, apiKey: String, apiSecret: String) async throws -> Bool
}

// MARK: - Default Service Implementation

@MainActor
struct KalshiService: KalshiServiceType {
    let baseURL: URL
    
    init(baseURL: URL = URL(string: "http://127.0.0.1:3000")!) {
        self.baseURL = baseURL
    }
    
    // MARK: - Markets
    
    func fetchMarkets(category: String? = nil, status: String? = nil, limit: Int? = nil, offset: Int? = nil, search: String? = nil) async throws -> [KalshiMarketSummary] {
        var components = URLComponents(url: baseURL.appendingPathComponent("kalshi/markets"), resolvingAgainstBaseURL: false)!
        var queryItems: [URLQueryItem] = []
        
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if let status = status {
            queryItems.append(URLQueryItem(name: "status", value: status))
        }
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        if let search = search {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([KalshiMarketSummary].self, from: data)
    }
    
    func fetchMarket(ticker: String) async throws -> KalshiMarketDetail {
        let url = baseURL.appendingPathComponent("kalshi/markets/\(ticker)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(KalshiMarketDetail.self, from: data)
    }
    
    // MARK: - User Account
    
    func fetchUserAccount(userId: String) async throws -> KalshiUserAccount {
        let url = baseURL.appendingPathComponent("kalshi/users/\(userId)/account")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(KalshiUserAccount.self, from: data)
    }
    
    func fetchUserBalance(userId: String) async throws -> KalshiUserBalance {
        let url = baseURL.appendingPathComponent("kalshi/users/\(userId)/balance")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(KalshiUserBalance.self, from: data)
    }
    
    func fetchUserPositions(userId: String) async throws -> [KalshiPosition] {
        let url = baseURL.appendingPathComponent("kalshi/users/\(userId)/positions")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([KalshiPosition].self, from: data)
    }
    
    // MARK: - Credentials
    
    func storeCredentials(userId: String, apiKey: String, apiSecret: String) async throws -> Bool {
        // TODO: This should call a backend endpoint to store encrypted credentials
        // For now, we'll store them locally in Keychain or UserDefaults
        // In production, this should be sent to the backend API
        
        // Store in UserDefaults for now (not secure, but for testing)
        // In production, use Keychain
        let credentials = KalshiCredentials(apiKey: apiKey, apiSecret: apiSecret)
        if let encoded = try? JSONEncoder().encode(credentials) {
            UserDefaults.standard.set(encoded, forKey: "kalshi_credentials_\(userId)")
            return true
        }
        return false
    }
}

