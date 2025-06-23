import Foundation

actor StorageManager {
    private let citationHistoryURL: URL
    private var citationHistory: [CitationRecord] = []
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("CiteBar")
        
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        citationHistoryURL = appFolder.appendingPathComponent("citation_history.json")
        
        Task {
            await loadCitationHistory()
        }
    }
    
    private func loadCitationHistory() {
        if let data = try? Data(contentsOf: citationHistoryURL),
           let history = try? JSONDecoder().decode([CitationRecord].self, from: data) {
            citationHistory = history
        }
    }
    
    private func saveCitationHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(citationHistory)
            try data.write(to: citationHistoryURL)
        } catch {
            print("Failed to save citation history: \(error)")
        }
    }
    
    func saveCitationRecord(_ record: CitationRecord) {
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
    
    func getCitationHistory(for profileId: String, days: Int = 30) -> [CitationRecord] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        return citationHistory
            .filter { $0.profileId == profileId && $0.timestamp >= cutoffDate }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    func calculateRecentGrowth(for profileId: String, days: Int = 30) -> Int? {
        let records = getCitationHistory(for: profileId, days: days)
        
        guard let oldest = records.first,
              let newest = records.last,
              records.count > 1 else {
            return nil
        }
        
        return newest.citationCount - oldest.citationCount
    }
    
    func getLatestCitationCount(for profileId: String) -> Int? {
        return citationHistory
            .filter { $0.profileId == profileId }
            .sorted { $0.timestamp > $1.timestamp }
            .first?
            .citationCount
    }
    
    func getCitationTrend(for profileId: String, days: Int = 30) -> [(Date, Int)] {
        let records = getCitationHistory(for: profileId, days: days)
        return records.map { ($0.timestamp, $0.citationCount) }
    }
    
    func getAllRecords() -> [CitationRecord] {
        return citationHistory
    }
    
    func cleanupOldRecords(olderThan days: Int = 365) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        citationHistory.removeAll { $0.timestamp < cutoffDate }
        saveCitationHistory()
    }
}