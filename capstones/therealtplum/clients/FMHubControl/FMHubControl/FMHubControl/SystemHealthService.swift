import Foundation

struct SystemHealth: Codable {
    let api: String
    let db: String
    let redis: String
    let marketStatus: String?
    let lastEtlRunUtc: String?
    let etlStatus: String
    let recentErrors: Int
    let dbTables: [String]
    let webLocal: WebHealth?
    let webProd: WebHealth?
    let regressionTest: RegressionTestResults?

    enum CodingKeys: String, CodingKey {
        case api
        case db
        case redis
        case marketStatus = "market_status"
        case lastEtlRunUtc = "last_etl_run_utc"
        case etlStatus = "etl_status"
        case recentErrors = "recent_errors"
        case dbTables = "db_tables"
        case webLocal = "web_local"
        case webProd = "web_prod"
        case regressionTest = "regression_test"
    }
}

struct RegressionTestResults: Codable {
    let lastRunUtc: String?
    let passed: Int
    let failed: Int
    let warnings: Int
    let success: Bool

    enum CodingKeys: String, CodingKey {
        case lastRunUtc = "last_run_utc"
        case passed
        case failed
        case warnings
        case success
    }
}

struct WebHealth: Codable {
    let status: String
    let url: String
    let httpStatus: Int?
    let buildCommit: String?
    let buildBranch: String?
    let deployedAtUtc: String?
    let isLatest: Bool?
    let lastCheckedUtc: String?

    enum CodingKeys: String, CodingKey {
        case status
        case url
        case httpStatus = "http_status"
        case buildCommit = "build_commit"
        case buildBranch = "build_branch"
        case deployedAtUtc = "deployed_at_utc"
        case isLatest = "is_latest"
        case lastCheckedUtc = "last_checked_utc"
    }
}
