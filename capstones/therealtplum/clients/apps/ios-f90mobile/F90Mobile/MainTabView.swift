//
//  MainTabView.swift
//  F90Mobile
//
//  Main tab-based navigation for iPhone
//

import SwiftUI
import F90Shared

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var userId: String? = UserDefaults.standard.string(forKey: "kalshi_user_id")
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MarketsListView()
                .tabItem {
                    Label("Markets", systemImage: "chart.xyaxis.line")
                }
                .tag(0)
            
            AccountView()
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
    }
}

#Preview {
    MainTabView()
}

