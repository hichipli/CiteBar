import Charts
import SwiftUI

/// The Citation Record studio: a live card preview, what to show on it, and a time machine to
/// make the card for any day in the profile's history.
struct CardStudioView: View {
    @ObservedObject var model: DashboardModel
    @State var profileID: String
    /// nil means today; otherwise a day from the time machine.
    @State var selectedDate: Date?

    @AppStorage("card.theme") private var themeRaw = CardTheme.record.rawValue
    @AppStorage("card.showChart") private var showChart = true
    @AppStorage("card.showIndices") private var showIndices = true
    @AppStorage("card.papers") private var papersRaw = CardPapers.mostCited.rawValue
    @AppStorage("card.growth") private var growthRaw = CardGrowth.month.rawValue

    @State private var featuredPaperID = ""
    @State private var note = ""
    @State private var timeline: CitationTimeline?
    @State private var profilePapers: ProfilePapers?
    @State private var shareURL: URL?
    @State private var status: Status?

    private enum Status: Equatable {
        case copied
        case saved(URL)
    }

    private static let previewWidth: CGFloat = 318
    private static let noteLimit = 90

    private var theme: CardTheme { CardTheme(rawValue: themeRaw) ?? .record }
    private var papersMode: CardPapers { CardPapers(rawValue: papersRaw) ?? .mostCited }
    private var growthPeriod: CardGrowth { CardGrowth(rawValue: growthRaw) ?? .month }

    private var entries: [DashboardModel.Entry] {
        model.entries.filter { $0.metrics != nil }
    }

    private var entry: DashboardModel.Entry? {
        entries.first { $0.id == profileID } ?? entries.first
    }

    /// Papers are only known for today, so past days leave them off.
    private var isToday: Bool { selectedDate == nil }

    private var paperChoices: [ScholarPaper] {
        let papers = (profilePapers?.papers ?? []).sorted { $0.citations > $1.citations }
        let watched = Set(SettingsManager.shared.settings.watchedPaperIDs)
        return papers.filter { watched.contains($0.id) } + papers.filter { !watched.contains($0.id) }
    }

    private var content: CardContent? {
        guard let entry, let metrics = entry.metrics else { return nil }
        let point = selectedDate.flatMap { timeline?.point(at: $0) }
        let date = point?.date ?? Date()
        let byYear = point?.citationsByYear ?? metrics.citationsByYear

        var content = CardContent(name: entry.profile.name, date: date, citations: point?.citations ?? metrics.citationCount)
        content.isEstimate = point?.isEstimate ?? false
        content.yearCitations = byYear?[content.year]
        if showIndices {
            content.hIndex = point.map(\.hIndex) ?? metrics.hIndex
            content.i10Index = point.map(\.i10Index) ?? metrics.i10Index
        }
        if showChart && theme.showsChart {
            content.chart = byYear
        }
        if growthPeriod != .off, let timeline,
           let growth = timeline.growth(endingAt: point?.date ?? .distantFuture, days: growthPeriod.rawValue) {
            content.growth = CardGrowthValue(
                value: growth.value,
                days: growth.coveredDays,
                isPartial: growth.coveredDays < growthPeriod.rawValue,
                startDate: Calendar.current.date(byAdding: .day, value: -growth.coveredDays, to: date) ?? date
            )
        }
        if isToday {
            switch papersMode {
            case .none:
                break
            case .mostCited:
                if theme.showsPaperList {
                    content.papers = Array(metrics.topPapers.prefix(3))
                }
            case .featured:
                content.featured = paperChoices.first { $0.id == featuredPaperID } ?? paperChoices.first
            }
        }
        content.milestone = timeline?.milestone(on: date)
        content.note = String(note.prefix(Self.noteLimit))
        return content
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 26) {
                preview
                controls
                    .frame(width: 262)
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 18)

            Divider()

            if let timeline, !timeline.points.isEmpty {
                TimeMachineView(timeline: timeline, selectedDate: $selectedDate)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            } else {
                Text("The time machine fills in as CiteBar records this profile's citations.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(20)
            }
        }
        .frame(width: 656)
        .task(id: entry?.id) {
            await loadProfile()
#if DEBUG
            // `-CiteBarDebugExportThemes YES` saves this card in every theme to Downloads.
            if UserDefaults.standard.bool(forKey: "CiteBarDebugExportThemes"), let content,
               let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                for theme in CardTheme.allCases {
                    try? StatsCard(content: content, theme: theme).pngData()?
                        .write(to: downloads.appendingPathComponent("card-\(theme.rawValue).png"))
                }
            }
#endif
        }
        .task(id: renderKey) {
            // Debounced so scrubbing the time machine stays smooth.
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            writeShareFile()
        }
        .onChange(of: renderKey) { _ in status = nil }
        .onExitCommand { NSApp.keyWindow?.close() }
    }

    private struct RenderKey: Equatable {
        let content: CardContent?
        let theme: CardTheme
    }

    private var renderKey: RenderKey { RenderKey(content: content, theme: theme) }

    // MARK: Preview

    private var preview: some View {
        let scale = Self.previewWidth / 900
        return ZStack(alignment: .topLeading) {
            if let content {
                StatsCard(content: content, theme: theme)
                    .scaleEffect(scale, anchor: .topLeading)
                    .animation(.easeInOut(duration: 0.2), value: theme)
            } else {
                Rectangle().fill(Color.secondary.opacity(0.08))
            }
        }
        .frame(width: Self.previewWidth, height: Self.previewWidth * 4 / 3, alignment: .topLeading)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(Color.primary.opacity(0.08)))
        .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
    }

    // MARK: Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Citation Record")
                .font(Theme.serif(24, .medium))
            if entries.count > 1 {
                Picker("Profile", selection: $profileID) {
                    ForEach(entries) { Text($0.profile.name).tag($0.id) }
                }
                .labelsHidden()
                .padding(.top, 10)
            }

            label("Theme").padding(.top, 18)
            HStack(spacing: 8) {
                ForEach(CardTheme.allCases) { option in
                    ThemeSwatch(theme: option, isSelected: option == theme) {
                        themeRaw = option.rawValue
                    }
                }
            }
            .padding(.top, 8)

            label("Show").padding(.top, 18)
            VStack(alignment: .leading, spacing: 7) {
                Toggle("Citations per year", isOn: $showChart)
                    .disabled(!theme.showsChart)
                Toggle("h-index and i10-index", isOn: $showIndices)
                LabeledPicker(title: "Papers") {
                    Picker("Papers", selection: $papersRaw) {
                        ForEach(CardPapers.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                }
                .disabled(!isToday)
                if papersMode == .featured && isToday && !paperChoices.isEmpty {
                    Picker("Paper", selection: $featuredPaperID) {
                        ForEach(paperChoices.prefix(40), id: \.id) { paper in
                            Text(paper.title).tag(paper.id)
                        }
                    }
                    .labelsHidden()
                }
                LabeledPicker(title: "Growth") {
                    Picker("Growth", selection: $growthRaw) {
                        ForEach(CardGrowth.allCases) { Text($0.title).tag($0.rawValue) }
                    }
                }
            }
            .toggleStyle(.checkbox)
            .font(.system(size: 12))
            .padding(.top, 8)

            TextField("Add a note (optional)", text: $note)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .padding(.top, 12)

            if !isToday {
                Text(selectedPointIsEstimate
                     ? "This day is before CiteBar started tracking, so the total is estimated from Google Scholar's yearly counts."
                     : "Showing the record as of this day. Paper lists are only kept for today.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }

            Spacer(minLength: 16)

            VStack(spacing: 8) {
                if let shareURL {
                    ShareLink(item: shareURL) {
                        Label("Share…", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                HStack(spacing: 8) {
                    Button(action: copy) {
                        Label(status == .copied ? "Copied" : "Copy",
                              systemImage: status == .copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .keyboardShortcut("c")
                    Button(action: save) {
                        Label("Save", systemImage: "arrow.down.to.line")
                            .frame(maxWidth: .infinity)
                    }
                    .keyboardShortcut("s")
                }
            }
            .controlSize(.large)
            .disabled(content == nil)

            if case .saved(let url) = status {
                Button("Saved to Downloads · Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .buttonStyle(.link)
                .font(.system(size: 11))
                .padding(.top, 8)
            }
        }
        // At least as tall as the preview; taller when the past-day note shows.
        .frame(minHeight: Self.previewWidth * 4 / 3, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var selectedPointIsEstimate: Bool {
        selectedDate.flatMap { timeline?.point(at: $0)?.isEstimate } ?? false
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }

    // MARK: Data and export

    private func loadProfile() async {
        guard let id = entry?.id,
              let storage = (NSApp.delegate as? AppDelegate)?.citationManager?.storageManager else { return }
        let records = await storage.records(for: id)
        profilePapers = await storage.getProfilePapers(for: id)
        timeline = CitationTimeline(records: records)
        if featuredPaperID.isEmpty || !paperChoices.contains(where: { $0.id == featuredPaperID }) {
            featuredPaperID = paperChoices.first?.id ?? ""
        }
    }

    private var fileName: String {
        let name = (content?.name ?? "Profile")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let day = ISO8601DateFormatter.string(from: content?.date ?? Date(), timeZone: .current, formatOptions: [.withFullDate])
        return "CiteBar-\(name)-\(day)-\(theme.rawValue).png"
    }

    private func renderPNG() -> Data? {
        guard let content else { return nil }
        return StatsCard(content: content, theme: theme).pngData()
    }

    private func writeShareFile() {
        guard let data = renderPNG() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        shareURL = (try? data.write(to: url, options: .atomic)) == nil ? nil : url
    }

    private func copy() {
        guard let data = renderPNG() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(data, forType: .png)
        status = .copied
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if status == .copied { status = nil }
        }
    }

    private func save() {
        guard let data = renderPNG(),
              let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else { return }
        let url = downloads.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            status = .saved(url)
        } catch {
            AppLog.error("Failed to save stats card: \(error)")
            NSSound.beep()
        }
    }
}

/// Label on the left, menu picker on the right, matching the checkbox rows.
private struct LabeledPicker<Content: View>: View {
    let title: String
    @ViewBuilder let picker: Content

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            picker
                .labelsHidden()
                .fixedSize()
        }
    }
}

/// A tiny preview of a theme's paper and ink.
private struct ThemeSwatch: View {
    let theme: CardTheme
    let isSelected: Bool
    let action: () -> Void

    private var colors: (paper: Color, ink: Color, accent: Color) {
        switch theme {
        case .record:
            return (Color(red: 0.965, green: 0.953, blue: 0.925), Color(red: 0.11, green: 0.11, blue: 0.10), Color(red: 0.56, green: 0.16, blue: 0.12))
        case .night:
            return (Color(red: 0.08, green: 0.09, blue: 0.11), Color(red: 0.94, green: 0.92, blue: 0.88), Color(red: 0.85, green: 0.66, blue: 0.32))
        case .gazette:
            return (Color(red: 0.95, green: 0.93, blue: 0.89), Color(red: 0.09, green: 0.09, blue: 0.09), Color(red: 0.09, green: 0.09, blue: 0.09))
        case .certificate:
            return (Color(red: 0.975, green: 0.957, blue: 0.918), Color(red: 0.17, green: 0.16, blue: 0.15), Color(red: 0.58, green: 0.45, blue: 0.22))
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous).fill(colors.paper)
                    if theme == .certificate {
                        RoundedRectangle(cornerRadius: 2).stroke(colors.accent, lineWidth: 1).padding(4)
                    }
                    VStack(spacing: 3) {
                        if theme == .gazette {
                            Rectangle().fill(colors.ink).frame(height: 2)
                        }
                        Text("Aa")
                            .font(Theme.serif(theme == .gazette ? 15 : 16, theme == .gazette ? .black : .regular))
                            .foregroundStyle(colors.ink)
                        Rectangle().fill(colors.accent).frame(width: 18, height: 2)
                    }
                    .padding(.horizontal, 8)
                }
                .frame(width: 54, height: 46)
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: isSelected ? 2 : 1)
                        .padding(-2)
                )
                Text(theme.title)
                    .font(.system(size: 10.5))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .help("\(theme.title) theme")
    }
}

// MARK: - Time machine

/// Citations over time. Drag across the chart, or pick a moment, to make the card for that day.
private struct TimeMachineView: View {
    let timeline: CitationTimeline
    @Binding var selectedDate: Date?

    private var selectedPoint: CitationTimeline.Point? {
        selectedDate.flatMap { timeline.point(at: $0) } ?? timeline.points.last
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("TIME MACHINE")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                if let point = selectedPoint {
                    Text(summary(point))
                        .font(.system(size: 12))
                        .monospacedDigit()
                }
                Spacer()
                Button("Today") { selectedDate = nil }
                    .controlSize(.small)
                    .disabled(selectedDate == nil)
            }

            chart
                .frame(height: 118)

            if !timeline.moments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(timeline.moments.reversed()) { moment in
                            MomentChip(moment: moment, isSelected: isSelected(moment)) {
                                selectedDate = moment.date
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if let first = timeline.firstTrackedDate, timeline.points.first?.isEstimate == true {
                Text("Hollow points before \(first.formatted(date: .abbreviated, time: .omitted)) are estimated from Google Scholar's yearly counts.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(timeline.points) { point in
                LineMark(x: .value("Date", point.date), y: .value("Citations", point.citations))
                    .foregroundStyle(Color.primary.opacity(0.55))
                    .interpolationMethod(.monotone)
                if point.isEstimate {
                    PointMark(x: .value("Date", point.date), y: .value("Citations", point.citations))
                        .symbol(Circle().strokeBorder(lineWidth: 1.2))
                        .symbolSize(28)
                        .foregroundStyle(Color.secondary)
                }
            }
            ForEach(timeline.moments) { moment in
                if case .citations = moment.kind, let point = timeline.point(at: moment.date) {
                    PointMark(x: .value("Date", point.date), y: .value("Citations", point.citations))
                        .foregroundStyle(Theme.accent)
                        .symbolSize(36)
                }
            }
            if let point = selectedPoint {
                RuleMark(x: .value("Selected", point.date))
                    .foregroundStyle(Theme.accent.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                PointMark(x: .value("Date", point.date), y: .value("Citations", point.citations))
                    .foregroundStyle(Theme.accent)
                    .symbolSize(70)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.primary.opacity(0.06))
                AxisValueLabel().font(.system(size: 9.5))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .year)) { _ in
                AxisValueLabel(format: .dateTime.year()).font(.system(size: 9.5))
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0).onChanged { value in
                            let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                            guard let date: Date = proxy.value(atX: x) else { return }
                            select(near: date)
                        }
                    )
                    .onContinuousHover { phase in
                        if case .active = phase {
                            NSCursor.crosshair.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
            }
        }
        .help("Drag to choose a day. The card above updates to that day.")
    }

    private func select(near date: Date) {
        guard let nearest = timeline.points.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }) else { return }
        // The latest point means today, so the card keeps today's papers.
        selectedDate = nearest == timeline.points.last ? nil : nearest.date
    }

    private func isSelected(_ moment: CitationTimeline.Moment) -> Bool {
        guard let selectedDate else { return false }
        return Calendar.current.isDate(moment.date, inSameDayAs: selectedDate)
    }

    private func summary(_ point: CitationTimeline.Point) -> String {
        let date = point.isEstimate
            ? "End of \(Calendar.current.component(.year, from: point.date))"
            : point.date.formatted(date: .abbreviated, time: .omitted)
        var text = "\(date) · \(point.isEstimate ? "~" : "")\(point.citations.decimalString) citations"
        if let hIndex = point.hIndex {
            text += " · h-index \(hIndex)"
        }
        return text
    }
}

private struct MomentChip: View {
    let moment: CitationTimeline.Moment
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: {
                    if case .citations = moment.kind { return "star.fill" }
                    return "chart.line.uptrend.xyaxis"
                }())
                .font(.system(size: 9))
                .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 0) {
                    Text(moment.title)
                        .font(.system(size: 11.5, weight: .medium))
                    Text(moment.isEstimate
                         ? "by \(moment.date.formatted(.dateTime.year()))"
                         : moment.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isSelected ? Theme.accent.opacity(0.5) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help("Make a card for \(moment.title)")
    }
}
