
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
    
    func testRefreshIntervalSeconds() {
        XCTAssertEqual(AppSettings.RefreshInterval.hourly.seconds, 60 * 60)
        XCTAssertEqual(AppSettings.RefreshInterval.sixHours.seconds, 6 * 60 * 60)
        XCTAssertEqual(AppSettings.RefreshInterval.daily.seconds, 24 * 60 * 60)
        XCTAssertEqual(AppSettings.RefreshInterval.twoDays.seconds, 48 * 60 * 60)
    }

    func testRefreshIntervalBackwardCompatibilityDecoding() throws {
        struct Wrapper: Codable {
            let refreshInterval: AppSettings.RefreshInterval
        }

        let oldFifteenMinutes = try JSONEncoder().encode(["refreshInterval": "15min"])
        let oldThreeHours = try JSONEncoder().encode(["refreshInterval": "3hours"])
        let unknownValue = try JSONEncoder().encode(["refreshInterval": "legacy-value"])

        XCTAssertEqual(try JSONDecoder().decode(Wrapper.self, from: oldFifteenMinutes).refreshInterval, .hourly)
        XCTAssertEqual(try JSONDecoder().decode(Wrapper.self, from: oldThreeHours).refreshInterval, .sixHours)
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
    }

    // New tests for CitationManager
    
    @MainActor
    func testFetchScholarMetrics_Success() async throws {
        let profile = ScholarProfile(id: "_5pgNWgAAAAJ", name: "Test User")
        guard let url = URL(string: profile.url) else {
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
    }
    
    @MainActor
    func testFetchScholarMetrics_NetworkError() async throws {
        let profile = ScholarProfile(id: "error_user", name: "Error User")
        guard let url = URL(string: profile.url) else {
            XCTFail("Invalid URL")
            return
        }
        
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        MockURLProtocol.setMockResponse(for: url, result: .failure(networkError))
        
        let citationManager = CitationManager(urlSession: urlSession)
        
        do {
            _ = try await citationManager.fetchScholarMetrics(for: profile)
            XCTFail("Expected fetchScholarMetrics to throw an error, but it did not.")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, NSURLErrorDomain)
            XCTAssertEqual(nsError.code, NSURLErrorNotConnectedToInternet)
        }
    }
}
