import Foundation

struct ScholarProfile: Hashable, Codable {
    let id: String
    let name: String
    let url: String
    var isEnabled: Bool = true
    var recentGrowth: Int?
    var sortOrder: Int = 0
    
    init(id: String, name: String, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.url = "https://scholar.google.com/citations?user=\(id)&hl=en"
        self.sortOrder = sortOrder
    }
    
    static func == (lhs: ScholarProfile, rhs: ScholarProfile) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct CitationRecord: Codable {
    let profileId: String
    let citationCount: Int
    let timestamp: Date
    
    init(profileId: String, citationCount: Int, timestamp: Date = Date()) {
        self.profileId = profileId
        self.citationCount = citationCount
        self.timestamp = timestamp
    }
}

struct AppSettings: Codable {
    var profiles: [ScholarProfile] = []
    var refreshInterval: RefreshInterval = .hourly
    var showNotifications: Bool = true
    var autoLaunch: Bool = true
    var lastUpdateTime: Date?
    var isRefreshing: Bool = false
    
    enum RefreshInterval: String, CaseIterable, Codable {
        case fifteenMinutes = "15min"
        case thirtyMinutes = "30min"
        case hourly = "1hour"
        case threeHours = "3hours"
        case sixHours = "6hours"
        case daily = "24hours"
        
        var displayName: String {
            switch self {
            case .fifteenMinutes: return "Every 15 minutes"
            case .thirtyMinutes: return "Every 30 minutes"
            case .hourly: return "Every hour"
            case .threeHours: return "Every 3 hours"
            case .sixHours: return "Every 6 hours"
            case .daily: return "Once daily"
            }
        }
        
        var seconds: TimeInterval {
            switch self {
            case .fifteenMinutes: return 15 * 60
            case .thirtyMinutes: return 30 * 60
            case .hourly: return 60 * 60
            case .threeHours: return 3 * 60 * 60
            case .sixHours: return 6 * 60 * 60
            case .daily: return 24 * 60 * 60
            }
        }
    }
}

@MainActor protocol CitationManagerDelegate: AnyObject {
    func citationsUpdated(_ citations: [ScholarProfile: Int])
    func citationCheckFailed(_ error: Error)
    func refreshingStateChanged(_ isRefreshing: Bool)
}