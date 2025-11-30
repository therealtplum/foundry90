//
//  MarketsListView.swift
//  F90Mobile
//
//  iPhone-optimized markets list view
//

import SwiftUI
import F90Shared

struct MarketsListView: View {
    @State private var markets: [KalshiMarketSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    
    private let kalshiService = KalshiService()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ErrorView(message: error) {
                        loadMarkets()
                    }
                } else {
                    marketsList
                }
            }
            .navigationTitle("Markets")
            .searchable(text: $searchText, prompt: "Search markets")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadMarkets) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                loadMarkets()
            }
            .onChange(of: searchText) { _, _ in
                loadMarkets()
            }
        }
    }
    
    private var marketsList: some View {
        List {
            ForEach(filteredMarkets) { market in
                NavigationLink(destination: MarketDetailView(market: market)) {
                    MarketRowView(market: market)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await refreshMarkets()
        }
    }
    
    private var filteredMarkets: [KalshiMarketSummary] {
        if searchText.isEmpty {
            return markets
        }
        return markets.filter { market in
            market.name.localizedCaseInsensitiveContains(searchText) ||
            market.ticker.localizedCaseInsensitiveContains(searchText) ||
            (market.displayName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    private func loadMarkets() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedMarkets = try await kalshiService.fetchMarkets(
                    category: selectedCategory,
                    status: "open",
                    limit: 100,
                    search: searchText.isEmpty ? nil : searchText
                )
                await MainActor.run {
                    self.markets = fetchedMarkets
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func refreshMarkets() async {
        do {
            let fetchedMarkets = try await kalshiService.fetchMarkets(
                category: selectedCategory,
                status: "open",
                limit: 100,
                search: searchText.isEmpty ? nil : searchText
            )
            await MainActor.run {
                self.markets = fetchedMarkets
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

struct MarketRowView: View {
    let market: KalshiMarketSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(market.displayName)
                .font(.headline)
                .lineLimit(2)
            
            HStack {
                if let yesPrice = market.yesPrice {
                    Text("Yes: \(formatPrice(yesPrice))")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                if let volume = market.volume {
                    Text("Vol: \(formatVolume(volume))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                if let category = market.category {
                    Text(category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Spacer()
                
                Text(market.status.capitalized)
                    .font(.caption)
                    .foregroundColor(statusColor(market.status))
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatPrice(_ price: Double) -> String {
        String(format: "%.2f¢", price * 100)
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1_000_000 {
            return String(format: "%.1fM", volume / 1_000_000)
        } else if volume >= 1_000 {
            return String(format: "%.1fK", volume / 1_000)
        }
        return String(format: "%.0f", volume)
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "open":
            return .green
        case "closed":
            return .red
        default:
            return .secondary
        }
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry", action: retryAction)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    MarketsListView()
}

