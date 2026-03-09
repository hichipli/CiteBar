import Foundation

actor StorageManager {
    private let citationHistoryURL: URL
    private var citationHistory: [CitationRecord] = []
    private var isInitialized = false
    
    private static let maxRecordsPerProfile = 1000
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("CiteBar")
        
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        citationHistoryURL = appFolder.appendingPathComponent("citation_history.json")
        
        // Load citation history synchronously during initialization
        loadCitationHistory()
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
            encoder.outputFormatting = .prettyPrinted
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
    
    func saveCitationRecord(_ record: CitationRecord) async {
        await ensureInitialized()
        citationHistory.append(record)
        
        // Keep only the last 1000 records per profile to manage storage
        let profileRecords = citationHistory.filter { $0.profileId == record.profileId }
        
        if profileRecords.count > Self.maxRecordsPerProfile {
            citationHistory.removeAll { $0.profileId == record.profileId }
            let recentRecords = profileRecords.suffix(Self.maxRecordsPerProfile)
            citationHistory.append(contentsOf: recentRecords)
        }
        
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
    
    func getLatestCitationCount(for profileId: String) async -> Int? {
        await getLatestRecord(for: profileId)?.citationCount
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
    
    func cleanupOldRecords(olderThan days: Int = 365) async {
        await ensureInitialized()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        citationHistory.removeAll { $0.timestamp < cutoffDate }
        saveCitationHistory()
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
