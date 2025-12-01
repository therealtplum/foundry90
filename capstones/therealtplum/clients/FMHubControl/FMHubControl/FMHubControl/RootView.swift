//
//  RootView.swift
//  FMHubControl
//
//  Created by Thomas Plummer on 11/25/25.
//


import SwiftUI

struct RootView: View {
    @StateObject private var themeManager = ThemeManager()
    @State private var selectedTab = 0
    @State private var kalshiUserId: String? = UserDefaults.standard.string(forKey: "kalshi_user_id")
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SystemHealthView()
                .tabItem {
                    Label("Health", systemImage: "heart.text.square")
                }
                .tag(0)

            OperationsView()
                .tabItem {
                    Label("Ops", systemImage: "terminal")
                }
                .tag(1)

            MarketsHubView()
                .tabItem {
                    Label("Markets", systemImage: "chart.xyaxis.line")
                }
                .tag(2)
        }
        .frame(minWidth: 900, minHeight: 600)
        .environmentObject(themeManager)
        .preferredColorScheme(themeManager.currentTheme == .hacker ? .dark : .light)
        .onChange(of: kalshiUserId) {
            // Update when login state changes
        }
    }
}
