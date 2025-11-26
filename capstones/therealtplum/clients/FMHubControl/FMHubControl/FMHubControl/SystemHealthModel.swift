import Foundation
import SwiftUI
import Combine

@MainActor
final class SystemHealthModel: ObservableObject {
    @Published var systemHealth: SystemHealth?
    @Published var isLoading = true
    @Published var error: String?

    func update(with health: SystemHealth) {
        systemHealth = health
        isLoading = false
        error = nil
    }

    func updateError(_ message: String) {
        error = message
        isLoading = false
    }
}

// MARK: - ETL helpers
extension SystemHealthModel {
    var etlStatusText: String {
        systemHealth?.etlStatus.capitalized ?? "Unknown"
    }

    var etlStatusColor: Color {
        guard let status = systemHealth?.etlStatus.lowercased() else { return .gray }

        switch status {
        case "idle": return .green
        case "running": return .orange
        case "error": return .red
        default: return .gray
        }
    }

    var lastEtlRunRelative: String {
        guard
            let raw = systemHealth?.lastEtlRunUtc
        else { return "Never" }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.insert(.withFractionalSeconds)

        guard let date = formatter.date(from: raw) else {
            return raw
        }

        let rel = RelativeDateTimeFormatter()
        rel.unitsStyle = .full

        return rel.localizedString(for: date, relativeTo: Date())
    }
}
