import Foundation
import Combine
import F90Shared

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

