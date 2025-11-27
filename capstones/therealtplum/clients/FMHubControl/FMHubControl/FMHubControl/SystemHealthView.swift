import SwiftUI

struct SystemHealthView: View {
    @StateObject private var viewModel = SystemHealthViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.02, green: 0.06, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                header
                statusRow
                webPanel
                dbSchemaPanel
                etlPanel
                Spacer()
            }
            .padding(24)
        }
        .foregroundColor(.white)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Health")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                Text("FMHub stack status · local")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Toggle("Auto-refresh", isOn: $viewModel.autoRefresh)

            Button {
                Task { await viewModel.refresh() }
            } label: {
                viewModel.isLoading
                    ? AnyView(ProgressView().controlSize(.small))
                    : AnyView(Text("Refresh"))
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Status row

    private var statusRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                statusTile(title: "API", status: viewModel.health?.api ?? "unknown")
                statusTile(title: "Database", status: viewModel.health?.db ?? "unknown")
                statusTile(title: "Redis", status: viewModel.health?.redis ?? "unknown")
                statusTile(title: "Web (local)", status: viewModel.health?.webLocal?.status ?? "unknown")
                statusTile(title: "Web (prod)", status: viewModel.health?.webProd?.status ?? "unknown")
            }
        }
    }

    private func statusTile(title: String, status: String) -> some View {
        let normalized = status.lowercased()
        let isUp = normalized == "up"

        return VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))

            HStack(spacing: 8) {
                Circle()
                    .fill(isUp ? Color.green : Color.red)
                    .frame(width: 10, height: 10)

                Text(isUp ? "Up" : "Down")
                    .font(.system(size: 15, weight: .medium))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .cornerRadius(16)
    }

    // MARK: - Web frontend panel

    private var webPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Web frontends")
                .font(.headline)

            webSection(
                title: "Local (Docker)",
                web: viewModel.health?.webLocal,
                isProdSection: false
            )

            Divider()
                .background(Color.white.opacity(0.1))

            webSection(
                title: "Production (Vercel)",
                web: viewModel.health?.webProd,
                isProdSection: true
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
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
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                if let status = web?.status {
                    Text(status.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(status.lowercased() == "up"
                                      ? Color.green.opacity(0.2)
                                      : Color.red.opacity(0.2))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        )
                } else {
                    Text("No data")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            if let web = web {
                // URL (clickable)
                HStack(alignment: .top, spacing: 8) {
                    Text("URL:")
                        .foregroundColor(.white.opacity(0.6))

                    if let url = URL(string: web.url) {
                        Link(web.url, destination: url)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                    } else {
                        Text(web.url)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                    }

                    Spacer()
                }

                // Build
                if let commit = web.buildCommit {
                    HStack(spacing: 8) {
                        Text("Build:")
                            .foregroundColor(.white.opacity(0.6))
                        Text(commit.count > 7 ? String(commit.prefix(7)) : commit)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                        Spacer()
                    }
                }

                // Branch
                if let branch = web.buildBranch {
                    HStack(spacing: 8) {
                        Text("Branch:")
                            .foregroundColor(.white.opacity(0.6))
                        Text(branch)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                        Spacer()
                    }
                }

                // Deployed at
                if let deployedAt = web.deployedAtUtc {
                    HStack(spacing: 8) {
                        Text("Deployed at (UTC):")
                            .foregroundColor(.white.opacity(0.6))
                        Text(deployedAt)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                        Spacer()
                    }
                }

                // Version status badge (Latest / Out of date)
                if let (label, color) = versionStatus(for: web, isProdSection: isProdSection) {
                    HStack(spacing: 8) {
                        Text("Version status:")
                            .foregroundColor(.white.opacity(0.6))
                        Text(label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(color)
                        Spacer()
                    }
                }
            } else {
                Text("No health data reported.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
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
                ? ("Latest", .green)
                : ("Out of date", .orange)
        }

        // 2) Otherwise, for prod, compare commit to local's commit if we have both
        if isProdSection,
           let prodCommit = web.buildCommit,
           let localCommit = viewModel.health?.webLocal?.buildCommit
        {
            if prodCommit == localCommit {
                return ("Latest (matches local)", .green)
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

                Spacer()

                if !viewModel.dbTables.isEmpty {
                    Text("\(viewModel.dbTables.count) tables")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            if viewModel.dbTables.isEmpty {
                if viewModel.isLoading {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Loading table list…")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                } else if let error = viewModel.errorMessage {
                    Text("Unable to load tables: \(error)")
                        .font(.subheadline)
                        .foregroundColor(.red)
                } else {
                    Text("No tables reported.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.dbTables, id: \.self) { name in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 6, height: 6)

                                Text(name)
                                    .font(.system(size: 13,
                                                  weight: .regular,
                                                  design: .monospaced))

                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 160)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .cornerRadius(16)
    }

    // MARK: - ETL panel

    private var etlPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ETL Status")
                .font(.headline)

            if let health = viewModel.health {
                HStack {
                    Text("State:")
                        .foregroundColor(.white.opacity(0.6))
                    Text(health.etlStatus.capitalized)
                        .fontWeight(.medium)
                }

                HStack {
                    Text("Last run (UTC):")
                        .foregroundColor(.white.opacity(0.6))
                    Text(health.lastEtlRunUtc ?? "Unknown")
                }

                HStack {
                    Text("Recent errors:")
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(health.recentErrors)")
                }
            } else if let error = viewModel.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
            } else {
                Text("Loading...")
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .cornerRadius(16)
    }
}
