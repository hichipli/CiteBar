import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var newProfileId = ""
    @State private var newProfileName = ""
    @State private var showingAddProfile = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                AppIconView(size: 40)
                
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
            
            TabView(selection: $selectedTab) {
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
                .tag(0)
                
                // General Tab
                GeneralTab(settingsManager: settingsManager)
                    .tabItem {
                        Label("General", systemImage: "gear")
                    }
                    .tag(1)
                
                // About Tab
                AboutTab()
                    .tabItem {
                        Label("About", systemImage: "info.circle")
                    }
                    .tag(2)
            }
            .frame(height: 300)
        }
        .padding()
        .frame(width: 500, height: 400)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSupportSection"))) { _ in
            selectedTab = 2 // Switch to About tab
        }
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
                VStack(alignment: .leading, spacing: 12) {
                    // Header with guidance
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Profile Order")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("First profile shows in menu bar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Drag-and-drop guidance
                        HStack {
                            Image(systemName: "hand.point.up.left")
                                .foregroundColor(.blue)
                                .font(.caption)
                            
                            Text("Drag profiles to reorder • Click profile names in menu to open Scholar pages")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    List {
                        ForEach(settingsManager.settings.profiles.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.id) { profile in
                            ProfileRow(profile: profile) { updatedProfile in
                                settingsManager.updateProfile(updatedProfile)
                            } onDelete: {
                                settingsManager.removeProfile(profile)
                                
                                // Trigger immediate refresh when deleting profile
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                        appDelegate.updateMenuBarDisplay()
                                    }
                                }
                            } onMakePrimary: {
                                // Move this profile to first position
                                var profiles = settingsManager.settings.profiles
                                profiles.removeAll { $0.id == profile.id }
                                profiles.insert(profile, at: 0)
                                settingsManager.reorderProfiles(profiles)
                                
                                // Trigger immediate refresh when making primary
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                        appDelegate.updateMenuBarDisplay()
                                    }
                                }
                            }
                        }
                        .onMove(perform: moveProfiles)
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
                
                // Immediately show new profile in menu with "Loading..." status
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                        appDelegate.showNewProfileLoading(profile)
                        // Then trigger actual data fetch
                        appDelegate.refreshCitations()
                    }
                }
            }
        }
    }
    
    private func moveProfiles(from source: IndexSet, to destination: Int) {
        var sortedProfiles = settingsManager.settings.profiles.sorted(by: { $0.sortOrder < $1.sortOrder })
        sortedProfiles.move(fromOffsets: source, toOffset: destination)
        settingsManager.reorderProfiles(sortedProfiles)
        
        // Immediately update menu bar display after reordering
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                appDelegate.updateMenuBarDisplay()
            }
        }
    }
}

struct ProfileRow: View {
    let profile: ScholarProfile
    let onUpdate: (ScholarProfile) -> Void
    let onDelete: () -> Void
    let onMakePrimary: () -> Void
    
    @State private var showingEditSheet = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.caption)
                .help("Drag to reorder profiles")
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(profile.name)
                        .font(.headline)
                    
                    if profile.sortOrder == 0 {
                        Text("Primary")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                }
                
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
            
            // Make Primary button (only show for non-primary profiles)
            if profile.sortOrder != 0 {
                Button("Set Primary") {
                    onMakePrimary()
                }
                .font(.caption)
                .foregroundColor(.orange)
                .help("Make this the primary profile")
            }
            
            Button("Edit") {
                showingEditSheet = true
            }
            .foregroundColor(.blue)
            .help("Edit or delete this profile")
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingEditSheet) {
            EditProfileSheet(profile: profile, onUpdate: { updatedProfile in
                onUpdate(updatedProfile)
            }, onDelete: {
                onDelete()
            })
        }
    }
}

struct GeneralTab: View {
    @ObservedObject var settingsManager: SettingsManager
    
    private func getAutoLaunchStatus() -> String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "✓ Auto-launch is enabled"
        case .notRegistered:
            return "Not registered for auto-launch"
        case .notFound:
            return "Service not found"
        case .requiresApproval:
            return "⚠️ Waiting for user approval in System Settings"
        @unknown default:
            return "Unknown status"
        }
    }
    
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
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Automatically start CiteBar when you log in")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Show current SMAppService status
                    let status = getAutoLaunchStatus()
                    if !status.isEmpty {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(status.contains("enabled") ? .green : (status.contains("approval") ? .orange : .secondary))
                    }
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Menu Bar Display")
                    .font(.headline)
                
                Text("The first profile in your Profiles list will be shown in the menu bar. Drag profiles to reorder them.")
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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // App header section
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        AppIconView(size: 56)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CiteBar")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Citation Tracking for Academics")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 8) {
                                Text(AppVersion.displayString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(3)
                                
                                Text("macOS")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(3)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                Divider()
                
                // Key features section
                VStack(spacing: 16) {
                    HStack {
                        Text("Key Features")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(
                            icon: "chart.line.uptrend.xyaxis",
                            iconColor: .blue,
                            title: "Real-time Citation Tracking",
                            description: "Monitor Google Scholar metrics directly from your menu bar"
                        )
                        
                        FeatureRow(
                            icon: "person.2",
                            iconColor: .green,
                            title: "Multiple Profile Support",
                            description: "Track citations for multiple researchers and collaborators"
                        )
                        
                        FeatureRow(
                            icon: "clock.arrow.circlepath",
                            iconColor: .orange,
                            title: "Configurable Updates",
                            description: "Set custom refresh intervals to respect rate limits"
                        )
                        
                        FeatureRow(
                            icon: "chart.xyaxis.line",
                            iconColor: .purple,
                            title: "Historical Data",
                            description: "View citation growth trends over time"
                        )
                    }
                }
                
                Divider()
                
                // Support section
                VStack(spacing: 16) {
                    HStack {
                        Text("Support & Feedback")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        SupportRow(
                            icon: "envelope",
                            iconColor: .blue,
                            title: "Email Support",
                            subtitle: "info@hichipli.com",
                            action: {
                                if let url = URL(string: "mailto:info@hichipli.com") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        )
                        
                        SupportRow(
                            icon: "globe",
                            iconColor: .purple,
                            title: "GitHub Repository",
                            subtitle: "Report issues & contribute",
                            action: {
                                if let url = URL(string: "https://github.com/hichipli/CiteBar") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        )
                    }
                }
                
                Divider()
                
                // Footer section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Built with passion for the academic community.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Helping researchers focus on what matters most.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    
                    HStack {
                        Text("© 2025 CiteBar")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                        
                        Spacer()
                        
                        Text("Made for macOS")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                
                Spacer(minLength: 16)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20, height: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct SupportRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20, height: 20)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

struct AddProfileSheet: View {
    @Binding var profileId: String
    @Binding var profileName: String
    @Binding var showingError: Bool
    @Binding var errorMessage: String
    let onAdd: (String, String) -> Void
    
    @State private var urlInput = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, url, id
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                AppIconView(size: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Google Scholar Profile")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Track citation metrics for a researcher")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Profile Name Section
            VStack(alignment: .leading, spacing: 8) {
                Label("Profile Name", systemImage: "person.circle")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("e.g., Dr. Jane Smith", text: $profileName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .name)
                    .onSubmit {
                        focusedField = .url
                    }
            }
            
            // Scholar URL/ID Section
            VStack(alignment: .leading, spacing: 12) {
                Label("Google Scholar Profile", systemImage: "link")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // URL Input with enhanced paste support
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Paste Google Scholar URL here", text: $urlInput)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .url)
                            .onChange(of: urlInput) { newValue in
                                extractScholarId(from: newValue)
                            }
                            .onSubmit {
                                if profileId.isEmpty {
                                    focusedField = .id
                                } else {
                                    submitForm()
                                }
                            }
                        
                        Button(action: {
                            if let clipboardString = NSPasteboard.general.string(forType: .string) {
                                urlInput = clipboardString
                                extractScholarId(from: clipboardString)
                            }
                        }) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.bordered)
                        .help("Paste from clipboard")
                    }
                    
                    Text("Example: https://scholar.google.com/citations?user=ABC123DEF&hl=en")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Alternative ID input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or enter Scholar ID directly:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("e.g., ABC123DEF456", text: $profileId)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .id)
                        .onSubmit {
                            submitForm()
                        }
                }
                
                // Instructions
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "1.circle.fill")
                                .foregroundColor(.blue)
                            Text("Go to your Google Scholar profile page")
                        }
                        .font(.caption)
                        
                        HStack {
                            Image(systemName: "2.circle.fill")
                                .foregroundColor(.blue)
                            Text("Copy the full URL from your browser")
                        }
                        .font(.caption)
                        
                        HStack {
                            Image(systemName: "3.circle.fill")
                                .foregroundColor(.blue)
                            Text("Paste it above - we'll extract the ID automatically")
                        }
                        .font(.caption)
                    }
                    .padding(.top, 8)
                } label: {
                    Label("How to find your Scholar ID", systemImage: "questionmark.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Success indicator
            if !profileId.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Scholar ID extracted: \(profileId)")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    clearForm()
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add Profile") {
                    submitForm()
                }
                .buttonStyle(.borderedProminent)
                .disabled(profileId.isEmpty || profileName.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 560)
        .onAppear {
            focusedField = .name
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func tryAutoPaste() {
        if let clipboardString = NSPasteboard.general.string(forType: .string) {
            urlInput = clipboardString
            extractScholarId(from: clipboardString)
        }
    }
    
    private func submitForm() {
        if profileId.isEmpty || profileName.isEmpty {
            errorMessage = "Please fill in all fields"
            showingError = true
        } else if !isValidScholarId(profileId) {
            errorMessage = "Invalid Scholar ID format. Please check your ID."
            showingError = true
        } else {
            onAdd(profileId, profileName)
            dismiss()
        }
    }
    
    private func clearForm() {
        profileId = ""
        profileName = ""
        urlInput = ""
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

struct EditProfileSheet: View {
    let profile: ScholarProfile
    let onUpdate: (ScholarProfile) -> Void
    let onDelete: () -> Void
    
    @State private var profileName: String
    @State private var profileId: String
    @State private var urlInput: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteConfirmation = false
    
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, url, id
    }
    
    init(profile: ScholarProfile, onUpdate: @escaping (ScholarProfile) -> Void, onDelete: @escaping () -> Void) {
        self.profile = profile
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self._profileName = State(initialValue: profile.name)
        self._profileId = State(initialValue: profile.id)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                AppIconView(size: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Edit Profile")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Update researcher information")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Profile Name Section
            VStack(alignment: .leading, spacing: 8) {
                Label("Profile Name", systemImage: "person.circle")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("e.g., Dr. Jane Smith", text: $profileName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .name)
                    .onSubmit {
                        focusedField = .url
                    }
            }
            
            // Scholar URL/ID Section
            VStack(alignment: .leading, spacing: 12) {
                Label("Google Scholar Profile", systemImage: "link")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // URL Input with enhanced paste support
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Paste Google Scholar URL here", text: $urlInput)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .url)
                            .onChange(of: urlInput) { newValue in
                                extractScholarId(from: newValue)
                            }
                            .onSubmit {
                                if profileId.isEmpty {
                                    focusedField = .id
                                } else {
                                    submitForm()
                                }
                            }
                        
                        Button(action: {
                            if let clipboardString = NSPasteboard.general.string(forType: .string) {
                                urlInput = clipboardString
                                extractScholarId(from: clipboardString)
                            }
                        }) {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.bordered)
                        .help("Paste from clipboard")
                    }
                    
                    Text("Example: https://scholar.google.com/citations?user=ABC123DEF&hl=en")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Direct ID input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scholar ID:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("e.g., ABC123DEF456", text: $profileId)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .id)
                        .onSubmit {
                            submitForm()
                        }
                }
            }
            
            // Success indicator
            if !profileId.isEmpty && profileId != profile.id {  
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Scholar ID updated: \(profileId)")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Delete Profile") {
                    showingDeleteConfirmation = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                Button("Save Changes") {
                    submitForm()
                }
                .buttonStyle(.borderedProminent)
                .disabled(profileId.isEmpty || profileName.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 560)
        .onAppear {
            focusedField = .name
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog("Delete Profile", isPresented: $showingDeleteConfirmation) {
            Button("Delete \(profile.name)", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(profile.name)'? This action cannot be undone.")
        }
    }
    
    private func submitForm() {
        if profileId.isEmpty || profileName.isEmpty {
            errorMessage = "Please fill in all fields"
            showingError = true
        } else if !isValidScholarId(profileId) {
            errorMessage = "Invalid Scholar ID format. Please check your ID."
            showingError = true
        } else {
            // Create new profile with updated values
            let updatedProfile = ScholarProfile(id: profileId, name: profileName, sortOrder: profile.sortOrder)
            var mutableProfile = updatedProfile
            mutableProfile.isEnabled = profile.isEnabled
            mutableProfile.recentGrowth = profile.recentGrowth
            onUpdate(mutableProfile)
            dismiss()
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

struct AppIconView: View {
    let size: CGFloat
    
    var body: some View {
        if let appIcon = loadAppIcon() {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: size, height: size)
                .cornerRadius(size * 0.176) // iOS/macOS app icon corner radius ratio
        } else {
            Image(systemName: "book.circle.fill")
                .font(.system(size: size * 0.75))
                .foregroundColor(.blue)
        }
    }
    
    private func loadAppIcon() -> NSImage? {
        // Try different methods to load the app icon
        if let iconFromBundle = NSImage(named: "AppIcon") {
            return iconFromBundle
        }
        
        // Try loading from resources
        if let resourcePath = Bundle.main.path(forResource: "1024", ofType: "png"),
           let iconFromResource = NSImage(contentsOfFile: resourcePath) {
            return iconFromResource
        }
        
        // Try loading from asset catalog path
        let assetPath = "Assets.xcassets/AppIcon.appiconset/1024.png"
        if let iconFromAsset = NSImage(contentsOfFile: assetPath) {
            return iconFromAsset
        }
        
        // Try loading the app's icon from the app bundle
        if let bundleIconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let iconFromICNS = NSImage(contentsOfFile: bundleIconPath) {
            return iconFromICNS
        }
        
        return nil
    }
}

