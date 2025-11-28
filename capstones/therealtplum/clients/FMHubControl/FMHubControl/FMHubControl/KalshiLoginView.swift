import SwiftUI
import Combine

@MainActor
class KalshiLoginViewModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var apiSecret: String = ""
    @Published var userId: String = ""
    @Published var isLoggingIn = false
    @Published var errorMessage: String?
    @Published var isLoggedIn = false
    
    private let service: KalshiServiceType
    
    init(service: KalshiServiceType = KalshiService()) {
        self.service = service
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

struct KalshiLoginView: View {
    @StateObject private var viewModel = KalshiLoginViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            if viewModel.isLoggedIn {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("Logged in as: \(viewModel.userId)")
                        .font(.headline)
                    
                    Button("Logout") {
                        viewModel.logout()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(spacing: 16) {
                    Text("Kalshi Login")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Enter your Kalshi API credentials")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("User ID", text: $viewModel.userId)
                            .textFieldStyle(.roundedBorder)
                        
                        SecureField("API Key", text: $viewModel.apiKey)
                            .textFieldStyle(.roundedBorder)
                        
                        SecureField("API Secret", text: $viewModel.apiSecret)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal)
                    
                    if let error = viewModel.errorMessage {
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
                            Text("Login")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoggingIn || viewModel.apiKey.isEmpty || viewModel.apiSecret.isEmpty || viewModel.userId.isEmpty)
                    
                    Text("Your credentials are stored locally and encrypted")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
        .frame(maxWidth: 400)
    }
}

