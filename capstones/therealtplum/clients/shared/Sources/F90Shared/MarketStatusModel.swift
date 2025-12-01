import Foundation

// MARK: - Market Status Model

public struct MarketStatus: Codable {
    public let serverTime: String
    public let market: String
    public let afterHours: Bool
    public let earlyHours: Bool
    public let exchangeNasdaq: String?
    public let exchangeNyse: String?
    public let exchangeOtc: String?
    public let currencyCrypto: String?
    public let currencyFx: String?
    public let optionsStatus: String?
    public let kalshiStatus: String?
    public let indicesGroups: [String: String]?
    
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
        case optionsStatus = "options_status"
        case kalshiStatus = "kalshi_status"
        case indicesGroups = "indices_groups"
    }
}

// MARK: - Market Status Helpers

extension MarketStatus {
    /// Returns true if market is open (open or extended-hours)
    public var isOpen: Bool {
        let normalized = market.lowercased()
        return normalized == "open" || normalized == "extended-hours"
    }
    
    /// Returns a human-readable status string
    public var statusDisplay: String {
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
    public var primaryExchangeStatus: String? {
        return exchangeNyse ?? exchangeNasdaq
    }
    
    /// Returns true if crypto markets are open
    public var isCryptoOpen: Bool {
        return currencyCrypto?.lowercased() == "open"
    }
    
    /// Returns true if forex markets are open
    public var isForexOpen: Bool {
        return currencyFx?.lowercased() == "open"
    }
    
    /// Returns true if US options markets are open (generally same hours as stocks)
    public var isOptionsOpen: Bool {
        // Options typically trade during regular market hours (same as stocks)
        // If optionsStatus is provided, use it; otherwise assume same as stocks
        if let options = optionsStatus {
            return options.lowercased() == "open"
        }
        return isOpen
    }
    
    /// Returns true if Kalshi markets are active
    public var isKalshiOpen: Bool {
        // Kalshi markets are typically always available (24/7)
        // If kalshiStatus is provided, use it; otherwise assume open
        if let kalshi = kalshiStatus {
            return kalshi.lowercased() == "open" || kalshi.lowercased() == "active"
        }
        return true // Kalshi markets are generally always available
    }
}

// MARK: - Market Open Time Calculator

public class MarketOpenTimeCalculator {
    /// Calculate the next market open time (9:30 AM ET on next trading day)
    public static func nextMarketOpen() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        // ET timezone
        guard let etTimeZone = TimeZone(identifier: "America/New_York") else {
            return nil
        }
        
        var etCalendar = calendar
        etCalendar.timeZone = etTimeZone
        
        // Get current time in ET
        let etNow = now
        let etComponents = etCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: etNow)
        
        // Market opens at 9:30 AM ET
        var marketOpenComponents = DateComponents()
        marketOpenComponents.year = etComponents.year
        marketOpenComponents.month = etComponents.month
        marketOpenComponents.day = etComponents.day
        marketOpenComponents.hour = 9
        marketOpenComponents.minute = 30
        marketOpenComponents.timeZone = etTimeZone
        
        guard var marketOpen = etCalendar.date(from: marketOpenComponents) else {
            return nil
        }
        
        // If market already opened today, move to tomorrow
        if marketOpen < etNow {
            guard let tomorrow = etCalendar.date(byAdding: .day, value: 1, to: marketOpen) else {
                return nil
            }
            marketOpen = tomorrow
        }
        
        // Skip weekends (Saturday = 7, Sunday = 1)
        while let weekday = etCalendar.dateComponents([.weekday], from: marketOpen).weekday,
              weekday == 1 || weekday == 7 {
            guard let nextDay = etCalendar.date(byAdding: .day, value: 1, to: marketOpen) else {
                return nil
            }
            marketOpen = nextDay
        }
        
        // TODO: Skip holidays (would need to query market_holidays table)
        // For now, we'll just skip weekends
        
        return marketOpen
    }
    
    /// Format time remaining until market open
    public static func timeUntilMarketOpen() -> String? {
        guard let nextOpen = nextMarketOpen() else {
            return nil
        }
        
        let now = Date()
        let timeInterval = nextOpen.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            return "Markets opening now"
        }
        
        let hours = Int(timeInterval) / 3600
        let minutes = (Int(timeInterval) % 3600) / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m until markets open"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s until markets open"
        } else {
            return "\(seconds)s until markets open"
        }
    }
}

