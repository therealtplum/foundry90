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
        HStack(spacing: 16) {
            statusTile(title: "API", status: viewModel.health?.api ?? "unknown")
            statusTile(title: "Database", status: viewModel.health?.db ?? "unknown")
            statusTile(title: "Redis", status: viewModel.health?.redis ?? "unknown")
            statusTile(title: "Web (local)", status: viewModel.health?.webLocal?.status ?? "unknown")
            statusTile(title: "Web (prod)", status: viewModel.health?.webProd?.status ?? "unknown")
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
                web: viewModel.health?.webLocal
            )

            Divider()
                .background(Color.white.opacity(0.1))

            webSection(
                title: "Production (Vercel)",
                web: viewModel.health?.webProd
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

    private func webSection(title: String, web: WebHealth?) -> some View {
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
                HStack(alignment: .top, spacing: 8) {
                    Text("URL:")
                        .foregroundColor(.white.opacity(0.6))
                    Text(web.url)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                }

                if let commit = web.buildCommit {
                    HStack(spacing: 8) {
                        Text("Build:")
                            .foregroundColor(.white.opacity(0.6))
                        Text(commit.count > 7 ? String(commit.prefix(7)) : commit)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                        Spacer()
                    }
                }

                if let branch = web.buildBranch {
                    HStack(spacing: 8) {
                        Text("Branch:")
                            .foregroundColor(.white.opacity(0.6))
                        Text(branch)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                        Spacer()
                    }
                }

                if let deployedAt = web.deployedAtUtc {
                    HStack(spacing: 8) {
                        Text("Deployed at (UTC):")
                            .foregroundColor(.white.opacity(0.6))
                        Text(deployedAt)
                            .font(.system(size: 12, weight: .regular, design: .monospaced))
                        Spacer()
                    }
                }

                if let isLatest = web.isLatest {
                    HStack(spacing: 8) {
                        Text("Version status:")
                            .foregroundColor(.white.opacity(0.6))
                        Text(isLatest ? "Latest" : "Out of date")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isLatest ? .green : .orange)
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
