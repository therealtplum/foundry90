import Foundation

// MARK: - Market Data Models

/// A single price data point for an instrument
public struct PriceDataPoint: Codable, Identifiable {
    public let id: String // instrument_id + price_date for unique ID
    public let instrumentId: Int64
    public let ticker: String
    public let name: String
    public let priceDate: Date
    public let open: Double?
    public let high: Double?
    public let low: Double?
    public let close: Double?
    public let volume: Double?
    
    enum CodingKeys: String, CodingKey {
        case instrumentId = "instrument_id"
        case ticker
        case name
        case priceDate = "price_date"
        case open
        case high
        case low
        case close
        case volume
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        instrumentId = try container.decode(Int64.self, forKey: .instrumentId)
        ticker = try container.decode(String.self, forKey: .ticker)
        name = try container.decode(String.self, forKey: .name)
        
        // Parse date string (YYYY-MM-DD)
        let dateString = try container.decode(String.self, forKey: .priceDate)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        guard let date = formatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(forKey: .priceDate, in: container, debugDescription: "Invalid date format")
        }
        priceDate = date
        
        // Decode optional numeric values (Decimal serializes as number in JSON)
        // Try decoding as Double first, fallback to String if needed
        if let openValue = try? container.decodeIfPresent(Double.self, forKey: .open) {
            open = openValue
        } else if let openStr = try? container.decodeIfPresent(String.self, forKey: .open) {
            open = Double(openStr)
        } else {
            open = nil
        }
        
        if let highValue = try? container.decodeIfPresent(Double.self, forKey: .high) {
            high = highValue
        } else if let highStr = try? container.decodeIfPresent(String.self, forKey: .high) {
            high = Double(highStr)
        } else {
            high = nil
        }
        
        if let lowValue = try? container.decodeIfPresent(Double.self, forKey: .low) {
            low = lowValue
        } else if let lowStr = try? container.decodeIfPresent(String.self, forKey: .low) {
            low = Double(lowStr)
        } else {
            low = nil
        }
        
        if let closeValue = try? container.decodeIfPresent(Double.self, forKey: .close) {
            close = closeValue
        } else if let closeStr = try? container.decodeIfPresent(String.self, forKey: .close) {
            close = Double(closeStr)
        } else {
            close = nil
        }
        
        if let volumeValue = try? container.decodeIfPresent(Double.self, forKey: .volume) {
            volume = volumeValue
        } else if let volumeStr = try? container.decodeIfPresent(String.self, forKey: .volume) {
            volume = Double(volumeStr)
        } else {
            volume = nil
        }
        
        // Create unique ID
        id = "\(instrumentId)-\(dateString)"
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(instrumentId, forKey: .instrumentId)
        try container.encode(ticker, forKey: .ticker)
        try container.encode(name, forKey: .name)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        try container.encode(formatter.string(from: priceDate), forKey: .priceDate)
        
        if let open = open {
            try container.encode(open, forKey: .open)
        }
        if let high = high {
            try container.encode(high, forKey: .high)
        }
        if let low = low {
            try container.encode(low, forKey: .low)
        }
        if let close = close {
            try container.encode(close, forKey: .close)
        }
        if let volume = volume {
            try container.encode(volume, forKey: .volume)
        }
    }
}

/// Grouped market data by instrument
public struct InstrumentMarketData: Identifiable {
    public let id: Int64
    public let ticker: String
    public let name: String
    public let dataPoints: [PriceDataPoint]
    
    public init(id: Int64, ticker: String, name: String, dataPoints: [PriceDataPoint]) {
        self.id = id
        self.ticker = ticker
        self.name = name
        self.dataPoints = dataPoints.sorted { $0.priceDate < $1.priceDate }
    }
    
    /// Get the latest close price
    public var latestClose: Double? {
        dataPoints.compactMap { $0.close }.last
    }
    
    /// Calculate percentage change from first to last
    public var priceChangePercent: Double? {
        guard let first = dataPoints.first?.close,
              let last = dataPoints.last?.close,
              first > 0 else { return nil }
        return ((last - first) / first) * 100.0
    }
    
    /// Get average volume
    public var averageVolume: Double? {
        let volumes = dataPoints.compactMap { $0.volume }
        guard !volumes.isEmpty else { return nil }
        return volumes.reduce(0, +) / Double(volumes.count)
    }
}

