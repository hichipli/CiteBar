import Foundation

actor StorageManager {
    private let citationHistoryURL: URL
    private var citationHistory: [CitationRecord] = []
    private var isInitialized = false
    
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
                print("Successfully loaded \(history.count) citation records from storage")
            }
        } catch {
            print("Failed to load citation history: \(error)")
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
            
            print("Successfully saved \(citationHistory.count) citation records to storage")
        } catch {
            print("Failed to save citation history: \(error)")
        }
    }
    
    func saveCitationRecord(_ record: CitationRecord) async {
        await ensureInitialized()
        citationHistory.append(record)
        
        // Keep only the last 1000 records per profile to manage storage
        let recordsPerProfile = 1000
        let profileRecords = citationHistory.filter { $0.profileId == record.profileId }
        
        if profileRecords.count > recordsPerProfile {
            citationHistory.removeAll { $0.profileId == record.profileId }
            let recentRecords = profileRecords.suffix(recordsPerProfile)
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
    
    func calculateRecentGrowth(for profileId: String, days: Int = 30) async -> Int? {
        let records = await getCitationHistory(for: profileId, days: days)
        
        guard let oldest = records.first,
              let newest = records.last,
              records.count > 1 else {
            return nil
        }
        
        return newest.citationCount - oldest.citationCount
    }
    
    func getLatestCitationCount(for profileId: String) async -> Int? {
        await ensureInitialized()
        return citationHistory
            .filter { $0.profileId == profileId }
            .sorted { $0.timestamp > $1.timestamp }
            .first?
            .citationCount
    }
    
    func getCitationTrend(for profileId: String, days: Int = 30) async -> [(Date, Int)] {
        let records = await getCitationHistory(for: profileId, days: days)
        return records.map { ($0.timestamp, $0.citationCount) }
    }
    
    func getAllRecords() async -> [CitationRecord] {
        await ensureInitialized()
        return citationHistory
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
        print("Force reloading citation history from disk...")
        loadCitationHistory()
    }
}