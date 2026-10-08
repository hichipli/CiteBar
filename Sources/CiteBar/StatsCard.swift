import SwiftUI

/// Shareable 3:4 "citation record", typeset like a page: serif numerals, hairline rules,
/// one ink accent for the current year. Rendered at 2× (1800×2400 px), which suits
/// Xiaohongshu, Instagram, X, and LinkedIn.
struct StatsCard: View {
    let name: String
    let metrics: ProfileMetrics
    let recentGrowth: Int?
    let recentGrowthDays: Int?
    var date = Date()

    private static let paper = Color(red: 0.965, green: 0.953, blue: 0.925)
    private static let ink = Color(red: 0.11, green: 0.11, blue: 0.10)
    private static let muted = Color(red: 0.42, green: 0.40, blue: 0.37)
    private static let rule = Color(red: 0.11, green: 0.11, blue: 0.10).opacity(0.75)
    private static let oxblood = Color(red: 0.56, green: 0.16, blue: 0.12)

    private var year: Int { Calendar.current.component(.year, from: date) }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            masthead
            Spacer(minLength: 36)

            Text(name)
                .font(Theme.serif(58, .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            HStack(alignment: .lastTextBaseline, spacing: 18) {
                Text(metrics.citationCount.decimalString)
                    .font(Theme.serif(176, .regular))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("citations")
                    .font(Theme.serif(34).italic())
                    .foregroundStyle(Self.muted)
            }
            .padding(.top, 2)

            statsRow
                .padding(.top, 26)

            Spacer(minLength: 36)

            if let counts = metrics.citationsByYear, counts.count > 1 {
                yearChart(counts)
                Spacer(minLength: 36)
            }

            if !metrics.topPapers.isEmpty {
                mostCited
                Spacer(minLength: 36)
            }

            footer
        }
        .foregroundStyle(Self.ink)
        .padding(.horizontal, 76)
        .padding(.vertical, 68)
        .frame(width: 900, height: 1200)
        .background(Self.paper)
        .environment(\.colorScheme, .light)
    }

    // MARK: - Parts

    private var masthead: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                smallCaps("Citation Record")
                Spacer()
                smallCaps(dateText)
            }
            .padding(.bottom, 14)
            Rectangle().fill(Self.rule).frame(height: 2.5)
            Rectangle().fill(Self.rule).frame(height: 0.75).padding(.top, 3)
        }
    }

    private var statsRow: some View {
        let stats = statItems
        return HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                if index > 0 {
                    Rectangle().fill(Self.rule.opacity(0.4)).frame(width: 0.75, height: 64)
                        .padding(.horizontal, 26)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(stat.value)
                        .font(Theme.serif(44))
                        .monospacedDigit()
                    smallCaps(stat.label)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var statItems: [(label: String, value: String)] {
        var items: [(label: String, value: String)] = []
        if let current = metrics.currentYearCitations {
            items.append(("In \(String(year))", current.decimalString))
        }
        if let recentGrowth, recentGrowth > 0, let recentGrowthDays {
            // A profile tracked for under 30 days shows when its window started (#21).
            let label: String
            if recentGrowthDays < Theme.growthWindowDays,
               let start = Calendar.current.date(byAdding: .day, value: -recentGrowthDays, to: date) {
                label = "Since \(start.formatted(.dateTime.month(.abbreviated).day()))"
            } else {
                label = "Last \(recentGrowthDays) days"
            }
            items.append((label, "+\(recentGrowth.decimalString)"))
        }
        if let hIndex = metrics.hIndex {
            items.append(("h-index", "\(hIndex)"))
        }
        if let i10 = metrics.i10Index {
            items.append(("i10-index", "\(i10)"))
        }
        return Array(items.prefix(4))
    }

    private func yearChart(_ counts: [Int: Int]) -> some View {
        let first = max(counts.keys.min() ?? year, year - 9)
        let years = Array(first...year)
        let maxCount = max(1, years.map { counts[$0] ?? 0 }.max() ?? 1)
        let chartHeight: CGFloat = 150

        return VStack(alignment: .leading, spacing: 14) {
            smallCaps("Citations per year")
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(years, id: \.self) { barYear in
                        let value = counts[barYear] ?? 0
                        VStack(spacing: 8) {
                            if barYear == year {
                                Text(value.decimalString)
                                    .font(Theme.serif(20, .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(Self.oxblood)
                                    .fixedSize()
                            }
                            Rectangle()
                                .fill(barYear == year ? Self.oxblood : Self.ink.opacity(0.62))
                                .frame(height: max(2, chartHeight * CGFloat(value) / CGFloat(maxCount)))
                                .padding(.horizontal, years.count > 6 ? 14 : 24)
                        }
                        .frame(maxWidth: .infinity, alignment: .bottom)
                    }
                }
                .frame(height: chartHeight + 34, alignment: .bottom)
                Rectangle().fill(Self.rule).frame(height: 0.75)
            }
            HStack(spacing: 12) {
                ForEach(years, id: \.self) { barYear in
                    Text(years.count > 7 ? "’\(String(barYear).suffix(2))" : String(barYear))
                        .font(Theme.serif(17))
                        .foregroundStyle(barYear == year ? Self.oxblood : Self.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var mostCited: some View {
        VStack(alignment: .leading, spacing: 14) {
            smallCaps("Most cited")
            ForEach(Array(metrics.topPapers.enumerated()), id: \.offset) { index, paper in
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text("\(index + 1).")
                        .font(Theme.serif(21))
                        .foregroundStyle(Self.muted)
                        .frame(width: 26, alignment: .leading)
                    Text(paper.title)
                        .font(Theme.serif(21).italic())
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 24)
                    Text(paper.citations.decimalString)
                        .font(Theme.serif(21))
                        .monospacedDigit()
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Rectangle().fill(Self.rule).frame(height: 0.75)
            HStack(alignment: .firstTextBaseline) {
                Text("Source: Google Scholar, \(dateText)")
                    .font(Theme.serif(17).italic())
                    .foregroundStyle(Self.muted)
                Spacer()
                smallCaps("citebar.org")
            }
        }
    }

    private func smallCaps(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 14, weight: .semibold))
            .tracking(2.2)
            .foregroundStyle(Self.muted)
    }

    // MARK: - Export

    @MainActor
    func pngData() -> Data? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 2
        guard let cgImage = renderer.cgImage else { return nil }
        return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    }
}

/// Preview window for the Citation Record card: pick a profile, then share, copy, or save.
struct CardStudioView: View {
    @ObservedObject var model: DashboardModel

    @State private var profileID = ""
    @State private var preview: NSImage?
    @State private var png: Data?
    @State private var shareURL: URL?
    @State private var status: Status?

    private enum Status: Equatable {
        case copied
        case saved(URL)
    }

    private var entries: [DashboardModel.Entry] {
        model.entries.filter { $0.metrics != nil }
    }

    private var selected: DashboardModel.Entry? {
        entries.first { $0.id == profileID } ?? entries.first
    }

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            ZStack {
                if let preview {
                    Image(nsImage: preview)
                        .resizable()
                        .interpolation(.high)
                } else {
                    Rectangle().fill(Color.secondary.opacity(0.08))
                    Text(entries.isEmpty ? "Add a profile to make a card." : "")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 330, height: 440)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(Color.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.16), radius: 14, y: 6)

            VStack(alignment: .leading, spacing: 0) {
                Text("Citation Record")
                    .font(Theme.serif(26, .medium))
                Text("A typeset card of a profile's citations, in 3:4 for Xiaohongshu, Instagram, X, and LinkedIn.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)

                if entries.count > 1 {
                    Picker("Profile", selection: $profileID) {
                        ForEach(entries) { entry in
                            Text(entry.profile.name).tag(entry.id)
                        }
                    }
                    .padding(.top, 20)
                }

                Spacer(minLength: 24)

                VStack(spacing: 10) {
                    if let shareURL, let preview {
                        ShareLink(
                            item: shareURL,
                            preview: SharePreview("Citation Record", image: Image(nsImage: preview))
                        ) {
                            Label("Share…", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button(action: copy) {
                        Label(status == .copied ? "Copied" : "Copy Image",
                              systemImage: status == .copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .keyboardShortcut("c")
                    Button(action: save) {
                        Label("Save to Downloads", systemImage: "arrow.down.to.line")
                            .frame(maxWidth: .infinity)
                    }
                    .keyboardShortcut("s")
                }
                .controlSize(.large)
                .disabled(png == nil)

                Group {
                    if case .saved(let url) = status {
                        Button("Saved to Downloads · Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                        .buttonStyle(.link)
                    } else {
                        Text("Copy pastes into WeChat, Slack, or a post; Share offers AirDrop, Messages, and more.")
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
            }
            .frame(width: 250, height: 440, alignment: .topLeading)
        }
        .padding(28)
        .onAppear {
            if profileID.isEmpty {
                profileID = entries.first?.id ?? ""
            }
            render()
        }
        .onChange(of: profileID) { _ in render() }
        .onExitCommand { NSApp.keyWindow?.close() }
    }

    private var fileName: String {
        let name = (selected?.profile.name ?? "Profile")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let day = ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withFullDate])
        return "CiteBar-\(name)-\(day).png"
    }

    private func render() {
        status = nil
        guard let entry = selected, let metrics = entry.metrics,
              let data = StatsCard(
                name: entry.profile.name,
                metrics: metrics,
                recentGrowth: entry.profile.recentGrowth,
                recentGrowthDays: entry.profile.recentGrowthDays
              ).pngData() else {
            return
        }
        png = data
        preview = NSImage(data: data)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        shareURL = (try? data.write(to: url, options: .atomic)) == nil ? nil : url
    }

    private func copy() {
        guard let png else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(png, forType: .png)
        status = .copied
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if status == .copied { status = nil }
        }
    }

    private func save() {
        guard let png, let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            return
        }
        let url = downloads.appendingPathComponent(fileName)
        do {
            try png.write(to: url, options: .atomic)
            status = .saved(url)
        } catch {
            AppLog.error("Failed to save stats card: \(error)")
            NSSound.beep()
        }
    }
}
