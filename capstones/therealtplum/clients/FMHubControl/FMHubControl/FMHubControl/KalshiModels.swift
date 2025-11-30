import Foundation

// MARK: - Market Models

struct KalshiMarketSummary: Codable, Identifiable {
    let id: Int64
    let ticker: String
    let name: String
    let displayName: String
    let category: String?
    let status: String
    let yesPrice: Double?
    let volume: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case ticker
        case name
        case displayName = "display_name"
        case category
        case status
        case yesPrice = "yes_price"
        case volume
    }
}

struct KalshiMarketDetail: Codable {
    let id: Int64
    let ticker: String
    let name: String
    let assetClass: String
    let status: String
    let externalRef: [String: AnyCodable]?
    let marketData: [String: AnyCodable]?
    let yesPrice: Double?
    let noPrice: Double?
    let volume: Double?
    let lastUpdated: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case ticker
        case name
        case assetClass = "asset_class"
        case status
        case externalRef = "external_ref"
        case marketData = "market_data"
        case yesPrice = "yes_price"
        case noPrice = "no_price"
        case volume
        case lastUpdated = "last_updated"
    }
}

// MARK: - User Account Models

struct KalshiUserBalance: Codable {
    let balance: Double
    let currency: String
    let availableBalance: Double
    let pendingWithdrawals: Double
    
    enum CodingKeys: String, CodingKey {
        case balance
        case currency
        case availableBalance = "available_balance"
        case pendingWithdrawals = "pending_withdrawals"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle balance as either String or Double
        if let balanceString = try? container.decode(String.self, forKey: .balance) {
            balance = Double(balanceString) ?? 0.0
        } else {
            balance = try container.decode(Double.self, forKey: .balance)
        }
        
        currency = try container.decode(String.self, forKey: .currency)
        
        // Handle availableBalance as either String or Double
        if let availableString = try? container.decode(String.self, forKey: .availableBalance) {
            availableBalance = Double(availableString) ?? 0.0
        } else {
            availableBalance = try container.decode(Double.self, forKey: .availableBalance)
        }
        
        // Handle pendingWithdrawals as either String or Double
        if let pendingString = try? container.decode(String.self, forKey: .pendingWithdrawals) {
            pendingWithdrawals = Double(pendingString) ?? 0.0
        } else {
            pendingWithdrawals = try container.decode(Double.self, forKey: .pendingWithdrawals)
        }
    }
}

struct KalshiPosition: Codable, Identifiable {
    var id: String { ticker }
    let ticker: String
    let position: Int32 // Positive for yes, negative for no
    let averagePrice: Double
    let currentPrice: Double
    let unrealizedPnl: Double
    
    enum CodingKeys: String, CodingKey {
        case ticker
        case position
        case averagePrice = "average_price"
        case currentPrice = "current_price"
        case unrealizedPnl = "unrealized_pnl"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        ticker = try container.decode(String.self, forKey: .ticker)
        position = try container.decode(Int32.self, forKey: .position)
        
        // Handle price fields as either String or Double
        if let priceString = try? container.decode(String.self, forKey: .averagePrice) {
            averagePrice = Double(priceString) ?? 0.0
        } else {
            averagePrice = try container.decode(Double.self, forKey: .averagePrice)
        }
        
        if let priceString = try? container.decode(String.self, forKey: .currentPrice) {
            currentPrice = Double(priceString) ?? 0.0
        } else {
            currentPrice = try container.decode(Double.self, forKey: .currentPrice)
        }
        
        if let pnlString = try? container.decode(String.self, forKey: .unrealizedPnl) {
            unrealizedPnl = Double(pnlString) ?? 0.0
        } else {
            unrealizedPnl = try container.decode(Double.self, forKey: .unrealizedPnl)
        }
    }
}

struct KalshiUserAccount: Codable {
    let balance: KalshiUserBalance
    let positions: [KalshiPosition]
    let fetchedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case balance
        case positions
        case fetchedAt = "fetched_at"
    }
}

// MARK: - Credentials Model

struct KalshiCredentials: Codable {
    let apiKey: String
    let apiSecret: String
}

// MARK: - Helper for JSON AnyCodable

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            let codableArray = array.map { AnyCodable($0) }
            try container.encode(codableArray)
        case let dictionary as [String: Any]:
            let codableDictionary = dictionary.mapValues { AnyCodable($0) }
            try container.encode(codableDictionary)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
        }
    }
}

