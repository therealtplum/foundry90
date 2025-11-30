import SwiftUI
import Combine

@MainActor
class KalshiAccountViewModel: ObservableObject {
    @Published var account: KalshiUserAccount?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let service: KalshiServiceType
    private let userId: String
    
    init(userId: String, service: KalshiServiceType? = nil) {
        self.userId = userId
        self.service = service ?? KalshiService()
    }
    
    func loadAccount() async {
        isLoading = true
        errorMessage = nil
        
        do {
            account = try await service.fetchUserAccount(userId: userId)
        } catch {
            errorMessage = "Error loading account: \(error.localizedDescription)"
            account = nil
        }
        
        isLoading = false
    }
    
    func refresh() async {
        // First trigger a refresh on the server, then load
        do {
            let baseURL = URL(string: "http://127.0.0.1:3000")!
            let url = baseURL.appendingPathComponent("kalshi/users/\(userId)/account/refresh")
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                // Refresh failed, but try to load cached data anyway
                await loadAccount()
                return
            }
        } catch {
            // Refresh failed, but try to load cached data anyway
            await loadAccount()
            return
        }
        
        // Then load the updated account
        await loadAccount()
    }
}

struct KalshiAccountView: View {
    let userId: String
    @StateObject private var viewModel: KalshiAccountViewModel
    
    init(userId: String) {
        self.userId = userId
        _viewModel = StateObject(wrappedValue: KalshiAccountViewModel(userId: userId))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if viewModel.isLoading {
                ProgressView()
            } else if let error = viewModel.errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                }
            } else if let account = viewModel.account {
                VStack(alignment: .leading, spacing: 16) {
                    // Balance Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Balance")
                            .font(.headline)
                        
                        HStack {
                            Text("$\(account.balance.balance, specifier: "%.2f")")
                                .font(.system(.title, design: .monospaced))
                                .fontWeight(.bold)
                            Text(account.balance.currency)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Available")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("$\(account.balance.availableBalance, specifier: "%.2f")")
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Pending")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("$\(account.balance.pendingWithdrawals, specifier: "%.2f")")
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Positions Section
                    if !account.positions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Positions")
                                .font(.headline)
                            
                            List(account.positions) { position in
                                PositionRow(position: position)
                            }
                            .frame(height: 200)
                        }
                    } else {
                        VStack {
                            Text("No open positions")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
                .padding()
            } else {
                Text("No account data")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await viewModel.loadAccount()
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    Task {
                        await viewModel.refresh()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
    }
}

struct PositionRow: View {
    let position: KalshiPosition
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(position.ticker)
                    .font(.headline)
                Text(position.position > 0 ? "YES" : "NO")
                    .font(.caption)
                    .foregroundColor(position.position > 0 ? .green : .red)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(position.position)")
                    .font(.system(.body, design: .monospaced))
                Text("Avg: $\(position.averagePrice, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(position.currentPrice, specifier: "%.2f")")
                    .font(.system(.body, design: .monospaced))
                Text("P&L: $\(position.unrealizedPnl, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(position.unrealizedPnl >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }
}

