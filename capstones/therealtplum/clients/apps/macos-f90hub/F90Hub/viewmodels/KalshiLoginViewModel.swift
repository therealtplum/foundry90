import Foundation
import Combine
import F90Shared

@MainActor
class KalshiLoginViewModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var apiSecret: String = ""
    @Published var userId: String = ""
    @Published var isLoggingIn = false
    @Published var errorMessage: String?
    @Published var isLoggedIn = false
    
    private let service: KalshiServiceType
    
    init(service: KalshiServiceType? = nil) {
        self.service = service ?? KalshiService()
        // Check if credentials are already stored
        checkStoredCredentials()
    }
    
    private func checkStoredCredentials() {
        // Check UserDefaults for stored credentials
        if let userId = UserDefaults.standard.string(forKey: "kalshi_user_id"),
           let _ = UserDefaults.standard.data(forKey: "kalshi_credentials_\(userId)") {
            self.userId = userId
            self.isLoggedIn = true
        }
    }
    
    func login() async {
        guard !apiKey.isEmpty && !apiSecret.isEmpty else {
            errorMessage = "Please enter both API key and secret"
            return
        }
        
        guard !userId.isEmpty else {
            errorMessage = "Please enter a user ID"
            return
        }
        
        isLoggingIn = true
        errorMessage = nil
        
        do {
            let success = try await service.storeCredentials(
                userId: userId,
                apiKey: apiKey,
                apiSecret: apiSecret
            )
            
            if success {
                UserDefaults.standard.set(userId, forKey: "kalshi_user_id")
                isLoggedIn = true
                // Clear sensitive fields
                apiKey = ""
                apiSecret = ""
            } else {
                errorMessage = "Failed to store credentials"
            }
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
        }
        
        isLoggingIn = false
    }
    
    func logout() {
        if let userId = UserDefaults.standard.string(forKey: "kalshi_user_id") {
            UserDefaults.standard.removeObject(forKey: "kalshi_credentials_\(userId)")
        }
        UserDefaults.standard.removeObject(forKey: "kalshi_user_id")
        isLoggedIn = false
        userId = ""
        apiKey = ""
        apiSecret = ""
    }
}

