//
//  MarketsPlaceholderView.swift
//  FMHubControl
//
//  Created by Thomas Plummer on 11/25/25.
//


import SwiftUI

struct MarketsPlaceholderView: View {
    @StateObject private var viewModel = MarketStatusViewModel()
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack {
            themeManager.backgroundGradient
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                header
                marketStatusIndicator
                Spacer()
            }
            .padding(24)
        }
        .foregroundColor(themeManager.textColor)
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
                        .fill(status.isOpen ? themeManager.statusUpColor : themeManager.statusDownColor)
                        .frame(width: 16, height: 16)
                        .shadow(
                            color: status.isOpen 
                                ? themeManager.statusUpColor.opacity(0.5) 
                                : themeManager.statusDownColor.opacity(0.5),
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
}