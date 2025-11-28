//
//  OperationsView.swift
//  FMHubControl
//
//  Created by Thomas Plummer on 11/25/25.
//

import SwiftUI

struct OperationsView: View {
    @StateObject private var viewModel = OperationsViewModel()
    @StateObject private var healthViewModel = SystemHealthViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.03, green: 0.05, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                headerRow
                HStack(spacing: 20) {
                    controlPanel
                    logPanel
                }
            }
            .padding(24)
        }
        .foregroundColor(.white)
        .task {
            await healthViewModel.refresh()
        }
    }

    // MARK: - Header row with ultra-minimal status

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Operations")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))

                Text("FMHub local stack · runbooks + status")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Minimal inline status row: ● API  ● DB  ● Redis  ● Web L  ● Web P
            HStack(spacing: 10) {
                statusDot(label: "API", status: healthViewModel.health?.api ?? "unknown")
                statusDot(label: "DB", status: healthViewModel.health?.db ?? "unknown")
                statusDot(label: "Redis", status: healthViewModel.health?.redis ?? "unknown")
                statusDot(label: "Web - Local", status: healthViewModel.health?.webLocal?.status ?? "unknown")
                statusDot(label: "Web - Prod", status: healthViewModel.health?.webProd?.status ?? "unknown")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .cornerRadius(14)

            Button {
                Task { await healthViewModel.refresh() }
            } label: {
                HStack(spacing: 6) {
                    if healthViewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.15))
        }
    }

    private func statusDot(label: String, status: String) -> some View {
        let normalized = status.lowercased()
        let isUp = normalized == "up"

        return HStack(spacing: 4) {
            Circle()
                .fill(isUp ? Color.green : Color.red)
                .frame(width: 8, height: 8)

            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.85))
        }
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Runbooks")
                .font(.system(size: 18, weight: .semibold, design: .rounded))

            Text("Start/stop the stack, run ETL, and rebuild the web image with the current commit.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))

            VStack(alignment: .leading, spacing: 12) {
                opButton(.startStack, systemImage: "play.fill")
                opButton(.stopStack, systemImage: "stop.fill")

                Divider().background(Color.white.opacity(0.1))

                opButton(.runFullEtl, systemImage: "bolt.fill")
                opButton(.exportSampleTickers, systemImage: "doc.text.fill")
                opButton(.rebuildWebWithGit, systemImage: "arrow.triangle.2.circlepath")
                
                Divider().background(Color.white.opacity(0.1))
                
                opButton(.runRegression, systemImage: "checkmark.seal.fill")
            }

            Divider().background(Color.white.opacity(0.1))

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

    // MARK: - Log Panel

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
