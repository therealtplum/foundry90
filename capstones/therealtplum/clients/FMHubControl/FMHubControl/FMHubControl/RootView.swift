//
//  RootView.swift
//  FMHubControl
//
//  Created by Thomas Plummer on 11/25/25.
//


import SwiftUI

struct RootView: View {
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

            MarketsPlaceholderView()
                .tabItem {
                    Label("Markets", systemImage: "chart.xyaxis.line")
                }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}