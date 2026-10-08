import SwiftUI

/// Shareable 1200×675 image of a profile's metrics, sized for social posts.
struct StatsCard: View {
    let name: String
    let metrics: ProfileMetrics
    let recentGrowth: Int?
    let recentGrowthDays: Int?
    var date = Date()

    private var year: Int { Calendar.current.component(.year, from: date) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "book.circle.fill")
                Text("CiteBar")
            }
            .font(.system(size: 30, weight: .semibold))
            .opacity(0.85)

            Spacer()

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(name)
                        .font(.system(size: 52, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Text(Self.format(metrics.citationCount))
                        .font(.system(size: 150, weight: .bold, design: .rounded))
                        .padding(.top, 4)
                    Text("citations on Google Scholar")
                        .font(.system(size: 30))
                        .opacity(0.8)
                }
                Spacer(minLength: 40)
                yearChart
            }

            HStack(spacing: 16) {
                if let currentYear = metrics.currentYearCitations {
                    chip("+\(Self.format(currentYear)) in \(String(year))")
                }
                if let recentGrowth, recentGrowth > 0, let recentGrowthDays {
                    chip("+\(Self.format(recentGrowth)) in \(recentGrowthDays) days")
                }
                if let hIndex = metrics.hIndex {
                    chip("h-index \(hIndex)")
                }
                if let i10Index = metrics.i10Index {
                    chip("i10-index \(i10Index)")
                }
            }
            .padding(.top, 36)

            Spacer()

            HStack {
                Text(date.formatted(date: .long, time: .omitted))
                Spacer()
                Text("citebar.org")
            }
            .font(.system(size: 24))
            .opacity(0.7)
        }
        .foregroundStyle(.white)
        .padding(64)
        .frame(width: 1200, height: 675)
        .background(
            LinearGradient(
                colors: [Color(red: 0.11, green: 0.20, blue: 0.45), Color(red: 0.32, green: 0.18, blue: 0.52)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    /// Citations per year for the last six years, current year highlighted.
    @ViewBuilder private var yearChart: some View {
        let counts = metrics.citationsByYear ?? [:]
        let years = counts.keys.sorted().suffix(6)
        if years.count >= 2, let maxCount = counts.values.max(), maxCount > 0 {
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(Array(years), id: \.self) { barYear in
                    VStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white.opacity(barYear == year ? 0.95 : 0.4))
                            .frame(width: 44, height: max(4, 220 * CGFloat(counts[barYear] ?? 0) / CGFloat(maxCount)))
                        Text("’\(String(barYear).suffix(2))")
                            .font(.system(size: 20))
                            .opacity(0.7)
                    }
                }
            }
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 28, weight: .medium))
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(.white.opacity(0.15), in: Capsule())
    }

    private static func format(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }

    @MainActor
    func pngData() -> Data? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 2
        guard let cgImage = renderer.cgImage else { return nil }
        return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
    }
}
