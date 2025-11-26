//
//  OperationsView.swift
//  FMHubControl
//
//  Created by Thomas Plummer on 11/25/25.
//


import SwiftUI

struct OperationsView: View {
    @StateObject private var viewModel = OperationsViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.03, green: 0.05, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            HStack(spacing: 20) {
                controlPanel
                logPanel
            }
            .padding(24)
        }
        .foregroundColor(.white)
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Operations")
                .font(.system(size: 24, weight: .semibold, design: .rounded))

            Text("Run core workflows against your local FMHub stack.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))

            VStack(alignment: .leading, spacing: 12) {
                opButton(.startStack, systemImage: "play.fill")
                opButton(.stopStack, systemImage: "stop.fill")

                Divider().background(Color.white.opacity(0.1))

                opButton(.runFullEtl, systemImage: "bolt.fill")
            }

            Divider().background(Color.white.opacity(0.1))

            // Big red PANIC button
            Button(role: .destructive) {
                viewModel.run(.panic)
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text("PANIC – Tear Down Stack")
                        .fontWeight(.semibold)
                    Spacer()
                    if viewModel.currentOperation == .panic && viewModel.isRunning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(viewModel.isRunning)

            Spacer()
        }
        .padding(16)
        .frame(width: 260, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .cornerRadius(20)
    }

    private func opButton(_ op: OperationType, systemImage: String) -> some View {
        Button {
            viewModel.run(op)
        } label: {
            HStack {
                Image(systemName: systemImage)
                Text(op.rawValue)
                Spacer()
                if viewModel.currentOperation == op && viewModel.isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(10)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isRunning)
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Operation Log")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )

                ScrollView {
                    Text(viewModel.logText.isEmpty ? "No operations run yet." : viewModel.logText)
                        .font(.system(.footnote, design: .monospaced))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .textSelection(.enabled) 
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.02))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.04), lineWidth: 1)
        )
        .cornerRadius(20)
    }
}
