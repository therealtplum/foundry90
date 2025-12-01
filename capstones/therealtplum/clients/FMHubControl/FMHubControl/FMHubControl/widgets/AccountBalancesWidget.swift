//
//  AccountBalancesWidget.swift
//  FMHubControl
//
//  Multi-broker account balances widget
//

import SwiftUI
import Combine

struct AccountBalancesWidget: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = AccountBalancesViewModel()
    
    var body: some View {
        BaseWidgetView(
            title: "Account Balances",
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            actions: AnyView(
                Button(action: {
                    Task { await viewModel.refresh() }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundColor(themeManager.textSoftColor)
                .padding(.trailing, 36) // Space for ellipsis button (28px width + 8px spacing)
            )
        ) {
            if viewModel.accounts.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    Text("No accounts connected")
                        .font(.subheadline)
                        .foregroundColor(themeManager.textSoftColor)
                    Button("Connect Account") {
                        // TODO: Show connect account dialog
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    // Total balance
                    if !viewModel.accounts.isEmpty {
                        HStack {
                            Text("Total Balance")
                                .font(.subheadline)
                                .foregroundColor(themeManager.textSoftColor)
                            Spacer()
                            Text(formatBalance(viewModel.totalBalance))
                                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                                .foregroundColor(themeManager.textColor)
                        }
                        .padding(.bottom, 8)
                    }
                    
                    // Account list
                    VStack(spacing: 12) {
                        ForEach(viewModel.accounts) { account in
                            AccountRow(account: account)
                        }
                    }
                }
            }
        }
    }
    
    private func formatBalance(_ balance: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: balance)) ?? "$0.00"
    }
}

// MARK: - View Model

@MainActor
class AccountBalancesViewModel: ObservableObject {
    @Published var accounts: [AccountBalance] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    var totalBalance: Double {
        accounts.filter { $0.status == .connected }.reduce(0) { $0 + $1.balance }
    }
    
    init() {
        Task {
            await loadAccounts()
        }
    }
    
    func loadAccounts() async {
        isLoading = true
        errorMessage = nil
        
        // Load Kalshi account
        var accountsList: [AccountBalance] = []
        
        do {
            let service = KalshiService()
            let account = try await service.fetchUserAccount(userId: "default")
            
            accountsList.append(AccountBalance(
                broker: "Kalshi",
                accountName: "Main Account",
                balance: account.balance.balance,
                currency: account.balance.currency,
                availableBalance: account.balance.availableBalance,
                pendingWithdrawals: account.balance.pendingWithdrawals,
                lastUpdated: Date(),
                status: .connected
            ))
        } catch {
            print("Failed to load Kalshi account: \(error)")
            // Add disconnected Kalshi account
            accountsList.append(AccountBalance(
                broker: "Kalshi",
                accountName: "Main Account",
                balance: 0,
                currency: "USD",
                lastUpdated: Date(),
                status: .disconnected
            ))
        }
        
        // Add placeholder accounts for other brokers
        accountsList.append(contentsOf: [
            AccountBalance(
                broker: "Robinhood",
                accountName: "Trading Account",
                balance: 0,
                currency: "USD",
                lastUpdated: Date(),
                status: .disconnected
            ),
            AccountBalance(
                broker: "Schwab",
                accountName: "Investment Account",
                balance: 0,
                currency: "USD",
                lastUpdated: Date(),
                status: .disconnected
            ),
            AccountBalance(
                broker: "Coinbase",
                accountName: "Crypto Wallet",
                balance: 0,
                currency: "USD",
                lastUpdated: Date(),
                status: .disconnected
            )
        ])
        
        self.accounts = accountsList
        self.isLoading = false
    }
    
    func refresh() async {
        await loadAccounts()
    }
}

// MARK: - Models

struct AccountBalance: Identifiable {
    let id = UUID()
    let broker: String
    let accountName: String
    let balance: Double
    let currency: String
    var availableBalance: Double? = nil
    var pendingWithdrawals: Double? = nil
    let lastUpdated: Date
    let status: AccountStatus
    
    enum AccountStatus {
        case connected
        case disconnected
        case error
        
        var indicator: String {
            switch self {
            case .connected: return "●"
            case .disconnected, .error: return "○"
            }
        }
    }
}

// MARK: - Account Row

struct AccountRow: View {
    let account: AccountBalance
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Broker icon
                Text(brokerIcon(for: account.broker))
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(themeManager.accentColor.opacity(0.2))
                    .foregroundColor(themeManager.accentColor)
                    .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.broker)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(themeManager.textColor)
                    Text(account.accountName)
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.textSoftColor)
                }
                
                Spacer()
                
                Text(account.status.indicator)
                    .font(.system(size: 12))
                    .foregroundColor(
                        account.status == .connected
                            ? Color.green
                            : themeManager.textSoftColor
                    )
            }
            
            if account.status == .connected {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatBalance(account.balance))
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(themeManager.textColor)
                    
                    if let available = account.availableBalance {
                        Text("Available: \(formatBalance(available))")
                            .font(.system(size: 11))
                            .foregroundColor(themeManager.textSoftColor)
                    }
                    
                    Text("Updated \(formatTime(account.lastUpdated))")
                        .font(.system(size: 10))
                        .foregroundColor(themeManager.textSoftColor)
                }
            } else {
                Button("Connect Account") {
                    // TODO: Show connect dialog
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(themeManager.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.panelBorder, lineWidth: 1)
        )
        .cornerRadius(8)
    }
    
    private func brokerIcon(for broker: String) -> String {
        switch broker {
        case "Kalshi": return "K"
        case "Robinhood": return "R"
        case "Schwab": return "S"
        case "Coinbase": return "C"
        default: return "•"
        }
    }
    
    private func formatBalance(_ balance: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = account.currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: balance)) ?? "$0.00"
    }
    
    private func formatTime(_ date: Date) -> String {
        let now = Date()
        let diff = now.timeIntervalSince(date)
        let minutes = Int(diff / 60)
        
        if minutes < 5 {
            return "just now"
        } else if minutes < 60 {
            return "\(minutes)m ago"
        } else {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

