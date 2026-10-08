
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
        XCTAssertEqual(metrics.papers.first?.year, 2024)
        XCTAssertEqual(metrics.papers.last?.citations, 0, "Uncited papers have an empty count link.")
        XCTAssertNil(metrics.papers.last?.citedByURL)
        // Sorted counts 50, 21, 7, 7, 3: h=4, and h=5 needs the fifth paper to gain 2.
        let step = try XCTUnwrap(StorageManager.computeNextHIndexStep(hIndex: 4, papers: metrics.papers))
        XCTAssertEqual(step.target, 5)
        XCTAssertEqual(step.needs.map(\.needed), [2])
        XCTAssertEqual(step.needs.first?.paper.citations, 3)
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
        XCTAssertEqual(gains.map(\.paperID), ["c", "a"])
        XCTAssertEqual(gains.map(\.delta), [3, 2])
        XCTAssertEqual(StorageManager.computePaperGains(previous: [], current: current), [], "First sight is a baseline")
    }

    func testComputeNextHIndexStep() {
        func papers(_ counts: [Int]) -> [ScholarPaper] {
            counts.enumerated().map { ScholarPaper(id: "u:\($0.offset)", title: "P\($0.offset)", citations: $0.element, citedByURL: nil) }
        }
        // h=3 -> 4: the top four are 9, 4, 3, 3, so the two 3s need one more each.
        let step = StorageManager.computeNextHIndexStep(hIndex: 3, papers: papers([9, 4, 3, 3, 1]))
        XCTAssertEqual(step?.target, 4)
        XCTAssertEqual(step?.needs.map(\.paper.title), ["P2", "P3"])
        XCTAssertEqual(step?.total, 2)
        XCTAssertEqual(StorageManager.computeNextHIndexStep(hIndex: 0, papers: papers([0]))?.total, 1)
        XCTAssertNil(StorageManager.computeNextHIndexStep(hIndex: 2, papers: papers([5, 5])), "Needs h+1 papers")
        XCTAssertNil(StorageManager.computeNextHIndexStep(hIndex: 1, papers: papers([5, 5])), "Already qualifies")
        XCTAssertEqual(
            ScholarPaper(id: "USER1:PAPER9", title: "", citations: 0, citedByURL: nil).scholarURL,
            "https://scholar.google.com/citations?view_op=view_citation&hl=en&user=USER1&citation_for_view=USER1:PAPER9"
        )
    }

    func testMergeHistoryDeduplicatesAndKeepsNewest() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        func record(_ id: String, _ count: Int, _ day: Double) -> CitationRecord {
            CitationRecord(profileId: id, citationCount: count, timestamp: base.addingTimeInterval(day * 86_400))
        }
        let existing = [record("a", 10, 0), record("a", 12, 2)]
        let incoming = [record("a", 10, 0), record("a", 11, 1), record("b", 5, 1)]

        let merged = StorageManager.mergeHistory(existing: existing, incoming: incoming, limitPerProfile: 1000)
        XCTAssertEqual(merged.map(\.citationCount), [10, 11, 5, 12], "Union in time order, duplicate dropped")

        let trimmed = StorageManager.mergeHistory(existing: existing, incoming: incoming, limitPerProfile: 2)
        XCTAssertEqual(trimmed.filter { $0.profileId == "a" }.map(\.citationCount), [11, 12])
    }

    @MainActor
    func testArchiveRoundTrip() throws {
        var settings = AppSettings()
        settings.profiles = [ScholarProfile(id: "_5pgNWgAAAAJ", name: "Ada", group: "Lab")]
        let archive = CiteBarArchive(
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            appVersion: "1.6.1",
            deviceName: "Test Mac",
            settings: settings,
            history: [CitationRecord(profileId: "_5pgNWgAAAAJ", citationCount: 98, hIndex: 4, timestamp: Date(timeIntervalSince1970: 1_700_000_000))],
            papers: ["_5pgNWgAAAAJ": ProfilePapers(papers: [ScholarPaper(id: "x:1", title: "T", citations: 3, citedByURL: nil)])]
        )
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("citebar-archive-test.json")
        try DataManager.encode(archive).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let decoded = try DataManager.readArchive(at: url)
        XCTAssertEqual(decoded.format, 1)
        XCTAssertEqual(decoded.settings.profiles.first?.group, "Lab")
        XCTAssertEqual(decoded.history.first?.citationCount, 98)
        XCTAssertEqual(decoded.papers["_5pgNWgAAAAJ"]?.papers.first?.citations, 3)
        XCTAssertEqual(decoded.exportedAt, archive.exportedAt)
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

        // A watched paper's gain leads, marked with a star, even when it is smaller.
        let big = PaperGain(title: "Big", delta: 5, citedByURL: nil, paperID: "u:1")
        let watched = PaperGain(title: "Mine", delta: 1, citedByURL: "https://mine", paperID: "u:2")
        let starred = CitationManager.changeNotificationText(
            for: [.init(name: "Ada", citationDelta: 6, paperGains: [big, watched], profileURL: "https://ada")],
            watchedPaperIDs: ["u:2"]
        )
        XCTAssertEqual(starred?.body, "★ “Mine” +1 · 1 more paper")
        XCTAssertEqual(starred?.url, "https://mine")
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
    func testStatsCardRendersEveryThemeAtTwiceSocialSize() throws {
        var content = CardContent(name: "Elena Varga", date: Date(), citations: 1_284)
        content.hIndex = 13
        content.i10Index = 15
        content.chart = [2023: 205, 2024: 301, 2025: 347, 2026: 312]
        content.yearCitations = 312
        content.milestone = 1_000
        content.note = "Thank you to everyone who cited our work."
        content.papers = [
            ScholarPaper(id: "a", title: "Measuring Productive Struggle in Online Mathematics Practice", citations: 412, citedByURL: nil, year: 2019)
        ]
        for theme in CardTheme.allCases {
            let png = try XCTUnwrap(StatsCard(content: content, theme: theme).pngData(), "\(theme)")
            let image = try XCTUnwrap(NSBitmapImageRep(data: png))
            XCTAssertEqual(image.pixelsWide, 1800, "\(theme)")
            XCTAssertEqual(image.pixelsHigh, 2400, "\(theme)")
            if let folder = ProcessInfo.processInfo.environment["CITEBAR_CARD_PREVIEW_DIR"] {
                try png.write(to: URL(fileURLWithPath: folder).appendingPathComponent("card-\(theme.rawValue).png"))
            }
        }
    }

    func testGazetteHeadlines() {
        var content = CardContent(name: "Hongming (Chip) Li", date: Date(timeIntervalSince1970: 1_791_000_000), citations: 1_284)
        content.milestone = 1_000
        XCTAssertEqual(StatsCard.gazetteHeadline(for: content).headline, "Li Passes 1,000 Citations")

        content.milestone = nil
        content.growth = CardGrowthValue(value: 27, days: 30, isPartial: false, startDate: Date())
        XCTAssertEqual(StatsCard.gazetteHeadline(for: content).headline, "Li Cited 27 Times in the Last 30 Days")

        content.growth = nil
        XCTAssertEqual(StatsCard.gazetteHeadline(for: content).headline, "Li's Work Now Cited 1,284 Times")
    }

    func testTimelinePointsEstimatesAndMoments() {
        let calendar = Calendar.current
        func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 10) -> Date {
            calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
        }
        // Like a profile first tracked by an older CiteBar: only the latest record has yearly counts.
        let records = [
            CitationRecord(profileId: "p", citationCount: 95, hIndex: 4, timestamp: date(2025, 1, 10, 9)),
            CitationRecord(profileId: "p", citationCount: 96, hIndex: 4, timestamp: date(2025, 1, 10, 18)),
            CitationRecord(profileId: "p", citationCount: 101, hIndex: 5, timestamp: date(2025, 2, 1)),
            CitationRecord(profileId: "p", citationCount: 110, hIndex: 5,
                           citationsByYear: [2023: 40, 2024: 50, 2025: 20], timestamp: date(2025, 3, 1))
        ]
        let timeline = CitationTimeline(records: records)

        // Year-end estimates (2023: 40, 2024: 90), milestone points in between, then one point per tracked day.
        XCTAssertEqual(timeline.points.map(\.citations), [10, 25, 40, 50, 90, 96, 101, 110])
        XCTAssertEqual(timeline.points.map(\.isEstimate), [true, true, true, true, true, false, false, false])
        XCTAssertEqual(timeline.firstTrackedDate, date(2025, 1, 10, 18))

        XCTAssertEqual(timeline.moments.map(\.kind), [.citations(10), .citations(25), .citations(50), .citations(100), .hIndex(5)])
        XCTAssertTrue(timeline.moments[0].isEstimate)
        // 10 of 2023's 40 citations: about a quarter of the way through 2023.
        XCTAssertEqual(calendar.dateComponents([.year, .month], from: timeline.moments[0].date), DateComponents(year: 2023, month: 4))
        // 50 is 10 into 2024's 50: about a fifth of the way through 2024.
        XCTAssertEqual(calendar.dateComponents([.year, .month], from: timeline.moments[2].date), DateComponents(year: 2024, month: 3))
        XCTAssertEqual(timeline.point(at: timeline.moments[2].date)?.citations, 50)
        XCTAssertFalse(timeline.moments[3].isEstimate, "100 was crossed between two tracked days")
        XCTAssertEqual(timeline.milestone(on: date(2025, 2, 1, 20)), 100)

        XCTAssertEqual(timeline.point(at: date(2025, 2, 15))?.citations, 101)
        let growth = timeline.growth(endingAt: date(2025, 3, 2), days: 30)
        XCTAssertEqual(growth?.value, 14, "From the Jan 10 point (96) to Mar 1 (110), since nothing is 30 days back")

        // A dip and recovery is not a new milestone.
        let wobbly = CitationTimeline(records: [
            CitationRecord(profileId: "p", citationCount: 98, hIndex: 5, timestamp: date(2025, 6, 1)),
            CitationRecord(profileId: "p", citationCount: 101, hIndex: 6, timestamp: date(2025, 6, 2)),
            CitationRecord(profileId: "p", citationCount: 99, hIndex: 5, timestamp: date(2025, 6, 3)),
            CitationRecord(profileId: "p", citationCount: 102, hIndex: 6, timestamp: date(2025, 6, 4))
        ])
        XCTAssertEqual(wobbly.moments.map(\.kind), [.citations(100), .hIndex(6)])

        // Without yearly counts there's no estimated past, so milestones already passed have no date.
        let untracked = CitationTimeline(records: [
            CitationRecord(profileId: "p", citationCount: 1_167, timestamp: date(2025, 6, 26)),
            CitationRecord(profileId: "p", citationCount: 1_170, timestamp: date(2025, 6, 27))
        ])
        XCTAssertEqual(untracked.points.count, 2)
        XCTAssertTrue(untracked.moments.isEmpty)
    }

    func testYearStartSnapshots() {
        let calendar = Calendar.current
        let paper = { (citations: Int) in
            ScholarPaper(id: "u:p1", title: "A", citations: citations, citedByURL: nil)
        }
        let october = calendar.date(from: DateComponents(year: 2026, month: 10, day: 9))!
        let november = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2))!
        let january = calendar.date(from: DateComponents(year: 2027, month: 1, day: 3))!

        var starts = StorageManager.recordingYearStart(nil, papers: [paper(40)], now: october)
        starts = StorageManager.recordingYearStart(starts, papers: [paper(45)], now: november)
        starts = StorageManager.recordingYearStart(starts, papers: [paper(52)], now: january)

        XCTAssertEqual(starts[2026], PaperSnapshot(date: october, citations: ["u:p1": 40]), "The first refresh of the year stays")
        XCTAssertEqual(starts[2027]?.citations["u:p1"], 52)
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
