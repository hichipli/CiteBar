import Foundation
import SwiftSoup
import UserNotifications

@MainActor class CitationManager {
    weak var delegate: CitationManagerDelegate?
    private let settingsManager = SettingsManager.shared
    private let storageManager = StorageManager()
    private var refreshTimer: Timer?
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
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
    
    func checkCitations(isStartup: Bool = false) {
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
            await performCitationCheck(for: profiles, isStartup: isStartup)
        }
    }
    
    private func performCitationCheck(for profiles: [ScholarProfile], isStartup: Bool) async {
        var results: [ScholarProfile: ProfileMetrics] = [:]
        var successfulProfiles = 0
        var changedProfiles = 0
        var totalCitationDelta = 0
        
        for profile in profiles {
            do {
                let metrics = try await fetchScholarMetrics(for: profile)
                let previousCitationCount = await storageManager.getLatestCitationCount(for: profile.id)
                successfulProfiles += 1
                
                if let previousCitationCount = previousCitationCount {
                    let delta = metrics.citationCount - previousCitationCount
                    totalCitationDelta += delta
                    if delta != 0 {
                        changedProfiles += 1
                    }
                }
                
                // Store the record
                let record = CitationRecord(profileId: profile.id, citationCount: metrics.citationCount, hIndex: metrics.hIndex, i10Index: metrics.i10Index)
                await storageManager.saveCitationRecord(record)
                
                // Calculate recent growth and baseline days
                let growthSummary = await storageManager.calculateRecentGrowthSummary(for: profile.id)
                var updatedProfile = profile
                updatedProfile.recentGrowth = growthSummary?.growth
                updatedProfile.recentGrowthDays = growthSummary?.baselineDays
                
                // Only add the updated profile with growth data to results
                results[updatedProfile] = ProfileMetrics(citationCount: metrics.citationCount, hIndex: metrics.hIndex, i10Index: metrics.i10Index)

                print("Successfully fetched \(metrics.citationCount) citations for \(profile.name)")
                if let hIndex = metrics.hIndex {
                    print("h-index for \(profile.name): \(hIndex)")
                }
                if let i10Index = metrics.i10Index {
                    print("i10-index for \(profile.name): \(i10Index)")
                }
                if let growthSummary = growthSummary {
                    let growth = growthSummary.growth
                    let dayLabel = growthSummary.baselineDays == 1 ? "day" : "days"
                    print("Recent growth for \(profile.name): \(growth > 0 ? "+\(growth)" : "\(growth)") in last \(growthSummary.baselineDays) \(dayLabel)")
                } else {
                    print("No recent growth data available for \(profile.name) (insufficient historical data)")
                }
                
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
                
                // Keep startup refresh low-noise; notify only for manual/timed refreshes.
                if !isStartup {
                    sendRefreshCompletionNotificationIfNeeded(
                        attemptedProfiles: profiles.count,
                        successfulProfiles: successfulProfiles,
                        changedProfiles: changedProfiles,
                        totalCitationDelta: totalCitationDelta
                    )
                }
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

    private func sendRefreshCompletionNotificationIfNeeded(
        attemptedProfiles: Int,
        successfulProfiles: Int,
        changedProfiles: Int,
        totalCitationDelta: Int
    ) {
        guard settingsManager.settings.showNotifications else { return }
        guard successfulProfiles > 0 else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                await self.postRefreshCompletionNotification(
                    attemptedProfiles: attemptedProfiles,
                    successfulProfiles: successfulProfiles,
                    changedProfiles: changedProfiles,
                    totalCitationDelta: totalCitationDelta
                )
            case .notDetermined:
                // Permission is requested from a user-facing flow (Settings / onboarding prompt),
                // not during background refresh completion.
                return
            case .denied:
                return
            @unknown default:
                return
            }
        }
    }

    private func postRefreshCompletionNotification(
        attemptedProfiles: Int,
        successfulProfiles: Int,
        changedProfiles: Int,
        totalCitationDelta: Int
    ) async {
        let profileWord = successfulProfiles == 1 ? "profile" : "profiles"
        let changedWord = changedProfiles == 1 ? "profile" : "profiles"

        let detailText: String
        if totalCitationDelta > 0 {
            detailText = "+\(totalCitationDelta) citations across \(changedProfiles) \(changedWord)."
        } else if totalCitationDelta < 0 {
            detailText = "\(totalCitationDelta) citations net across \(changedProfiles) \(changedWord)."
        } else if changedProfiles > 0 {
            detailText = "Citation totals changed in \(changedProfiles) \(changedWord)."
        } else {
            detailText = "No citation changes this cycle."
        }

        let content = UNMutableNotificationContent()
        content.title = "CiteBar Refresh Complete"
        content.body = "Updated \(successfulProfiles)/\(attemptedProfiles) \(profileWord). \(detailText)"
        content.threadIdentifier = "com.hichipli.citebar.refresh"

        let request = UNNotificationRequest(
            identifier: "citebar-refresh-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to post refresh notification: \(error)")
        }
    }
    
    func fetchScholarMetrics(for profile: ScholarProfile) async throws -> ScholarMetrics {
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
        
        let (data, response) = try await urlSession.data(for: request)
        
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
        
        return try parseScholarMetrics(from: html)
    }
    
    private func parseScholarMetrics(from html: String) throws -> ScholarMetrics {
        do {
            let doc = try SwiftSoup.parse(html)
            
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
                            print("Successfully parsed from table - Citations: \(metrics.citationCount), h-index: \(metrics.hIndex ?? -1), i10-index: \(metrics.i10Index ?? -1)")
                            return metrics
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
                print("Selector '\(selector)' found \(elements.count) elements")
                
                if elements.count >= 2 {
                    // Debug: Print all table cell values to understand the structure
                    let elementsArray = Array(elements)
                    print("=== Table Cell Contents ===")
                    for (index, element) in elementsArray.enumerated() {
                        do {
                            let text = try element.text()
                            print("Cell \(index): '\(text)'")
                        } catch {
                            print("Cell \(index): Error reading text")
                        }
                    }
                    print("=== End Table Cells ===")
                    
                    let metrics = parseScholarCellArray(elementsArray)
                    if metrics.citationCount > 0 {
                        print("Successfully parsed from cells - Citations: \(metrics.citationCount), h-index: \(metrics.hIndex ?? -1), i10-index: \(metrics.i10Index ?? -1)")
                        return metrics
                    }
                }
            }
            
            // Last resort fallback
            let allElements = try doc.select("*")
            for element in allElements {
                let text = try element.text()
                if let number = extractValidCitationCount(from: text) {
                    print("Found potential citation count in fallback: \(text) -> \(number)")
                    return ScholarMetrics(citationCount: number, hIndex: nil, i10Index: nil)
                }
            }
            
            print("Could not find citation count in HTML")
            throw CitationError.citationCountNotFound
            
        } catch let error as Exception {
            print("HTML parsing error: \(error)")
            throw CitationError.parsingError
        }
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
                print("Row label: '\(rowLabel)'")

                if rowLabel.lowercased().contains("citations") {
                    // This is the citations row, get the "All" value (second cell)
                    if cells.count >= 2 {
                        let allCell = cells[1]
                        let text = try allCell.text()
                        citationCount = extractValidCitationCount(from: text)
                        print("Found citations row: \(text) -> \(citationCount ?? -1)")
                    }
                } else if rowLabel.lowercased().contains("h-index") {
                    // This is the h-index row, get the "All" value (second cell)
                    if cells.count >= 2 {
                        let allCell = cells[1]
                        let text = try allCell.text()
                        hIndex = extractNumber(from: text)
                        print("Found h-index row: \(text) -> \(hIndex ?? -1)")
                    }
                } else if rowLabel.lowercased().contains("i10-index") {
                    // This is the i10-index row, get the "All" value (second cell)
                    if cells.count >= 2 {
                        let allCell = cells[1]
                        let text = try allCell.text()
                        i10Index = extractNumber(from: text)
                        print("Found i10-index row: \(text) -> \(i10Index ?? -1)")
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
                    print("Found citations after label at index \(index + 1): \(nextText) -> \(citationCount ?? -1)")
                }

                // If we find a cell that says "h-index", the next numeric cell should be h-index
                if text.lowercased().contains("h-index") && index + 1 < elements.count {
                    let nextElement = elements[index + 1]
                    let nextText = try nextElement.text()
                    hIndex = extractNumber(from: nextText)
                    print("Found h-index after label at index \(index + 1): \(nextText) -> \(hIndex ?? -1)")
                }

                // If we find a cell that says "i10-index", the next numeric cell should be i10-index
                if text.lowercased().contains("i10-index") && index + 1 < elements.count {
                    let nextElement = elements[index + 1]
                    let nextText = try nextElement.text()
                    i10Index = extractNumber(from: nextText)
                    print("Found i10-index after label at index \(index + 1): \(nextText) -> \(i10Index ?? -1)")
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
                let records = await storageManager.getAllRecords()
                var currentData: [ScholarProfile: ProfileMetrics] = [:]
                
                for profile in profiles {
                    // Find the most recent record for this profile
                    let profileRecords = records.filter { $0.profileId == profile.id }
                    if let latestRecord = profileRecords.max(by: { $0.timestamp < $1.timestamp }) {
                        // Calculate recent growth for historical data
                        let growthSummary = await storageManager.calculateRecentGrowthSummary(for: profile.id)
                        var updatedProfile = profile
                        updatedProfile.recentGrowth = growthSummary?.growth
                        updatedProfile.recentGrowthDays = growthSummary?.baselineDays
                        currentData[updatedProfile] = ProfileMetrics(citationCount: latestRecord.citationCount, hIndex: latestRecord.hIndex, i10Index: latestRecord.i10Index)

                        print("Loaded historical data for \(profile.name): \(latestRecord.citationCount) citations")
                        if let hIndex = latestRecord.hIndex {
                            print("Historical h-index for \(profile.name): \(hIndex)")
                        }
                        if let i10Index = latestRecord.i10Index {
                            print("Historical i10-index for \(profile.name): \(i10Index)")
                        }
                        if let growthSummary = growthSummary {
                            let growth = growthSummary.growth
                            let dayLabel = growthSummary.baselineDays == 1 ? "day" : "days"
                            print("Historical growth for \(profile.name): \(growth > 0 ? "+\(growth)" : "\(growth)") in last \(growthSummary.baselineDays) \(dayLabel)")
                        }
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
