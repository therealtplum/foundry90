//
//  AccountView.swift
//  F90Mobile
//
//  Account view for iPhone showing balance and positions
//

import SwiftUI
import F90Shared

struct AccountView: View {
    @State private var account: KalshiUserAccount?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var userId: String? = UserDefaults.standard.string(forKey: "kalshi_user_id")
    
    private let kalshiService = KalshiService()
    
    var body: some View {
        NavigationStack {
            VStack {
                if userId == nil {
                    LoginPromptView()
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ErrorView(message: error) {
                        loadAccount()
                    }
                } else if let account = account {
                    accountContent(account: account)
                } else {
                    Text("No account data")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Account")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: loadAccount) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                if userId != nil {
                    loadAccount()
                }
            }
            .refreshable {
                if userId != nil {
                    await refreshAccount()
                }
            }
        }
    }
    
    private func accountContent(account: KalshiUserAccount) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Balance Card
                BalanceCard(balance: account.balance)
                
                // Positions Section
                if !account.positions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Positions")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(account.positions) { position in
                            PositionRowView(position: position)
                        }
                    }
                } else {
                    VStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No open positions")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            }
            .padding(.vertical)
        }
    }
    
    private func loadAccount() {
        guard let userId = userId else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedAccount = try await kalshiService.fetchUserAccount(userId: userId)
                await MainActor.run {
                    self.account = fetchedAccount
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
    
    private func refreshAccount() async {
        guard let userId = userId else { return }
        
        do {
            let fetchedAccount = try await kalshiService.fetchUserAccount(userId: userId)
            await MainActor.run {
                self.account = fetchedAccount
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

struct BalanceCard: View {
    let balance: KalshiUserBalance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Balance")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(formatCurrency(balance.balance))
                .font(.system(size: 36, weight: .bold))
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(balance.availableBalance))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Pending")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(balance.pendingWithdrawals))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        String(format: "$%.2f", amount / 100.0)
    }
}

struct PositionRowView: View {
    let position: KalshiPosition
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(position.ticker)
                    .font(.headline)
                
                Spacer()
                
                Text(position.position > 0 ? "YES" : "NO")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(position.position > 0 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                    .foregroundColor(position.position > 0 ? .green : .red)
                    .cornerRadius(6)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Avg Price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatPrice(position.averagePrice))
                        .font(.subheadline)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Current Price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatPrice(position.currentPrice))
                        .font(.subheadline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("P&L")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(position.unrealizedPnl))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(position.unrealizedPnl >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private func formatPrice(_ price: Double) -> String {
        String(format: "%.2f¢", price * 100)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let sign = amount >= 0 ? "+" : ""
        return String(format: "%@$%.2f", sign, amount / 100.0)
    }
}

struct LoginPromptView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("Not Logged In")
                .font(.headline)
            
            Text("Please log in through Settings to view your account")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

#Preview {
    AccountView()
}

