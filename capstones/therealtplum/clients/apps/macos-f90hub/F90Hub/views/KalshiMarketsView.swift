import SwiftUI
import F90Shared

struct KalshiMarketsView: View {
    @StateObject private var viewModel = KalshiMarketsViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        // Always show markets view when using local config
        // Login view is skipped for local development
        marketsView
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Markets")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(themeManager.textColor)
            Text("Kalshi prediction markets · research console")
                .font(.caption)
                .foregroundColor(themeManager.textSoftColor)
        }
    }
    
    private var loginView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Kalshi Markets")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Sign in with your Kalshi API credentials to explore markets")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text("You'll need your API Key ID and RSA Private Key from Kalshi")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    TextField("User ID", text: $viewModel.loginUserId)
                        .textFieldStyle(.roundedBorder)
                    
                    SecureField("API Key ID", text: $viewModel.loginApiKey)
                        .textFieldStyle(.roundedBorder)
                    
                    SecureField("RSA Private Key", text: $viewModel.loginApiSecret)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 40)
                
                if let error = viewModel.loginErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                Button(action: {
                    Task {
                        await viewModel.login()
                    }
                }) {
                    if viewModel.isLoggingIn {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("Sign In")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoggingIn || viewModel.loginApiKey.isEmpty || viewModel.loginApiSecret.isEmpty || viewModel.loginUserId.isEmpty)
                
                VStack(spacing: 4) {
                    Text("Need API keys?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Link("Get them from your Kalshi account settings", destination: URL(string: "https://kalshi.com/trade-api")!)
                        .font(.caption)
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var marketsView: some View {
        ZStack {
            themeManager.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    
                    // Market Status Section (Traditional + Kalshi)
                    // Note: marketStatus properties may not be available in all versions
                    // Commented out until viewModel is updated with these properties
                    /*
                    VStack(spacing: 0) {
                        HStack(spacing: 16) {
                        // Traditional Market Status (NYSE/NASDAQ)
                        if let status = viewModel.marketStatus {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(status.isOpen ? Color.green : Color.red)
                                    .frame(width: 10, height: 10)
                                    .shadow(
                                        color: status.isOpen ? Color.green.opacity(0.5) : Color.red.opacity(0.5),
                                        radius: 3
                                    )
                                
                                Text("NYSE/NASDAQ: \(status.statusDisplay)")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        } else if viewModel.marketStatusLoading {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Loading...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Kalshi Market Status
                        if viewModel.kalshiTotalMarkets > 0 {
                            Divider()
                                .frame(height: 16)
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(viewModel.kalshiActiveMarkets > 0 ? Color.blue : Color.gray)
                                    .frame(width: 8, height: 8)
                                
                                Text("Kalshi: \(viewModel.kalshiActiveMarkets)/\(viewModel.kalshiTotalMarkets) active")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    */
                    
                    // Header with account info
                    HStack {
                        if let account = viewModel.account {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Balance")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("$\(account.balance.balance, specifier: "%.2f")")
                                        .font(.system(.headline, design: .monospaced))
                                        .fontWeight(.semibold)
                                }
                                
                                if !account.positions.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Positions")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("\(account.positions.count)")
                                            .font(.system(.headline, design: .monospaced))
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Show local config indicator
                        HStack(spacing: 4) {
                            Image(systemName: "gear")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Using local configuration")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // Search and filters
                    VStack(spacing: 12) {
                        HStack {
                            TextField("Search markets...", text: $viewModel.searchText)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    Task {
                                        await viewModel.loadMarkets()
                                    }
                                }
                            
                            Button(action: {
                                Task {
                                    await viewModel.loadMarkets()
                                }
                            }) {
                                Image(systemName: "magnifyingglass")
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        HStack {
                            Picker("Status", selection: $viewModel.selectedStatus) {
                                Text("Active").tag("active")
                                Text("All").tag("")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 120)
                            
                            Spacer()
                            
                            Button("Refresh") {
                                Task {
                                    await viewModel.refresh()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // Markets list
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.errorMessage {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            Text(error)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.markets.isEmpty {
                        VStack {
                            Text("No markets found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Markets will appear here once they're loaded from Kalshi")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(viewModel.markets) { market in
                            MarketRow(market: market)
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundColor(themeManager.textColor)
        .task {
            // Always load markets when view appears (using local config)
            await viewModel.loadMarkets()
        }
    }
}

struct MarketRow: View {
    let market: KalshiMarketSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(market.displayName)
                    .font(.headline)
                Spacer()
                if let price = market.yesPrice {
                    Text("\(Int(price))%")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.blue)
                }
            }
            
            HStack {
                if let category = market.category {
                    Text(category)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Text(market.ticker)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let volume = market.volume {
                    Text("Vol: \(Int(volume))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

