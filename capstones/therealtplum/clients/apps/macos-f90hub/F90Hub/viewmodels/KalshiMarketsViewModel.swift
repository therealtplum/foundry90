import Foundation
import Combine
import F90Shared

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
    
    // Login form fields
    @Published var loginApiKey: String = ""
    @Published var loginApiSecret: String = ""
    @Published var loginUserId: String = ""
    @Published var isLoggingIn = false
    @Published var loginErrorMessage: String?
    
    private let service: KalshiServiceType
    private var currentOffset = 0
    private let pageSize = 50
    
    init(service: KalshiServiceType? = nil) {
        self.service = service ?? KalshiService()
        // For local development, use "default" user ID from .env config
        // Skip login form and use local configuration
        self.userId = "default"
        self.isLoggedIn = true
        Task {
            await loadAccount()
            await loadMarkets()
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
        } catch {
            errorMessage = "Error loading markets: \(error.localizedDescription)"
            markets = []
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadMarkets()
    }
}

