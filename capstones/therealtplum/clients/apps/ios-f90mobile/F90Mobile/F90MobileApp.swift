//
//  F90MobileApp.swift
//  F90Mobile
//
//  Created by Thomas Plummer on 12/1/25.
//

import SwiftUI
import F90Shared

@main
struct F90MobileApp: App {
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ComingSoonView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.currentTheme == .hacker ? .dark : .light)
        }
    }
}
