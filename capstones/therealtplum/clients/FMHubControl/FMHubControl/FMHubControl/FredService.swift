//
//  FredService.swift
//  FMHubControl
//
//  Service for fetching FRED economic releases
//

import Foundation

// MARK: - Service Protocol

protocol FredServiceType {
    func fetchUpcomingReleases(days: Int) async throws -> [EconomicRelease]
}

// MARK: - Default Service Implementation

struct FredService: FredServiceType {
    /// Base URL for the Rust API FRED endpoint.
    /// For local dev, this matches:
    ///   curl http://127.0.0.1:3000/fred/releases/upcoming
    let baseURL: URL
    
    init(baseURL: URL = URL(string: "http://127.0.0.1:3000")!) {
        self.baseURL = baseURL
    }
    
    func fetchUpcomingReleases(days: Int) async throws -> [EconomicRelease] {
        var components = URLComponents(url: baseURL.appendingPathComponent("fred/releases/upcoming"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "days", value: "\(days)")
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // Log error details for debugging
        if !(200..<300).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unable to decode error response"
            print("FRED API error: status=\(httpResponse.statusCode), body=\(errorBody)")
            throw URLError(.badServerResponse)
        }
        
        // Try to decode the response
        do {
            let decoder = JSONDecoder()
            let releases = try decoder.decode([EconomicRelease].self, from: data)
            print("FRED Service: Successfully decoded \(releases.count) releases")
            if let first = releases.first {
                print("FRED Service: First release - \(first.releaseName), daysUntil: \(first.daysUntil)")
            }
            return releases
        } catch {
            // Log the actual response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("FRED Service: Failed to decode response: \(error)")
                print("FRED Service: Response (first 1000 chars): \(responseString.prefix(1000))")
                // If it's an error response from our API, try to extract the error message
                if let errorData = responseString.data(using: .utf8),
                   let errorJson = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
                   let errorMsg = errorJson["error"] as? String {
                    throw NSError(domain: "FredService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                }
            }
            throw error
        }
    }
}

