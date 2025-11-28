//
//  BlackProgressView.swift
//  FMHubControl
//
//  Created by Thomas Plummer on 11/25/25.
//

import SwiftUI

struct BlackProgressView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.7)
            .stroke(Color.black, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
            .frame(width: 12, height: 12)
            .onAppear {
                withAnimation(Animation.linear(duration: 1).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

