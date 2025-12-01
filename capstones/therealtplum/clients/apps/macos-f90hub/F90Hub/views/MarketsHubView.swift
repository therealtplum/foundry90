//
//  MarketsHubView.swift
//  FMHubControl
//
//  Markets Hub - Main dashboard view combining market status and Kalshi markets
//

import SwiftUI
import F90Shared

struct MarketsHubView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedSection: MarketsSection = .overview
    
    enum MarketsSection: String, CaseIterable {
        case overview = "Overview"
        case kalshi = "Kalshi Markets"
        
        var icon: String {
            switch self {
            case .overview:
                return "chart.line.uptrend.xyaxis"
            case .kalshi:
                return "chart.xyaxis.line"
            }
        }
    }
    
    var body: some View {
        ZStack {
            themeManager.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with section selector
                header
                
                Divider()
                
                // Content area
                contentView
            }
        }
        .foregroundColor(themeManager.textColor)
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Markets Hub")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(themeManager.textColor)
                    Text("Market status and Kalshi markets console")
                        .font(.subheadline)
                        .foregroundColor(themeManager.textSoftColor)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            
            // Section selector
            HStack(spacing: 12) {
                ForEach(MarketsSection.allCases, id: \.self) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: section.icon)
                                .font(.system(size: 14))
                            Text(section.rawValue)
                                .font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selectedSection == section
                                ? themeManager.accentColor.opacity(0.2)
                                : themeManager.panelBackground
                        )
                        .foregroundColor(
                            selectedSection == section
                                ? themeManager.accentColor
                                : themeManager.textColor
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    selectedSection == section
                                        ? themeManager.accentColor
                                        : themeManager.panelBorder,
                                    lineWidth: selectedSection == section ? 2 : 1
                                )
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        Group {
            switch selectedSection {
            case .overview:
                MarketsHubOverviewView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .kalshi:
                KalshiMarketsView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
