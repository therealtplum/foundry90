import Foundation

// MARK: - Market Models

public struct KalshiMarketSummary: Codable, Identifiable {
    public let id: Int64
    public let ticker: String
    public let name: String
    public let displayName: String
    public let category: String?
    public let status: String
    public let yesPrice: Double?
    public let volume: Double?
    
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
    
    public init(id: Int64, ticker: String, name: String, displayName: String, category: String?, status: String, yesPrice: Double?, volume: Double?) {
        self.id = id
        self.ticker = ticker
        self.name = name
        self.displayName = displayName
        self.category = category
        self.status = status
        self.yesPrice = yesPrice
        self.volume = volume
    }
}

public struct KalshiMarketDetail: Codable {
    public let id: Int64
    public let ticker: String
    public let name: String
    public let assetClass: String
    public let status: String
    public let externalRef: [String: AnyCodable]?
    public let marketData: [String: AnyCodable]?
    public let yesPrice: Double?
    public let noPrice: Double?
    public let volume: Double?
    public let lastUpdated: String?
    
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
    
    public init(id: Int64, ticker: String, name: String, assetClass: String, status: String, externalRef: [String: AnyCodable]?, marketData: [String: AnyCodable]?, yesPrice: Double?, noPrice: Double?, volume: Double?, lastUpdated: String?) {
        self.id = id
        self.ticker = ticker
        self.name = name
        self.assetClass = assetClass
        self.status = status
        self.externalRef = externalRef
        self.marketData = marketData
        self.yesPrice = yesPrice
        self.noPrice = noPrice
        self.volume = volume
        self.lastUpdated = lastUpdated
    }
}

// MARK: - User Account Models

public struct KalshiUserBalance: Codable {
    public let balance: Double
    public let currency: String
    public let availableBalance: Double
    public let pendingWithdrawals: Double
    
    enum CodingKeys: String, CodingKey {
        case balance
        case currency
        case availableBalance = "available_balance"
        case pendingWithdrawals = "pending_withdrawals"
    }
    
    public init(balance: Double, currency: String, availableBalance: Double, pendingWithdrawals: Double) {
        self.balance = balance
        self.currency = currency
        self.availableBalance = availableBalance
        self.pendingWithdrawals = pendingWithdrawals
    }
    
    public init(from decoder: Decoder) throws {
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

public struct KalshiPosition: Codable, Identifiable {
    public var id: String { ticker }
    public let ticker: String
    public let position: Int32 // Positive for yes, negative for no
    public let averagePrice: Double
    public let currentPrice: Double
    public let unrealizedPnl: Double
    
    enum CodingKeys: String, CodingKey {
        case ticker
        case position
        case averagePrice = "average_price"
        case currentPrice = "current_price"
        case unrealizedPnl = "unrealized_pnl"
    }
    
    public init(ticker: String, position: Int32, averagePrice: Double, currentPrice: Double, unrealizedPnl: Double) {
        self.ticker = ticker
        self.position = position
        self.averagePrice = averagePrice
        self.currentPrice = currentPrice
        self.unrealizedPnl = unrealizedPnl
    }
    
    public init(from decoder: Decoder) throws {
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

public struct KalshiUserAccount: Codable {
    public let balance: KalshiUserBalance
    public let positions: [KalshiPosition]
    public let fetchedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case balance
        case positions
        case fetchedAt = "fetched_at"
    }
    
    public init(balance: KalshiUserBalance, positions: [KalshiPosition], fetchedAt: String?) {
        self.balance = balance
        self.positions = positions
        self.fetchedAt = fetchedAt
    }
}

// MARK: - Credentials Model

public struct KalshiCredentials: Codable {
    public let apiKey: String
    public let apiSecret: String
    
    public init(apiKey: String, apiSecret: String) {
        self.apiKey = apiKey
        self.apiSecret = apiSecret
    }
}

// MARK: - Helper for JSON AnyCodable

public struct AnyCodable: Codable {
    public let value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
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
    
    public func encode(to encoder: Encoder) throws {
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

