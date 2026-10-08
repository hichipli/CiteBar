import Foundation
import SwiftSoup
import UserNotifications

@MainActor class CitationManager {
    struct ScholarProfileSnapshot {
        let profileID: String
        let displayName: String?
        let metrics: ScholarMetrics?
    }

    weak var delegate: CitationManagerDelegate?
    private let settingsManager = SettingsManager.shared
    private let storageManager = StorageManager()
    private var refreshTimer: Timer?
    private let urlSession: URLSession
    private var isChecking = false
    private var retryTimer: Timer?
    private var consecutiveFailedCycles = 0
    /// Waits before the 2nd and 3rd attempt of a request that failed on a network blip.
    var requestRetryDelays: [TimeInterval] = [2, 5]
    
    private static func makeURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }

    init(urlSession: URLSession = CitationManager.makeURLSession()) {
        self.urlSession = urlSession
        setupTimer()
        
        // Debug storage status at startup
#if DEBUG
        Task {
            let info = await storageManager.getStorageInfo()
            AppLog.debug("Storage status: \(info.recordCount) records, file exists: \(info.fileExists)")
            AppLog.debug("Storage path: \(info.filePath)")
            
            // If we have historical data, log which profiles have data
            if info.recordCount > 0 {
                let profileIDs = await storageManager.getProfileIDsWithHistory()
                AppLog.debug("Historical data available for profile IDs: \(profileIDs)")
            }
        }
#endif
    }
    
    deinit {
        // Timer cleanup will happen automatically when the object is deallocated
        // We can't call MainActor methods from deinit
    }
    
    private func setupTimer() {
        // Invalidate existing timer first
        refreshTimer?.invalidate()
        refreshTimer = nil
        
        let interval = settingsManager.settings.refreshInterval.seconds
        
        // Ensure timer is created on main queue
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    self.checkCitations()
                }
            }
        }
    }
    
    /// Scheduled and startup refreshes wait out a Scholar rate-limit pause (and make sure a
    /// retry is queued for when it ends); a refresh the user asked for runs anyway.
    /// `onlyProfileIDs` limits an automatic retry to the profiles that failed.
    func checkCitations(userInitiated: Bool = false, onlyProfileIDs: Set<String>? = nil) {
        guard !isChecking else { return }

        var profiles = settingsManager.settings.profiles.filter { $0.isEnabled }
        if let onlyProfileIDs {
            profiles = profiles.filter { onlyProfileIDs.contains($0.id) }
            guard !profiles.isEmpty else { return }
        }

        guard !profiles.isEmpty else {
            delegate?.citationsUpdated([:])
            return
        }

        if !userInitiated, let pausedUntil = settingsManager.settings.scholarPausedUntil, pausedUntil > Date() {
            AppLog.debug("Skipping refresh; Google Scholar rate-limit pause until \(pausedUntil)")
            if retryTimer == nil {
                scheduleRetry(at: pausedUntil, profileIDs: onlyProfileIDs)
            }
            return
        }

        if userInitiated {
            retryTimer?.invalidate()
            retryTimer = nil
        }

        isChecking = true
        // Set refreshing state
        settingsManager.setRefreshing(true)
        
        // Notify delegate to update UI with refreshing state
        delegate?.refreshingStateChanged(true)
        
        Task {
            await performCitationCheck(for: profiles)
        }
    }

    func fetchScholarProfileSnapshot(for profileID: String) async -> ScholarProfileSnapshot? {
        guard let url = Self.scholarProfileURL(for: profileID) else {
            return nil
        }

        do {
            let html = try await fetchScholarHTML(from: url)
            let displayName = parseScholarDisplayName(from: html)

            let metrics: ScholarMetrics?
            do {
                metrics = try parseScholarMetrics(from: html)
            } catch {
                AppLog.debug("Failed to parse scholar metrics from snapshot for profile ID \(profileID): \(error)")
                metrics = nil
            }

            guard displayName != nil || metrics != nil else {
                return nil
            }

            return ScholarProfileSnapshot(
                profileID: profileID,
                displayName: displayName,
                metrics: metrics
            )
        } catch {
            AppLog.debug("Failed to fetch scholar snapshot for profile ID \(profileID): \(error)")
            return nil
        }
    }

    func fetchScholarDisplayName(for profileID: String) async -> String? {
        await fetchScholarProfileSnapshot(for: profileID)?.displayName
    }

    func primeProfileData(
        for profile: ScholarProfile,
        prefetchedSnapshot: ScholarProfileSnapshot? = nil
    ) async -> ScholarProfileSnapshot? {
        let snapshot: ScholarProfileSnapshot?
        if let prefetchedSnapshot {
            snapshot = prefetchedSnapshot
        } else {
            snapshot = await fetchScholarProfileSnapshot(for: profile.id)
        }

        guard let snapshot else {
            AppLog.debug("No scholar snapshot available for profile \(profile.id); skipping immediate prime")
            return nil
        }

        guard let metrics = snapshot.metrics else {
            AppLog.debug("Scholar snapshot for profile \(profile.id) has no metrics; skipping immediate metric save")
            return snapshot
        }

        let record = CitationRecord(
            profileId: profile.id,
            citationCount: metrics.citationCount,
            hIndex: metrics.hIndex,
            i10Index: metrics.i10Index,
            citationsByYear: metrics.citationsByYear
        )
        await storageManager.saveCitationRecord(record)
        // Baseline for per-paper gains on the next refresh.
        _ = await storageManager.updatePapers(metrics.papers, for: profile.id)
        settingsManager.setLastUpdateTime(Date())

        return snapshot
    }

    nonisolated static func shouldRefreshOnStartup(
        latestRecordDates: [Date?],
        now: Date = Date(),
        refreshInterval: TimeInterval
    ) -> Bool {
        guard !latestRecordDates.isEmpty else {
            return false
        }

        // If any enabled profile has no local history yet, refresh immediately.
        if latestRecordDates.contains(where: { $0 == nil }) {
            return true
        }

        guard let oldestLatestRecord = latestRecordDates.compactMap({ $0 }).min() else {
            return true
        }

        let age = max(0, now.timeIntervalSince(oldestLatestRecord))
        return age >= refreshInterval
    }

    func shouldRefreshAtStartup() async -> Bool {
        let enabledProfiles = settingsManager.settings.profiles.filter { $0.isEnabled }
        guard !enabledProfiles.isEmpty else {
            return false
        }

        var latestRecordDates: [Date?] = []
        latestRecordDates.reserveCapacity(enabledProfiles.count)

        for profile in enabledProfiles {
            let latestRecord = await storageManager.getLatestRecord(for: profile.id)
            latestRecordDates.append(latestRecord?.timestamp)
        }

        let interval = settingsManager.settings.refreshInterval.seconds
        let shouldRefresh = Self.shouldRefreshOnStartup(
            latestRecordDates: latestRecordDates,
            refreshInterval: interval
        )

        AppLog.debug(
            "Startup refresh decision: enabledProfiles=\(enabledProfiles.count), intervalSeconds=\(Int(interval)), shouldRefresh=\(shouldRefresh)"
        )
        return shouldRefresh
    }
    
    struct ProfileChange {
        let name: String
        let citationDelta: Int
        let paperGains: [PaperGain]
        let profileURL: String
    }

    static let recentPaperGainWindow: TimeInterval = 7 * 24 * 60 * 60
    nonisolated static let citationMilestones = [10, 25, 50, 100, 250, 500, 1_000, 2_500, 5_000, 10_000, 25_000, 50_000, 100_000]

    private func performCitationCheck(for profiles: [ScholarProfile]) async {
        var changes: [ProfileChange] = []
        var milestones: [String] = []
        var rateLimited = false
        var succeeded = 0
        // Profiles still worth retrying: not yet fetched, or failed on a network blip.
        var pending = Set(profiles.map(\.id))

        for (index, profile) in profiles.enumerated() {
            // Be respectful to Google's servers, including after a failed request.
            if index > 0 {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }

            do {
                let metrics = try await fetchScholarMetrics(for: profile)
                let previousRecord = await storageManager.getLatestRecord(for: profile.id)
                let paperGains = await storageManager.updatePapers(metrics.papers, for: profile.id)

                let record = CitationRecord(
                    profileId: profile.id,
                    citationCount: metrics.citationCount,
                    hIndex: metrics.hIndex,
                    i10Index: metrics.i10Index,
                    citationsByYear: metrics.citationsByYear
                )
                await storageManager.saveCitationRecord(record)

                if let previousRecord {
                    let delta = metrics.citationCount - previousRecord.citationCount
                    if delta != 0 || !paperGains.isEmpty {
                        changes.append(ProfileChange(
                            name: profile.name,
                            citationDelta: delta,
                            paperGains: paperGains,
                            profileURL: profile.url
                        ))
                    }
                    milestones += Self.milestoneMessages(name: profile.name, previous: previousRecord, current: record)
                }

                succeeded += 1
                pending.remove(profile.id)

                AppLog.debug(
                    "Fetched \(profile.name): citations=\(metrics.citationCount), h=\(metrics.hIndex ?? -1), i10=\(metrics.i10Index ?? -1), papers=\(metrics.papers.count), paperGains=\(paperGains.count)"
                )
            } catch CitationError.rateLimited {
                // Further requests would only extend the block, so stop this cycle.
                AppLog.error("Google Scholar is rate-limiting this network; stopping refresh cycle")
                rateLimited = true
                break
            } catch {
                AppLog.error("Failed to fetch citations for \(profile.name): \(error)")
                // Don't let one profile failure stop the whole process; only network
                // failures are worth an automatic retry.
                if !Self.isTransient(error) {
                    pending.remove(profile.id)
                }
            }
        }

        let issue: RefreshIssue?
        if pending.isEmpty {
            consecutiveFailedCycles = 0
            retryTimer?.invalidate()
            retryTimer = nil
            settingsManager.setScholarPausedUntil(nil)
            issue = nil
        } else {
            consecutiveFailedCycles += 1
            let retryAt = Date().addingTimeInterval(
                Self.retryDelay(afterFailedCycles: consecutiveFailedCycles, rateLimited: rateLimited)
            )
            settingsManager.setScholarPausedUntil(rateLimited ? retryAt : nil)
            scheduleRetry(at: retryAt, profileIDs: pending)
            issue = rateLimited ? .rateLimited(retryAt: retryAt) : .networkUnavailable(retryAt: retryAt)
        }

        if succeeded > 0 {
            settingsManager.setLastUpdateTime(Date())
        }
        settingsManager.setRefreshing(false)
        isChecking = false
        delegate?.refreshingStateChanged(false)
        delegate?.refreshIssueChanged(issue, failedProfileIDs: pending)

        if succeeded > 0 {
            // Reload every profile from storage so ones that failed this cycle keep showing
            // their last known data.
            updateMenuBarWithCurrentData()
            notifyIfNeeded(changes: changes, milestones: milestones)
        } else {
            // Keep showing historical data when the network fails; only surface an
            // error when there is nothing stored for the active profiles.
            AppLog.debug("Refresh completed but no new data retrieved")
            let hasHistoricalData = await storageManager.hasHistoricalData(for: Set(profiles.map(\.id)))
            if !hasHistoricalData {
                delegate?.citationCheckFailed(rateLimited ? CitationError.rateLimited : CitationError.noDataAvailable)
            }
        }
    }

    private func scheduleRetry(at date: Date, profileIDs: Set<String>?) {
        retryTimer?.invalidate()
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.retryTimer = nil
                self?.checkCitations(onlyProfileIDs: profileIDs)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        retryTimer = timer
        AppLog.debug("Scheduled automatic retry at \(date) for \(profileIDs?.count ?? -1) profiles")
    }

    /// Wait before automatically retrying a cycle that left profiles unfetched. Network blips
    /// retry after 5, 10, 20, 40, then 60 minutes; Scholar rate limits after 15, 30, 60, 120,
    /// then 240 minutes. Refresh Now always works in the meantime.
    nonisolated static func retryDelay(afterFailedCycles count: Int, rateLimited: Bool) -> TimeInterval {
        let base: TimeInterval = rateLimited ? 15 * 60 : 5 * 60
        let cap: TimeInterval = rateLimited ? 4 * 60 * 60 : 60 * 60
        return min(cap, base * pow(2, Double(max(0, count - 1))))
    }

    /// Failures worth retrying soon: dropped or missing connections, timeouts, and 5xx.
    nonisolated static func isTransient(_ error: Error) -> Bool {
        if (error as? CitationError) == .serverError {
            return true
        }
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed, .internationalRoamingOff, .dataNotAllowed:
            return true
        default:
            return false
        }
    }

    /// Menu data for a profile: stored metrics plus growth and paper insights.
    private func displayData(for profile: ScholarProfile, record: CitationRecord) async -> (ScholarProfile, ProfileMetrics) {
        let growthSummary = await storageManager.calculateRecentGrowthSummary(for: profile.id)
        var updatedProfile = profile
        updatedProfile.recentGrowth = growthSummary?.growth
        updatedProfile.recentGrowthDays = growthSummary?.baselineDays

        var metrics = ProfileMetrics(
            citationCount: record.citationCount,
            hIndex: record.hIndex,
            i10Index: record.i10Index,
            citationsByYear: record.citationsByYear
        )
        if let profilePapers = await storageManager.getProfilePapers(for: profile.id) {
            if let hIndex = record.hIndex {
                metrics.citationsToNextHIndex = StorageManager.computeCitationsToNextHIndex(
                    hIndex: hIndex,
                    papers: profilePapers.papers
                )
            }
            metrics.topPapers = Array(profilePapers.papers.sorted { $0.citations > $1.citations }.prefix(3))
            if let gainDate = profilePapers.lastGainDate,
               Date().timeIntervalSince(gainDate) < Self.recentPaperGainWindow {
                metrics.recentPaperGains = profilePapers.lastGains
            }
        }
        return (updatedProfile, metrics)
    }

    nonisolated static func milestoneMessages(name: String, previous: CitationRecord, current: CitationRecord) -> [String] {
        var messages: [String] = []
        if let reached = citationMilestones.last(where: { previous.citationCount < $0 && current.citationCount >= $0 }) {
            let formatted = NumberFormatter.localizedString(from: NSNumber(value: reached), number: .decimal)
            messages.append("\(name) passed \(formatted) citations")
        }
        if let old = previous.hIndex, let new = current.hIndex, new > old {
            messages.append("\(name)'s h-index rose to \(new)")
        }
        if let old = previous.i10Index, let new = current.i10Index, new > old {
            messages.append("\(name)'s i10-index rose to \(new)")
        }
        return messages
    }

    /// Notification for a refresh that changed something; nil when nothing changed.
    nonisolated static func changeNotificationText(for changes: [ProfileChange]) -> (title: String, body: String, url: String?)? {
        guard let first = changes.first else { return nil }

        let totalDelta = changes.reduce(0) { $0 + $1.citationDelta }
        let title: String
        if totalDelta > 0 {
            title = totalDelta == 1 ? "+1 new citation" : "+\(totalDelta) new citations"
        } else {
            title = "Citation counts changed"
        }

        let showNames = changes.count > 1
        let lines = changes.prefix(3).map { change -> String in
            let prefix = showNames ? "\(change.name): " : ""
            guard let topGain = change.paperGains.first else {
                let signedDelta = change.citationDelta > 0 ? "+\(change.citationDelta)" : "\(change.citationDelta)"
                return "\(change.name) \(signedDelta)"
            }
            let others = change.paperGains.count - 1
            let suffix = others > 0 ? " · \(others) more \(others == 1 ? "paper" : "papers")" : ""
            return "\(prefix)\(topGain.shortTitle) +\(topGain.delta)\(suffix)"
        }
        var body = lines.joined(separator: "\n")
        if changes.count > 3 {
            body += "\n…and \(changes.count - 3) more profiles"
        }

        return (title, body, first.paperGains.first?.citedByURL ?? first.profileURL)
    }

    private func notifyIfNeeded(changes: [ProfileChange], milestones: [String]) {
        guard settingsManager.settings.showNotifications else { return }
        let changeText = Self.changeNotificationText(for: changes)
        guard changeText != nil || !milestones.isEmpty else { return }

        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus
            // Permission is requested from a user-facing flow (Settings / onboarding prompt),
            // not during background refresh completion.
            guard status == .authorized || status == .provisional else { return }

            if !milestones.isEmpty {
                await Self.postNotification(
                    title: "🎉 Milestone reached",
                    body: milestones.joined(separator: "\n"),
                    url: changeText?.url
                )
            }
            if let changeText {
                await Self.postNotification(title: changeText.title, body: changeText.body, url: changeText.url)
            }
        }
    }

    private static func postNotification(title: String, body: String, url: String?) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.threadIdentifier = "com.hichipli.citebar.refresh"
        if let url {
            // Opened by AppDelegate when the notification is clicked.
            content.userInfo = ["url": url]
        }

        let request = UNNotificationRequest(
            identifier: "citebar-refresh-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            AppLog.error("Failed to post notification: \(error)")
        }
    }
    
    func fetchScholarMetrics(for profile: ScholarProfile) async throws -> ScholarMetrics {
        guard let url = Self.scholarProfileURL(for: profile.id) else {
            throw CitationError.invalidURL
        }
        let html = try await fetchScholarHTML(from: url)

        // Debug: Print first 500 characters of HTML
        AppLog.debug("HTML Preview: \(String(html.prefix(500)))")

        return try parseScholarMetrics(from: html)
    }

    /// First profile page with up to 100 papers, so per-paper counts come from the same single
    /// request. robots.txt allows `/citations?user=`; it disallows `cstart=` pagination, so
    /// papers beyond the first 100 (the least cited ones) are not tracked.
    nonisolated static func scholarProfileURL(for profileID: String) -> URL? {
        URL(string: "https://scholar.google.com/citations?user=\(profileID)&hl=en&pagesize=100")
    }

    /// Google answers rate-limited clients with HTTP 429, a redirect to its /sorry page, or a
    /// CAPTCHA page that can come back as 200.
    nonisolated static func isRateLimitResponse(statusCode: Int, url: URL?, html: String) -> Bool {
        if statusCode == 429 || url?.path.hasPrefix("/sorry") == true {
            return true
        }
        // A real profile page always has the stats table, so markers elsewhere on it are ignored.
        guard !html.contains("gsc_rsb_st") else { return false }
        return html.contains("gs_captcha") || html.contains("unusual traffic from your computer network")
    }

    private func makeScholarRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.5", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.timeoutInterval = 30.0
        return request
    }

    private func fetchScholarHTML(from url: URL) async throws -> String {
        var attempt = 0
        while true {
            do {
                return try await fetchScholarHTMLOnce(from: url)
            } catch let error where attempt < requestRetryDelays.count && Self.isTransient(error) {
                AppLog.debug("Request failed (\(error)); retrying in \(requestRetryDelays[attempt])s")
                try? await Task.sleep(nanoseconds: UInt64(requestRetryDelays[attempt] * 1_000_000_000))
                attempt += 1
            }
        }
    }

    private func fetchScholarHTMLOnce(from url: URL) async throws -> String {
        let request = makeScholarRequest(for: url)
        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CitationError.networkError
        }

        AppLog.debug("HTTP Status Code: \(httpResponse.statusCode)")

        let html = String(data: data, encoding: .utf8)
        if Self.isRateLimitResponse(statusCode: httpResponse.statusCode, url: httpResponse.url, html: html ?? "") {
            throw CitationError.rateLimited
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 404:
            throw CitationError.profileNotFound
        case 500...599:
            throw CitationError.serverError
        default:
            throw CitationError.networkError
        }

        guard let html else {
            throw CitationError.invalidResponse
        }

        return html
    }

    private func parseScholarDisplayName(from html: String) -> String? {
        do {
            let doc = try SwiftSoup.parse(html)

            if let profileHeaderName = try doc.select("#gsc_prf_in").first()?.text(),
               let cleanedName = cleanedScholarDisplayName(from: profileHeaderName) {
                return cleanedName
            }

            if let ogTitleName = try doc.select("meta[property=og:title]").first()?.attr("content"),
               let cleanedName = cleanedScholarDisplayName(from: ogTitleName) {
                return cleanedName
            }

            if let pageTitle = try doc.select("title").first()?.text(),
               let cleanedName = cleanedScholarDisplayName(from: pageTitle) {
                return cleanedName
            }
        } catch let error as Exception {
            AppLog.debug("Scholar name parsing failed: \(error)")
        } catch {
            AppLog.debug("Scholar name parsing failed: \(error)")
        }

        return nil
    }

    private func cleanedScholarDisplayName(from rawName: String) -> String? {
        let directionalMarks = CharacterSet(charactersIn: "\u{202A}\u{202B}\u{202C}\u{202D}\u{202E}\u{2066}\u{2067}\u{2068}\u{2069}")
        let filteredScalars = rawName.unicodeScalars.filter { !directionalMarks.contains($0) }
        var name = String(String.UnicodeScalarView(filteredScalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            return nil
        }

        name = name.replacingOccurrences(
            of: "\\s*-\\s*Google Scholar.*$",
            with: "",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            return nil
        }

        if name.caseInsensitiveCompare("Google Scholar") == .orderedSame {
            return nil
        }

        return name
    }
    
    private func parseScholarMetrics(from html: String) throws -> ScholarMetrics {
        do {
            let doc = try SwiftSoup.parse(html)
            let citationsByYear = parseCitationsByYear(from: doc)
            let papers = parsePapers(from: doc)
            
            // Try multiple selectors for the statistics table
            let possibleSelectors = [
                "table.gsc_rsb_st",
                "#gsc_rsb_st",
                ".gsc_rsb_st"
            ]
            
            for selector in possibleSelectors {
                let tables = try doc.select(selector)
                if !tables.isEmpty() {
                    if let table = tables.first() {
                        let metrics = try parseScholarTable(table)
                        if metrics.citationCount > 0 {
                            AppLog.debug("Successfully parsed from table - Citations: \(metrics.citationCount), h-index: \(metrics.hIndex ?? -1), i10-index: \(metrics.i10Index ?? -1)")
                            return ScholarMetrics(
                                citationCount: metrics.citationCount,
                                hIndex: metrics.hIndex,
                                i10Index: metrics.i10Index,
                                citationsByYear: citationsByYear,
                                papers: papers
                            )
                        }
                    }
                }
            }
            
            // Fallback: Try to find cells directly
            let cellSelectors = [
                "td.gsc_rsb_std",
                "#gsc_rsb_st td",
                ".gsc_rsb_std"
            ]
            
            for selector in cellSelectors {
                let elements = try doc.select(selector)
                AppLog.debug("Selector '\(selector)' found \(elements.count) elements")
                
                if elements.count >= 2 {
                    // Debug: Print all table cell values to understand the structure
                    let elementsArray = Array(elements)
                    AppLog.debug("=== Table Cell Contents ===")
                    for (index, element) in elementsArray.enumerated() {
                        do {
                            let text = try element.text()
                            AppLog.debug("Cell \(index): '\(text)'")
                        } catch {
                            AppLog.debug("Cell \(index): Error reading text")
                        }
                    }
                    AppLog.debug("=== End Table Cells ===")
                    
                    let metrics = parseScholarCellArray(elementsArray)
                    if metrics.citationCount > 0 {
                        AppLog.debug("Successfully parsed from cells - Citations: \(metrics.citationCount), h-index: \(metrics.hIndex ?? -1), i10-index: \(metrics.i10Index ?? -1)")
                        return ScholarMetrics(
                            citationCount: metrics.citationCount,
                            hIndex: metrics.hIndex,
                            i10Index: metrics.i10Index,
                            citationsByYear: citationsByYear,
                            papers: papers
                        )
                    }
                }
            }
            
            // Last resort fallback
            let allElements = try doc.select("*")
            for element in allElements {
                let text = try element.text()
                if let number = extractValidCitationCount(from: text) {
                    AppLog.debug("Found potential citation count in fallback: \(text) -> \(number)")
                    return ScholarMetrics(citationCount: number, hIndex: nil, i10Index: nil, citationsByYear: citationsByYear, papers: papers)
                }
            }
            
            AppLog.debug("Could not find citation count in HTML")
            throw CitationError.citationCountNotFound
            
        } catch let error as Exception {
            AppLog.error("HTML parsing error: \(error)")
            throw CitationError.parsingError
        }
    }

    private func parseCitationsByYear(from doc: Document) -> [Int: Int]? {
        do {
            let yearElements = Array(try doc.select(".gsc_g_t"))
            let barValueElements = Array(try doc.select(".gsc_g_a .gsc_g_al"))
            let pairCount = min(yearElements.count, barValueElements.count)

            guard pairCount > 0 else {
                return nil
            }

            var citationsByYear: [Int: Int] = [:]
            for index in 0..<pairCount {
                let yearText = try yearElements[index].text()
                let valueText = try barValueElements[index].text()

                guard let year = parseYearLabel(from: yearText),
                      let citations = extractNumber(from: valueText) else {
                    continue
                }

                citationsByYear[year] = max(0, citations)
            }

            if citationsByYear.isEmpty {
                return nil
            }

            AppLog.debug("Parsed citation histogram for \(citationsByYear.count) years")
            return citationsByYear
        } catch let error as Exception {
            AppLog.debug("Citation histogram parsing failed: \(error)")
            return nil
        } catch {
            AppLog.debug("Citation histogram parsing failed: \(error)")
            return nil
        }
    }

    private func parsePapers(from doc: Document) -> [ScholarPaper] {
        guard let rows = try? doc.select("tr.gsc_a_tr") else { return [] }

        return rows.compactMap { row -> ScholarPaper? in
            guard let titleLink = try? row.select("a.gsc_a_at").first(),
                  let title = try? titleLink.text(), !title.isEmpty,
                  let href = try? titleLink.attr("href"),
                  let id = href.components(separatedBy: "citation_for_view=").dropFirst().first?
                    .components(separatedBy: "&").first, !id.isEmpty else {
                return nil
            }

            // Uncited papers have an empty count link.
            let countLink = try? row.select("a.gsc_a_ac").first()
            let citations = (try? countLink?.text()).flatMap { extractNumber(from: $0) } ?? 0
            let citedByURL = (try? countLink?.attr("href")).flatMap { $0.isEmpty ? nil : $0 }

            return ScholarPaper(id: id, title: title, citations: citations, citedByURL: citedByURL)
        }
    }

    private func parseYearLabel(from text: String) -> Int? {
        guard let year = extractNumber(from: text) else { return nil }
        guard year >= 1900 && year <= 2100 else { return nil }
        return year
    }
    
    private func parseScholarTable(_ table: Element) throws -> ScholarMetrics {
        // Parse the table row by row to find Citations, h-index, and i10-index rows
        let rows = try table.select("tr")
        var citationCount: Int?
        var hIndex: Int?
        var i10Index: Int?

        for row in rows {
            let cells = try row.select("td")
            if cells.count >= 2 {
                let rowLabel = try cells.first()?.text() ?? ""
                AppLog.debug("Row label: '\(rowLabel)'")

                if rowLabel.lowercased().contains("citations") {
                    // This is the citations row, get the "All" value (second cell)
                    if cells.count >= 2 {
                        let allCell = cells[1]
                        let text = try allCell.text()
                        citationCount = extractValidCitationCount(from: text)
                        AppLog.debug("Found citations row: \(text) -> \(citationCount ?? -1)")
                    }
                } else if rowLabel.lowercased().contains("h-index") {
                    // This is the h-index row, get the "All" value (second cell)
                    if cells.count >= 2 {
                        let allCell = cells[1]
                        let text = try allCell.text()
                        hIndex = extractNumber(from: text)
                        AppLog.debug("Found h-index row: \(text) -> \(hIndex ?? -1)")
                    }
                } else if rowLabel.lowercased().contains("i10-index") {
                    // This is the i10-index row, get the "All" value (second cell)
                    if cells.count >= 2 {
                        let allCell = cells[1]
                        let text = try allCell.text()
                        i10Index = extractNumber(from: text)
                        AppLog.debug("Found i10-index row: \(text) -> \(i10Index ?? -1)")
                    }
                }
            }
        }

        return ScholarMetrics(citationCount: citationCount ?? 0, hIndex: hIndex, i10Index: i10Index)
    }
    
    private func parseScholarCellArray(_ elements: [Element]) -> ScholarMetrics {
        // Google Scholar table structure when read as linear array:
        // The exact pattern depends on how the HTML is structured, so we need to be more flexible

        var citationCount: Int?
        var hIndex: Int?
        var i10Index: Int?

        // Look for patterns in the text content
        for (index, element) in elements.enumerated() {
            do {
                let text = try element.text()

                // If we find a cell that says "Citations", the next numeric cell should be citation count
                if text.lowercased().contains("citations") && index + 1 < elements.count {
                    let nextElement = elements[index + 1]
                    let nextText = try nextElement.text()
                    citationCount = extractValidCitationCount(from: nextText)
                    AppLog.debug("Found citations after label at index \(index + 1): \(nextText) -> \(citationCount ?? -1)")
                }

                // If we find a cell that says "h-index", the next numeric cell should be h-index
                if text.lowercased().contains("h-index") && index + 1 < elements.count {
                    let nextElement = elements[index + 1]
                    let nextText = try nextElement.text()
                    hIndex = extractNumber(from: nextText)
                    AppLog.debug("Found h-index after label at index \(index + 1): \(nextText) -> \(hIndex ?? -1)")
                }

                // If we find a cell that says "i10-index", the next numeric cell should be i10-index
                if text.lowercased().contains("i10-index") && index + 1 < elements.count {
                    let nextElement = elements[index + 1]
                    let nextText = try nextElement.text()
                    i10Index = extractNumber(from: nextText)
                    AppLog.debug("Found i10-index after label at index \(index + 1): \(nextText) -> \(i10Index ?? -1)")
                }
            } catch {
                continue
            }
        }

        // If we still don't have citation count, try the old method as fallback
        if citationCount == nil {
            citationCount = extractValidCitationCount(from: elements)
        }

        return ScholarMetrics(citationCount: citationCount ?? 0, hIndex: hIndex, i10Index: i10Index)
    }
    
    private func extractValidCitationCount(from elements: [Element]) -> Int? {
        // Look for citation count in the first few elements
        for (index, element) in elements.enumerated() {
            if index > 5 { break } // Don't check too many elements
            
            do {
                let text = try element.text()
                if let number = extractValidCitationCount(from: text) {
                    return number
                }
            } catch {
                continue
            }
        }
        return nil
    }
    
    
    private func extractValidCitationCount(from text: String) -> Int? {
        guard let number = extractNumber(from: text) else { return nil }
        
        // Filter out numbers that are likely years (1900-2030)
        if number >= 1900 && number <= 2030 {
            return nil
        }
        
        // Filter out numbers that are too small to be realistic citation counts for established scholars
        // But allow 0 for new scholars
        if number < 0 {
            return nil
        }
        
        // Filter out unrealistically large numbers (probably parsing errors)
        if number > 1000000 {
            return nil
        }
        
        return number
    }
    
    private func extractNumber(from text: String) -> Int? {
        let cleanedText = text.replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
        
        // Try to extract a number from the text
        let pattern = #"\d+"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: cleanedText, range: NSRange(cleanedText.startIndex..., in: cleanedText)),
           let range = Range(match.range, in: cleanedText) {
            return Int(String(cleanedText[range]))
        }
        
        return nil
    }
    
    func refreshSettings() {
        // Safely refresh timer settings
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.refreshTimer?.invalidate()
            self.refreshTimer = nil
            self.setupTimer()
        }
    }
    
    func updateMenuBarWithCurrentData() {
        // Update menu display immediately without fetching new data
        let profiles = settingsManager.settings.profiles.filter { $0.isEnabled }
        if !profiles.isEmpty {
            // Get last known citation data for these profiles
            Task {
                var currentData: [ScholarProfile: ProfileMetrics] = [:]
                
                for profile in profiles {
                    if let latestRecord = await storageManager.getLatestRecord(for: profile.id) {
                        let (updatedProfile, metrics) = await displayData(for: profile, record: latestRecord)
                        currentData[updatedProfile] = metrics
                    }
                }
                
                await MainActor.run {
                    if !currentData.isEmpty {
                        AppLog.debug("Loaded historical data for \(currentData.count) profiles")
                        delegate?.citationsUpdated(currentData)
                    } else {
                        AppLog.debug("No historical data found, showing empty state")
                        // Show empty state with helpful message
                        delegate?.citationsUpdated([:])
                    }
                }
            }
        } else {
            // No enabled profiles
            delegate?.citationsUpdated([:])
        }
    }
}

enum CitationError: Error, LocalizedError {
    case invalidURL
    case networkError
    case invalidResponse
    case citationCountNotFound
    case invalidCitationFormat
    case parsingError
    case noDataAvailable
    case rateLimited
    case profileNotFound
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Google Scholar URL"
        case .networkError:
            return "Network request failed"
        case .invalidResponse:
            return "Invalid response from Google Scholar"
        case .citationCountNotFound:
            return "Could not find citation count on page"
        case .invalidCitationFormat:
            return "Citation count format is invalid"
        case .parsingError:
            return "Failed to parse HTML content"
        case .noDataAvailable:
            return "No citation data available"
        case .rateLimited:
            return "Google Scholar is temporarily limiting requests from this network"
        case .profileNotFound:
            return "Google Scholar profile not found"
        case .serverError:
            return "Google Scholar is temporarily unavailable"
        }
    }
}
