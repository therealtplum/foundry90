import Foundation
import Combine

@MainActor
final class SystemHealthViewModel: ObservableObject {
    @Published var health: SystemHealth?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var autoRefresh = true

    private let service: SystemHealthServiceType

    // Allow passing a mock in tests, default to real service otherwise
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
            let result = try await service.fetchHealth()
            self.health = result
        } catch {
            // NEW: clear the old "up" state
            self.health = nil
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func startAutoRefresh() {
        Task {
            while true {
                try? await Task.sleep(nanoseconds: 10 * 1_000_000_000)
                guard autoRefresh else { continue }
                await refresh()
            }
        }
    }
}
