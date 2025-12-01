//
//  MarketDetailView.swift
//  F90Mobile
//
//  Detailed market view for iPhone
//

import SwiftUI
import F90Shared

struct MarketDetailView: View {
    let market: KalshiMarketSummary
    @State private var marketDetail: KalshiMarketDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let kalshiService = KalshiService()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if let error = errorMessage {
                    ErrorView(message: error) {
                        loadMarketDetail()
                    }
                } else if let detail = marketDetail {
                    marketDetailContent(detail: detail)
                } else {
                    marketSummaryContent
                }
            }
            .padding()
        }
        .navigationTitle(market.displayName)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadMarketDetail()
        }
    }
    
    private var marketSummaryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(market.name)
                .font(.title2)
                .fontWeight(.bold)
            
            if let yesPrice = market.yesPrice {
                HStack {
                    Text("Yes Price:")
                        .font(.headline)
                    Spacer()
                    Text(formatPrice(yesPrice))
                        .font(.title)
                        .foregroundColor(.green)
                }
            }
            
            if let volume = market.volume {
                HStack {
                    Text("Volume:")
                        .font(.headline)
                    Spacer()
                    Text(formatVolume(volume))
                }
            }
            
            Divider()
            
            HStack {
                Text("Status:")
                    .font(.headline)
                Spacer()
                Text(market.status.capitalized)
                    .foregroundColor(statusColor(market.status))
            }
            
            if let category = market.category {
                HStack {
                    Text("Category:")
                        .font(.headline)
                    Spacer()
                    Text(category)
                }
            }
        }
    }
    
    private func marketDetailContent(detail: KalshiMarketDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(detail.name)
                .font(.title2)
                .fontWeight(.bold)
            
            if let yesPrice = detail.yesPrice {
                HStack {
                    Text("Yes Price:")
                        .font(.headline)
                    Spacer()
                    Text(formatPrice(yesPrice))
                        .font(.title)
                        .foregroundColor(.green)
                }
            }
            
            if let noPrice = detail.noPrice {
                HStack {
                    Text("No Price:")
                        .font(.headline)
                    Spacer()
                    Text(formatPrice(noPrice))
                        .font(.title)
                        .foregroundColor(.red)
                }
            }
            
            if let volume = detail.volume {
                HStack {
                    Text("Volume:")
                        .font(.headline)
                    Spacer()
                    Text(formatVolume(volume))
                }
            }
            
            Divider()
            
            HStack {
                Text("Status:")
                    .font(.headline)
                Spacer()
                Text(detail.status.capitalized)
                    .foregroundColor(statusColor(detail.status))
            }
            
            HStack {
                Text("Asset Class:")
                    .font(.headline)
                Spacer()
                Text(detail.assetClass)
            }
            
            if let lastUpdated = detail.lastUpdated {
                HStack {
                    Text("Last Updated:")
                        .font(.headline)
                    Spacer()
                    Text(formatDate(lastUpdated))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func loadMarketDetail() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let detail = try await kalshiService.fetchMarket(ticker: market.ticker)
                await MainActor.run {
                    self.marketDetail = detail
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
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
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

#Preview {
    // Preview disabled - KalshiMarketSummary requires JSON decoding
    // To test, use a real market from the API
    NavigationStack {
        Text("Market Detail Preview")
            .navigationTitle("Market Detail")
    }
}

