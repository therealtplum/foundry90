import SwiftUI
import Combine

@MainActor
class KalshiMarketsViewModel: ObservableObject {
    @Published var markets: [KalshiMarketSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText: String = ""
    @Published var selectedCategory: String? = nil
    @Published var selectedStatus: String = "active"
    
    // Login state
    @Published var isLoggedIn = false
    @Published var userId: String? = nil
    @Published var account: KalshiUserAccount? = nil
    
    // Market status (traditional markets)
    @Published var marketStatus: MarketStatus?
    @Published var marketStatusLoading = false
    @Published var marketStatusError: String?
    @Published var autoRefreshMarketStatus = true
    
    // Kalshi market status (aggregate)
    @Published var kalshiActiveMarkets: Int = 0
    @Published var kalshiTotalMarkets: Int = 0
    
    // Login form fields
    @Published var loginApiKey: String = ""
    @Published var loginApiSecret: String = ""
    @Published var loginUserId: String = ""
    @Published var isLoggingIn = false
    @Published var loginErrorMessage: String?
    
    private let service: KalshiServiceType
    private let marketStatusService: MarketStatusServiceType
    private var currentOffset = 0
    private let pageSize = 50
    
    init(service: KalshiServiceType? = nil, marketStatusService: MarketStatusServiceType? = nil) {
        self.service = service ?? KalshiService()
        self.marketStatusService = marketStatusService ?? MarketStatusService()
        // For local development, use "default" user ID from .env config
        // Skip login form and use local configuration
        self.userId = "default"
        self.isLoggedIn = true
        Task {
            await loadAccount()
            await loadMarkets()
            await loadMarketStatus()
            updateKalshiMarketStatus()
            startMarketStatusAutoRefresh()
        }
    }
    
    private func checkStoredCredentials() {
        // Check UserDefaults for stored credentials (not used when using local config)
        if let userId = UserDefaults.standard.string(forKey: "kalshi_user_id"),
           let _ = UserDefaults.standard.data(forKey: "kalshi_credentials_\(userId)") {
            self.userId = userId
            self.isLoggedIn = true
            Task {
                await loadAccount()
            }
        }
    }
    
    func login() async {
        guard !loginApiKey.isEmpty && !loginApiSecret.isEmpty else {
            loginErrorMessage = "Please enter both API key and secret"
            return
        }
        
        guard !loginUserId.isEmpty else {
            loginErrorMessage = "Please enter a user ID"
            return
        }
        
        isLoggingIn = true
        loginErrorMessage = nil
        
        do {
            let success = try await service.storeCredentials(
                userId: loginUserId,
                apiKey: loginApiKey,
                apiSecret: loginApiSecret
            )
            
            if success {
                UserDefaults.standard.set(loginUserId, forKey: "kalshi_user_id")
                userId = loginUserId
                isLoggedIn = true
                // Clear sensitive fields
                loginApiKey = ""
                loginApiSecret = ""
                loginUserId = ""
                
                // Load account and markets
                await loadAccount()
                await loadMarkets()
            } else {
                loginErrorMessage = "Failed to store credentials"
            }
        } catch {
            loginErrorMessage = "Error: \(error.localizedDescription)"
        }
        
        isLoggingIn = false
    }
    
    func logout() {
        if let userId = userId {
            UserDefaults.standard.removeObject(forKey: "kalshi_credentials_\(userId)")
        }
        UserDefaults.standard.removeObject(forKey: "kalshi_user_id")
        isLoggedIn = false
        userId = nil
        account = nil
        markets = []
        loginApiKey = ""
        loginApiSecret = ""
        loginUserId = ""
    }
    
    func loadAccount() async {
        guard let userId = userId else { return }
        
        do {
            account = try await service.fetchUserAccount(userId: userId)
        } catch {
            // Silently fail - account loading is optional
            print("Failed to load account: \(error)")
        }
    }
    
    func loadMarkets() async {
        isLoading = true
        errorMessage = nil
        currentOffset = 0
        
        do {
            let results = try await service.fetchMarkets(
                category: selectedCategory,
                status: selectedStatus,
                limit: pageSize,
                offset: currentOffset,
                search: searchText.isEmpty ? nil : searchText
            )
            markets = results
            updateKalshiMarketStatus()
        } catch {
            errorMessage = "Error loading markets: \(error.localizedDescription)"
            markets = []
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadMarkets()
        updateKalshiMarketStatus()
    }
    
    private func updateKalshiMarketStatus() {
        kalshiTotalMarkets = markets.count
        kalshiActiveMarkets = markets.filter { $0.status.lowercased() == "active" }.count
    }
    
    func loadMarketStatus() async {
        marketStatusLoading = true
        marketStatusError = nil
        
        do {
            let status = try await marketStatusService.fetchMarketStatus()
            self.marketStatus = status
        } catch {
            self.marketStatus = nil
            self.marketStatusError = error.localizedDescription
        }
        
        marketStatusLoading = false
    }
    
    private func startMarketStatusAutoRefresh() {
        Task { [weak self] in
            while let self = self {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000) // 60 seconds
                guard self.autoRefreshMarketStatus else { continue }
                await self.loadMarketStatus()
            }
        }
    }
}

struct KalshiMarketsView: View {
    @StateObject private var viewModel = KalshiMarketsViewModel()
    
    var body: some View {
        // Always show markets view when using local config
        // Login view is skipped for local development
        marketsView
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
        VStack(spacing: 0) {
            // Market Status Section (Traditional + Kalshi)
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

