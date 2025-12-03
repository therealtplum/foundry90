import Foundation
import Combine
import F90Shared

// MARK: - ViewModel

@MainActor
final class MarketDataViewModel: ObservableObject {
    @Published var marketData: [InstrumentMarketData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var autoRefresh = true
    @Published var selectedInstrument: InstrumentMarketData?
    
    private let service: MarketDataServiceType
    private var refreshTask: Task<Void, Never>?
    
    init(service: MarketDataServiceType? = nil) {
        self.service = service ?? MarketDataService()
        
        Task {
            await refresh()
            startAutoRefresh()
        }
    }
    
    deinit {
        refreshTask?.cancel()
    }
    
    func refresh(limit: Int? = nil, days: Int? = nil) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        
        do {
            let dataPoints = try await service.fetchFocusMarketData(limit: limit ?? 20, days: days ?? 30)
            let grouped = dataPoints.groupedByInstrument()
            self.marketData = grouped
            
            // Auto-select first instrument if none selected
            if selectedInstrument == nil, let first = grouped.first {
                selectedInstrument = first
            }
        } catch {
            self.marketData = []
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func startAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while let self = self, !Task.isCancelled {
                // Refresh every 5 minutes (market data updates during trading hours)
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
                guard self.autoRefresh else { continue }
                await self.refresh()
            }
        }
    }
    
    func selectInstrument(_ instrument: InstrumentMarketData) {
        selectedInstrument = instrument
    }
}

