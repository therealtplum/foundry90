//
//  MarketStatusWidget.swift
//  FMHubControl
//
//  Market status widget showing market open/close status
//

import SwiftUI

struct MarketStatusWidget: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = MarketStatusViewModel()
    @State private var timeUntilOpen: String? = nil
    @State private var countdownTimer: Timer?
    
    var body: some View {
        BaseWidgetView(
            title: "Market Status",
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            actions: AnyView(
                Button(action: {
                    Task { await viewModel.refresh() }
                }) {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(themeManager.textSoftColor)
                .padding(.trailing, 36) // Space for ellipsis button (28px width + 8px spacing)
            )
        ) {
            if let status = viewModel.marketStatus {
                VStack(alignment: .leading, spacing: 16) {
                    // Main status indicator
                    HStack(spacing: 16) {
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
                    .padding(12)
                    .background(themeManager.panelBackground)
                    .cornerRadius(8)
                    
                    // Asset class statuses
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Asset Classes")
                            .font(.headline)
                            .foregroundColor(themeManager.textColor)
                        
                        VStack(spacing: 8) {
                            assetClassRow(
                                name: "US Equities",
                                isOpen: status.isOpen,
                                detail: status.primaryExchangeStatus?.capitalized
                            )
                            
                            assetClassRow(
                                name: "US Options",
                                isOpen: status.isOptionsOpen,
                                detail: status.optionsStatus?.capitalized ?? (status.isOptionsOpen ? "Open" : "Closed")
                            )
                            
                            assetClassRow(
                                name: "Kalshi",
                                isOpen: status.isKalshiOpen,
                                detail: status.kalshiStatus?.capitalized ?? (status.isKalshiOpen ? "Active" : "Inactive")
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
                        }
                    }
                }
            }
        }
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
}

