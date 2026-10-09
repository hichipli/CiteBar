import Foundation

actor StorageManager {
    private let citationHistoryURL: URL
    private var citationHistory: [CitationRecord] = []
    private var isInitialized = false
    private let papersURL: URL
    private var profilePapers: [String: ProfilePapers]
    private let paperHistoryURL: URL
    /// Paper history by profile ID; empty unless the user keeps paper history.
    private var paperHistory: [String: PaperHistory]

    /// ~/Library/Application Support/CiteBar, where settings, history, and paper lists live.
    nonisolated static var appFolderURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CiteBar")
    }

    init() {
        let appFolder = Self.appFolderURL

        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        citationHistoryURL = appFolder.appendingPathComponent("citation_history.json")
        papersURL = appFolder.appendingPathComponent("papers.json")
        profilePapers = Self.load(from: papersURL) ?? [:]
        paperHistoryURL = appFolder.appendingPathComponent("paper_history.json")
        paperHistory = Self.load(from: paperHistoryURL) ?? [:]

        // Load citation history synchronously during initialization
        loadCitationHistory()
    }

    private static func load<T: Decodable>(from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    private static func save<T: Encodable>(_ value: T, to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(value).write(to: url, options: .atomic)
        } catch {
            AppLog.error("Failed to save \(url.lastPathComponent): \(error)")
        }
    }

    private func saveProfilePapers() {
        Self.save(profilePapers, to: papersURL)
    }

    private func savePaperHistory() {
        Self.save(paperHistory, to: paperHistoryURL)
    }

    /// Stores the latest paper list for a profile and returns per-paper gains since the
    /// previous list. Returns no gains the first time a profile's papers are seen.
    func updatePapers(_ papers: [ScholarPaper], for profileId: String, keepHistory: Bool = false,
                      now: Date = Date()) -> [PaperGain] {
        // An empty list means parsing failed; keep the previous baseline.
        guard !papers.isEmpty else { return [] }

        var entry = profilePapers[profileId] ?? ProfilePapers(papers: [])
        let gains = Self.computePaperGains(previous: entry.papers, current: papers)
        entry.papers = papers
        if !gains.isEmpty {
            entry.lastGains = gains
            entry.lastGainDate = now
            var changes = entry.lastChanges ?? [:]
            for gain in gains {
                if let id = gain.paperID {
                    changes[id] = PaperChange(delta: gain.delta, date: now)
                }
            }
            entry.lastChanges = changes
        }
        entry.yearStarts = Self.recordingYearStart(entry.yearStarts, papers: papers, now: now)
        profilePapers[profileId] = entry
        saveProfilePapers()
        if keepHistory {
            paperHistory[profileId] = Self.recordingPaperPoints(paperHistory[profileId] ?? [:], papers: papers, now: now)
            savePaperHistory()
        }
        return gains
    }

    /// Adds a point for each paper whose citations changed since its last point.
    static func recordingPaperPoints(_ history: PaperHistory, papers: [ScholarPaper], now: Date) -> PaperHistory {
        var history = history
        for paper in papers where history[paper.id]?.last?.citations != paper.citations {
            history[paper.id, default: []].append(PaperPoint(date: now, citations: paper.citations))
        }
        return history
    }

    /// Starts paper history from the paper lists already saved, dated to the last refresh.
    func startPaperHistory(at date: Date) {
        for (profileId, entry) in profilePapers {
            paperHistory[profileId] = Self.recordingPaperPoints(paperHistory[profileId] ?? [:], papers: entry.papers, now: date)
        }
        savePaperHistory()
    }

    func paperHistory(for profileId: String) -> PaperHistory {
        paperHistory[profileId] ?? [:]
    }

    func deletePaperHistory() {
        paperHistory = [:]
        try? FileManager.default.removeItem(at: paperHistoryURL)
    }

    /// Adds this year's snapshot on the first refresh of the year; later refreshes leave it alone.
    static func recordingYearStart(_ yearStarts: [Int: PaperSnapshot]?, papers: [ScholarPaper],
                                   now: Date) -> [Int: PaperSnapshot] {
        var yearStarts = yearStarts ?? [:]
        let year = Calendar.current.component(.year, from: now)
        if yearStarts[year] == nil {
            let citations = Dictionary(papers.map { ($0.id, $0.citations) }) { first, _ in first }
            yearStarts[year] = PaperSnapshot(date: now, citations: citations)
        }
        return yearStarts
    }

    func getProfilePapers(for profileId: String) -> ProfilePapers? {
        profilePapers[profileId]
    }

    // MARK: - Export and import

    func exportData() async -> (history: [CitationRecord], papers: [String: ProfilePapers], paperHistory: [String: PaperHistory]) {
        await ensureInitialized()
        return (citationHistory, profilePapers, paperHistory)
    }

    func historySummary() async -> (count: Int, earliest: Date?) {
        await ensureInitialized()
        return (citationHistory.count, citationHistory.map(\.timestamp).min())
    }

    /// When paper history begins, or nil when there is none.
    func paperHistoryStart() -> Date? {
        paperHistory.values.flatMap(\.values).compactMap(\.first?.date).min()
    }

    /// Adds history and paper lists from a backup without removing anything here, except
    /// history older than `cutoff` (the retention setting). Returns how many history records
    /// were new.
    @discardableResult
    func importData(history: [CitationRecord], papers: [String: ProfilePapers],
                    paperHistory incomingPaperHistory: [String: PaperHistory] = [:], since cutoff: Date? = nil) async -> Int {
        await ensureInitialized()
        let merged = Self.mergeHistory(existing: citationHistory, incoming: history, since: cutoff)
        let added = merged.count - citationHistory.count
        citationHistory = merged
        saveCitationHistory()

        if !incomingPaperHistory.isEmpty {
            paperHistory.merge(incomingPaperHistory) { current, incoming in
                current.merging(incoming) { a, b in
                    // Union by date, in time order.
                    var seen = Set<Date>()
                    return (a + b).sorted { $0.date < $1.date }.filter { seen.insert($0.date).inserted }
                }
            }
            savePaperHistory()
        }

        // Paper lists on this Mac are the most recent baseline, so they win, but each year
        // keeps its earliest snapshot from either Mac.
        profilePapers.merge(papers) { current, incoming in
            var merged = current
            merged.yearStarts = (current.yearStarts ?? [:]).merging(incoming.yearStarts ?? [:]) {
                $0.date <= $1.date ? $0 : $1
            }
            return merged
        }
        saveProfilePapers()
        return max(0, added)
    }

    /// Union of both histories, de-duplicated and in time order, without incoming records
    /// from before `cutoff`.
    static func mergeHistory(existing: [CitationRecord], incoming: [CitationRecord], since cutoff: Date? = nil) -> [CitationRecord] {
        func key(_ record: CitationRecord) -> String {
            // Saved timestamps have whole-second precision.
            "\(record.profileId)|\(Int(record.timestamp.timeIntervalSince1970))|\(record.citationCount)"
        }

        var seen = Set(existing.map(key))
        var combined = existing
        for record in incoming where record.timestamp >= (cutoff ?? .distantPast) && seen.insert(key(record)).inserted {
            combined.append(record)
        }
        return combined.sorted { ($0.timestamp, $0.profileId) < ($1.timestamp, $1.profileId) }
    }

    // MARK: - Retention

    /// How many history records are older than `cutoff`.
    func recordCount(before cutoff: Date) async -> Int {
        await ensureInitialized()
        return citationHistory.count { $0.timestamp < cutoff }
    }

    /// Removes history older than the retention setting. Paper history keeps the last point
    /// before the cutoff, since that count still holds afterwards. Returns how many history
    /// records were removed.
    @discardableResult
    func applyRetention(_ retention: HistoryRetention, now: Date = Date()) async -> Int {
        await ensureInitialized()
        guard let cutoff = retention.cutoff(from: now) else { return 0 }
        let before = citationHistory.count
        citationHistory.removeAll { $0.timestamp < cutoff }
        if citationHistory.count < before {
            saveCitationHistory()
        }
        let trimmed = paperHistory.mapValues { $0.mapValues { Self.trimmed($0, before: cutoff) } }
        if trimmed != paperHistory {
            paperHistory = trimmed
            savePaperHistory()
        }
        return before - citationHistory.count
    }

    /// Drops points older than `cutoff`, keeping the last one before it.
    static func trimmed(_ points: [PaperPoint], before cutoff: Date) -> [PaperPoint] {
        let firstKept = points.firstIndex { $0.date >= cutoff } ?? points.count
        return Array(points[max(0, firstKept - 1)...])
    }

    /// Papers missing from `previous` are skipped so a paper entering the fetched list
    /// (new on the profile, or newly inside the first page) is not reported as a gain.
    static func computePaperGains(previous: [ScholarPaper], current: [ScholarPaper]) -> [PaperGain] {
        let previousCitations = Dictionary(previous.map { ($0.id, $0.citations) }, uniquingKeysWith: max)
        return current.compactMap { paper -> PaperGain? in
            guard let old = previousCitations[paper.id], paper.citations > old else { return nil }
            return PaperGain(title: paper.title, delta: paper.citations - old, citedByURL: paper.citedByURL, paperID: paper.id)
        }
        .sorted { $0.delta > $1.delta }
    }

    /// The papers that would raise the h-index by one with the fewest new citations: the top
    /// h+1 papers each need at least h+1. Ties break by paper ID so the answer is stable.
    static func computeNextHIndexStep(hIndex: Int, papers: [ScholarPaper]) -> HIndexStep? {
        let target = hIndex + 1
        let top = papers
            .sorted { ($0.citations, $1.id) > ($1.citations, $0.id) }
            .prefix(target)
        guard top.count == target else { return nil }
        let needs = top
            .filter { $0.citations < target }
            .map { HIndexStep.Need(paper: $0, needed: target - $0.citations) }
            .sorted { $0.needed < $1.needed }
        // Empty means the papers already qualify and Scholar's h-index hasn't caught up.
        return needs.isEmpty ? nil : HIndexStep(target: target, needs: needs)
    }
    
    private nonisolated func loadCitationHistory() {
        do {
            let data = try Data(contentsOf: citationHistoryURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let history = try decoder.decode([CitationRecord].self, from: data)
            Task {
                await self.setCitationHistory(history)
                AppLog.debug("Successfully loaded \(history.count) citation records from storage")
            }
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            Task {
                await self.setCitationHistory([])
                AppLog.debug("No citation history file found yet; starting with empty storage")
            }
        } catch {
            AppLog.error("Failed to load citation history: \(error)")
            // Initialize with empty history if loading fails
            Task {
                await self.setCitationHistory([])
            }
        }
    }
    
    private func setCitationHistory(_ history: [CitationRecord]) {
        citationHistory = history
        isInitialized = true
    }
    
    private func ensureInitialized() async {
        while !isInitialized {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
    
    private func saveCitationHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(citationHistory)
            
            // Write to a temporary file first, then move to final location
            // This prevents corruption if the app crashes during write
            let tempURL = citationHistoryURL.appendingPathExtension("tmp")
            try data.write(to: tempURL)
            _ = try FileManager.default.replaceItem(at: citationHistoryURL, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
            
            AppLog.debug("Successfully saved \(citationHistory.count) citation records to storage")
        } catch {
            AppLog.error("Failed to save citation history: \(error)")
        }
    }
    
    /// Adds a record. How long records are kept is up to the retention setting; see
    /// `applyRetention`.
    func saveCitationRecord(_ record: CitationRecord) async {
        await ensureInitialized()
        citationHistory.append(record)
        saveCitationHistory()
    }
    
    func getCitationHistory(for profileId: String, days: Int = 30) async -> [CitationRecord] {
        await ensureInitialized()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        return citationHistory
            .filter { $0.profileId == profileId && $0.timestamp >= cutoffDate }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    func calculateRecentGrowthSummary(for profileId: String, days: Int = 30) async -> (growth: Int, baselineDays: Int)? {
        await ensureInitialized()
        let profileRecords = citationHistory.filter { $0.profileId == profileId }
        return StorageManager.computeRecentGrowthSummary(from: profileRecords, days: days)
    }

    static func computeRecentGrowthSummary(from records: [CitationRecord], days: Int = 30) -> (growth: Int, baselineDays: Int)? {
        guard records.count > 1 else {
            return nil
        }

        let sortedRecords = records.enumerated().sorted { lhs, rhs in
            if lhs.element.timestamp == rhs.element.timestamp {
                return lhs.offset < rhs.offset
            }
            return lhs.element.timestamp < rhs.element.timestamp
        }.map(\.element)

        guard let oldestOverall = sortedRecords.first,
              let newest = sortedRecords.last else {
            return nil
        }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: newest.timestamp) ?? newest.timestamp
        let windowRecords = sortedRecords.filter { $0.timestamp >= cutoffDate }

        guard let summary = computeGrowthSummary(from: windowRecords) else {
            return nil
        }

        let hasFullWindowCoverage = oldestOverall.timestamp <= cutoffDate
        let baselineDays = hasFullWindowCoverage ? days : summary.baselineDays

        return (summary.growth, baselineDays)
    }

    static func computeGrowthSummary(from records: [CitationRecord]) -> (growth: Int, baselineDays: Int)? {
        guard records.count > 1 else {
            return nil
        }

        // Keep deterministic ordering when multiple records share the same timestamp.
        let sortedRecords = records.enumerated().sorted { lhs, rhs in
            if lhs.element.timestamp == rhs.element.timestamp {
                return lhs.offset < rhs.offset
            }
            return lhs.element.timestamp < rhs.element.timestamp
        }

        guard let oldest = sortedRecords.first?.element,
              let newest = sortedRecords.last?.element else {
            return nil
        }

        let growth = newest.citationCount - oldest.citationCount
        let dayDifference = Calendar.current.dateComponents([.day], from: oldest.timestamp, to: newest.timestamp).day ?? 0
        let baselineDays = max(1, dayDifference)

        return (growth, baselineDays)
    }

    func calculateRecentGrowth(for profileId: String, days: Int = 30) async -> Int? {
        await calculateRecentGrowthSummary(for: profileId, days: days)?.growth
    }
    
    private func latestRecord(for profileId: String) -> CitationRecord? {
        var latest: CitationRecord?

        for record in citationHistory where record.profileId == profileId {
            guard let currentLatest = latest else {
                latest = record
                continue
            }

            if record.timestamp > currentLatest.timestamp {
                latest = record
            }
        }

        return latest
    }
    
    func getLatestRecord(for profileId: String) async -> CitationRecord? {
        await ensureInitialized()
        return latestRecord(for: profileId)
    }
    
    func getLatestHIndex(for profileId: String) async -> Int? {
        await getLatestRecord(for: profileId)?.hIndex
    }

    func getLatestI10Index(for profileId: String) async -> Int? {
        await getLatestRecord(for: profileId)?.i10Index
    }
    
    func getCitationTrend(for profileId: String, days: Int = 30) async -> [(Date, Int)] {
        let records = await getCitationHistory(for: profileId, days: days)
        return records.map { ($0.timestamp, $0.citationCount) }
    }
    
    func records(for profileId: String) async -> [CitationRecord] {
        await ensureInitialized()
        return citationHistory.filter { $0.profileId == profileId }
    }

    func getAllRecords() async -> [CitationRecord] {
        await ensureInitialized()
        return citationHistory
    }
    
    func getProfileIDsWithHistory() async -> Set<String> {
        await ensureInitialized()
        return Set(citationHistory.map(\.profileId))
    }
    
    func hasHistoricalData(for profileIDs: Set<String>) async -> Bool {
        await ensureInitialized()
        guard !profileIDs.isEmpty else { return false }
        
        for record in citationHistory where profileIDs.contains(record.profileId) {
            return true
        }
        
        return false
    }
    
    func getStorageInfo() async -> (recordCount: Int, filePath: String, fileExists: Bool) {
        await ensureInitialized()
        let fileExists = FileManager.default.fileExists(atPath: citationHistoryURL.path)
        return (citationHistory.count, citationHistoryURL.path, fileExists)
    }
    
    func forceReload() {
        AppLog.debug("Force reloading citation history from disk...")
        loadCitationHistory()
    }
}
