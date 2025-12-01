//
//  FredModels.swift
//  FMHubControl
//
//  Models for FRED economic releases
//

import Foundation

public struct EconomicRelease: Identifiable, Codable {
    public let releaseId: Int
    public let releaseName: String
    public let releaseDate: String
    public let daysUntil: Int
    
    enum CodingKeys: String, CodingKey {
        case releaseId = "release_id"
        case releaseName = "release_name"
        case releaseDate = "release_date"
        case daysUntil = "days_until"
    }
    
    // Use combination of releaseId and releaseDate for unique ID
    // since the same release can occur on multiple dates
    public var id: String { "\(releaseId)-\(releaseDate)" }
    
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: releaseDate) {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        return releaseDate
    }
    
    public var daysUntilText: String {
        if daysUntil == 0 {
            return "Today"
        } else if daysUntil == 1 {
            return "Tomorrow"
        } else {
            return "\(daysUntil) days"
        }
    }
}

