import Foundation
import Combine

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

            self.dbTables = (health.dbTables ?? [])
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        } catch {
            self.health = nil
            self.dbTables = []
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func startAutoRefresh() {
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                guard autoRefresh else { continue }
                await refresh()
            }
        }
    }
}
