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
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack {
            themeManager.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    headerRow
                    HStack(spacing: 20) {
                        controlPanel
                        logPanel
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundColor(themeManager.textColor)
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
                    .foregroundColor(themeManager.textColor)

                Text("FMHub local stack · runbooks + status")
                    .font(.caption)
                    .foregroundColor(themeManager.textSoftColor)
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
            .background(themeManager.panelBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(themeManager.panelBorder, lineWidth: 1)
            )
            .cornerRadius(14)

            Button {
                Task { await healthViewModel.refresh() }
            } label: {
                HStack(spacing: 6) {
                    if healthViewModel.isLoading {
                        BlackProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(themeManager.accentColor)
        }
    }

    private func statusDot(label: String, status: String) -> some View {
        let normalized = status.lowercased()
        let isUp = normalized == "up"

        return HStack(spacing: 4) {
            Circle()
                .fill(isUp ? themeManager.statusUpColor : themeManager.statusDownColor)
                .frame(width: 8, height: 8)
                .shadow(color: isUp ? themeManager.statusUpColor.opacity(0.5) : Color.clear, radius: 3)

            Text(label)
                .font(.caption2)
                .foregroundColor(themeManager.textColor)
        }
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Runbooks")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(themeManager.textColor)

            Text("Start/stop the stack, run ETL, and rebuild the web image with the current commit.")
                .font(.subheadline)
                .foregroundColor(themeManager.textSoftColor)

            VStack(alignment: .leading, spacing: 12) {
                opButton(.startStack, systemImage: "play.fill")
                opButton(.stopStack, systemImage: "stop.fill")

                Divider().background(themeManager.panelBorder)

                opButton(.runFullEtl, systemImage: "bolt.fill")
                opButton(.exportSampleTickers, systemImage: "doc.text.fill")
                opButton(.rebuildWebWithGit, systemImage: "arrow.triangle.2.circlepath")
                
                Divider().background(themeManager.panelBorder)
                
                opButton(.runRegression, systemImage: "checkmark.seal.fill")
            }

            Divider().background(themeManager.panelBorder)

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
            .tint(.red) // Always red regardless of theme
            .disabled(viewModel.isRunning)

            Divider().background(themeManager.panelBorder)

            // Theme toggle at bottom of runbooks panel
            Button {
                themeManager.toggleTheme()
            } label: {
                HStack {
                    Image(systemName: themeManager.currentTheme == .hacker ? "sparkles" : "terminal")
                    Text("Switch to \(themeManager.currentTheme == .hacker ? "Kawaii" : "Hacker") Theme")
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(10)
            }
            .buttonStyle(.bordered)
            .tint(themeManager.accentColor.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1)
            )

            Spacer()
        }
        .padding(16)
        .frame(width: 260, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(themeManager.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(themeManager.panelBorder, lineWidth: 1)
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
        .tint(themeManager.accentColor)
        .disabled(viewModel.isRunning)
    }

    // MARK: - Log Panel

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Operation Log")
                .font(.headline)
                .foregroundColor(themeManager.textColor)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(themeManager.panelBackground.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeManager.panelBorder, lineWidth: 1)
                    )

                ScrollView {
                    Text(viewModel.logText.isEmpty ? "No operations run yet." : viewModel.logText)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(themeManager.textColor)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(16)
        .background(themeManager.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(themeManager.panelBorder, lineWidth: 1)
        )
        .cornerRadius(20)
    }
}
