//
//  BaseWidgetView.swift
//  FMHubControl
//
//  Base widget component providing common structure for all widgets
//

import SwiftUI

struct BaseWidgetView<Content: View>: View {
    let title: String
    let content: Content
    var actions: AnyView? = nil
    var isLoading: Bool = false
    var errorMessage: String? = nil
    
    @EnvironmentObject var themeManager: ThemeManager
    
    init(
        title: String,
        isLoading: Bool = false,
        errorMessage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.content = content()
        self.actions = nil
    }
    
    init(
        title: String,
        isLoading: Bool = false,
        errorMessage: String? = nil,
        actions: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.actions = actions
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(themeManager.textColor)
                
                Spacer()
                
                if let actions = actions {
                    actions
                }
            }
            .padding(16)
            .background(themeManager.panelBackground)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(themeManager.panelBorder),
                alignment: .bottom
            )
            
            // Content
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(themeManager.textSoftColor)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 200)
                .padding(24)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                        .foregroundColor(themeManager.statusDownColor)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(themeManager.textSoftColor)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 200)
                .padding(24)
            } else {
                content
                    .padding(16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(themeManager.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(themeManager.panelBorder, lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

