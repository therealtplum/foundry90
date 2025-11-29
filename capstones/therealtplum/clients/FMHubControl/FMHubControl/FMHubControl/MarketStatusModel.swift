import Foundation

// MARK: - Market Status Model

struct MarketStatus: Codable {
    let serverTime: String
    let market: String
    let afterHours: Bool
    let earlyHours: Bool
    let exchangeNasdaq: String?
    let exchangeNyse: String?
    let exchangeOtc: String?
    let currencyCrypto: String?
    let currencyFx: String?
    let indicesGroups: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case serverTime = "server_time"
        case market
        case afterHours = "after_hours"
        case earlyHours = "early_hours"
        case exchangeNasdaq = "exchange_nasdaq"
        case exchangeNyse = "exchange_nyse"
        case exchangeOtc = "exchange_otc"
        case currencyCrypto = "currency_crypto"
        case currencyFx = "currency_fx"
        case indicesGroups = "indices_groups"
    }
}

// MARK: - Market Status Helpers

extension MarketStatus {
    /// Returns true if market is open (open or extended-hours)
    var isOpen: Bool {
        let normalized = market.lowercased()
        return normalized == "open" || normalized == "extended-hours"
    }
    
    /// Returns a human-readable status string
    var statusDisplay: String {
        let normalized = market.lowercased()
        switch normalized {
        case "open":
            return "Open"
        case "closed":
            return "Closed"
        case "extended-hours":
            return "Extended Hours"
        default:
            return market.capitalized
        }
    }
    
    /// Returns the primary exchange status (NYSE or NASDAQ)
    var primaryExchangeStatus: String? {
        return exchangeNyse ?? exchangeNasdaq
    }
}

