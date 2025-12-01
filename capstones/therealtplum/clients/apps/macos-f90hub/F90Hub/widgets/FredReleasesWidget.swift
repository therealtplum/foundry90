//
//  FredReleasesWidget.swift
//  FMHubControl
//
//  Widget displaying upcoming FRED economic releases
//

import SwiftUI
import Combine
import F90Shared

@MainActor
class FredReleasesViewModel: ObservableObject {
    @Published var releases: [EconomicRelease] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let service: FredServiceType
    
    init(service: FredServiceType? = nil) {
        self.service = service ?? FredService()
    }
    
    func loadReleases() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetched = try await service.fetchUpcomingReleases(days: 30)
            print("FRED: Fetched \(fetched.count) releases")
            // Sort by days_until ascending (most recent first)
            releases = fetched.sorted { $0.daysUntil < $1.daysUntil }
            print("FRED: Displaying \(releases.count) releases after sorting")
        } catch let error as URLError {
            print("FRED: URLError - \(error.localizedDescription)")
            // Provide more specific error messages
            switch error.code {
            case .badServerResponse:
                errorMessage = "Server error. Make sure the Rust API is running on port 3000."
            case .notConnectedToInternet:
                errorMessage = "No internet connection."
            case .timedOut:
                errorMessage = "Request timed out."
            case .cannotFindHost:
                errorMessage = "Cannot connect to API server. Is it running?"
            default:
                errorMessage = "Network error: \(error.localizedDescription)"
            }
            releases = []
        } catch {
            print("FRED: Error loading releases - \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                print("FRED: Decoding error details: \(decodingError)")
            }
            errorMessage = "Error: \(error.localizedDescription)"
            releases = []
        }
        
        isLoading = false
    }
}

struct FredReleasesWidget: View {
    @StateObject private var viewModel = FredReleasesViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        BaseWidgetView(
            title: "Economic Releases",
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage
        ) {
            if !viewModel.releases.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.releases) { release in
                            ReleaseRow(release: release)
                                .id("\(release.releaseId)-\(release.releaseDate)")
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: 500)
            } else if !viewModel.isLoading {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 32))
                        .foregroundColor(themeManager.textSoftColor)
                    Text("No upcoming releases")
                        .font(.subheadline)
                        .foregroundColor(themeManager.textSoftColor)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
            }
        }
        .task {
            await viewModel.loadReleases()
        }
    }
}

struct ReleaseRow: View {
    let release: EconomicRelease
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(release.releaseName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(themeManager.textColor)
                    .lineLimit(2)
                
                Spacer()
                
                Text(release.daysUntilText)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(daysColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(daysColor.opacity(0.15))
                    .cornerRadius(6)
            }
            
            Text(release.formattedDate)
                .font(.system(size: 11))
                .foregroundColor(themeManager.textSoftColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(themeManager.panelBackground)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(themeManager.panelBorder, lineWidth: 1)
        )
    }
    
    private var daysColor: Color {
        if release.daysUntil == 0 {
            return .orange
        } else if release.daysUntil <= 3 {
            return .yellow
        } else if release.daysUntil <= 7 {
            return .blue
        } else {
            return themeManager.textSoftColor
        }
    }
}

