//
//  MarketsPlaceholderView.swift
//  FMHubControl
//
//  Created by Thomas Plummer on 11/25/25.
//


import SwiftUI

struct MarketsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Markets dashboard coming soon")
                .font(.title2)
                .foregroundColor(.white.opacity(0.9))

            Text("This tab will evolve into a research and markets console for FMHub.")
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}