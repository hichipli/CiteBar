import Foundation

struct ScholarProfile: Hashable, Codable {
    let id: String
    let name: String
    let url: String
    var isEnabled: Bool = true
    var recentGrowth: Int?
    var recentGrowthDays: Int?
    var sortOrder: Int = 0
    /// Optional group such as a lab or a set of collaborators; nil means ungrouped.
    var group: String?
    
    init(id: String, name: String, sortOrder: Int = 0, group: String? = nil) {
        self.id = id
        self.name = name
        self.url = "https://scholar.google.com/citations?user=\(id)&hl=en"
        self.sortOrder = sortOrder
        self.group = group
    }

    /// Same profile under a new display name, keeping order, group, and state.
    func renamed(to newName: String) -> ScholarProfile {
        var copy = ScholarProfile(id: id, name: newName, sortOrder: sortOrder, group: group)
        copy.isEnabled = isEnabled
        copy.recentGrowth = recentGrowth
        copy.recentGrowthDays = recentGrowthDays
        return copy
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
    let citationsByYear: [Int: Int]?
    let papers: [ScholarPaper]

    init(citationCount: Int, hIndex: Int? = nil, i10Index: Int? = nil, citationsByYear: [Int: Int]? = nil, papers: [ScholarPaper] = []) {
        self.citationCount = citationCount
        self.hIndex = hIndex
        self.i10Index = i10Index
        self.citationsByYear = citationsByYear
        self.papers = papers
    }
}

/// One row of the publication list on a Scholar profile page.
struct ScholarPaper: Codable, Equatable {
    let id: String
    let title: String
    let citations: Int
    let citedByURL: String?
}

struct PaperGain: Codable, Equatable {
    let title: String
    let delta: Int
    let citedByURL: String?

    /// Quoted title short enough for a menu line or notification.
    var shortTitle: String {
        let limit = 48
        let text = title.count > limit ? title.prefix(limit - 1).trimmingCharacters(in: .whitespaces) + "…" : title
        return "“\(text)”"
    }
}

/// Latest publication list for a profile plus the most recent per-paper gains.
struct ProfilePapers: Codable {
    var papers: [ScholarPaper]
    var lastGains: [PaperGain] = []
    var lastGainDate: Date?
}

struct CitationRecord: Codable {
    let profileId: String
    let citationCount: Int
    let hIndex: Int?
    let i10Index: Int?
    let citationsByYear: [Int: Int]?
    let timestamp: Date

    init(profileId: String, citationCount: Int, hIndex: Int? = nil, i10Index: Int? = nil, citationsByYear: [Int: Int]? = nil, timestamp: Date = Date()) {
        self.profileId = profileId
        self.citationCount = citationCount
        self.hIndex = hIndex
        self.i10Index = i10Index
        self.citationsByYear = citationsByYear
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
    var showHIndexInMenu: Bool = true
    var showI10IndexInMenu: Bool = true
    var showTrendInMenu: Bool = true
    var menuBarPrimaryMetric: MenuBarPrimaryMetric = .totalCitations
    /// Set when Google Scholar rate-limits us; scheduled refreshes wait until then.
    var scholarPausedUntil: Date?

    enum CodingKeys: String, CodingKey {
        case profiles
        case refreshInterval
        case showNotifications
        case autoLaunch
        case lastUpdateTime
        case isRefreshing
        case showHIndexInMenu
        case showI10IndexInMenu
        case showTrendInMenu
        case menuBarPrimaryMetric
        case scholarPausedUntil
    }

    enum MenuBarPrimaryMetric: String, CaseIterable, Codable {
        case totalCitations = "totalCitations"
        case currentYearCitations = "currentYearCitations"

        var displayName: String {
            switch self {
            case .totalCitations:
                return "Total citations"
            case .currentYearCitations:
                return "Current year citations"
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = MenuBarPrimaryMetric(rawValue: rawValue) ?? .totalCitations
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try container.decodeIfPresent([ScholarProfile].self, forKey: .profiles) ?? []
        refreshInterval = try container.decodeIfPresent(RefreshInterval.self, forKey: .refreshInterval) ?? .daily
        showNotifications = try container.decodeIfPresent(Bool.self, forKey: .showNotifications) ?? true
        autoLaunch = try container.decodeIfPresent(Bool.self, forKey: .autoLaunch) ?? true
        lastUpdateTime = try container.decodeIfPresent(Date.self, forKey: .lastUpdateTime)
        isRefreshing = try container.decodeIfPresent(Bool.self, forKey: .isRefreshing) ?? false
        showHIndexInMenu = try container.decodeIfPresent(Bool.self, forKey: .showHIndexInMenu) ?? true
        showI10IndexInMenu = try container.decodeIfPresent(Bool.self, forKey: .showI10IndexInMenu) ?? true
        showTrendInMenu = try container.decodeIfPresent(Bool.self, forKey: .showTrendInMenu) ?? true
        menuBarPrimaryMetric = try container.decodeIfPresent(MenuBarPrimaryMetric.self, forKey: .menuBarPrimaryMetric) ?? .totalCitations
        scholarPausedUntil = try container.decodeIfPresent(Date.self, forKey: .scholarPausedUntil)
    }
    
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
    let citationsByYear: [Int: Int]?
    /// Citations still needed to reach the next h-index, when the paper list allows computing it.
    var citationsToNextHIndex: Int?
    var recentPaperGains: [PaperGain] = []
    /// Most cited papers, for the stats card.
    var topPapers: [ScholarPaper] = []

    init(citationCount: Int, hIndex: Int? = nil, i10Index: Int? = nil, citationsByYear: [Int: Int]? = nil) {
        self.citationCount = citationCount
        self.hIndex = hIndex
        self.i10Index = i10Index
        self.citationsByYear = citationsByYear
    }

    var currentYearCitations: Int? {
        guard let citationsByYear else { return nil }
        let currentYear = Calendar.current.component(.year, from: Date())
        return citationsByYear[currentYear] ?? 0
    }
}

/// Why the last refresh left profiles unfetched, and when CiteBar retries on its own.
enum RefreshIssue: Equatable {
    case rateLimited(retryAt: Date)
    case networkUnavailable(retryAt: Date)

    var retryAt: Date {
        switch self {
        case .rateLimited(let date), .networkUnavailable(let date):
            return date
        }
    }
}

@MainActor protocol CitationManagerDelegate: AnyObject {
    func citationsUpdated(_ citations: [ScholarProfile: ProfileMetrics])
    func citationCheckFailed(_ error: Error)
    func refreshingStateChanged(_ isRefreshing: Bool)
    func refreshIssueChanged(_ issue: RefreshIssue?, failedProfileIDs: Set<String>)
}
