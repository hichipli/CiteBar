import SwiftUI

// MARK: - Design tokens

enum Theme {
    /// Oxblood ink in light mode, a soft coral in dark mode. Used sparingly: the current
    /// year, newly cited papers, h-index progress.
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.93, green: 0.52, blue: 0.44, alpha: 1)
            : NSColor(srgbRed: 0.61, green: 0.17, blue: 0.13, alpha: 1)
    })

    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static let sectionLabel = Font.system(size: 10.5, weight: .semibold)
}

extension Int {
    var decimalString: String {
        NumberFormatter.localizedString(from: NSNumber(value: self), number: .decimal)
    }

    var signedString: String {
        self > 0 ? "+\(decimalString)" : decimalString
    }
}

// MARK: - Model

/// What the menu bar panel shows. MenuBarManager keeps it current.
@MainActor final class DashboardModel: ObservableObject {
    struct Entry: Identifiable {
        let profile: ScholarProfile
        /// nil until the first fetch for this profile finishes.
        let metrics: ProfileMetrics?
        var id: String { profile.id }
    }

    @Published var entries: [Entry] = []
    @Published var isRefreshing = false
    @Published var issue: RefreshIssue?
    @Published var failedProfileIDs: Set<String> = []
    @Published var errorMessage: String?
    @Published var loadingProfileIDs: Set<String> = []
    @Published var footerNote: FooterNote?

    struct FooterNote: Equatable {
        let text: String
        /// Clicking the note reveals this file in Finder.
        let fileURL: URL?
    }
}

struct PanelActions {
    let refresh: @MainActor () -> Void
    let openSettings: @MainActor () -> Void
    let addProfile: @MainActor () -> Void
    let openURL: @MainActor (String) -> Void
    let saveStatsCard: @MainActor () -> Void
    let checkForUpdates: @MainActor () -> Void
    let showSupport: @MainActor () -> Void
    let quit: @MainActor () -> Void
}

// MARK: - Panel

struct PanelView: View {
    @ObservedObject var model: DashboardModel
    @ObservedObject var settings = SettingsManager.shared
    let actions: PanelActions

    @AppStorage("panel.collapsedGroups") private var collapsedGroupsStorage = ""
    @State private var expandedProfileID: String?
    @State private var listHeight: CGFloat = 0

    private static let width: CGFloat = 340
    private static let maxListHeight: CGFloat = 380

    private var primary: DashboardModel.Entry? { model.entries.first }

    private var groupNames: [String] {
        var seen = Set<String>()
        return model.entries.compactMap(\.profile.group).filter { seen.insert($0).inserted }
    }

    private var collapsedGroups: Set<String> {
        Set(collapsedGroupsStorage.split(separator: "\n").map(String.init))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let primary {
                HeroView(entry: primary, settings: settings.settings, actions: actions)
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 14)

                if model.entries.count > 1 || !groupNames.isEmpty {
                    Divider().padding(.horizontal, 12)
                    profileList
                }
            } else {
                EmptyStateView(errorMessage: model.errorMessage, addProfile: actions.addProfile)
            }

            Divider()
            FooterView(model: model, actions: actions)
        }
        .frame(width: Self.width)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: expandedProfileID)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: collapsedGroupsStorage)
    }

    private var profileList: some View {
        ScrollView(.vertical, showsIndicators: listHeight > Self.maxListHeight) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(groupNames, id: \.self) { group in
                    let members = model.entries.filter { $0.profile.group == group }
                    GroupHeader(
                        name: group,
                        members: members,
                        isCollapsed: collapsedGroups.contains(group)
                    ) {
                        toggleGroup(group)
                    }
                    if !collapsedGroups.contains(group) {
                        rows(for: members)
                    }
                }

                let ungrouped = model.entries.dropFirst().filter { $0.profile.group == nil }
                if !ungrouped.isEmpty {
                    if !groupNames.isEmpty {
                        SectionLabel(text: "Other profiles")
                            .padding(.horizontal, 10)
                            .padding(.top, 10)
                            .padding(.bottom, 2)
                    }
                    rows(for: Array(ungrouped))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: HeightKey.self, value: proxy.size.height)
                }
            )
        }
        .frame(height: min(max(listHeight, 1), Self.maxListHeight))
        .onPreferenceChange(HeightKey.self) { listHeight = $0 }
    }

    @ViewBuilder
    private func rows(for entries: [DashboardModel.Entry]) -> some View {
        ForEach(entries) { entry in
            ProfileRowView(
                entry: entry,
                isExpanded: expandedProfileID == entry.id,
                isLoading: entry.metrics == nil
                    && (model.isRefreshing || model.loadingProfileIDs.contains(entry.id)),
                failed: model.failedProfileIDs.contains(entry.id),
                settings: settings.settings,
                actions: actions
            ) {
                expandedProfileID = expandedProfileID == entry.id ? nil : entry.id
            }
        }
    }

    private func toggleGroup(_ group: String) {
        var groups = collapsedGroups
        if groups.contains(group) {
            groups.remove(group)
        } else {
            groups.insert(group)
        }
        collapsedGroupsStorage = groups.sorted().joined(separator: "\n")
    }
}

private struct HeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Hero

private struct HeroView: View {
    let entry: DashboardModel.Entry
    let settings: AppSettings
    let actions: PanelActions

    private var year: Int { Calendar.current.component(.year, from: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                LinkText(text: entry.profile.name, font: .system(size: 13, weight: .semibold)) {
                    actions.openURL(entry.profile.url)
                }
                Spacer(minLength: 8)
                if let group = entry.profile.group {
                    Text(group)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            if let metrics = entry.metrics, metrics.citationCount >= 0 {
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headline(metrics).decimalString)
                            .font(Theme.serif(42, .medium))
                            .monospacedDigit()
                            .numericTransition(value: headline(metrics))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(headlineLabel(metrics))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if let counts = metrics.citationsByYear, counts.count > 1 {
                        YearBars(counts: counts, height: 40)
                            .padding(.bottom, 4)
                            .help("Citations per year")
                    }
                }

                statsLine(metrics)

                if settings.showTrendInMenu {
                    InsightRows(metrics: metrics, actions: actions)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Fetching citations…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 48)
            }
        }
    }

    private func headline(_ metrics: ProfileMetrics) -> Int {
        if settings.menuBarPrimaryMetric == .currentYearCitations, let current = metrics.currentYearCitations {
            return current
        }
        return metrics.citationCount
    }

    private func headlineLabel(_ metrics: ProfileMetrics) -> String {
        if settings.menuBarPrimaryMetric == .currentYearCitations, metrics.currentYearCitations != nil {
            return "citations in \(String(year))"
        }
        return "citations"
    }

    @ViewBuilder
    private func statsLine(_ metrics: ProfileMetrics) -> some View {
        let items = statItems(metrics)
        if !items.isEmpty {
            HStack(spacing: 14) {
                ForEach(items, id: \.label) { item in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.value)
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                        Text(item.label)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func statItems(_ metrics: ProfileMetrics) -> [(label: String, value: String)] {
        var items: [(label: String, value: String)] = []
        if settings.showTrendInMenu, let growth = entry.profile.recentGrowth {
            let days = max(1, entry.profile.recentGrowthDays ?? 30)
            items.append(("last \(days) \(days == 1 ? "day" : "days")", growth.signedString))
        }
        if settings.menuBarPrimaryMetric == .currentYearCitations {
            items.append(("total", metrics.citationCount.decimalString))
        } else if let current = metrics.currentYearCitations {
            items.append(("in \(String(year))", current.decimalString))
        }
        if settings.showHIndexInMenu, let hIndex = metrics.hIndex {
            items.append(("h-index", "\(hIndex)"))
        }
        if settings.showI10IndexInMenu, let i10 = metrics.i10Index {
            items.append(("i10-index", "\(i10)"))
        }
        return items
    }
}

/// Newly cited paper and nearby next h-index, for the hero and expanded rows.
private struct InsightRows: View {
    let metrics: ProfileMetrics
    let actions: PanelActions

    var body: some View {
        if metrics.recentPaperGains.first != nil || nextHIndexIsClose {
            VStack(alignment: .leading, spacing: 6) {
                if let gain = metrics.recentPaperGains.first {
                    HoverRow(action: { actions.openURL(gain.citedByURL ?? "") }) {
                        HStack(spacing: 8) {
                            Circle().fill(Theme.accent).frame(width: 5, height: 5)
                            Text("“\(gain.title)”")
                                .font(.system(size: 12))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer(minLength: 4)
                            Text("+\(gain.delta)")
                                .font(.system(size: 12, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .help(gainHelp)
                }

                if nextHIndexIsClose, let hIndex = metrics.hIndex, let needed = metrics.citationsToNextHIndex {
                    HStack(spacing: 8) {
                        Image(systemName: "scope")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 5)
                        Text("h-index \(hIndex + 1) is \(needed) \(needed == 1 ? "citation" : "citations") away")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 6)
                }
            }
        }
    }

    private var nextHIndexIsClose: Bool {
        guard let needed = metrics.citationsToNextHIndex, metrics.hIndex != nil else { return false }
        return needed <= 5
    }

    private var gainHelp: String {
        let others = metrics.recentPaperGains.count - 1
        let more = others > 0 ? " (and \(others) more \(others == 1 ? "paper" : "papers"))" : ""
        return "Newly cited\(more). Click to see who cited it."
    }
}

// MARK: - List

private struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(Theme.sectionLabel)
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }
}

private struct GroupHeader: View {
    let name: String
    let members: [DashboardModel.Entry]
    let isCollapsed: Bool
    let toggle: () -> Void

    @State private var isHovering = false

    private var total: Int {
        members.compactMap(\.metrics).map(\.citationCount).filter { $0 >= 0 }.reduce(0, +)
    }

    private var growth: Int? {
        let values = members.compactMap(\.profile.recentGrowth)
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                SectionLabel(text: name)
                Text("\(members.count)")
                    .font(Theme.sectionLabel)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 8)
                Text(total.decimalString)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .numericTransition(value: total)
                if let growth, growth != 0 {
                    Text(growth.signedString)
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .frame(minWidth: 34, alignment: .trailing)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isHovering ? 1 : 0.92)
        .onHover { isHovering = $0 }
        .help(isCollapsed ? "Show \(name)" : "Hide \(name)")
    }
}

private struct ProfileRowView: View {
    let entry: DashboardModel.Entry
    let isExpanded: Bool
    let isLoading: Bool
    let failed: Bool
    let settings: AppSettings
    let actions: PanelActions
    let toggle: () -> Void

    private var hasRecentGain: Bool { !(entry.metrics?.recentPaperGains.isEmpty ?? true) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HoverRow(isSelected: isExpanded, action: toggle) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(hasRecentGain ? Theme.accent : .clear)
                        .frame(width: 5, height: 5)
                    Text(entry.profile.name)
                        .font(.system(size: 13))
                        .lineLimit(1)
                    if failed {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .help("Couldn't update this profile. CiteBar will retry automatically.")
                    }
                    Spacer(minLength: 8)
                    if let metrics = entry.metrics, metrics.citationCount >= 0 {
                        Text(value(metrics).decimalString)
                            .font(.system(size: 13, weight: .medium))
                            .monospacedDigit()
                            .numericTransition(value: value(metrics))
                        Text(deltaText)
                            .font(.system(size: 11))
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: 34, alignment: .trailing)
                    } else if isLoading {
                        ProgressView().controlSize(.mini)
                    } else {
                        Text("—").foregroundStyle(.tertiary)
                    }
                }
            }

            if isExpanded, let metrics = entry.metrics {
                ProfileDetail(entry: entry, metrics: metrics, settings: settings, actions: actions)
                    .padding(.leading, 23)
                    .padding(.trailing, 10)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func value(_ metrics: ProfileMetrics) -> Int {
        if settings.menuBarPrimaryMetric == .currentYearCitations, let current = metrics.currentYearCitations {
            return current
        }
        return metrics.citationCount
    }

    private var deltaText: String {
        guard settings.showTrendInMenu, let growth = entry.profile.recentGrowth, growth != 0 else { return "" }
        return growth.signedString
    }
}

private struct ProfileDetail: View {
    let entry: DashboardModel.Entry
    let metrics: ProfileMetrics
    let settings: AppSettings
    let actions: PanelActions

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .bottom, spacing: 16) {
                // The row already shows the menu bar metric; show the other one here.
                if settings.menuBarPrimaryMetric == .currentYearCitations {
                    detailStat(metrics.citationCount.decimalString, "total")
                } else if let current = metrics.currentYearCitations {
                    detailStat(current.decimalString, "this year")
                }
                if let hIndex = metrics.hIndex {
                    detailStat("\(hIndex)", "h-index")
                }
                if let i10 = metrics.i10Index {
                    detailStat("\(i10)", "i10")
                }
                Spacer(minLength: 0)
                if let counts = metrics.citationsByYear, counts.count > 1 {
                    YearBars(counts: counts, barWidth: 5, spacing: 2, height: 24)
                }
            }

            InsightRows(metrics: metrics, actions: actions)
                .padding(.leading, -6)

            LinkText(text: "Open Scholar profile ↗", font: .system(size: 11.5)) {
                actions.openURL(entry.profile.url)
            }
            .foregroundStyle(.secondary)
        }
    }

    private func detailStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Footer

private struct FooterView: View {
    @ObservedObject var model: DashboardModel
    @ObservedObject var settings = SettingsManager.shared
    let actions: PanelActions

    var body: some View {
        HStack(spacing: 4) {
            status
                .padding(.leading, 6)
            Spacer(minLength: 8)

            IconButton(symbol: "arrow.clockwise", help: "Refresh now (⌘R)", isBusy: model.isRefreshing) {
                actions.refresh()
            }
            .keyboardShortcut("r", modifiers: .command)
            .disabled(model.isRefreshing)

            IconButton(symbol: "square.and.arrow.up", help: "Save a stats card to share") {
                actions.saveStatsCard()
            }
            .disabled(model.entries.first?.metrics == nil)

            IconButton(symbol: "gearshape", help: "Settings (⌘,)") {
                actions.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Menu {
                Button("Check for Updates…") { actions.checkForUpdates() }
                Button("Support & Feedback") { actions.showSupport() }
                Divider()
                Button("Quit CiteBar") { actions.quit() }
                    .keyboardShortcut("q", modifiers: .command)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .medium))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .frame(width: 26, height: 24)
            .help("More")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private var status: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Group {
                if let note = model.footerNote {
                    Button {
                        if let fileURL = note.fileURL {
                            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                        }
                    } label: {
                        Label(note.text, systemImage: "checkmark")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")
                    .transition(.opacity)
                } else if model.isRefreshing {
                    Text("Updating…")
                } else if let issue = model.issue, issue.retryAt > context.date {
                    HStack(spacing: 5) {
                        Circle().fill(Color.orange).frame(width: 5, height: 5)
                        Text(issueText(issue))
                    }
                    .help(issueHelp(issue))
                } else if let lastUpdate = settings.settings.lastUpdateTime {
                    Text("Updated \(Self.relative(lastUpdate, now: context.date))")
                        .help("Last updated \(lastUpdate.formatted(date: .abbreviated, time: .shortened))")
                } else {
                    Text("Not updated yet")
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    private func issueText(_ issue: RefreshIssue) -> String {
        let time = issue.retryAt.formatted(date: .omitted, time: .shortened)
        switch issue {
        case .rateLimited:
            return "Scholar paused · retry \(time)"
        case .networkUnavailable:
            return "Offline · retry \(time)"
        }
    }

    private func issueHelp(_ issue: RefreshIssue) -> String {
        switch issue {
        case .rateLimited:
            return "Google Scholar is limiting requests from this network. CiteBar retries automatically; Refresh works any time."
        case .networkUnavailable:
            return "Some profiles couldn't be reached. CiteBar retries automatically; Refresh works any time."
        }
    }

    static func relative(_ date: Date, now: Date) -> String {
        if now.timeIntervalSince(date) < 60 {
            return "just now"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

// MARK: - Empty state

private struct EmptyStateView: View {
    let errorMessage: String?
    let addProfile: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your citations,\nat a glance.")
                .font(Theme.serif(24, .medium))
                .fixedSize(horizontal: false, vertical: true)
            Text(errorMessage ?? "Add a Google Scholar profile, yours or anyone's, and CiteBar keeps its numbers in the menu bar.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Add Scholar Profile…") { addProfile() }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }
}

// MARK: - Building blocks

/// Citations per year as quiet bars; the current year is drawn in the accent color.
struct YearBars: View {
    let counts: [Int: Int]
    var maxYears = 8
    var barWidth: CGFloat = 6
    var spacing: CGFloat = 3
    var height: CGFloat = 32
    var baseColor: Color = Color.primary.opacity(0.18)
    var highlightColor: Color = Theme.accent
    var animated = true
    var currentYear = Calendar.current.component(.year, from: Date())

    @State private var grown = false

    private var years: [Int] {
        let first = max(counts.keys.min() ?? currentYear, currentYear - maxYears + 1)
        return Array(first...currentYear)
    }

    var body: some View {
        let maxCount = max(1, years.map { counts[$0] ?? 0 }.max() ?? 1)
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(years, id: \.self) { year in
                let fraction = CGFloat(counts[year] ?? 0) / CGFloat(maxCount)
                RoundedRectangle(cornerRadius: min(1.5, barWidth / 2), style: .continuous)
                    .fill(year == currentYear ? highlightColor : baseColor)
                    .frame(width: barWidth, height: max(1.5, height * fraction * ((grown || !animated) ? 1 : 0.08)))
            }
        }
        .frame(height: height, alignment: .bottom)
        .onAppear {
            guard animated else { return }
            withAnimation(.easeOut(duration: 0.5).delay(0.05)) { grown = true }
        }
    }
}

/// Full-width row with a menu-like hover highlight.
private struct HoverRow<Content: View>: View {
    var isSelected = false
    let action: () -> Void
    @ViewBuilder let content: Content

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            content
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(isHovering ? 0.07 : (isSelected ? 0.04 : 0)))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

private struct LinkText: View {
    let text: String
    let font: Font
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(font)
                .lineLimit(1)
                .underline(isHovering, color: .secondary)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

private struct IconButton: View {
    let symbol: String
    let help: String
    var isBusy = false
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            ZStack {
                if isBusy {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .frame(width: 26, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(isHovering && isEnabled ? 0.08 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .onHover { isHovering = $0 }
        .help(help)
    }
}

extension View {
    /// Rolls digits when a number changes, on macOS 14 and later.
    @ViewBuilder
    func numericTransition(value: Int) -> some View {
        if #available(macOS 14.0, *) {
            self.contentTransition(.numericText(value: Double(value)))
                .animation(.snappy, value: value)
        } else {
            self
        }
    }
}
