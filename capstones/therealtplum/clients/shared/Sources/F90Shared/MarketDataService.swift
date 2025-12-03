import Foundation

// MARK: - Service Protocol

public protocol MarketDataServiceType {
    func fetchFocusMarketData(limit: Int?, days: Int?) async throws -> [PriceDataPoint]
}

// MARK: - Default Service Implementation

public struct MarketDataService: MarketDataServiceType {
    /// Base URL for the Rust API market data endpoint.
    public let baseURL: URL
    
    public init(baseURL: URL = URL(string: "http://127.0.0.1:3000")!) {
        self.baseURL = baseURL
    }
    
    public func fetchFocusMarketData(limit: Int? = nil, days: Int? = nil) async throws -> [PriceDataPoint] {
        let pathString = baseURL.absoluteString.hasSuffix("/") 
            ? "\(baseURL.absoluteString)focus/market-data"
            : "\(baseURL.absoluteString)/focus/market-data"
        
        guard var components = URLComponents(string: pathString) else {
            throw URLError(.badURL)
        }
        
        var queryItems: [URLQueryItem] = []
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }
        if let days = days {
            queryItems.append(URLQueryItem(name: "days", value: "\(days)"))
        }
        
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // Log error details for debugging
        if !(200..<300).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unable to decode error response"
            print("MarketData API error: status=\(httpResponse.statusCode), body=\(errorBody)")
            print("MarketData API request URL: \(url)")
            
            if httpResponse.statusCode == 404 {
                print("MarketData API: 404 Not Found - Check if Rust API server is running on port 3000")
                print("MarketData API: Try: curl \(url)")
            }
            
            throw URLError(.badServerResponse)
        }
        
        // Try to decode the response
        do {
            let decoder = JSONDecoder()
            let dataPoints = try decoder.decode([PriceDataPoint].self, from: data)
            print("MarketData Service: Successfully decoded \(dataPoints.count) data points")
            return dataPoints
        } catch {
            // Log the actual response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("MarketData Service: Failed to decode response: \(error)")
                print("MarketData Service: Response (first 1000 chars): \(responseString.prefix(1000))")
            }
            throw error
        }
    }
}

// MARK: - Helper Functions

public extension Array where Element == PriceDataPoint {
    /// Group price data points by instrument
    func groupedByInstrument() -> [InstrumentMarketData] {
        let grouped = Dictionary(grouping: self) { $0.instrumentId }
        return grouped.map { (instrumentId, points) in
            let firstPoint = points.first!
            // Sort data points by date to ensure chronological order
            let sortedPoints = points.sorted { $0.priceDate < $1.priceDate }
            return InstrumentMarketData(
                id: instrumentId,
                ticker: firstPoint.ticker,
                name: firstPoint.name,
                dataPoints: sortedPoints
            )
        }
        .sorted { $0.ticker < $1.ticker }
    }
}

