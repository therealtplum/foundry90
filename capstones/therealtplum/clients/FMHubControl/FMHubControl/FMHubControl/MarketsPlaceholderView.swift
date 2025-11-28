//
//  MarketsPlaceholderView.swift
//  FMHubControl
//
//  Created by Thomas Plummer on 11/25/25.
//


import SwiftUI

struct MarketsPlaceholderView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack {
            themeManager.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Markets dashboard coming soon")
                    .font(.title2)
                    .foregroundColor(themeManager.textColor)

                Text("This tab will evolve into a research and markets console for FMHub.")
                    .foregroundColor(themeManager.textSoftColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}