//
//  RootView.swift
//  FMHubControl
//
//  Created by Thomas Plummer on 11/25/25.
//


import SwiftUI

struct RootView: View {
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        TabView {
            SystemHealthView()
                .tabItem {
                    Label("Health", systemImage: "heart.text.square")
                }

            OperationsView()
                .tabItem {
                    Label("Ops", systemImage: "terminal")
                }

            KalshiMarketsView()
                .tabItem {
                    Label("Markets", systemImage: "chart.xyaxis.line")
                }
        }
        .frame(minWidth: 900, minHeight: 600)
        .environmentObject(themeManager)
        .preferredColorScheme(themeManager.currentTheme == .hacker ? .dark : .light)
    }
}
