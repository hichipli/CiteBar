import SwiftUI

struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager()
    @State private var newProfileId = ""
    @State private var newProfileName = ""
    @State private var showingAddProfile = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "book.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("CiteBar Settings")
                        .font(.title2)
                        .bold()
                    Text("Manage your Google Scholar profiles and preferences")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            
            TabView {
                // Profiles Tab
                ProfilesTab(
                    settingsManager: settingsManager,
                    newProfileId: $newProfileId,
                    newProfileName: $newProfileName,
                    showingAddProfile: $showingAddProfile,
                    showingError: $showingError,
                    errorMessage: $errorMessage
                )
                .tabItem {
                    Label("Profiles", systemImage: "person.2.fill")
                }
                
                // General Tab
                GeneralTab(settingsManager: settingsManager)
                    .tabItem {
                        Label("General", systemImage: "gear")
                    }
                
                // About Tab
                AboutTab()
                    .tabItem {
                        Label("About", systemImage: "info.circle")
                    }
            }
            .frame(height: 300)
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

struct ProfilesTab: View {
    @ObservedObject var settingsManager: SettingsManager
    @Binding var newProfileId: String
    @Binding var newProfileName: String
    @Binding var showingAddProfile: Bool
    @Binding var showingError: Bool
    @Binding var errorMessage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Google Scholar Profiles")
                    .font(.headline)
                
                Spacer()
                
                Button("Add Profile") {
                    showingAddProfile = true
                }
            }
            
            if settingsManager.settings.profiles.isEmpty {
                VStack {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("No profiles configured")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Add your Google Scholar profile to start tracking citations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(settingsManager.settings.profiles, id: \.id) { profile in
                        ProfileRow(profile: profile) { updatedProfile in
                            settingsManager.updateProfile(updatedProfile)
                        } onDelete: {
                            settingsManager.removeProfile(profile)
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingAddProfile) {
            AddProfileSheet(
                profileId: $newProfileId,
                profileName: $newProfileName,
                showingError: $showingError,
                errorMessage: $errorMessage
            ) { id, name in
                let profile = ScholarProfile(id: id, name: name)
                settingsManager.addProfile(profile)
                newProfileId = ""
                newProfileName = ""
                showingAddProfile = false
            }
        }
    }
}

struct ProfileRow: View {
    let profile: ScholarProfile
    let onUpdate: (ScholarProfile) -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)
                
                Text("ID: \(profile.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let growth = profile.recentGrowth {
                    Text("Recent growth: +\(growth)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { profile.isEnabled },
                set: { enabled in
                    var updatedProfile = profile
                    updatedProfile.isEnabled = enabled
                    onUpdate(updatedProfile)
                }
            ))
            
            Button("Delete") {
                onDelete()
            }
            .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }
}

struct GeneralTab: View {
    @ObservedObject var settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Refresh Interval")
                    .font(.headline)
                
                Text("How often to check for citation updates")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Refresh Interval", selection: Binding(
                    get: { settingsManager.settings.refreshInterval },
                    set: { interval in
                        settingsManager.setRefreshInterval(interval)
                    }
                )) {
                    ForEach(AppSettings.RefreshInterval.allCases, id: \.self) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Show Notifications", isOn: Binding(
                    get: { settingsManager.settings.showNotifications },
                    set: { enabled in
                        settingsManager.setNotifications(enabled)
                    }
                ))
                
                Text("Get notified when citation counts update")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Launch at Login", isOn: Binding(
                    get: { settingsManager.settings.autoLaunch },
                    set: { enabled in
                        settingsManager.setAutoLaunch(enabled)
                    }
                ))
                
                Text("Automatically start CiteBar when you log in")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("CiteBar")
                .font(.title)
                .bold()
            
            Text("Citation Tracking for Academics")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("CiteBar helps early-career academics track their Google Scholar citation metrics right from the menu bar.")
                    .multilineTextAlignment(.center)
                
                Text("Built with passion for the academic community.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct AddProfileSheet: View {
    @Binding var profileId: String
    @Binding var profileName: String
    @Binding var showingError: Bool
    @Binding var errorMessage: String
    let onAdd: (String, String) -> Void
    
    @State private var urlInput = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Google Scholar Profile")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Profile Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Your Name", text: $profileName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Google Scholar Profile")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // URL Input with paste button
                HStack {
                    TextField("Paste your Google Scholar profile URL here", text: $urlInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: urlInput) { newValue in
                            extractScholarId(from: newValue)
                        }
                    
                    Button("Paste") {
                        if let clipboardString = NSPasteboard.general.string(forType: .string) {
                            urlInput = clipboardString
                            extractScholarId(from: clipboardString)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Text("Or enter Scholar ID directly:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("e.g., ABC123DEF456", text: $profileId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("How to find your Google Scholar ID:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("1. Go to your Google Scholar profile page")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("2. Copy the full URL (e.g., https://scholar.google.com/citations?user=ABC123DEF&hl=en)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("3. Paste it above, or just copy the ID part after 'user='")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
            
            if !profileId.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Scholar ID: \(profileId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Button("Cancel") {
                    profileId = ""
                    profileName = ""
                    urlInput = ""
                }
                
                Spacer()
                
                Button("Add Profile") {
                    if profileId.isEmpty || profileName.isEmpty {
                        errorMessage = "Please fill in all fields"
                        showingError = true
                    } else if !isValidScholarId(profileId) {
                        errorMessage = "Invalid Scholar ID format. Please check your ID."
                        showingError = true
                    } else {
                        onAdd(profileId, profileName)
                    }
                }
                .disabled(profileId.isEmpty || profileName.isEmpty)
            }
        }
        .padding()
        .frame(width: 500)
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func extractScholarId(from url: String) {
        // Extract Scholar ID from URL
        if let range = url.range(of: "user=") {
            var id = String(url[range.upperBound...])
            
            // Remove everything after & or # if present
            if let ampersandRange = id.range(of: "&") {
                id = String(id[..<ampersandRange.lowerBound])
            }
            if let hashRange = id.range(of: "#") {
                id = String(id[..<hashRange.lowerBound])
            }
            
            if !id.isEmpty && id != profileId {
                profileId = id
            }
        }
    }
    
    private func isValidScholarId(_ id: String) -> Bool {
        // Basic validation: should be alphanumeric and reasonable length
        let pattern = "^[A-Za-z0-9_-]{8,20}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: id.count)
        return regex?.firstMatch(in: id, options: [], range: range) != nil
    }
}

