
import XCTest
@testable import CiteBar

final class CiteBarTests: XCTestCase {
    
    var urlSession: URLSession!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        urlSession = URLSession(configuration: config)
    }

    override func tearDown() {
        MockURLProtocol.clearMocks()
        urlSession = nil
        super.tearDown()
    }

    func testScholarProfileCreation() {
        let profile = ScholarProfile(id: "testID", name: "Test Scholar")
        
        XCTAssertEqual(profile.id, "testID")
        XCTAssertEqual(profile.name, "Test Scholar")
        XCTAssertEqual(profile.url, "https://scholar.google.com/citations?user=testID&hl=en")
        XCTAssertTrue(profile.isEnabled)
    }
    
    func testScholarProfileEquality() {
        let profile1 = ScholarProfile(id: "same", name: "Scholar 1")
        let profile2 = ScholarProfile(id: "same", name: "Scholar 2")
        let profile3 = ScholarProfile(id: "different", name: "Scholar 3")
        
        XCTAssertEqual(profile1, profile2)
        XCTAssertNotEqual(profile1, profile3)
    }

    func testShouldRefreshOnStartup_WhenAnyProfileHasNoHistory_ReturnsTrue() {
        let now = Date()
        let shouldRefresh = CitationManager.shouldRefreshOnStartup(
            latestRecordDates: [now.addingTimeInterval(-60), nil],
            now: now,
            refreshInterval: 3600
        )

        XCTAssertTrue(shouldRefresh)
    }

    func testShouldRefreshOnStartup_WhenOldestRecordIsWithinInterval_ReturnsFalse() {
        let now = Date()
        let shouldRefresh = CitationManager.shouldRefreshOnStartup(
            latestRecordDates: [
                now.addingTimeInterval(-600),
                now.addingTimeInterval(-1200),
                now.addingTimeInterval(-1800)
            ],
            now: now,
            refreshInterval: 3600
        )

        XCTAssertFalse(shouldRefresh)
    }

    func testShouldRefreshOnStartup_WhenOldestRecordExceedsInterval_ReturnsTrue() {
        let now = Date()
        let shouldRefresh = CitationManager.shouldRefreshOnStartup(
            latestRecordDates: [
                now.addingTimeInterval(-600),
                now.addingTimeInterval(-7200),
                now.addingTimeInterval(-1800)
            ],
            now: now,
            refreshInterval: 3600
        )

        XCTAssertTrue(shouldRefresh)
    }

    func testShouldRefreshOnStartup_WithNoProfiles_ReturnsFalse() {
        let shouldRefresh = CitationManager.shouldRefreshOnStartup(
            latestRecordDates: [],
            refreshInterval: 3600
        )

        XCTAssertFalse(shouldRefresh)
    }
    
    func testRefreshIntervalSeconds() {
        XCTAssertEqual(AppSettings.RefreshInterval.allCases, [.twelveHours, .daily, .twoDays])
        XCTAssertEqual(AppSettings.RefreshInterval.twelveHours.seconds, 12 * 60 * 60)
        XCTAssertEqual(AppSettings.RefreshInterval.daily.seconds, 24 * 60 * 60)
        XCTAssertEqual(AppSettings.RefreshInterval.twoDays.seconds, 48 * 60 * 60)
    }

    func testRefreshIntervalBackwardCompatibilityDecoding() throws {
        struct Wrapper: Codable {
            let refreshInterval: AppSettings.RefreshInterval
        }

        let oldFifteenMinutes = try JSONEncoder().encode(["refreshInterval": "15min"])
        let oldThreeHours = try JSONEncoder().encode(["refreshInterval": "3hours"])
        let oldSixHours = try JSONEncoder().encode(["refreshInterval": "6hours"])
        let unknownValue = try JSONEncoder().encode(["refreshInterval": "legacy-value"])

        XCTAssertEqual(try JSONDecoder().decode(Wrapper.self, from: oldFifteenMinutes).refreshInterval, .twelveHours)
        XCTAssertEqual(try JSONDecoder().decode(Wrapper.self, from: oldThreeHours).refreshInterval, .twelveHours)
        XCTAssertEqual(try JSONDecoder().decode(Wrapper.self, from: oldSixHours).refreshInterval, .twelveHours)
        XCTAssertEqual(try JSONDecoder().decode(Wrapper.self, from: unknownValue).refreshInterval, .daily)
    }
    
    func testCitationRecordCreation() {
        let record = CitationRecord(profileId: "test", citationCount: 100)

        XCTAssertEqual(record.profileId, "test")
        XCTAssertEqual(record.citationCount, 100)
        XCTAssertNil(record.hIndex)
        XCTAssertNil(record.i10Index)
        XCTAssertNotNil(record.timestamp)
    }

    func testCitationRecordWithHIndex() {
        let record = CitationRecord(profileId: "test", citationCount: 100, hIndex: 25, i10Index: 12)

        XCTAssertEqual(record.profileId, "test")
        XCTAssertEqual(record.citationCount, 100)
        XCTAssertEqual(record.hIndex, 25)
        XCTAssertEqual(record.i10Index, 12)
        XCTAssertNotNil(record.timestamp)
    }

    func testComputeGrowthSummary_UsesActualBaselineDays() {
        let now = Date()
        let oldest = CitationRecord(profileId: "test", citationCount: 100, timestamp: Calendar.current.date(byAdding: .day, value: -5, to: now)!)
        let newest = CitationRecord(profileId: "test", citationCount: 112, timestamp: Calendar.current.date(byAdding: .day, value: -2, to: now)!)

        let summary = StorageManager.computeGrowthSummary(from: [oldest, newest])

        XCTAssertEqual(summary?.growth, 12)
        XCTAssertEqual(summary?.baselineDays, 3)
    }

    func testComputeGrowthSummary_SameDayRecordsClampToOneDay() {
        let now = Date()
        let first = CitationRecord(profileId: "test", citationCount: 100, timestamp: now)
        let second = CitationRecord(profileId: "test", citationCount: 103, timestamp: now)

        let summary = StorageManager.computeGrowthSummary(from: [first, second])

        XCTAssertEqual(summary?.growth, 3)
        XCTAssertEqual(summary?.baselineDays, 1)
    }

    func testComputeRecentGrowthSummary_ShowsFullWindowWhenHistoryIsLongEnough() {
        let now = Date()
        let oldRecord = CitationRecord(profileId: "test", citationCount: 80, timestamp: Calendar.current.date(byAdding: .day, value: -40, to: now)!)
        let nearWindowStart = CitationRecord(profileId: "test", citationCount: 100, timestamp: Calendar.current.date(byAdding: .day, value: -29, to: now)!)
        let latest = CitationRecord(profileId: "test", citationCount: 130, timestamp: now)

        let summary = StorageManager.computeRecentGrowthSummary(from: [oldRecord, nearWindowStart, latest], days: 30)

        XCTAssertEqual(summary?.growth, 30)
        XCTAssertEqual(summary?.baselineDays, 30)
    }

    func testComputeRecentGrowthSummary_UsesActualDaysForNewProfiles() {
        let now = Date()
        let first = CitationRecord(profileId: "test", citationCount: 100, timestamp: Calendar.current.date(byAdding: .day, value: -5, to: now)!)
        let second = CitationRecord(profileId: "test", citationCount: 112, timestamp: now)

        let summary = StorageManager.computeRecentGrowthSummary(from: [first, second], days: 30)

        XCTAssertEqual(summary?.growth, 12)
        XCTAssertEqual(summary?.baselineDays, 5)
    }
    
    func testAppSettingsDefaults() {
        let settings = AppSettings()
        
        XCTAssertTrue(settings.profiles.isEmpty)
        XCTAssertEqual(settings.refreshInterval, .daily)
        XCTAssertTrue(settings.showNotifications)
        XCTAssertTrue(settings.autoLaunch)
        XCTAssertTrue(settings.showHIndexInMenu)
        XCTAssertTrue(settings.showI10IndexInMenu)
        XCTAssertTrue(settings.showTrendInMenu)
        XCTAssertEqual(settings.menuBarPrimaryMetric, .totalCitations)
    }

    func testAppSettingsBackwardCompatibilityDecodingDefaultsNewDisplayOptions() throws {
        let legacyJSON = """
        {
          "profiles": [],
          "refreshInterval": "1hour",
          "showNotifications": true,
          "autoLaunch": false,
          "isRefreshing": false
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(AppSettings.self, from: legacyJSON)
        XCTAssertTrue(decoded.showHIndexInMenu)
        XCTAssertTrue(decoded.showI10IndexInMenu)
        XCTAssertTrue(decoded.showTrendInMenu)
        XCTAssertEqual(decoded.menuBarPrimaryMetric, .totalCitations)
    }

    // New tests for CitationManager
    
    @MainActor
    func testFetchScholarMetrics_Success() async throws {
        let profile = ScholarProfile(id: "_5pgNWgAAAAJ", name: "Test User")
        guard let url = CitationManager.scholarProfileURL(for: profile.id) else {
            XCTFail("Invalid URL")
            return
        }
        
        let sampleHTMLData = MockURLProtocol.loadSampleData(from: "scholar_profile_sample", fileExtension: "html")
        XCTAssertNotNil(sampleHTMLData, "Failed to load sample HTML file.")

        MockURLProtocol.setMockResponse(for: url, result: .success(sampleHTMLData!))
        
        let citationManager = CitationManager(urlSession: urlSession)
        
        let metrics = try await citationManager.fetchScholarMetrics(for: profile)
        
        XCTAssertEqual(metrics.citationCount, 98, "Citation count should be parsed correctly from the sample HTML.")
        XCTAssertEqual(metrics.hIndex, 4, "h-index should be parsed correctly from the sample HTML.")
        XCTAssertEqual(metrics.i10Index, 2, "i10-index should be parsed correctly from the sample HTML.")
        XCTAssertEqual(metrics.citationsByYear?[2022], 3, "2022 yearly citations should be parsed from the citation graph.")
        XCTAssertEqual(metrics.citationsByYear?[2023], 10, "2023 yearly citations should be parsed from the citation graph.")
        XCTAssertEqual(metrics.citationsByYear?[2024], 59, "2024 yearly citations should be parsed from the citation graph.")
        XCTAssertEqual(metrics.citationsByYear?[2025], 25, "2025 yearly citations should be parsed from the citation graph.")

        XCTAssertEqual(metrics.papers.count, 15)
        XCTAssertEqual(metrics.papers.first?.id, "_5pgNWgAAAAJ:IjCSPb-OGe4C")
        XCTAssertEqual(metrics.papers.first?.citations, 50)
        XCTAssertEqual(
            metrics.papers.first?.citedByURL,
            "https://scholar.google.com/scholar?oi=bibs&hl=en&cites=10836885476083945808"
        )
        XCTAssertEqual(metrics.papers.last?.citations, 0, "Uncited papers have an empty count link.")
        XCTAssertNil(metrics.papers.last?.citedByURL)
        // Sorted counts 50, 21, 7, 7, 3: h=4, and h=5 needs the fifth paper to gain 2.
        XCTAssertEqual(StorageManager.computeCitationsToNextHIndex(hIndex: 4, papers: metrics.papers), 2)
    }

    func testComputePaperGains_ReportsOnlyIncreasesOnKnownPapers() {
        let previous = [
            ScholarPaper(id: "a", title: "A", citations: 10, citedByURL: "https://a"),
            ScholarPaper(id: "b", title: "B", citations: 5, citedByURL: nil),
            ScholarPaper(id: "c", title: "C", citations: 3, citedByURL: nil)
        ]
        let current = [
            ScholarPaper(id: "a", title: "A", citations: 12, citedByURL: "https://a"),
            ScholarPaper(id: "b", title: "B", citations: 4, citedByURL: nil), // Scholar recount: ignored
            ScholarPaper(id: "c", title: "C", citations: 6, citedByURL: nil),
            ScholarPaper(id: "new", title: "New", citations: 9, citedByURL: nil) // not in baseline: ignored
        ]

        let gains = StorageManager.computePaperGains(previous: previous, current: current)

        XCTAssertEqual(gains.map(\.title), ["C", "A"], "Largest gain first")
        XCTAssertEqual(gains.map(\.delta), [3, 2])
        XCTAssertEqual(StorageManager.computePaperGains(previous: [], current: current), [], "First sight is a baseline")
    }

    func testComputeCitationsToNextHIndex() {
        func papers(_ counts: [Int]) -> [ScholarPaper] {
            counts.enumerated().map { ScholarPaper(id: "\($0.offset)", title: "", citations: $0.element, citedByURL: nil) }
        }
        XCTAssertEqual(StorageManager.computeCitationsToNextHIndex(hIndex: 3, papers: papers([9, 4, 3, 3, 1])), 2)
        XCTAssertEqual(StorageManager.computeCitationsToNextHIndex(hIndex: 0, papers: papers([0])), 1)
        XCTAssertNil(StorageManager.computeCitationsToNextHIndex(hIndex: 2, papers: papers([5, 5])), "Needs h+1 papers")
    }

    func testIsRateLimitResponse() {
        let profilePage = "<table id=\"gsc_rsb_st\"></table>Detecting unusual traffic from your computer network"
        XCTAssertTrue(CitationManager.isRateLimitResponse(statusCode: 429, url: nil, html: ""))
        XCTAssertTrue(CitationManager.isRateLimitResponse(
            statusCode: 200,
            url: URL(string: "https://www.google.com/sorry/index?continue=x"),
            html: ""
        ))
        XCTAssertTrue(CitationManager.isRateLimitResponse(statusCode: 200, url: nil, html: "<form id=\"gs_captcha_f\">"))
        XCTAssertFalse(CitationManager.isRateLimitResponse(statusCode: 200, url: nil, html: profilePage))
        XCTAssertFalse(CitationManager.isRateLimitResponse(statusCode: 500, url: nil, html: ""))
    }

    func testMilestoneMessages() {
        let previous = CitationRecord(profileId: "p", citationCount: 95, hIndex: 4, i10Index: 2)
        let current = CitationRecord(profileId: "p", citationCount: 260, hIndex: 5, i10Index: 2)

        XCTAssertEqual(
            CitationManager.milestoneMessages(name: "Ada", previous: previous, current: current),
            ["Ada passed 250 citations", "Ada's h-index rose to 5"]
        )
        XCTAssertEqual(CitationManager.milestoneMessages(name: "Ada", previous: current, current: current), [])
    }

    func testChangeNotificationText() {
        let gain = PaperGain(title: "Attention Is All You Need", delta: 2, citedByURL: "https://cites")
        let single = CitationManager.changeNotificationText(for: [
            .init(name: "Ada", citationDelta: 3, paperGains: [gain, gain], profileURL: "https://profile")
        ])
        XCTAssertEqual(single?.title, "+3 new citations")
        XCTAssertEqual(single?.body, "“Attention Is All You Need” +2 · 1 more paper")
        XCTAssertEqual(single?.url, "https://cites")

        let multiple = CitationManager.changeNotificationText(for: [
            .init(name: "Ada", citationDelta: 2, paperGains: [gain], profileURL: "https://ada"),
            .init(name: "Bob", citationDelta: -1, paperGains: [], profileURL: "https://bob")
        ])
        XCTAssertEqual(multiple?.title, "+1 new citation")
        XCTAssertEqual(multiple?.body, "Ada: “Attention Is All You Need” +2\nBob -1")

        XCTAssertNil(CitationManager.changeNotificationText(for: []))
    }

    @MainActor
    func testFetchScholarDisplayName_FromProfilePage() async {
        let profileID = "_5pgNWgAAAAJ"
        guard let url = CitationManager.scholarProfileURL(for: profileID) else {
            XCTFail("Invalid URL")
            return
        }

        guard let sampleHTMLData = MockURLProtocol.loadSampleData(from: "scholar_profile_sample", fileExtension: "html") else {
            XCTFail("Failed to load sample HTML file.")
            return
        }

        MockURLProtocol.setMockResponse(for: url, result: .success(sampleHTMLData))
        let citationManager = CitationManager(urlSession: urlSession)

        let name = await citationManager.fetchScholarDisplayName(for: profileID)
        XCTAssertEqual(name, "Hongming Chip Li")
    }

    @MainActor
    func testFetchScholarProfileSnapshot_ContainsNameAndMetrics() async {
        let profileID = "_5pgNWgAAAAJ"
        guard let url = CitationManager.scholarProfileURL(for: profileID) else {
            XCTFail("Invalid URL")
            return
        }

        guard let sampleHTMLData = MockURLProtocol.loadSampleData(from: "scholar_profile_sample", fileExtension: "html") else {
            XCTFail("Failed to load sample HTML file.")
            return
        }

        MockURLProtocol.setMockResponse(for: url, result: .success(sampleHTMLData))
        let citationManager = CitationManager(urlSession: urlSession)

        let snapshot = await citationManager.fetchScholarProfileSnapshot(for: profileID)
        XCTAssertEqual(snapshot?.profileID, profileID)
        XCTAssertEqual(snapshot?.displayName, "Hongming Chip Li")
        XCTAssertEqual(snapshot?.metrics?.citationCount, 98)
        XCTAssertEqual(snapshot?.metrics?.hIndex, 4)
        XCTAssertEqual(snapshot?.metrics?.i10Index, 2)
    }

    @MainActor
    func testFetchScholarDisplayName_FromOgTitleFallback() async {
        let profileID = "fallback123"
        guard let url = CitationManager.scholarProfileURL(for: profileID) else {
            XCTFail("Invalid URL")
            return
        }

        let html = """
        <!doctype html>
        <html>
          <head>
            <meta property="og:title" content="Fallback Scholar">
          </head>
          <body></body>
        </html>
        """

        guard let data = html.data(using: .utf8) else {
            XCTFail("Failed to encode HTML test fixture.")
            return
        }

        MockURLProtocol.setMockResponse(for: url, result: .success(data))
        let citationManager = CitationManager(urlSession: urlSession)

        let name = await citationManager.fetchScholarDisplayName(for: profileID)
        XCTAssertEqual(name, "Fallback Scholar")
    }
    
    @MainActor
    func testFetchScholarMetrics_NetworkError() async throws {
        let profile = ScholarProfile(id: "error_user", name: "Error User")
        guard let url = CitationManager.scholarProfileURL(for: profile.id) else {
            XCTFail("Invalid URL")
            return
        }
        
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        MockURLProtocol.setMockResponse(for: url, result: .failure(networkError))
        
        let citationManager = CitationManager(urlSession: urlSession)
        citationManager.requestRetryDelays = [0, 0]
        
        do {
            _ = try await citationManager.fetchScholarMetrics(for: profile)
            XCTFail("Expected fetchScholarMetrics to throw an error, but it did not.")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NSURLErrorDomain)
            XCTAssertEqual(nsError.code, NSURLErrorNotConnectedToInternet)
        }
    }

    @MainActor
    func testStatsCardRendersAtTwiceSocialSize() throws {
        var metrics = ProfileMetrics(
            citationCount: 1_284,
            hIndex: 13,
            i10Index: 15,
            citationsByYear: [2019: 12, 2020: 40, 2021: 88, 2022: 140, 2023: 205, 2024: 301, 2025: 347, 2026: 312]
        )
        metrics.topPapers = [
            ScholarPaper(id: "a", title: "Intelligent Productivity Transformation: Corporate Market Demand Forecasting with the Aid of an AI Virtual Assistant", citations: 412, citedByURL: nil),
            ScholarPaper(id: "b", title: "A Human-Centered Framework for Transparent, Responsible, and Collaborative AI-Assisted Instructional Design", citations: 208, citedByURL: nil),
            ScholarPaper(id: "c", title: "Post-pandemic Reflections", citations: 97, citedByURL: nil)
        ]
        let png = try XCTUnwrap(StatsCard(name: "Hongming (Chip) Li", metrics: metrics, recentGrowth: 27, recentGrowthDays: 30).pngData())
        let image = try XCTUnwrap(NSBitmapImageRep(data: png))
        XCTAssertEqual(image.pixelsWide, 1800)
        XCTAssertEqual(image.pixelsHigh, 2400)
        if let preview = ProcessInfo.processInfo.environment["CITEBAR_CARD_PREVIEW"] {
            try png.write(to: URL(fileURLWithPath: preview))
        }
    }

    func testScholarIDParser() {
        let pasted = """
        Ada: https://scholar.google.com/citations?user=_5pgNWgAAAAJ&hl=en
        https://scholar.google.com/citations?hl=en&user=XoZzqwgAAAAJ and https://scholar.google.com/citations?user=C9Wb_2cAAAAJ
        oP3xHMMAAAAJ
        not an id
        https://scholar.google.com/citations?user=_5pgNWgAAAAJ
        """
        XCTAssertEqual(
            ScholarIDParser.ids(in: pasted),
            ["_5pgNWgAAAAJ", "XoZzqwgAAAAJ", "C9Wb_2cAAAAJ", "oP3xHMMAAAAJ"]
        )
        XCTAssertEqual(ScholarIDParser.ids(in: ""), [])
    }

    func testRetryDelayEscalatesAndCaps() {
        XCTAssertEqual(CitationManager.retryDelay(afterFailedCycles: 1, rateLimited: false), 5 * 60)
        XCTAssertEqual(CitationManager.retryDelay(afterFailedCycles: 3, rateLimited: false), 20 * 60)
        XCTAssertEqual(CitationManager.retryDelay(afterFailedCycles: 10, rateLimited: false), 60 * 60)
        XCTAssertEqual(CitationManager.retryDelay(afterFailedCycles: 1, rateLimited: true), 15 * 60)
        XCTAssertEqual(CitationManager.retryDelay(afterFailedCycles: 10, rateLimited: true), 4 * 60 * 60)
    }

    func testIsTransient() {
        XCTAssertTrue(CitationManager.isTransient(URLError(.timedOut)))
        XCTAssertTrue(CitationManager.isTransient(URLError(.networkConnectionLost)))
        XCTAssertTrue(CitationManager.isTransient(CitationError.serverError))
        XCTAssertFalse(CitationManager.isTransient(CitationError.rateLimited))
        XCTAssertFalse(CitationManager.isTransient(CitationError.profileNotFound))
        XCTAssertFalse(CitationManager.isTransient(URLError(.badURL)))
    }
}
