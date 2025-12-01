//
//  ThemeManager.swift
//  FMHubControl
//
//  Created by Thomas Plummer on 11/25/25.
//

import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

public enum AppTheme: String, CaseIterable {
    case hacker
    case kawaii
    
    public var displayName: String {
        switch self {
        case .hacker: return "Hacker"
        case .kawaii: return "Kawaii"
        }
    }
}

public class ThemeManager: ObservableObject {
    @Published public var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "appTheme")
            Task { @MainActor in
                applyTheme()
            }
        }
    }
    
    // MARK: - Hacker Theme Colors (matching website)
    struct HackerTheme {
        static let bg = Color(red: 0.02, green: 0.02, blue: 0.03) // #050608
        static let bgSoft = Color(red: 0.04, green: 0.06, blue: 0.08) // #0b0f14
        static let bgSofter = Color(red: 0.06, green: 0.08, blue: 0.11) // #0f141b
        
        static let border = Color(red: 0.11, green: 0.14, blue: 0.18) // #1b232e
        static let borderSoft = Color(red: 0.08, green: 0.11, blue: 0.14) // #151b23
        
        static let text = Color(red: 0.90, green: 0.94, blue: 1.0) // #e5f0ff
        static let textSoft = Color(red: 0.55, green: 0.61, blue: 0.70) // #8b9bb3
        static let textTerminal = Color(red: 0.65, green: 0.95, blue: 0.77) // #a7f3c5
        
        static let accent = Color(red: 0.26, green: 1.0, blue: 0.54) // #43ff8a - primary neon green
        static let accentSoft = Color(red: 0.26, green: 1.0, blue: 0.54).opacity(0.12)
        static let accentMint = Color(red: 0.65, green: 0.95, blue: 0.77) // #a7f3c5
        static let accentEmerald = Color(red: 0.06, green: 0.73, blue: 0.51) // #10b981
        
        static let downBorder = Color(red: 0.97, green: 0.44, blue: 0.44).opacity(0.9)
        static let downBg = Color(red: 0.94, green: 0.27, blue: 0.27).opacity(0.2)
        static let downText = Color(red: 1.0, green: 0.79, blue: 0.79) // #fecaca
        
        // Background gradient
        static func backgroundGradient() -> LinearGradient {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.09, blue: 0.15), // #101726
                    Color(red: 0.02, green: 0.02, blue: 0.03), // #050608
                    Color(red: 0.02, green: 0.02, blue: 0.03).opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Kawaii Theme Colors (matching website)
    struct KawaiiTheme {
        static let bg = Color(red: 1.0, green: 0.96, blue: 0.98) // #fff5fb
        static let bgSoft = Color(red: 1.0, green: 0.89, blue: 0.95) // #ffe4f2
        static let bgSofter = Color(red: 1.0, green: 0.84, blue: 0.93) // #ffd6ec
        
        static let border = Color(red: 1.0, green: 0.72, blue: 0.84) // #ffb7d5
        static let borderSoft = Color(red: 1.0, green: 0.79, blue: 0.88) // #ffc9e1
        
        static let text = Color(red: 0.23, green: 0.12, blue: 0.17) // #3b1f2b
        static let textSoft = Color(red: 0.48, green: 0.29, blue: 0.38) // #7b4b62
        
        static let accent = Color(red: 1.0, green: 0.31, blue: 0.64) // #ff4fa3
        static let accentSoft = Color(red: 1.0, green: 0.31, blue: 0.64).opacity(0.14)
        
        // Background gradient
        static func backgroundGradient() -> LinearGradient {
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.91, blue: 0.96), // #ffe7f6
                    Color(red: 1.0, green: 0.96, blue: 0.98), // #fff5fb
                    Color(red: 1.0, green: 0.88, blue: 0.95) // #ffe0f2
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Computed Theme Colors
    public var backgroundColor: Color {
        currentTheme == .hacker ? HackerTheme.bg : KawaiiTheme.bg
    }
    
    public var backgroundGradient: LinearGradient {
        currentTheme == .hacker ? HackerTheme.backgroundGradient() : KawaiiTheme.backgroundGradient()
    }
    
    public var textColor: Color {
        currentTheme == .hacker ? HackerTheme.text : KawaiiTheme.text
    }
    
    public var textSoftColor: Color {
        currentTheme == .hacker ? HackerTheme.textSoft : KawaiiTheme.textSoft
    }
    
    public var accentColor: Color {
        currentTheme == .hacker ? HackerTheme.accent : KawaiiTheme.accent
    }
    
    public var accentSoftColor: Color {
        currentTheme == .hacker ? HackerTheme.accentSoft : KawaiiTheme.accentSoft
    }
    
    public var borderColor: Color {
        currentTheme == .hacker ? HackerTheme.border : KawaiiTheme.border
    }
    
    public var panelBackground: Color {
        currentTheme == .hacker 
            ? Color.white.opacity(0.03) 
            : Color.white.opacity(0.4)
    }
    
    public var panelBorder: Color {
        currentTheme == .hacker 
            ? Color.white.opacity(0.05) 
            : Color.white.opacity(0.3)
    }
    
    public var statusUpColor: Color {
        currentTheme == .hacker ? HackerTheme.accent : KawaiiTheme.accent
    }
    
    public var statusDownColor: Color {
        currentTheme == .hacker ? HackerTheme.downText : Color.red
    }
    
    public init() {
        let saved = UserDefaults.standard.string(forKey: "appTheme") ?? "hacker"
        self.currentTheme = AppTheme(rawValue: saved) ?? .hacker
        Task { @MainActor in
            applyTheme()
        }
    }
    
    @MainActor
    public func toggleTheme() {
        currentTheme = currentTheme == .hacker ? .kawaii : .hacker
    }
    
    @MainActor
    private func applyTheme() {
        // Update app icon based on theme
        updateAppIcon()
    }
    
    @MainActor
    private func updateAppIcon() {
        // On macOS, we can change the app icon dynamically using NSApplication
        // The icon files would need to be added to the Assets catalog or bundle
        // For now, we store the preference and attempt to set it
        
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "preferredIconTheme")
        
        // Try to load icon from Assets or bundle
        // If separate theme icons exist, they should be named:
        // - AppIcon-Hacker.icns or AppIcon-Hacker (in Assets)
        // - AppIcon-Kawaii.icns or AppIcon-Kawaii (in Assets)
        
        // Attempt 1: Try loading from Assets (if separate icon sets exist)
        // This would require adding separate AppIcon sets in Assets.xcassets
        
        // Attempt 2: Try loading from bundle resources (macOS only)
        #if os(macOS)
        let iconName = currentTheme == .hacker ? "AppIcon-Hacker" : "AppIcon-Kawaii"
        
        if let iconPath = Bundle.main.path(forResource: iconName, ofType: "icns"),
           let iconImage = NSImage(contentsOfFile: iconPath) {
            NSApplication.shared.applicationIconImage = iconImage
            return
        }
        #endif
        
        // Attempt 3: Try to modify the existing icon programmatically
        // For a production app, you'd want to have separate icon assets
        // For now, we'll use the default icon but store the preference
        // The actual icon switching can be implemented when separate icon assets are added
    }
}

