import SwiftUI

// MARK: - What a card shows

enum CardTheme: String, CaseIterable, Identifiable {
    case record, night, gazette, certificate

    var id: Self { self }

    var title: String {
        switch self {
        case .record: return "Record"
        case .night: return "Night"
        case .gazette: return "Gazette"
        case .certificate: return "Certificate"
        }
    }

    /// The certificate is a single statement, so it has no chart or paper list.
    var showsChart: Bool { self != .certificate }
    var showsPaperList: Bool { self != .certificate }
}

enum CardGrowth: Int, CaseIterable, Identifiable {
    case off = 0, week = 7, month = 30, quarter = 90, year = 365

    var id: Self { self }

    var title: String {
        switch self {
        case .off: return "Off"
        case .week: return "7 days"
        case .month: return "30 days"
        case .quarter: return "90 days"
        case .year: return "1 year"
        }
    }
}

enum CardPapers: String, CaseIterable, Identifiable {
    case none, mostCited, featured

    var id: Self { self }

    var title: String {
        switch self {
        case .none: return "None"
        case .mostCited: return "Most cited"
        case .featured: return "One paper"
        }
    }
}

/// Citations gained over a period ending on the card's date.
struct CardGrowthValue: Equatable {
    let value: Int
    let days: Int
    /// Fewer days than requested, because tracking began recently.
    let isPartial: Bool
    let startDate: Date

    /// "Last 30 days", or "Since Oct 5" for a short history.
    var label: String {
        if isPartial {
            return "Since \(startDate.formatted(.dateTime.month(.abbreviated).day()))"
        }
        return days >= 365 ? "Last year" : "Last \(days) days"
    }

    /// For headlines: "in the Last 30 Days", "Since Oct 5", "in the Last Year".
    var headlinePhrase: String {
        if isPartial {
            return "Since \(startDate.formatted(.dateTime.month(.abbreviated).day()))"
        }
        return days >= 365 ? "in the Last Year" : "in the Last \(days) Days"
    }
}

/// One profile at one moment, already filtered to what the user chose to show.
struct CardContent: Equatable {
    var name: String
    var date: Date
    /// A year-end total estimated from Scholar's per-year counts.
    var isEstimate = false
    var citations: Int
    var hIndex: Int?
    var i10Index: Int?
    /// Citations per year for the chart; nil hides the chart.
    var chart: [Int: Int]?
    var yearCitations: Int?
    var growth: CardGrowthValue?
    var papers: [ScholarPaper] = []
    var featured: ScholarPaper?
    var milestone: Int?
    var note = ""

    var year: Int { Calendar.current.component(.year, from: date) }

    /// "Varga" from "Elena Varga", "Li" from "Hongming (Chip) Li".
    var surname: String {
        name.split(separator: " ").last.map(String.init) ?? name
    }

    static func longDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }

    var dateText: String {
        isEstimate ? "End of \(year)" : Self.longDate(date)
    }

    var sourceText: String {
        isEstimate
            ? "Source: Google Scholar yearly counts, approximate, end of \(year)"
            : "Source: Google Scholar, \(Self.longDate(date))"
    }
}

// MARK: - Card

/// Shareable 3:4 card (900×1200 pt, rendered at 2×) in one of four themes.
struct StatsCard: View {
    let content: CardContent
    var theme: CardTheme = .record

    var body: some View {
        Group {
            switch theme {
            case .record: RecordLayout(content: content, palette: .paper)
            case .night: RecordLayout(content: content, palette: .night)
            case .gazette: GazetteLayout(content: content)
            case .certificate: CertificateLayout(content: content)
            }
        }
        .frame(width: 900, height: 1200)
        .environment(\.colorScheme, .light)
    }

    @MainActor
    func pngData() -> Data? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 2
        guard let cgImage = renderer.cgImage else { return nil }
        return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    }

    // MARK: Gazette copy

    /// Front-page headline and deck written from the card's numbers.
    static func gazetteHeadline(for content: CardContent) -> (headline: String, deck: String) {
        let total = content.citations.decimalString
        let surname = content.surname
        let hClause = content.hIndex.map { "; the h-index stands at \($0)" } ?? ""

        if let milestone = content.milestone {
            return (
                "\(surname) Passes \(milestone.decimalString) Citations",
                "The mark fell on \(CardContent.longDate(content.date)). \(content.name)'s work is now cited \(total) times on Google Scholar\(hClause)."
            )
        }
        if let paper = content.featured {
            let title = paper.title.count > 44 ? paper.title.prefix(43).trimmingCharacters(in: .whitespaces) + "…" : paper.title
            let year = paper.year.map { " \($0)" } ?? ""
            return (
                "“\(title)” Reaches \(paper.citations.decimalString) Citations",
                "\(content.name)'s\(year) paper leads the record, with total citations standing at \(total)."
            )
        }
        if let growth = content.growth, growth.value > 0 {
            return (
                "\(surname) Cited \(growth.value.decimalString) Times \(growth.headlinePhrase)",
                "Total citations for \(content.name) reach \(total)\(hClause)."
            )
        }
        return (
            "\(surname)'s Work Now Cited \(total) Times",
            content.isEstimate
                ? "An estimate from Google Scholar's yearly counts at the end of \(content.year)."
                : "So says Google Scholar as of \(CardContent.longDate(content.date))\(hClause)."
        )
    }
}

// MARK: - Shared pieces

private struct CardPalette {
    let paper: Color
    let ink: Color
    let muted: Color
    let rule: Color
    let accent: Color

    static let paper = CardPalette(
        paper: Color(red: 0.965, green: 0.953, blue: 0.925),
        ink: Color(red: 0.11, green: 0.11, blue: 0.10),
        muted: Color(red: 0.42, green: 0.40, blue: 0.37),
        rule: Color(red: 0.11, green: 0.11, blue: 0.10).opacity(0.75),
        accent: Color(red: 0.56, green: 0.16, blue: 0.12)
    )

    static let night = CardPalette(
        paper: Color(red: 0.08, green: 0.09, blue: 0.11),
        ink: Color(red: 0.94, green: 0.92, blue: 0.88),
        muted: Color(red: 0.62, green: 0.60, blue: 0.56),
        rule: Color(red: 0.94, green: 0.92, blue: 0.88).opacity(0.55),
        accent: Color(red: 0.85, green: 0.66, blue: 0.32)
    )
}

private func smallCaps(_ text: String, _ color: Color, size: CGFloat = 14) -> some View {
    Text(text.uppercased())
        .font(.system(size: size, weight: .semibold))
        .tracking(2.2)
        .foregroundStyle(color)
}

/// Citations per year as bars on a baseline, the card's year in the accent color.
private struct YearChart: View {
    let counts: [Int: Int]
    let year: Int
    let ink: Color
    let muted: Color
    let rule: Color
    let accent: Color
    var height: CGFloat = 150
    var maxYears = 10

    var body: some View {
        let first = max(counts.keys.min() ?? year, year - maxYears + 1)
        let years = Array(first...max(first, year))
        let maxCount = max(1, years.map { counts[$0] ?? 0 }.max() ?? 1)

        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(years, id: \.self) { barYear in
                    let value = counts[barYear] ?? 0
                    VStack(spacing: 8) {
                        if barYear == year {
                            Text(value.decimalString)
                                .font(Theme.serif(20, .medium))
                                .monospacedDigit()
                                .foregroundStyle(accent)
                                .fixedSize()
                        }
                        Rectangle()
                            .fill(barYear == year ? accent : ink.opacity(0.62))
                            .frame(height: max(2, height * CGFloat(value) / CGFloat(maxCount)))
                            .padding(.horizontal, years.count > 6 ? 14 : 24)
                    }
                    .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
            .frame(height: height + 34, alignment: .bottom)
            Rectangle().fill(rule).frame(height: 0.75)
            HStack(spacing: 12) {
                ForEach(years, id: \.self) { barYear in
                    Text(years.count > 7 ? "’\(String(barYear).suffix(2))" : String(barYear))
                        .font(Theme.serif(17))
                        .foregroundStyle(barYear == year ? accent : muted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 12)
        }
    }
}

// MARK: - Record and Night

private struct RecordLayout: View {
    let content: CardContent
    let palette: CardPalette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            masthead
            Spacer(minLength: 30)

            if let milestone = content.milestone {
                smallCaps("★  Passed \(milestone.decimalString) citations", palette.accent, size: 15)
                    .padding(.bottom, 14)
            }
            Text(content.name)
                .font(Theme.serif(58, .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.55)

            HStack(alignment: .lastTextBaseline, spacing: 18) {
                Text((content.isEstimate ? "~" : "") + content.citations.decimalString)
                    .font(Theme.serif(176, .regular))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("citations")
                    .font(Theme.serif(34).italic())
                    .foregroundStyle(palette.muted)
            }
            .padding(.top, 2)

            statsRow
                .padding(.top, 22)

            Spacer(minLength: 30)

            if let chart = content.chart, chart.count > 1 {
                VStack(alignment: .leading, spacing: 14) {
                    smallCaps("Citations per year", palette.muted)
                    YearChart(counts: chart, year: content.year, ink: palette.ink, muted: palette.muted,
                              rule: palette.rule, accent: palette.accent)
                }
                Spacer(minLength: 30)
            }

            papers

            if !content.note.isEmpty {
                Text("“\(content.note)”")
                    .font(Theme.serif(24).italic())
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 26)
            }

            footer
        }
        .foregroundStyle(palette.ink)
        .padding(.horizontal, 76)
        .padding(.vertical, 68)
        .background(palette.paper)
    }

    private var masthead: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                smallCaps("Citation Record", palette.muted)
                Spacer()
                smallCaps(content.dateText, palette.muted)
            }
            .padding(.bottom, 14)
            Rectangle().fill(palette.rule).frame(height: 2.5)
            Rectangle().fill(palette.rule).frame(height: 0.75).padding(.top, 3)
        }
    }

    private var statsRow: some View {
        var items: [(label: String, value: String)] = []
        if let current = content.yearCitations {
            items.append(("In \(String(content.year))", current.decimalString))
        }
        if let growth = content.growth {
            items.append((growth.label, growth.value.signedString))
        }
        if let hIndex = content.hIndex {
            items.append(("h-index", "\(hIndex)"))
        }
        if let i10 = content.i10Index {
            items.append(("i10-index", "\(i10)"))
        }
        let stats = Array(items.prefix(4))

        return HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                if index > 0 {
                    Rectangle().fill(palette.rule.opacity(0.4)).frame(width: 0.75, height: 64)
                        .padding(.horizontal, 26)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(stat.value)
                        .font(Theme.serif(44))
                        .monospacedDigit()
                    smallCaps(stat.label, palette.muted)
                }
            }
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var papers: some View {
        if let paper = content.featured {
            VStack(alignment: .leading, spacing: 10) {
                smallCaps("Featured paper", palette.muted)
                Text(paper.title)
                    .font(Theme.serif(28).italic())
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .lastTextBaseline, spacing: 10) {
                    Text(paper.citations.decimalString)
                        .font(Theme.serif(44))
                        .foregroundStyle(palette.accent)
                    Text(paper.year.map { "citations · \(String($0))" } ?? "citations")
                        .font(Theme.serif(22).italic())
                        .foregroundStyle(palette.muted)
                }
            }
            Spacer(minLength: 30)
        } else if !content.papers.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                smallCaps("Most cited", palette.muted)
                ForEach(Array(content.papers.enumerated()), id: \.offset) { index, paper in
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        Text("\(index + 1).")
                            .font(Theme.serif(21))
                            .foregroundStyle(palette.muted)
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
            Spacer(minLength: 30)
        }
    }

    private var footer: some View {
        VStack(spacing: 14) {
            Rectangle().fill(palette.rule).frame(height: 0.75)
            HStack(alignment: .firstTextBaseline) {
                Text(content.sourceText)
                    .font(Theme.serif(17).italic())
                    .foregroundStyle(palette.muted)
                Spacer()
                smallCaps("citebar.org", palette.muted)
            }
        }
    }
}

// MARK: - Gazette

private struct GazetteLayout: View {
    let content: CardContent

    private let paper = Color(red: 0.95, green: 0.93, blue: 0.89)
    private let ink = Color(red: 0.09, green: 0.09, blue: 0.09)
    private let muted = Color(red: 0.36, green: 0.35, blue: 0.33)
    private let accent = Color(red: 0.56, green: 0.16, blue: 0.12)

    private var weekdayDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return content.isEstimate ? "End of \(content.year)" : formatter.string(from: content.date)
    }

    var body: some View {
        let copy = StatsCard.gazetteHeadline(for: content)

        VStack(alignment: .leading, spacing: 0) {
            HStack {
                smallCaps("Vol. \(String(content.year))", muted, size: 13)
                Spacer()
                smallCaps("Google Scholar Edition", muted, size: 13)
                Spacer()
                smallCaps("Free", muted, size: 13)
            }
            Rectangle().fill(ink).frame(height: 1).padding(.top, 10)
            Text("The Citation Gazette")
                .font(Theme.serif(80, .black))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            Rectangle().fill(ink).frame(height: 3)
            Rectangle().fill(ink).frame(height: 1).padding(.top, 3)
            HStack {
                smallCaps(weekdayDate, ink, size: 13)
                Spacer()
                smallCaps("citebar.org", ink, size: 13)
            }
            .padding(.vertical, 9)
            Rectangle().fill(ink).frame(height: 1)

            Text(copy.headline)
                .font(Theme.serif(60, .bold))
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 34)
            Text(copy.deck)
                .font(Theme.serif(25).italic())
                .foregroundStyle(muted)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            Rectangle().fill(ink).frame(height: 1).padding(.top, 30)

            HStack(alignment: .top, spacing: 28) {
                numbers
                    .frame(width: 290, alignment: .leading)
                Rectangle().fill(ink.opacity(0.5)).frame(width: 1)
                rightColumn
            }
            .padding(.top, 24)

            Spacer(minLength: 20)

            if !content.note.isEmpty {
                (Text("Editor’s note. ").font(Theme.serif(21, .semibold))
                    + Text(content.note).font(Theme.serif(21).italic()))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 18)
            }

            Rectangle().fill(ink).frame(height: 1)
            Text(content.sourceText)
                .font(Theme.serif(16).italic())
                .foregroundStyle(muted)
                .padding(.top, 10)
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 64)
        .padding(.vertical, 56)
        .background(paper)
    }

    private var numbers: some View {
        VStack(alignment: .leading, spacing: 0) {
            smallCaps("By the numbers", muted, size: 13)
            Text((content.isEstimate ? "~" : "") + content.citations.decimalString)
                .font(Theme.serif(96, .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 6)
            Text("citations")
                .font(Theme.serif(24).italic())
                .foregroundStyle(muted)
            VStack(spacing: 10) {
                if let growth = content.growth {
                    line(growth.label, growth.value.signedString)
                }
                if let current = content.yearCitations {
                    line("In \(String(content.year))", current.decimalString)
                }
                if let hIndex = content.hIndex {
                    line("h-index", "\(hIndex)")
                }
                if let i10 = content.i10Index {
                    line("i10-index", "\(i10)")
                }
            }
            .padding(.top, 22)
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label).font(Theme.serif(21))
            Rectangle()
                .fill(ink.opacity(0.35))
                .frame(height: 1)
                .offset(y: -4)
            Text(value).font(Theme.serif(21, .semibold)).monospacedDigit()
        }
    }

    @ViewBuilder
    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let chart = content.chart, chart.count > 1 {
                smallCaps("Fig. 1 — Citations per year", muted, size: 13)
                YearChart(counts: chart, year: content.year, ink: ink, muted: muted, rule: ink.opacity(0.7),
                          accent: accent, height: 140, maxYears: 7)
            }
            if let paper = content.featured {
                smallCaps("The paper", muted, size: 13)
                    .padding(.top, content.chart == nil ? 0 : 12)
                Text(paper.title)
                    .font(Theme.serif(22).italic())
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !content.papers.isEmpty {
                smallCaps("Most cited", muted, size: 13)
                    .padding(.top, content.chart == nil ? 0 : 12)
                ForEach(Array(content.papers.prefix(content.chart == nil ? 3 : 2).enumerated()), id: \.offset) { _, paper in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(paper.title)
                            .font(Theme.serif(19).italic())
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(paper.citations.decimalString)
                            .font(Theme.serif(19))
                            .monospacedDigit()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Certificate

private struct CertificateLayout: View {
    let content: CardContent

    private let paper = Color(red: 0.975, green: 0.957, blue: 0.918)
    private let ink = Color(red: 0.17, green: 0.16, blue: 0.15)
    private let muted = Color(red: 0.45, green: 0.42, blue: 0.38)
    private let gold = Color(red: 0.58, green: 0.45, blue: 0.22)
    private let seal = Color(red: 0.56, green: 0.16, blue: 0.12)

    private static let ordinals = [
        "first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth",
        "eleventh", "twelfth", "thirteenth", "fourteenth", "fifteenth", "sixteenth", "seventeenth",
        "eighteenth", "nineteenth", "twentieth", "twenty-first", "twenty-second", "twenty-third",
        "twenty-fourth", "twenty-fifth", "twenty-sixth", "twenty-seventh", "twenty-eighth",
        "twenty-ninth", "thirtieth", "thirty-first"
    ]

    /// "as of the eighth of October, 2026"
    private var dateInWords: String {
        if content.isEstimate {
            return "by the end of \(content.year), approximately"
        }
        let day = Calendar.current.component(.day, from: content.date)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM, yyyy"
        return "as of the \(Self.ordinals[max(0, min(30, day - 1))]) of \(formatter.string(from: content.date))"
    }

    private var count: Int { content.featured?.citations ?? content.citations }

    var body: some View {
        ZStack {
            paper
            border

            VStack(spacing: 0) {
                Spacer(minLength: 70)
                smallCaps("Certificate of Citation", gold, size: 18)
                Text("— ✦ —")
                    .font(Theme.serif(22))
                    .foregroundStyle(gold)
                    .padding(.top, 10)

                Spacer(minLength: 34)

                italic("This is to certify that")
                if let paper = content.featured {
                    italic("the paper")
                        .padding(.top, 6)
                    Text("“\(paper.title)”")
                        .font(Theme.serif(38, .medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 14)
                    italic("by \(content.name)")
                        .padding(.top, 12)
                } else {
                    Text(content.name)
                        .font(Theme.serif(64, .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.top, 18)
                }

                italic("has been cited")
                    .padding(.top, 22)
                Text((content.isEstimate ? "~" : "") + count.decimalString)
                    .font(Theme.serif(150, .regular))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                italic("times on Google Scholar")
                if let milestone = content.milestone, content.featured == nil {
                    Text("passing the \(milestone.decimalString)-citation mark")
                        .font(Theme.serif(26).italic())
                        .foregroundStyle(seal)
                        .padding(.top, 10)
                }
                italic(dateInWords)
                    .padding(.top, 10)

                if !content.note.isEmpty {
                    Text("“\(content.note)”")
                        .font(Theme.serif(22).italic())
                        .foregroundStyle(ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 22)
                }

                Spacer(minLength: 30)

                HStack(alignment: .bottom) {
                    signature("Google Scholar", "Source")
                    Spacer()
                    sealView
                    Spacer()
                    signature("CiteBar", "citebar.org")
                }
                .padding(.horizontal, 30)

                Spacer(minLength: 64)
            }
            .foregroundStyle(ink)
            .padding(.horizontal, 110)
        }
    }

    private func italic(_ text: String) -> some View {
        Text(text)
            .font(Theme.serif(28).italic())
            .foregroundStyle(muted)
            .multilineTextAlignment(.center)
    }

    private var border: some View {
        ZStack {
            Rectangle().stroke(gold, lineWidth: 2.5).padding(38)
            Rectangle().stroke(gold.opacity(0.8), lineWidth: 0.75).padding(50)
            GeometryReader { geometry in
                let inset: CGFloat = 44
                ForEach(0..<4, id: \.self) { corner in
                    Rectangle()
                        .fill(gold)
                        .frame(width: 14, height: 14)
                        .rotationEffect(.degrees(45))
                        .position(
                            x: corner % 2 == 0 ? inset : geometry.size.width - inset,
                            y: corner < 2 ? inset : geometry.size.height - inset
                        )
                }
            }
        }
    }

    private func signature(_ name: String, _ role: String) -> some View {
        VStack(spacing: 8) {
            Text(name)
                .font(Theme.serif(26).italic())
            Rectangle().fill(ink.opacity(0.6)).frame(width: 190, height: 1)
            smallCaps(role, muted, size: 12)
        }
    }

    private var sealView: some View {
        ZStack {
            Circle().fill(seal)
            Circle().stroke(paper.opacity(0.55), lineWidth: 1.5).padding(9)
            Circle().stroke(paper.opacity(0.3), lineWidth: 0.75).padding(15)
            VStack(spacing: 2) {
                Text("★").font(.system(size: 16))
                Text(count.decimalString)
                    .font(Theme.serif(26, .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("CITED")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.5)
            }
            .foregroundStyle(paper)
            .padding(.horizontal, 22)
        }
        .frame(width: 132, height: 132)
        .rotationEffect(.degrees(-8))
    }
}
