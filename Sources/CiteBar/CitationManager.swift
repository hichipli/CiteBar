import Foundation
import SwiftSoup

@MainActor class CitationManager {
    weak var delegate: CitationManagerDelegate?
    private let settingsManager = SettingsManager.shared
    private let storageManager = StorageManager()
    private var refreshTimer: Timer?
    
    init() {
        setupTimer()
        // Debug storage status at startup
        Task {
            let info = await storageManager.getStorageInfo()
            print("Storage status: \(info.recordCount) records, file exists: \(info.fileExists)")
            print("Storage path: \(info.filePath)")
            
            // If we have historical data, log which profiles have data
            if info.recordCount > 0 {
                let records = await storageManager.getAllRecords()
                let profileIds = Set(records.map { $0.profileId })
                print("Historical data available for profile IDs: \(profileIds)")
            }
        }
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
    
    func checkCitations() {
        let profiles = settingsManager.settings.profiles.filter { $0.isEnabled }
        
        guard !profiles.isEmpty else {
            delegate?.citationsUpdated([:])
            return
        }
        
        // Set refreshing state
        settingsManager.setRefreshing(true)
        
        // Notify delegate to update UI with refreshing state
        delegate?.refreshingStateChanged(true)
        
        Task {
            await performCitationCheck(for: profiles)
        }
    }
    
    private func performCitationCheck(for profiles: [ScholarProfile]) async {
        var results: [ScholarProfile: Int] = [:]
        
        for profile in profiles {
            do {
                let count = try await fetchCitationCount(for: profile)
                results[profile] = count
                
                // Store the record
                let record = CitationRecord(profileId: profile.id, citationCount: count)
                await storageManager.saveCitationRecord(record)
                
                // Calculate recent growth
                let growth = await storageManager.calculateRecentGrowth(for: profile.id)
                var updatedProfile = profile
                updatedProfile.recentGrowth = growth
                results[updatedProfile] = count
                
                print("Successfully fetched \(count) citations for \(profile.name)")
                
                // Add delay to be respectful to Google's servers
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
            } catch {
                print("Failed to fetch citations for \(profile.name): \(error)")
                print("Error details: \(error.localizedDescription)")
                
                // Don't let one profile failure stop the whole process
                // Continue with other profiles
            }
        }
        
        // Update last refresh time and clear refreshing state on main actor
        await MainActor.run {
            settingsManager.setLastUpdateTime(Date())
            settingsManager.setRefreshing(false)
            
            // Notify delegate that refreshing is complete
            delegate?.refreshingStateChanged(false)
            
            if !results.isEmpty {
                delegate?.citationsUpdated(results)
            } else {
                // If network request failed but we might have historical data showing,
                // don't call citationCheckFailed as it would show error and hide historical data
                // Instead, just log the issue
                print("Network request completed but no new data retrieved")
                
                // Only show error if we have no historical data available
                // Check if we have any stored data for current profiles
                Task {
                    let profiles = settingsManager.settings.profiles.filter { $0.isEnabled }
                    let records = await storageManager.getAllRecords()
                    let hasHistoricalData = profiles.contains { profile in
                        records.contains { $0.profileId == profile.id }
                    }
                    
                    if !hasHistoricalData {
                        await MainActor.run {
                            delegate?.citationCheckFailed(CitationError.noDataAvailable)
                        }
                    }
                }
            }
        }
    }
    
    private func fetchCitationCount(for profile: ScholarProfile) async throws -> Int {
        guard let url = URL(string: profile.url) else {
            throw CitationError.invalidURL
        }
        
        // Create request with proper headers to avoid being blocked
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.5", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.timeoutInterval = 30.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CitationError.networkError
        }
        
        print("HTTP Status Code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            throw CitationError.networkError
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw CitationError.invalidResponse
        }
        
        // Debug: Print first 500 characters of HTML
        print("HTML Preview: \(String(html.prefix(500)))")
        
        return try parseCitationCount(from: html)
    }
    
    private func parseCitationCount(from html: String) throws -> Int {
        do {
            let doc = try SwiftSoup.parse(html)
            
            // Debug: Check if we can find any citation-related elements
            let allTableCells = try doc.select("td")
            print("Found \(allTableCells.count) table cells")
            
            // Try multiple selectors for citation count
            let possibleSelectors = [
                "td.gsc_rsb_std",
                "#gsc_rsb_st td",
                ".gsc_rsb_std",
                "table.gsc_rsb_st td"
            ]
            
            for selector in possibleSelectors {
                let elements = try doc.select(selector)
                print("Selector '\(selector)' found \(elements.count) elements")
                
                if let firstElement = elements.first() {
                    let text = try firstElement.text()
                    print("First element text: '\(text)'")
                    
                    // Look for numbers in the text
                    if let number = extractNumber(from: text) {
                        print("Successfully extracted citation count: \(number)")
                        return number
                    }
                }
            }
            
            // If standard selectors fail, look for any element containing numbers
            let allElements = try doc.select("*")
            for element in allElements {
                let text = try element.text()
                if text.count < 10, let number = extractNumber(from: text), number > 0 {
                    print("Found potential citation count in element: \(text) -> \(number)")
                    return number
                }
            }
            
            print("Could not find citation count in HTML")
            throw CitationError.citationCountNotFound
            
        } catch let error as Exception {
            print("HTML parsing error: \(error)")
            throw CitationError.parsingError
        }
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
                let records = await storageManager.getAllRecords()
                var currentData: [ScholarProfile: Int] = [:]
                
                for profile in profiles {
                    // Find the most recent record for this profile
                    let profileRecords = records.filter { $0.profileId == profile.id }
                    if let latestRecord = profileRecords.max(by: { $0.timestamp < $1.timestamp }) {
                        // Calculate recent growth for historical data
                        let growth = await storageManager.calculateRecentGrowth(for: profile.id)
                        var updatedProfile = profile
                        updatedProfile.recentGrowth = growth
                        currentData[updatedProfile] = latestRecord.citationCount
                    }
                }
                
                await MainActor.run {
                    if !currentData.isEmpty {
                        print("Loaded historical data for \(currentData.count) profiles")
                        delegate?.citationsUpdated(currentData)
                    } else {
                        print("No historical data found, showing empty state")
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
        }
    }
}