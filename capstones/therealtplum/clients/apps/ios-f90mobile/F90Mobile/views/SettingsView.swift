//
//  SettingsView.swift
//  F90Mobile
//
//  Settings view for iPhone
//

import SwiftUI
import F90Shared

struct SettingsView: View {
    @State private var userId: String? = UserDefaults.standard.string(forKey: "kalshi_user_id")
    @State private var apiKey: String = ""
    @State private var apiSecret: String = ""
    @State private var isLoggedIn: Bool = false
    @State private var showingLoginSheet = false
    @State private var showingLogoutAlert = false
    
    private let kalshiService = KalshiService()
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let userId = userId {
                        HStack {
                            Text("User ID")
                            Spacer()
                            Text(userId)
                                .foregroundColor(.secondary)
                        }
                        
                        Button(role: .destructive, action: {
                            showingLogoutAlert = true
                        }) {
                            Text("Log Out")
                        }
                    } else {
                        Button(action: {
                            showingLoginSheet = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.key")
                                Text("Log In")
                            }
                        }
                    }
                } header: {
                    Text("Account")
                }
                
                Section {
                    HStack {
                        Text("API Base URL")
                        Spacer()
                        Text(kalshiService.baseURL.absoluteString)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                } header: {
                    Text("Configuration")
                }
                
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingLoginSheet) {
                LoginView(isPresented: $showingLoginSheet)
            }
            .alert("Log Out", isPresented: $showingLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    logout()
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
    }
    
    private func logout() {
        UserDefaults.standard.removeObject(forKey: "kalshi_user_id")
        userId = nil
        isLoggedIn = false
    }
}

struct LoginView: View {
    @Binding var isPresented: Bool
    @State private var userId: String = ""
    @State private var apiKey: String = ""
    @State private var apiSecret: String = ""
    @State private var isLoggingIn = false
    @State private var errorMessage: String?
    
    private let kalshiService = KalshiService()
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("User ID", text: $userId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    SecureField("API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    SecureField("API Secret", text: $apiSecret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Kalshi Credentials")
                } footer: {
                    Text("Enter your Kalshi API credentials to access your account.")
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Log In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log In") {
                        login()
                    }
                    .disabled(userId.isEmpty || apiKey.isEmpty || apiSecret.isEmpty || isLoggingIn)
                }
            }
            .overlay {
                if isLoggingIn {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }
    
    private func login() {
        guard !userId.isEmpty, !apiKey.isEmpty, !apiSecret.isEmpty else { return }
        
        isLoggingIn = true
        errorMessage = nil
        
        Task {
            do {
                let success = try await kalshiService.storeCredentials(
                    userId: userId,
                    apiKey: apiKey,
                    apiSecret: apiSecret
                )
                
                if success {
                    await MainActor.run {
                        UserDefaults.standard.set(userId, forKey: "kalshi_user_id")
                        isPresented = false
                    }
                } else {
                    await MainActor.run {
                        errorMessage = "Failed to store credentials"
                        isLoggingIn = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoggingIn = false
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}

