import SwiftUI
import F90Shared

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

