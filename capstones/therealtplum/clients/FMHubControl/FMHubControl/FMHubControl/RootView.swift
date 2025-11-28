//
//  RootView.swift
//  FMHubControl
//
//  Created by Thomas Plummer on 11/25/25.
//


import SwiftUI

struct RootView: View {
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

            KalshiMarketsView()
                .tabItem {
                    Label("Kalshi Markets", systemImage: "chart.xyaxis.line")
                }
                .tag(2)
        }
        .frame(minWidth: 900, minHeight: 600)
        .onChange(of: kalshiUserId) {
            // Update when login state changes
        }
    }
}