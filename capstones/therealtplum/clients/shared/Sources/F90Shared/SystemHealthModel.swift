import Foundation

// MARK: - Data Models

public struct SystemHealth: Codable {
    public let api: String
    public let db: String
    public let redis: String
    public let useqStatus: String?
    public let usoptStatus: String?
    public let fxStatus: String?
    public let cryptoStatus: String?
    public let kalshiStatus: String?
    public let lastEtlRunUtc: String?
    public let etlStatus: String
    public let recentErrors: Int
    public let dbTables: [String]
    public let webLocal: WebHealth?
    public let webProd: WebHealth?
    public let regressionTest: RegressionTestResults?

    enum CodingKeys: String, CodingKey {
        case api
        case db
        case redis
        case useqStatus = "useq_status"
        case usoptStatus = "usopt_status"
        case fxStatus = "fx_status"
        case cryptoStatus = "crypto_status"
        case kalshiStatus = "kalshi_status"
        case lastEtlRunUtc = "last_etl_run_utc"
        case etlStatus = "etl_status"
        case recentErrors = "recent_errors"
        case dbTables = "db_tables"
        case webLocal = "web_local"
        case webProd = "web_prod"
        case regressionTest = "regression_test"
    }
}

public struct RegressionTestResults: Codable {
    public let lastRunUtc: String?
    public let passed: Int
    public let failed: Int
    public let warnings: Int
    public let success: Bool

    enum CodingKeys: String, CodingKey {
        case lastRunUtc = "last_run_utc"
        case passed
        case failed
        case warnings
        case success
    }
}

public struct WebHealth: Codable {
    public let status: String
    public let url: String
    public let httpStatus: Int?
    public let buildCommit: String?
    public let buildBranch: String?
    public let deployedAtUtc: String?
    public let isLatest: Bool?
    public let lastCheckedUtc: String?

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

