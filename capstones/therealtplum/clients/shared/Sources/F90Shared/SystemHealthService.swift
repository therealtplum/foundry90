import Foundation

// MARK: - Service Protocol

public protocol SystemHealthServiceType {
    func fetchHealth() async throws -> SystemHealth
}

// MARK: - Default Service Implementation

public struct SystemHealthService: SystemHealthServiceType {
    /// Base URL for the Rust API system health endpoint.
    /// For local dev, this matches your curl:
    ///   curl http://127.0.0.1:3000/system/health
    public let baseURL: URL

    public init(baseURL: URL = URL(string: "http://127.0.0.1:3000")!) {
        self.baseURL = baseURL
    }

    public func fetchHealth() async throws -> SystemHealth {
        let url = baseURL.appendingPathComponent("system/health")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        // We already handle snake_case via CodingKeys in SystemHealth/WebHealth,
        // so we can use the default keyDecodingStrategy.
        return try decoder.decode(SystemHealth.self, from: data)
    }
}
