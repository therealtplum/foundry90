//
//  ComingSoonView.swift
//  F90Mobile
//
//  Created by Thomas Plummer on 11/25/25.
//

import SwiftUI
import F90Shared

struct ComingSoonView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showTypewriter = false
    
    var body: some View {
        ZStack {
            // Background gradient
            themeManager.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Main content
                VStack(spacing: 32) {
                    // Logo pill
                    HStack(spacing: 12) {
                        Text("90")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(themeManager.accentColor)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 999)
                                    .fill(themeManager.currentTheme == .hacker 
                                          ? Color(red: 0.02, green: 0.16, blue: 0.06).opacity(0.9)
                                          : Color(red: 1.0, green: 0.94, blue: 0.97))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 999)
                                            .stroke(themeManager.accentColor.opacity(0.6), lineWidth: 1)
                                    )
                            )
                            .shadow(color: themeManager.accentColor.opacity(0.3), radius: 12, x: 0, y: 0)
                        
                        Text("Foundry90 Studio")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(themeManager.textSoftColor)
                    }
                    .padding(.bottom, 8)
                    
                    // Title with typewriter effect
                    VStack(spacing: 16) {
                        Text("FOUNDRY90")
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(themeManager.textColor)
                            .tracking(8)
                            .opacity(showTypewriter ? 1 : 0)
                            .animation(.easeInOut(duration: 0.8).delay(0.2), value: showTypewriter)
                        
                        // Typewriter cursor
                        if showTypewriter {
                            Text("_")
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundColor(themeManager.accentColor)
                                .opacity(1)
                                .animation(
                                    Animation.easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                                    value: showTypewriter
                                )
                        }
                    }
                    
                    // Subtitle
                    Text("Coming Soon")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(themeManager.textSoftColor)
                        .opacity(showTypewriter ? 1 : 0)
                        .animation(.easeInOut(duration: 0.8).delay(0.6), value: showTypewriter)
                    
                    // Description
                    Text("A small studio for building deep, production-grade data systems: ETL, APIs, and dashboards that actually ship.")
                        .font(.system(size: 15))
                        .foregroundColor(themeManager.textSoftColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .opacity(showTypewriter ? 1 : 0)
                        .animation(.easeInOut(duration: 0.8).delay(0.8), value: showTypewriter)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Footer
                VStack(spacing: 12) {
                    // Stack info
                    Text("Rust · Python · Next.js · Postgres · SwiftUI")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.textSoftColor)
                        .tracking(1)
                    
                    Text("90 days is all it takes")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(themeManager.textSoftColor)
                        .tracking(1)
                    
                    // GitHub link
                    Link(destination: URL(string: "https://github.com/therealtplum/foundry90/")!) {
                        Text("foundry90 on GitHub")
                            .font(.system(size: 14))
                            .foregroundColor(themeManager.textSoftColor)
                    }
                    .padding(.top, 8)
                }
                .padding(.bottom, 40)
                .opacity(showTypewriter ? 1 : 0)
                .animation(.easeInOut(duration: 0.8).delay(1.0), value: showTypewriter)
            }
        }
        .onAppear {
            // Trigger typewriter animation
            withAnimation {
                showTypewriter = true
            }
        }
    }
}

#Preview {
    ComingSoonView()
        .environmentObject(ThemeManager())
}

