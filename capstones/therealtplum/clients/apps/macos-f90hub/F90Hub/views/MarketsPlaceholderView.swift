//
//  MarketsPlaceholderView.swift
//  FMHubControl
//
//  Created by Thomas Plummer on 11/25/25.
//


import SwiftUI
import F90Shared

struct MarketsPlaceholderView: View {
    @StateObject private var viewModel = MarketStatusViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @State private var timeUntilOpen: String? = nil
    @State private var countdownTimer: Timer?

    var body: some View {
        ZStack {
            themeManager.backgroundGradient
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                header
                marketStatusIndicator
                assetClassStatuses
                Spacer()
            }
            .padding(24)
        }
        .foregroundColor(themeManager.textColor)
        .onAppear {
            updateCountdown()
            startCountdownTimer()
        }
        .onDisappear {
            countdownTimer?.invalidate()
        }
    }
    
    private func updateCountdown() {
        timeUntilOpen = MarketOpenTimeCalculator.timeUntilMarketOpen()
    }
    
    private func startCountdownTimer() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateCountdown()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Markets")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(themeManager.textColor)
            Text("Market status and research console")
                .font(.subheadline)
                .foregroundColor(themeManager.textSoftColor)
        }
    }
    
    // MARK: - Market Status Indicator
    
    private var marketStatusIndicator: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Market Status")
                    .font(.headline)
                    .foregroundColor(themeManager.textColor)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Toggle("Auto-refresh", isOn: $viewModel.autoRefresh)
                    
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        if viewModel.isLoading {
                            BlackProgressView()
                        } else {
                            Text("Refresh")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.accentColor)
                }
            }
            
            if let status = viewModel.marketStatus {
                HStack(spacing: 16) {
                    // Green/Red indicator circle
                    Circle()
                        .fill(status.isOpen ? Color.green : Color.red)
                        .frame(width: 16, height: 16)
                        .shadow(
                            color: status.isOpen 
                                ? Color.green.opacity(0.5) 
                                : Color.red.opacity(0.5),
                            radius: 6
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(status.statusDisplay)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(themeManager.textColor)
                        
                        if let exchangeStatus = status.primaryExchangeStatus {
                            Text("NYSE/NASDAQ: \(exchangeStatus.capitalized)")
                                .font(.subheadline)
                                .foregroundColor(themeManager.textSoftColor)
                        }
                        
                        if status.afterHours {
                            Text("After Hours")
                                .font(.caption)
                                .foregroundColor(themeManager.textSoftColor)
                        } else if status.earlyHours {
                            Text("Early Hours")
                                .font(.caption)
                                .foregroundColor(themeManager.textSoftColor)
                        }
                        
                        // Countdown timer when market is closed
                        if !status.isOpen, let countdown = timeUntilOpen {
                            Text(countdown)
                                .font(.caption)
                                .foregroundColor(themeManager.accentColor)
                                .padding(.top, 4)
                        }
                    }
                    
                    Spacer()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeManager.panelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.panelBorder, lineWidth: 1)
                )
                .cornerRadius(16)
            } else if viewModel.isLoading {
                HStack(spacing: 12) {
                    ProgressView().controlSize(.small)
                    Text("Loading market status...")
                        .font(.subheadline)
                        .foregroundColor(themeManager.textSoftColor)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeManager.panelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.panelBorder, lineWidth: 1)
                )
                .cornerRadius(16)
            } else if let error = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unable to load market status")
                        .font(.subheadline)
                        .foregroundColor(themeManager.statusDownColor)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(themeManager.textSoftColor)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeManager.panelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.panelBorder, lineWidth: 1)
                )
                .cornerRadius(16)
            }
        }
    }
    
    // MARK: - Asset Class Statuses
    
    private var assetClassStatuses: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Asset Classes")
                .font(.headline)
                .foregroundColor(themeManager.textColor)
            
            if let status = viewModel.marketStatus {
                VStack(spacing: 12) {
                    assetClassRow(
                        name: "Stocks",
                        isOpen: status.isOpen,
                        detail: status.primaryExchangeStatus?.capitalized
                    )
                    
                    if let cryptoStatus = status.currencyCrypto {
                        assetClassRow(
                            name: "Crypto",
                            isOpen: status.isCryptoOpen,
                            detail: cryptoStatus.capitalized
                        )
                    }
                    
                    if let fxStatus = status.currencyFx {
                        assetClassRow(
                            name: "Forex",
                            isOpen: status.isForexOpen,
                            detail: fxStatus.capitalized
                        )
                    }
                    
                    // Indices groups - show only major indices
                    if let indices = status.indicesGroups, !indices.isEmpty {
                        // Filter to show only major, well-known indices
                        let majorIndices = ["dow_jones", "s_and_p", "nasdaq", "ftse_russell", "msci"]
                        let filteredIndices = indices.filter { majorIndices.contains($0.key) }
                        
                        if !filteredIndices.isEmpty {
                            ForEach(Array(filteredIndices.keys.sorted()), id: \.self) { key in
                                if let value = indices[key] {
                                    let displayName = formatIndexName(key)
                                    assetClassRow(
                                        name: displayName,
                                        isOpen: value.lowercased() == "open",
                                        detail: value.capitalized
                                    )
                                }
                            }
                        }
                    }
                }
            } else {
                Text("Loading asset class statuses...")
                    .font(.subheadline)
                    .foregroundColor(themeManager.textSoftColor)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeManager.panelBorder, lineWidth: 1)
        )
        .cornerRadius(16)
    }
    
    private func assetClassRow(name: String, isOpen: Bool, detail: String?) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isOpen ? Color.green : Color.red)
                .frame(width: 10, height: 10)
                .shadow(
                    color: isOpen
                        ? Color.green.opacity(0.5)
                        : Color.red.opacity(0.5),
                    radius: 4
                )
            
            Text(name)
                .font(.subheadline)
                .foregroundColor(themeManager.textColor)
            
            Spacer()
            
            if let detail = detail {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(themeManager.textSoftColor)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatIndexName(_ key: String) -> String {
        switch key {
        case "dow_jones":
            return "Dow Jones"
        case "s_and_p":
            return "S&P 500"
        case "nasdaq":
            return "NASDAQ"
        case "ftse_russell":
            return "FTSE Russell"
        case "msci":
            return "MSCI"
        default:
            return key.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}