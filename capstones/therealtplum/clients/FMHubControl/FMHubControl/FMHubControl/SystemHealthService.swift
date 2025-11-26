import Foundation

// Mirrors the JSON from /system/health
struct SystemHealth: Codable {
    let api: String
    let db: String
    let redis: String
    let lastEtlRunUtc: String?
    let etlStatus: String
    let recentErrors: Int
    let dbTables: [String]?

    enum CodingKeys: String, CodingKey {
        case api
        case db
        case redis
        case lastEtlRunUtc = "last_etl_run_utc"
        case etlStatus = "etl_status"
        case recentErrors = "recent_errors"
        case dbTables = "db_tables"
    }
}

protocol SystemHealthServiceType {
    func fetchHealth() async throws -> SystemHealth
}

struct SystemHealthService: SystemHealthServiceType {
    let baseURL: URL

    init(baseURL: URL = URL(string: "http://127.0.0.1:3000")!) {
        self.baseURL = baseURL
    }

    func fetchHealth() async throws -> SystemHealth {
        let url = baseURL.appendingPathComponent("system/health")
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        return try decoder.decode(SystemHealth.self, from: data)
    }
}
