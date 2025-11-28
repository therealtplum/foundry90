import SwiftUI

struct SystemHealthView: View {
    @StateObject private var viewModel = SystemHealthViewModel()
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack {
            themeManager.backgroundGradient
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                header
                statusRow
                webPanel
                dbSchemaPanel
                regressionPanel
                etlPanel
                Spacer()
            }
            .padding(24)
        }
        .foregroundColor(themeManager.textColor)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("System Health")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(themeManager.textColor)
            Text("FMHub stack status · local")
                .font(.subheadline)
                .foregroundColor(themeManager.textSoftColor)
        }
    }

    // MARK: - Status row

    private var statusRow: some View {
        HStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    statusTile(title: "API", status: viewModel.health?.api ?? "unknown")
                    statusTile(title: "Database", status: viewModel.health?.db ?? "unknown")
                    statusTile(title: "Redis", status: viewModel.health?.redis ?? "unknown")
                    statusTile(title: "Web (local)", status: viewModel.health?.webLocal?.status ?? "unknown")
                    statusTile(title: "Web (prod)", status: viewModel.health?.webProd?.status ?? "unknown")
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Toggle("Auto-refresh", isOn: $viewModel.autoRefresh)

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    if viewModel.isLoading {
                        BlackProgressView()
                    } else {
                        Text("Refresh")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.accentColor)
            }
        }
    }

    private func statusTile(title: String, status: String) -> some View {
        let normalized = status.lowercased()
        let isUp = normalized == "up"

        return VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundColor(themeManager.textSoftColor)

            HStack(spacing: 8) {
                Circle()
                    .fill(isUp ? themeManager.statusUpColor : themeManager.statusDownColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: isUp ? themeManager.statusUpColor.opacity(0.5) : Color.clear, radius: 4)

                Text(isUp ? "Up" : "Down")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(themeManager.textColor)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeManager.panelBorder, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    // MARK: - Web frontend panel

    private var webPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Web frontends")
                .font(.headline)
                .foregroundColor(themeManager.textColor)

            webSection(
                title: "Local (Docker)",
                web: viewModel.health?.webLocal,
                isProdSection: false
            )

            Divider()
                .background(themeManager.panelBorder)

            webSection(
                title: "Production (Vercel)",
                web: viewModel.health?.webProd,
                isProdSection: true
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeManager.panelBorder, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private func webSection(
        title: String,
        web: WebHealth?,
        isProdSection: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(themeManager.textColor)

                Spacer()

                if let status = web?.status {
                    Text(status.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(status.lowercased() == "up"
                                      ? themeManager.statusUpColor.opacity(0.2)
                                      : themeManager.statusDownColor.opacity(0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeManager.panelBorder, lineWidth: 0.5)
                        )
                } else {
                    Text("No data")
                        .font(.caption)
                        .foregroundColor(themeManager.textSoftColor)
                }
            }

            if let web = web {
                // URL (clickable)
                HStack(alignment: .top, spacing: 8) {
                    Text("URL:")
                        .foregroundColor(themeManager.textSoftColor)

                    if let url = URL(string: web.url) {
                        Link(web.url, destination: url)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(themeManager.accentColor)
                    } else {
                        Text(web.url)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(themeManager.textColor)
                    }

                    Spacer()
                }

                // Build
                if let commit = web.buildCommit {
                    HStack(spacing: 8) {
                        Text("Build:")
                            .foregroundColor(themeManager.textSoftColor)
                        Text(commit.count > 7 ? String(commit.prefix(7)) : commit)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(themeManager.textColor)
                        Spacer()
                    }
                }

                // Branch
                if let branch = web.buildBranch {
                    HStack(spacing: 8) {
                        Text("Branch:")
                            .foregroundColor(themeManager.textSoftColor)
                        Text(branch)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(themeManager.textColor)
                        Spacer()
                    }
                }

                // Deployed at
                if let deployedAt = web.deployedAtUtc {
                    HStack(spacing: 8) {
                        Text("Deployed at (UTC):")
                            .foregroundColor(themeManager.textSoftColor)
                        Text(deployedAt)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                            .foregroundColor(themeManager.textColor)
                        Spacer()
                    }
                }

                // Version status badge (Latest / Out of date)
                if let (label, color) = versionStatus(for: web, isProdSection: isProdSection) {
                    HStack(spacing: 8) {
                        Text("Version status:")
                            .foregroundColor(themeManager.textSoftColor)
                        Text(label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(color)
                        Spacer()
                    }
                }
            } else {
                Text("No health data reported.")
                    .font(.subheadline)
                    .foregroundColor(themeManager.textSoftColor)
            }
        }
    }

    /// Decide what to show in the "Version status" badge.
    ///
    /// Priority:
    /// 1. If backend gave us `is_latest`, use that (Vercel comparison).
    /// 2. For the Production section, if we have both prod + local commits, compare them:
    ///    - same  → "Latest (matches local)"
    ///    - diff  → "Out of date vs local"
    private func versionStatus(for web: WebHealth, isProdSection: Bool) -> (String, Color)? {
        // 1) Trust backend if it gave us `is_latest`
        if let isLatest = web.isLatest {
            return isLatest
                ? ("Latest", themeManager.statusUpColor)
                : ("Out of date", .orange)
        }

        // 2) Otherwise, for prod, compare commit to local's commit if we have both
        if isProdSection,
           let prodCommit = web.buildCommit,
           let localCommit = viewModel.health?.webLocal?.buildCommit
        {
            if prodCommit == localCommit {
                return ("Latest (matches local)", themeManager.statusUpColor)
            } else {
                return ("Out of date vs local", .orange)
            }
        }

        // Nothing meaningful to show
        return nil
    }

    // MARK: - DB table list

    private var dbSchemaPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Database tables")
                    .font(.headline)
                    .foregroundColor(themeManager.textColor)

                Spacer()

                if !viewModel.dbTables.isEmpty {
                    Text("\(viewModel.dbTables.count) tables")
                        .font(.caption)
                        .foregroundColor(themeManager.textSoftColor)
                }
            }

            if viewModel.dbTables.isEmpty {
                if viewModel.isLoading {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Loading table list…")
                            .font(.subheadline)
                            .foregroundColor(themeManager.textSoftColor)
                    }
                } else if let error = viewModel.errorMessage {
                    Text("Unable to load tables: \(error)")
                        .font(.subheadline)
                        .foregroundColor(themeManager.statusDownColor)
                } else {
                    Text("No tables reported.")
                        .font(.subheadline)
                        .foregroundColor(themeManager.textSoftColor)
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.dbTables, id: \.self) { name in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(themeManager.accentColor.opacity(0.6))
                                    .frame(width: 6, height: 6)

                                Text(name)
                                    .font(.system(size: 13,
                                                  weight: .regular,
                                                  design: .monospaced))
                                    .foregroundColor(themeManager.textColor)

                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(themeManager.panelBackground.opacity(0.5))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: 200) // Fixed height to show ~4-5 items (each item ~28px with padding + 4px spacing)
                .scrollIndicators(.visible) // Show scroll indicators so users know they can scroll
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeManager.panelBorder, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    // MARK: - Regression test panel

    private var regressionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Regression Test")
                .font(.headline)
                .foregroundColor(themeManager.textColor)

            if let regression = viewModel.health?.regressionTest {
                HStack {
                    Text("Last run (UTC):")
                        .foregroundColor(themeManager.textSoftColor)
                    Text(regression.lastRunUtc ?? "Unknown")
                        .foregroundColor(themeManager.textColor)
                }

                if let utcString = regression.lastRunUtc {
                    HStack {
                        Text("Last run (Local):")
                            .foregroundColor(themeManager.textSoftColor)
                        Text(formatUtcToLocal(utcString))
                            .foregroundColor(themeManager.textColor)
                    }
                }

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Text("✅")
                        Text("\(regression.passed)")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(themeManager.statusUpColor)

                    if regression.failed > 0 {
                        HStack(spacing: 4) {
                            Text("❌")
                            Text("\(regression.failed)")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(themeManager.statusDownColor)
                    }

                    if regression.warnings > 0 {
                        HStack(spacing: 4) {
                            Text("⚠️")
                            Text("\(regression.warnings)")
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.orange)
                    }
                }

                HStack {
                    Text("Status:")
                        .foregroundColor(themeManager.textSoftColor)
                    Text(regression.success ? "All tests passed" : "Some tests failed")
                        .fontWeight(.medium)
                        .foregroundColor(regression.success ? themeManager.statusUpColor : themeManager.statusDownColor)
                }
            } else {
                Text("No regression test results available")
                    .foregroundColor(themeManager.textSoftColor)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeManager.panelBorder, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    // MARK: - ETL panel

    private var etlPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ETL Status")
                .font(.headline)
                .foregroundColor(themeManager.textColor)

            if let health = viewModel.health {
                HStack {
                    Text("State:")
                        .foregroundColor(themeManager.textSoftColor)
                    Text(health.etlStatus.capitalized)
                        .fontWeight(.medium)
                        .foregroundColor(themeManager.textColor)
                }

                HStack {
                    Text("Last run (UTC):")
                        .foregroundColor(themeManager.textSoftColor)
                    Text(health.lastEtlRunUtc ?? "Unknown")
                        .foregroundColor(themeManager.textColor)
                }

                if let utcString = health.lastEtlRunUtc {
                    HStack {
                        Text("Last run (Local):")
                            .foregroundColor(themeManager.textSoftColor)
                        Text(formatUtcToLocal(utcString))
                            .foregroundColor(themeManager.textColor)
                    }
                }

                HStack {
                    Text("Recent errors:")
                        .foregroundColor(themeManager.textSoftColor)
                    Text("\(health.recentErrors)")
                        .foregroundColor(themeManager.textColor)
                }
            } else if let error = viewModel.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(themeManager.statusDownColor)
            } else {
                Text("Loading...")
                    .foregroundColor(themeManager.textSoftColor)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(themeManager.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeManager.panelBorder, lineWidth: 1)
        )
        .cornerRadius(16)
    }

    // MARK: - Helper functions

    private func formatUtcToLocal(_ utcString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: utcString) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: utcString) else {
                return utcString // Return original if parsing fails
            }
            return formatDateToLocal(date)
        }
        
        return formatDateToLocal(date)
    }
    
    private func formatDateToLocal(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }
}
