import Foundation
import Combine

// MARK: - ViewModel

@MainActor
final class SystemHealthViewModel: ObservableObject {
    @Published var health: SystemHealth?
    @Published var dbTables: [String] = []

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var autoRefresh = true

    private let service: SystemHealthServiceType

    init(service: SystemHealthServiceType? = nil) {
        self.service = service ?? SystemHealthService()

        Task {
            await refresh()
            startAutoRefresh()
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let health = try await service.fetchHealth()
            self.health = health

            // dbTables is non-optional in the model
            self.dbTables = health.dbTables
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        } catch {
            self.health = nil
            self.dbTables = []
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func startAutoRefresh() {
        Task { [weak self] in
            while let self = self {
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                guard self.autoRefresh else { continue }
                await self.refresh()
            }
        }
    }
}

// MARK: - Service Protocol

protocol SystemHealthServiceType {
    func fetchHealth() async throws -> SystemHealth
}

// MARK: - Default Service Implementation

struct SystemHealthService: SystemHealthServiceType {
    /// Base URL for the Rust API system health endpoint.
    /// For local dev, this matches your curl:
    ///   curl http://127.0.0.1:3000/system/health
    let baseURL: URL

    init(baseURL: URL = URL(string: "http://127.0.0.1:3000")!) {
        self.baseURL = baseURL
    }

    func fetchHealth() async throws -> SystemHealth {
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
