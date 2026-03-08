import Foundation

struct ScholarProfile: Hashable, Codable {
    let id: String
    let name: String
    let url: String
    var isEnabled: Bool = true
    var recentGrowth: Int?
    var recentGrowthDays: Int?
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

struct ScholarMetrics {
    let citationCount: Int
    let hIndex: Int?
    let i10Index: Int?
}

struct CitationRecord: Codable {
    let profileId: String
    let citationCount: Int
    let hIndex: Int?
    let i10Index: Int?
    let timestamp: Date

    init(profileId: String, citationCount: Int, hIndex: Int? = nil, i10Index: Int? = nil, timestamp: Date = Date()) {
        self.profileId = profileId
        self.citationCount = citationCount
        self.hIndex = hIndex
        self.i10Index = i10Index
        self.timestamp = timestamp
    }
}

struct AppSettings: Codable {
    var profiles: [ScholarProfile] = []
    var refreshInterval: RefreshInterval = .daily
    var showNotifications: Bool = true
    var autoLaunch: Bool = true
    var lastUpdateTime: Date?
    var isRefreshing: Bool = false
    
    enum RefreshInterval: String, CaseIterable, Codable {
        case hourly = "1hour"
        case sixHours = "6hours"
        case daily = "24hours"
        case twoDays = "48hours"
        
        var displayName: String {
            switch self {
            case .hourly: return "Every hour"
            case .sixHours: return "Every 6 hours"
            case .daily: return "Once daily"
            case .twoDays: return "Every 2 days"
            }
        }
        
        var seconds: TimeInterval {
            switch self {
            case .hourly: return 60 * 60
            case .sixHours: return 6 * 60 * 60
            case .daily: return 24 * 60 * 60
            case .twoDays: return 48 * 60 * 60
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)

            switch rawValue {
            case Self.hourly.rawValue, "15min", "30min":
                self = .hourly
            case Self.sixHours.rawValue, "3hours":
                self = .sixHours
            case Self.daily.rawValue:
                self = .daily
            case Self.twoDays.rawValue:
                self = .twoDays
            default:
                self = .daily
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }
}

struct ProfileMetrics {
    let citationCount: Int
    let hIndex: Int?
    let i10Index: Int?
}

@MainActor protocol CitationManagerDelegate: AnyObject {
    func citationsUpdated(_ citations: [ScholarProfile: ProfileMetrics])
    func citationCheckFailed(_ error: Error)
    func refreshingStateChanged(_ isRefreshing: Bool)
}
