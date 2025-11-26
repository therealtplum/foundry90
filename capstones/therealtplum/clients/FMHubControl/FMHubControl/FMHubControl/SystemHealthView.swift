import SwiftUI

struct SystemHealthView: View {
    @StateObject private var viewModel = SystemHealthViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.02, green: 0.06, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                header
                statusRow
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
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Refresh")
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Status Row

    private var statusRow: some View {
        HStack(spacing: 16) {
            statusTile(title: "API", status: viewModel.health?.api ?? "unknown")
            statusTile(title: "Database", status: viewModel.health?.db ?? "unknown")
            statusTile(title: "Redis", status: viewModel.health?.redis ?? "unknown")
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

    // MARK: - DB Schema Panel

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
                        ProgressView()
                            .controlSize(.small)
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
                .frame(maxHeight: 160) // keeps it compact; scales to hundreds of tables
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

    // MARK: - ETL Panel

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
