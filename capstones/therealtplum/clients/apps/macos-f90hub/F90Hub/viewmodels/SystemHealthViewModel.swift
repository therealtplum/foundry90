import Foundation
import Combine
import F90Shared

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
