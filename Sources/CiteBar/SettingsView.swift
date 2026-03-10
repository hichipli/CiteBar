import SwiftUI
import ServiceManagement
import UserNotifications

private enum SettingsSection: String, CaseIterable, Identifiable {
    case profiles
    case general
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .profiles: return "Profiles"
        case .general: return "General"
        case .about: return "About"
        }
    }

    var subtitle: String {
        switch self {
        case .profiles: return "Manage Scholar accounts"
        case .general: return "Refresh and display options"
        case .about: return "Version, features, and support"
        }
    }

    var icon: String {
        switch self {
        case .profiles: return "person.2.fill"
        case .general: return "gearshape.fill"
        case .about: return "info.circle.fill"
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var newProfileId = ""
    @State private var newProfileName = ""
    @State private var showingAddProfile = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedSection: SettingsSection = .profiles

    var body: some View {
        // A fixed split layout is more predictable here than NavigationSplitView
        // for this app's settings window sizing and section switching behavior.
        HStack(spacing: 0) {
            SettingsSidebar(selectedSection: $selectedSection)
                .frame(width: 260)

            Divider()

            Group {
                switch selectedSection {
                case .profiles:
                    ProfilesTab(
                        settingsManager: settingsManager,
                        newProfileId: $newProfileId,
                        newProfileName: $newProfileName,
                        showingAddProfile: $showingAddProfile,
                        showingError: $showingError,
                        errorMessage: $errorMessage
                    )
                case .general:
                    GeneralTab(settingsManager: settingsManager)
                case .about:
                    AboutTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 900, minHeight: 620)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSupportSection"))) { _ in
            selectedSection = .about
        }
    }
}

private struct SettingsSidebar: View {
    @Binding var selectedSection: SettingsSection

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                AppIconView(size: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text("CiteBar Settings")
                        .font(.headline)
                    Text("Preferences")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            // Keep native List selection for reliable macOS row hit-testing.
            List(SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
                    .help(section.subtitle)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
    }
}

struct ProfilesTab: View {
    @ObservedObject var settingsManager: SettingsManager
    @Binding var newProfileId: String
    @Binding var newProfileName: String
    @Binding var showingAddProfile: Bool
    @Binding var showingError: Bool
    @Binding var errorMessage: String

    private var sortedProfiles: [ScholarProfile] {
        settingsManager.settings.profiles.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Google Scholar Profiles")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Add, reorder, and maintain the profiles shown in your menu bar.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    showingAddProfile = true
                } label: {
                    Label("Add Profile", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if sortedProfiles.isEmpty {
                SettingsCard {
                    VStack(spacing: 14) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 34, weight: .regular))
                            .foregroundColor(.secondary)

                        Text("No profiles configured")
                            .font(.headline)

                        Text("Add your Google Scholar profile to start tracking citations.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button {
                            showingAddProfile = true
                        } label: {
                            Label("Add First Profile", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, minHeight: 240)
                    .padding(.vertical, 12)
                }
            } else {
                SettingsCard(
                    title: "Profile Order",
                    subtitle: "Drag rows to reorder. The top profile is shown in the menu bar.",
                    expandContent: true
                ) {
                    List {
                        ForEach(sortedProfiles, id: \.id) { profile in
                            ProfileRow(profile: profile) { updatedProfile in
                                settingsManager.updateProfile(updatedProfile)
                            } onDelete: {
                                settingsManager.removeProfile(profile)

                                // Trigger immediate refresh when deleting profile.
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                        appDelegate.updateMenuBarDisplay()
                                    }
                                }
                            } onMakePrimary: {
                                // Move this profile to first position.
                                var profiles = settingsManager.settings.profiles
                                profiles.removeAll { $0.id == profile.id }
                                profiles.insert(profile, at: 0)
                                settingsManager.reorderProfiles(profiles)

                                // Trigger immediate refresh when making primary.
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                        appDelegate.updateMenuBarDisplay()
                                    }
                                }
                            }
                        }
                        .onMove(perform: moveProfiles)
                    }
                    .listStyle(.inset)
                    .frame(maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)
                .layoutPriority(1)

                SettingsCard {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("Click profile names in the menu to open each Scholar page quickly.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showingAddProfile) {
            AddProfileSheet(
                profileId: $newProfileId,
                profileName: $newProfileName,
                showingError: $showingError,
                errorMessage: $errorMessage
            ) { id, name, prefetchedSnapshot in
                let profile = ScholarProfile(id: id, name: name)
                settingsManager.addProfile(profile)
                newProfileId = ""
                newProfileName = ""
                showingAddProfile = false

                // Immediately show new profile in menu with "Loading..." status.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                        appDelegate.showNewProfileLoading(profile)
                        Task { @MainActor in
                            await appDelegate.primeNewProfile(profile, prefetchedSnapshot: prefetchedSnapshot)
                        }
                    }
                }
            }
        }
    }

    private func moveProfiles(from source: IndexSet, to destination: Int) {
        var updatedProfiles = settingsManager.settings.profiles.sorted(by: { $0.sortOrder < $1.sortOrder })
        updatedProfiles.move(fromOffsets: source, toOffset: destination)
        settingsManager.reorderProfiles(updatedProfiles)

        // Immediately update menu bar display after reordering.
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
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.caption)
                .help("Drag to reorder profiles")

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(profile.name)
                        .font(.body)
                        .fontWeight(.semibold)

                    if profile.sortOrder == 0 {
                        Text("Primary")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundColor(.accentColor)
                            .clipShape(Capsule())
                    }

                    Spacer()
                }

                Text("ID: \(profile.id)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let growth = profile.recentGrowth {
                    let growthText = growth > 0 ? "+\(growth)" : "\(growth)"
                    if let growthDays = profile.recentGrowthDays {
                        let dayLabel = growthDays == 1 ? "day" : "days"
                        Text("Recent growth: \(growthText) in last \(growthDays) \(dayLabel)")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Recent growth: \(growthText)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            Spacer()

            HStack(spacing: 10) {
                if profile.sortOrder != 0 {
                    Button("Set Primary") {
                        onMakePrimary()
                    }
                    .frame(width: 124)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Make this the primary profile")
                } else {
                    Color.clear
                        .frame(width: 124, height: 0)
                }

                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit", systemImage: "slider.horizontal.3")
                }
                .frame(width: 112)
                .buttonStyle(.bordered)
                .labelStyle(.titleAndIcon)
                .controlSize(.regular)
                .help("Edit or delete this profile")
            }
            .frame(width: 246, alignment: .trailing)
        }
        .padding(.vertical, 6)
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
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined

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

    private func refreshNotificationAuthorizationStatus() {
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            notificationAuthorizationStatus = settings.authorizationStatus
        }
    }

    private func requestNotificationPermissionIfNeeded() {
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            notificationAuthorizationStatus = settings.authorizationStatus

            guard settings.authorizationStatus == .notDetermined else { return }

            _ = (try? await center.requestAuthorization(options: [.alert, .badge])) ?? false
            let updated = await center.notificationSettings()
            notificationAuthorizationStatus = updated.authorizationStatus
        }
    }

    private func openNotificationSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.notifications",
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
        ]

        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard(
                    title: "Refresh Schedule",
                    subtitle: "Recommended: Once daily. Use \"Refresh Now\" when you need an immediate update."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        SettingsControlRow("Refresh Interval") {
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
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .fixedSize(horizontal: true, vertical: false)
                        }

                        Divider()

                        Text("Short intervals (for example hourly) increase request frequency and may trigger temporary Google Scholar rate limits, including reduced access to profiles or search.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider()

                        SettingsActionRow(
                            text: "Need immediate data? Trigger a refresh now.",
                            buttonTitle: "Refresh Now"
                        ) {
                            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                appDelegate.refreshCitations()
                            }
                        }
                    }
                }

                SettingsCard(
                    title: "Notifications",
                    subtitle: "Get notified when refresh completes with a citation summary."
                ) {
                    SettingsToggleRow(
                        "Show Notifications",
                        subtitle: "Use macOS notifications for refresh completion.",
                        isOn: Binding(
                            get: { settingsManager.settings.showNotifications },
                            set: { enabled in
                                settingsManager.setNotifications(enabled)
                                if enabled {
                                    requestNotificationPermissionIfNeeded()
                                }
                            }
                        )
                    )

                    if settingsManager.settings.showNotifications {
                        Divider()
                        switch notificationAuthorizationStatus {
                        case .authorized, .provisional:
                            SettingsStatusRow(
                                icon: "checkmark.seal.fill",
                                text: "System notification permission is enabled.",
                                tint: .green
                            )
                        case .notDetermined:
                            SettingsActionRow(
                                text: "Notification permission has not been requested yet.",
                                buttonTitle: "Enable Notifications"
                            ) {
                                requestNotificationPermissionIfNeeded()
                            }
                        case .denied:
                            SettingsStatusRow(
                                icon: "exclamationmark.triangle.fill",
                                text: "System notification permission is currently blocked for CiteBar.",
                                tint: .orange
                            )
                            SettingsActionRow(
                                text: "Permission is blocked in macOS settings.",
                                buttonTitle: "Open Notification Settings"
                            ) {
                                openNotificationSettings()
                            }
                        case .ephemeral:
                            SettingsStatusRow(
                                icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                                text: "System notification permission is temporarily available.",
                                tint: .secondary
                            )
                        @unknown default:
                            EmptyView()
                        }
                    }
                }

                SettingsCard(
                    title: "Startup",
                    subtitle: "Control whether CiteBar starts automatically when you sign in."
                ) {
                    SettingsToggleRow(
                        "Launch at Login",
                        subtitle: "Automatically start CiteBar when you log in.",
                        isOn: Binding(
                            get: { settingsManager.settings.autoLaunch },
                            set: { enabled in
                                settingsManager.setAutoLaunch(enabled)
                            }
                        )
                    )

                    Divider()

                    let status = getAutoLaunchStatus()
                    SettingsStatusRow(
                        icon: status.contains("enabled") ? "checkmark.circle.fill" : "gearshape.2.fill",
                        text: status,
                        tint: status.contains("enabled") ? .green : (status.contains("approval") ? .orange : .secondary)
                    )
                }

                SettingsCard(
                    title: "Menu Bar Display",
                    subtitle: "Choose which citation metric appears in the menu bar, then toggle optional details below."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("To change profile order (and which profile appears first), use the Profiles section and drag rows.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider()

                        SettingsControlRow("Primary citation metric") {
                            Picker("Primary citation metric", selection: Binding(
                                get: { settingsManager.settings.menuBarPrimaryMetric },
                                set: { metric in
                                    settingsManager.setMenuBarPrimaryMetric(metric)
                                    if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                        appDelegate.updateMenuBarDisplay()
                                    }
                                }
                            )) {
                                ForEach(AppSettings.MenuBarPrimaryMetric.allCases, id: \.self) { metric in
                                    Text(metric.displayName).tag(metric)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .fixedSize(horizontal: true, vertical: false)
                        }

                        Divider()

                        SettingsToggleRow(
                            "Show h-index",
                            subtitle: "Display h-index under each profile.",
                            isOn: Binding(
                                get: { settingsManager.settings.showHIndexInMenu },
                                set: { enabled in
                                    settingsManager.setShowHIndexInMenu(enabled)
                                }
                            )
                        )

                        SettingsToggleRow(
                            "Show i10-index",
                            subtitle: "Display i10-index under each profile.",
                            isOn: Binding(
                                get: { settingsManager.settings.showI10IndexInMenu },
                                set: { enabled in
                                    settingsManager.setShowI10IndexInMenu(enabled)
                                }
                            )
                        )

                        SettingsToggleRow(
                            "Show trend (+X in last Y days)",
                            subtitle: "Display recent growth information when available.",
                            isOn: Binding(
                                get: { settingsManager.settings.showTrendInMenu },
                                set: { enabled in
                                    settingsManager.setShowTrendInMenu(enabled)
                                }
                            )
                        )
                    }
                }

                SettingsCard(
                    title: "App",
                    subtitle: "Advanced app controls."
                ) {
                    SettingsActionRow(
                        text: "Quit CiteBar and stop background refresh until the app is opened again.",
                        buttonTitle: "Quit CiteBar"
                    ) {
                        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                            appDelegate.quitApp()
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            refreshNotificationAuthorizationStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshNotificationAuthorizationStatus()
        }
    }
}

struct AboutTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsCard {
                    HStack(spacing: 16) {
                        AppIconView(size: 56)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("CiteBar")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Citation Tracking for Academics")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                Text(AppVersion.displayString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())

                                Text("macOS")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.14))
                                    .clipShape(Capsule())
                            }

                            Button {
                                if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                    appDelegate.checkForUpdates()
                                }
                            } label: {
                                Label("Check for Updates...", systemImage: "arrow.down.circle")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .padding(.top, 2)
                        }

                        Spacer()
                    }
                }

                SettingsCard(title: "Key Features") {
                    VStack(alignment: .leading, spacing: 12) {
                        FeatureRow(
                            icon: "chart.line.uptrend.xyaxis",
                            iconColor: .blue,
                            title: "Real-time Citation Tracking",
                            description: "Monitor Google Scholar metrics directly from your menu bar."
                        )

                        FeatureRow(
                            icon: "person.2",
                            iconColor: .green,
                            title: "Multiple Profile Support",
                            description: "Track citations for multiple researchers and collaborators."
                        )

                        FeatureRow(
                            icon: "clock.arrow.circlepath",
                            iconColor: .orange,
                            title: "Configurable Updates",
                            description: "Set refresh intervals that balance freshness and rate-limit safety."
                        )

                        FeatureRow(
                            icon: "chart.xyaxis.line",
                            iconColor: .purple,
                            title: "Historical Data",
                            description: "View citation growth trends over time."
                        )
                    }
                }

                SettingsCard(title: "Support & Feedback") {
                    VStack(alignment: .leading, spacing: 10) {
                        SupportRow(
                            icon: "envelope.fill",
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
                            icon: "chevron.left.forwardslash.chevron.right",
                            iconColor: .purple,
                            title: "GitHub Repository",
                            subtitle: "Report issues and contribute",
                            action: {
                                if let url = URL(string: "https://github.com/hichipli/CiteBar") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        )
                    }
                }

                SettingsCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Built with passion for the academic community.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("© 2026 CiteBar")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.75))
                            Spacer()
                            Text("Made for macOS")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.75))
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 14, weight: .semibold))
            }

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
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconColor.opacity(0.14))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.system(size: 14, weight: .semibold))
                }

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
            .padding(.vertical, 2)
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

private struct SettingsCard<Content: View>: View {
    let title: String?
    let subtitle: String?
    let expandContent: Bool
    let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        expandContent: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.expandContent = expandContent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
            }

            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if expandContent {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: expandContent ? .infinity : nil, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsControlRow<Control: View>: View {
    let title: String
    let subtitle: String?
    let control: Control

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            control
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsActionRow: View {
    let text: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsStatusRow: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(tint)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

struct AddProfileSheet: View {
    @Binding var profileId: String
    @Binding var profileName: String
    @Binding var showingError: Bool
    @Binding var errorMessage: String
    let onAdd: (String, String, CitationManager.ScholarProfileSnapshot?) -> Void
    
    @State private var urlInput = ""
    @State private var isAutoResolvingName = false
    @State private var lastAutoResolvedId = ""
    @State private var prefetchedSnapshot: CitationManager.ScholarProfileSnapshot?
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
                Label("Profile Name (Optional)", systemImage: "person.circle")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("Auto-filled from profile page (or type manually)", text: $profileName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .name)
                    .onSubmit {
                        focusedField = .url
                    }

                Text("Leave blank to add with just the Scholar URL/ID.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
            if isAutoResolvingName && profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Trying to auto-fill profile name...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

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
                .disabled(
                    profileId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    (isAutoResolvingName && profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                )
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 560)
        .onAppear {
            focusedField = .url
        }
        .onChange(of: profileId) { newId in
            maybeAutoResolveName(for: newId)
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
        let trimmedId = profileId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedId.isEmpty {
            errorMessage = "Please enter a Scholar URL or ID"
            showingError = true
        } else if !isValidScholarId(trimmedId) {
            errorMessage = "Invalid Scholar ID format. Please check your ID."
            showingError = true
        } else {
            let trimmedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackName = "Scholar \(trimmedId)"
            let snapshotForID = prefetchedSnapshot?.profileID == trimmedId ? prefetchedSnapshot : nil
            let snapshotName = snapshotForID?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalName: String
            if trimmedName.isEmpty,
               let snapshotName,
               !snapshotName.isEmpty {
                finalName = snapshotName
            } else if trimmedName.isEmpty {
                finalName = fallbackName
            } else {
                finalName = trimmedName
            }
            onAdd(trimmedId, finalName, snapshotForID)
            dismiss()
        }
    }
    
    private func clearForm() {
        profileId = ""
        profileName = ""
        urlInput = ""
        isAutoResolvingName = false
        lastAutoResolvedId = ""
        prefetchedSnapshot = nil
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

    private func maybeAutoResolveName(for rawId: String) {
        let trimmedId = rawId.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)

        if prefetchedSnapshot?.profileID != trimmedId {
            prefetchedSnapshot = nil
        }

        guard !trimmedId.isEmpty, isValidScholarId(trimmedId) else {
            isAutoResolvingName = false
            return
        }

        guard trimmedName.isEmpty else {
            isAutoResolvingName = false
            return
        }

        guard trimmedId != lastAutoResolvedId else {
            return
        }

        lastAutoResolvedId = trimmedId
        isAutoResolvingName = true

        Task {
            let snapshot = await (NSApplication.shared.delegate as? AppDelegate)?
                .citationManager?
                .fetchScholarProfileSnapshot(for: trimmedId)

            await MainActor.run {
                guard profileId.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedId else {
                    return
                }

                isAutoResolvingName = false
                prefetchedSnapshot = snapshot

                guard profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return
                }

                if let resolvedName = snapshot?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !resolvedName.isEmpty {
                    profileName = resolvedName
                }
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
            mutableProfile.recentGrowthDays = profile.recentGrowthDays
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
