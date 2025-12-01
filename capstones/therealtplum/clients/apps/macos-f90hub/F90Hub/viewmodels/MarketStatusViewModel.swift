import Foundation
import Combine
import F90Shared

// MARK: - ViewModel

@MainActor
final class MarketStatusViewModel: ObservableObject {
    @Published var marketStatus: MarketStatus?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var autoRefresh = true
    
    private let service: MarketStatusServiceType
    
    init(service: MarketStatusServiceType? = nil) {
        self.service = service ?? MarketStatusService()

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
            let status = try await service.fetchMarketStatus()
            self.marketStatus = status
        } catch {
            self.marketStatus = nil
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func startAutoRefresh() {
        Task { [weak self] in
            while let self = self {
                // Refresh every 60 seconds (market status changes infrequently)
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                guard self.autoRefresh else { continue }
                await self.refresh()
            }
        }
    }
}
