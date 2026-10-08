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
            items.append(("Last \(recentGrowthDays) days", "+\(recentGrowth.decimalString)"))
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
