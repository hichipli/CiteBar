#!/usr/bin/env swift

import Foundation

// Test Google Scholar fetching with the provided URL
func testScholarFetch() async {
    let testURL = "https://scholar.google.com/citations?user=_5pgNWgAAAAJ&hl=en"
    
    print("Testing Google Scholar fetch for: \(testURL)")
    
    // Create request with proper headers
    guard let url = URL(string: testURL) else {
        print("❌ Invalid URL")
        return
    }
    
    var request = URLRequest(url: url)
    request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
    request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", forHTTPHeaderField: "Accept")
    request.setValue("en-US,en;q=0.5", forHTTPHeaderField: "Accept-Language")
    request.timeoutInterval = 30.0
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Not HTTP response")
            return
        }
        
        print("✓ HTTP Status Code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("❌ HTTP error: \(httpResponse.statusCode)")
            return
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            print("❌ Could not decode HTML")
            return
        }
        
        print("✓ HTML received (\(html.count) characters)")
        print("HTML preview: \(String(html.prefix(500)))")
        
        // Simple search for citation patterns
        if html.contains("gsc_rsb_std") {
            print("✓ Found gsc_rsb_std class in HTML")
        } else {
            print("❌ gsc_rsb_std class not found")
        }
        
        // Look for patterns that might contain citation counts
        let patterns = [
            "gsc_rsb_std",
            "Citations",
            "All</td>",
            "h-index",
            "i10-index"
        ]
        
        for pattern in patterns {
            if html.contains(pattern) {
                print("✓ Found pattern: \(pattern)")
            }
        }
        
        print("🔍 This gives us insight into the HTML structure")
        
    } catch {
        print("❌ Error: \(error)")
    }
}

func extractNumber(from text: String) -> Int? {
    let cleanedText = text.replacingOccurrences(of: ",", with: "")
        .replacingOccurrences(of: " ", with: "")
    
    let pattern = #"\d+"#
    if let regex = try? NSRegularExpression(pattern: pattern),
       let match = regex.firstMatch(in: cleanedText, range: NSRange(cleanedText.startIndex..., in: cleanedText)),
       let range = Range(match.range, in: cleanedText) {
        return Int(String(cleanedText[range]))
    }
    
    return nil
}

// Run the test
await testScholarFetch()
print("Test completed")