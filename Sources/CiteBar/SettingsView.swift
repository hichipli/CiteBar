import SwiftUI
import ServiceManagement
import UserNotifications

enum SettingsPane: Int {
    case profiles, general, about
}

/// Settings window content: native toolbar tabs, one SwiftUI pane per tab. The window
/// resizes to each pane, keeping its top edge in place.
@MainActor final class SettingsTabController: NSTabViewController {
    init(model: DashboardModel, pane: SettingsPane, startAddingProfile: Bool) {
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
        transitionOptions = [.crossfade, .allowUserInteraction]

        addPane("Profiles", symbol: "person.2", ProfilesPane(model: model, showingAdd: startAddingProfile))
        addPane("General", symbol: "gearshape", GeneralPane(model: model))
        addPane("About", symbol: "info.circle", AboutPane())
        selectedTabViewItemIndex = pane.rawValue
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addPane<Content: View>(_ title: String, symbol: String, _ content: Content) {
        let host = NSHostingController(rootView: content)
        host.sizingOptions = [.preferredContentSize]
        host.title = title
        let item = NSTabViewItem(viewController: host)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        addTabViewItem(item)
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        guard let window = view.window, let size = tabViewItem?.viewController?.preferredContentSize,
              size.width > 0, size.height > 0 else { return }
        let frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        let origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        window.setFrame(NSRect(origin: origin, size: frame.size), display: true, animate: window.isVisible)
    }
}

@MainActor private func refreshMenuBar() {
    (NSApp.delegate as? AppDelegate)?.updateMenuBarDisplay()
}

// MARK: - Profiles

struct ProfilesPane: View {
    @ObservedObject var model: DashboardModel
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State var showingAdd: Bool

    @State private var renamingProfile: ScholarProfile?
    @State private var groupingProfile: ScholarProfile?
    @State private var renamingGroup: String?
    @State private var removingProfile: ScholarProfile?
    @State private var note: String?

    private var profiles: [ScholarProfile] {
        settingsManager.settings.profiles.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var groups: [String] { settingsManager.groups }

    /// Groups and the ungrouped profiles, each placed where its first member sits in the
    /// overall order, so the menu bar profile's section always comes first.
    private var sections: [(group: String?, profiles: [ScholarProfile])] {
        var result: [(group: String?, profiles: [ScholarProfile])] = []
        for profile in profiles where !result.contains(where: { $0.group == profile.group }) {
            result.append((profile.group, profiles.filter { $0.group == profile.group }))
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            if profiles.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(sections, id: \.group) { section in
                            Section {
                                ForEach(section.profiles, id: \.id) { profile in
                                    row(for: profile)
                                }
                                .onMove { source, destination in
                                    move(section.profiles, from: source, to: destination)
                                }
                            } header: {
                                sectionHeader(section.group, members: section.profiles)
                            }
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: false))
                    .onAppear {
                        // The list can open scrolled to the end while the window sizes itself.
                        DispatchQueue.main.async {
                            proxy.scrollTo(profiles.first?.id, anchor: .top)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 12) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add Profiles…", systemImage: "plus")
                }
                Text(note ?? (groups.isEmpty && profiles.count > 1
                    ? "Tip: choose ⋯ › Group to gather your lab or co-authors under one heading."
                    : "Drag to reorder. The first profile is shown in the menu bar."))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 600, height: 460)
        .sheet(isPresented: $showingAdd) {
            AddProfilesSheet(existingIDs: Set(profiles.map(\.id)), groups: groups) { newProfiles, snapshots in
                settingsManager.addProfiles(newProfiles)
                (NSApp.delegate as? AppDelegate)?.primeNewProfiles(newProfiles, snapshots: snapshots)
            }
        }
        .sheet(item: $renamingProfile) { profile in
            TextPromptSheet(title: "Rename Profile", label: "Name", initialText: profile.name, confirmTitle: "Rename") { name in
                settingsManager.updateProfile(profile.renamed(to: name))
                refreshMenuBar()
            }
        }
        .sheet(item: $groupingProfile) { profile in
            TextPromptSheet(
                title: "New Group",
                message: "Groups gather a lab, co-authors, or a cohort under one heading with a combined total.",
                label: "Group name",
                initialText: "",
                confirmTitle: "Create"
            ) { name in
                settingsManager.setGroup(name, forProfileID: profile.id)
                refreshMenuBar()
            }
        }
        .sheet(item: Binding(
            get: { renamingGroup.map(GroupName.init) },
            set: { renamingGroup = $0?.name }
        )) { group in
            TextPromptSheet(title: "Rename Group", label: "Group name", initialText: group.name, confirmTitle: "Rename") { name in
                settingsManager.renameGroup(group.name, to: name)
                refreshMenuBar()
            }
        }
        .alert(
            "Remove \(removingProfile?.name ?? "profile")?",
            isPresented: Binding(get: { removingProfile != nil }, set: { if !$0 { removingProfile = nil } }),
            presenting: removingProfile
        ) { profile in
            Button("Remove", role: .destructive) {
                settingsManager.removeProfile(profile)
                refreshMenuBar()
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("CiteBar stops tracking this profile. Its saved history stays on this Mac.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("No profiles yet")
                .font(Theme.serif(22, .medium))
            Text("Add your Google Scholar profile, then anyone else you follow:\nco-authors, your advisor, or a whole lab.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Profiles…") { showingAdd = true }
                .buttonStyle(.borderedProminent)
                .padding(.top, 6)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func row(for profile: ScholarProfile) -> some View {
        let isPrimary = profile.id == profiles.first?.id
        let citations = model.entries.first { $0.id == profile.id }?.metrics?.citationCount

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if isPrimary {
                        Text("Menu bar")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Capsule().stroke(Theme.accent.opacity(0.5), lineWidth: 0.75))
                    }
                }
                Text(profile.id)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 12)
            if let citations, citations >= 0 {
                Text(citations.decimalString)
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Menu {
                profileMenu(for: profile, isPrimary: isPrimary)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Profile options")
        }
        .padding(.vertical, 4)
        .contextMenu {
            profileMenu(for: profile, isPrimary: isPrimary)
        }
    }

    @ViewBuilder
    private func profileMenu(for profile: ScholarProfile, isPrimary: Bool) -> some View {
        if !isPrimary {
            Button("Show in Menu Bar") {
                var reordered = profiles.filter { $0.id != profile.id }
                reordered.insert(profile, at: 0)
                settingsManager.reorderProfiles(reordered)
                refreshMenuBar()
            }
        }
        Menu("Group") {
            Button {
                settingsManager.setGroup(nil, forProfileID: profile.id)
                refreshMenuBar()
            } label: {
                checkmarkLabel("None", checked: profile.group == nil)
            }
            if !groups.isEmpty {
                Divider()
                ForEach(groups, id: \.self) { group in
                    Button {
                        settingsManager.setGroup(group, forProfileID: profile.id)
                        refreshMenuBar()
                    } label: {
                        checkmarkLabel(group, checked: profile.group == group)
                    }
                }
            }
            Divider()
            Button("New Group…") { groupingProfile = profile }
        }
        Button("Rename…") { renamingProfile = profile }
        Button("Open Scholar Profile") {
            if let url = URL(string: profile.url) {
                NSWorkspace.shared.open(url)
            }
        }
        Divider()
        Button("Remove…", role: .destructive) { removingProfile = profile }
    }

    @ViewBuilder
    private func checkmarkLabel(_ title: String, checked: Bool) -> some View {
        if checked {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }

    @ViewBuilder
    private func sectionHeader(_ group: String?, members: [ScholarProfile]) -> some View {
        if let group {
            let total = members.compactMap { member in
                model.entries.first { $0.id == member.id }?.metrics?.citationCount
            }.filter { $0 >= 0 }.reduce(0, +)

            HStack(spacing: 6) {
                Text(group)
                Text("\(members.count) · \(total.decimalString) citations")
                    .fontWeight(.regular)
                    .foregroundStyle(.tertiary)
                Spacer()
                Menu {
                    Button("Rename Group…") { renamingGroup = group }
                    Button("Copy Profile Links") { copyLinks(group: group, members: members) }
                    Divider()
                    Button("Ungroup") {
                        settingsManager.dissolveGroup(group)
                        refreshMenuBar()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Group options")
            }
        } else if !groups.isEmpty {
            Text("Ungrouped")
        }
    }

    /// Readable list that AddProfilesSheet can paste back in, for sharing a lab with others.
    private func copyLinks(group: String, members: [ScholarProfile]) {
        let text = members.map { "\($0.name): \($0.url)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        note = "Copied \(members.count) \(group) links. Paste them into Add Profiles on another Mac."
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { note = nil }
    }

    /// Reorders within one section while keeping every other profile where it was.
    private func move(_ members: [ScholarProfile], from source: IndexSet, to destination: Int) {
        var reordered = members
        reordered.move(fromOffsets: source, toOffset: destination)
        let memberIDs = Set(members.map(\.id))
        var next = reordered.makeIterator()
        settingsManager.reorderProfiles(profiles.map { memberIDs.contains($0.id) ? (next.next() ?? $0) : $0 })
        refreshMenuBar()
    }
}

extension ScholarProfile: Identifiable {}

private struct GroupName: Identifiable {
    let name: String
    var id: String { name }
}

// MARK: - Add profiles

struct AddProfilesSheet: View {
    let existingIDs: Set<String>
    let groups: [String]
    let onAdd: ([ScholarProfile], [String: CitationManager.ScholarProfileSnapshot]) -> Void

    @State private var text = ""
    @State private var groupChoice = ""
    @State private var newGroupName = ""
    @State private var snapshots: [String: CitationManager.ScholarProfileSnapshot] = [:]
    @State private var unresolved: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    @FocusState private var editorFocused: Bool

    private static let newGroupTag = "\u{0}new"

    private var ids: [String] { ScholarIDParser.ids(in: text) }
    private var newIDs: [String] { ids.filter { !existingIDs.contains($0) } }

    private var chosenGroup: String? {
        let name = groupChoice == Self.newGroupTag ? newGroupName : groupChoice
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Add Scholar Profiles")
                    .font(.system(size: 15, weight: .semibold))
                Text("Paste Google Scholar profile links or IDs, one per line. One profile is fine; a whole lab works too.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .focused($editorFocused)
                    .padding(6)
                if text.isEmpty {
                    Text(verbatim: "https://scholar.google.com/citations?user=…")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 92)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))

            if !ids.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(ids, id: \.self) { id in
                            detectedRow(id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 130)
            }

            HStack(spacing: 8) {
                Text("Group")
                    .font(.system(size: 12))
                Picker("Group", selection: $groupChoice) {
                    Text("None").tag("")
                    if !groups.isEmpty {
                        Divider()
                        ForEach(groups, id: \.self) { Text($0).tag($0) }
                    }
                    Divider()
                    Text("New Group…").tag(Self.newGroupTag)
                }
                .labelsHidden()
                .fixedSize()
                if groupChoice == Self.newGroupTag {
                    TextField("e.g. My Lab", text: $newGroupName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
                Spacer()
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(newIDs.count > 1 ? "Add \(newIDs.count) Profiles" : "Add Profile") {
                    add()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newIDs.isEmpty || (groupChoice == Self.newGroupTag && chosenGroup == nil))
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear {
            editorFocused = true
        }
        .task(id: newIDs) {
            await resolveNames()
        }
    }

    @ViewBuilder
    private func detectedRow(_ id: String) -> some View {
        HStack(spacing: 8) {
            if existingIDs.contains(id) {
                Image(systemName: "checkmark.circle").foregroundStyle(.tertiary)
                Text(id).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                Text("already tracked").font(.system(size: 11)).foregroundStyle(.tertiary)
            } else if let name = snapshots[id]?.displayName {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(name).font(.system(size: 12, weight: .medium))
                Text(id).font(.system(size: 11, design: .monospaced)).foregroundStyle(.tertiary)
            } else if unresolved.contains(id) {
                Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
                Text(id).font(.system(size: 12, design: .monospaced))
                Text("name will fill in later").font(.system(size: 11)).foregroundStyle(.tertiary)
            } else {
                ProgressView().controlSize(.mini).frame(width: 14)
                Text(id).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    /// Looks up names one profile at a time, spaced out to be gentle on Google Scholar.
    private func resolveNames() async {
        let manager = (NSApp.delegate as? AppDelegate)?.citationManager
        for id in newIDs where snapshots[id] == nil && !unresolved.contains(id) {
            guard !Task.isCancelled else { return }
            if let snapshot = await manager?.fetchScholarProfileSnapshot(for: id), snapshot.displayName != nil {
                snapshots[id] = snapshot
            } else {
                unresolved.insert(id)
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    private func add() {
        let profiles = newIDs.map { id in
            ScholarProfile(id: id, name: snapshots[id]?.displayName ?? "Scholar \(id)", group: chosenGroup)
        }
        onAdd(profiles, snapshots)
        dismiss()
    }
}

/// Pulls Scholar profile IDs out of pasted text: profile links anywhere in a line, or a
/// line that is just an ID.
enum ScholarIDParser {
    static func ids(in text: String) -> [String] {
        var result: [String] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let linkIDs = trimmed.components(separatedBy: "user=").dropFirst().compactMap { part in
                part.prefix { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }.description
            }
            let candidates = linkIDs.isEmpty ? [trimmed] : linkIDs
            for id in candidates where isValid(id) && !result.contains(id) {
                result.append(id)
            }
        }
        return result
    }

    static func isValid(_ id: String) -> Bool {
        id.range(of: "^[A-Za-z0-9_-]{8,20}$", options: .regularExpression) != nil
    }
}

private struct TextPromptSheet: View {
    let title: String
    var message: String?
    let label: String
    let initialText: String
    let confirmTitle: String
    let onSubmit: (String) -> Void

    @State private var text = ""
    @Environment(\.dismiss) private var dismiss

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            if let message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(confirmTitle, action: submit)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
        .onAppear { text = initialText }
    }

    private func submit() {
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
        dismiss()
    }
}

// MARK: - General

struct GeneralPane: View {
    @ObservedObject var model: DashboardModel
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var menuBarManagerName: String?
    @State private var hasRecentDelay = false

    var body: some View {
        Form {
            Section {
                Picker("Check for new citations", selection: Binding(
                    get: { settingsManager.settings.refreshInterval },
                    set: { settingsManager.setRefreshInterval($0) }
                )) {
                    ForEach(AppSettings.RefreshInterval.allCases, id: \.self) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                LabeledContent {
                    Button("Refresh Now") {
                        (NSApp.delegate as? AppDelegate)?.refreshCitations()
                    }
                    .disabled(model.isRefreshing)
                } label: {
                    Text(statusText)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Updates")
            } footer: {
                Text("Google Scholar updates its counts every day or two, so a daily check keeps CiteBar current. Network hiccups retry automatically.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section("Menu Bar") {
                Picker("Number in menu bar", selection: Binding(
                    get: { settingsManager.settings.menuBarPrimaryMetric },
                    set: { metric in
                        settingsManager.setMenuBarPrimaryMetric(metric)
                        refreshMenuBar()
                    }
                )) {
                    ForEach(AppSettings.MenuBarPrimaryMetric.allCases, id: \.self) { metric in
                        Text(metric.displayName).tag(metric)
                    }
                }
                Toggle("Show h-index", isOn: Binding(
                    get: { settingsManager.settings.showHIndexInMenu },
                    set: { settingsManager.setShowHIndexInMenu($0) }
                ))
                Toggle("Show i10-index", isOn: Binding(
                    get: { settingsManager.settings.showI10IndexInMenu },
                    set: { settingsManager.setShowI10IndexInMenu($0) }
                ))
                Toggle(isOn: Binding(
                    get: { settingsManager.settings.showTrendInMenu },
                    set: { settingsManager.setShowTrendInMenu($0) }
                )) {
                    Text("Show trends and insights")
                    Text("30-day growth, newly cited papers, and a nearby next h-index")
                }
                if menuBarManagerName != nil || hasRecentDelay {
                    LabeledContent {
                        Button("Report Issue") {
                            if let url = URL(string: "https://github.com/hichipli/CiteBar/issues/new") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    } label: {
                        Text(menuBarNotice)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Notifications") {
                Toggle(isOn: Binding(
                    get: { settingsManager.settings.showNotifications },
                    set: { enabled in
                        settingsManager.setNotifications(enabled)
                        if enabled {
                            requestNotificationPermission()
                        }
                    }
                )) {
                    Text("Notify me about new citations")
                    Text("Which papers were cited, plus milestones like 1,000 citations or a higher h-index")
                }
                if settingsManager.settings.showNotifications {
                    switch notificationStatus {
                    case .notDetermined:
                        LabeledContent("Permission not requested yet") {
                            Button("Allow Notifications") { requestNotificationPermission() }
                        }
                    case .denied:
                        LabeledContent("Notifications are turned off for CiteBar in System Settings") {
                            Button("Open System Settings") { openNotificationSettings() }
                        }
                    default:
                        EmptyView()
                    }
                }
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { settingsManager.settings.autoLaunch },
                    set: { settingsManager.setAutoLaunch($0) }
                ))
                switch SMAppService.mainApp.status {
                case .requiresApproval:
                    LabeledContent("Waiting for approval in Login Items") {
                        Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                    }
                case .notFound:
                    LabeledContent("Login item not found; add CiteBar in Login Items") {
                        Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                    }
                default:
                    EmptyView()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 660)
        .onAppear(perform: refreshStatuses)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshStatuses()
        }
    }

    private var statusText: String {
        if model.isRefreshing {
            return "Updating…"
        }
        if let issue = model.issue, issue.retryAt > Date() {
            let time = issue.retryAt.formatted(date: .omitted, time: .shortened)
            switch issue {
            case .rateLimited:
                return "Google Scholar paused requests; retrying at \(time)"
            case .networkUnavailable:
                return "Couldn't reach Google Scholar; retrying at \(time)"
            }
        }
        guard let lastUpdate = settingsManager.settings.lastUpdateTime else {
            return "Not updated yet"
        }
        return "Last updated \(lastUpdate.formatted(date: .abbreviated, time: .shortened))"
    }

    private var menuBarNotice: String {
        if let name = menuBarManagerName {
            return "\(name) manages your menu bar and can delay CiteBar's icon. CiteBar keeps running meanwhile."
        }
        return "macOS recently delayed CiteBar's menu bar icon. CiteBar keeps running meanwhile."
    }

    private func refreshStatuses() {
        menuBarManagerName = MenuBarCompatibility.activeManagerDisplayName()
        hasRecentDelay = MenuBarCompatibility.hasRecentDelayObservation()
        guard Bundle.main.bundleIdentifier != nil else { return }
        Task { @MainActor in
            notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        }
    }

    private func requestNotificationPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        Task { @MainActor in
            let center = UNUserNotificationCenter.current()
            if await center.notificationSettings().authorizationStatus == .notDetermined {
                _ = try? await center.requestAuthorization(options: [.alert, .badge])
            }
            notificationStatus = await center.notificationSettings().authorizationStatus
        }
    }

    private func openNotificationSettings() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.hichipli.citebar"
        // Try the app's own notification pane first; fall back to the Notifications page.
        let candidates = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleID)",
            "x-apple.systempreferences:com.apple.preference.notifications?id=\(bundleID)",
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}

// MARK: - About

struct AboutPane: View {
    var body: some View {
        VStack(spacing: 0) {
            AppIconView(size: 76)
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                .padding(.bottom, 14)

            Text("CiteBar")
                .font(Theme.serif(28, .medium))
            Text("Your Google Scholar citations, in the menu bar.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            Text("Version \(AppVersion.current) (\(AppVersion.build))")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
                .padding(.top, 10)

            Button("Check for Updates…") {
                (NSApp.delegate as? AppDelegate)?.checkForUpdates()
            }
            .padding(.top, 14)

            Divider()
                .frame(width: 240)
                .padding(.vertical, 22)

            HStack(spacing: 20) {
                aboutLink("Website", "https://www.citebar.org")
                aboutLink("Source Code", "https://github.com/hichipli/CiteBar")
                aboutLink("Report an Issue", "https://github.com/hichipli/CiteBar/issues/new/choose")
                aboutLink("Email", "mailto:info@hichipli.com")
            }

            Text("Free and open source under the MIT License.\nCiteBar reads public Scholar pages and keeps everything on this Mac.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 22)
        }
        .padding(.vertical, 34)
        .frame(width: 520)
    }

    private func aboutLink(_ title: String, _ urlString: String) -> some View {
        Button(title) {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
        .buttonStyle(.link)
        .font(.system(size: 12))
    }
}

struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        if let icon = NSImage(named: "AppIcon")
            ?? Bundle.main.path(forResource: "AppIcon", ofType: "png").flatMap(NSImage.init(contentsOfFile:))
            ?? NSImage(contentsOfFile: "Assets.xcassets/AppIcon.appiconset/1024.png") {
            Image(nsImage: icon)
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "book.circle.fill")
                .font(.system(size: size * 0.75))
                .foregroundStyle(Theme.accent)
        }
    }
}
