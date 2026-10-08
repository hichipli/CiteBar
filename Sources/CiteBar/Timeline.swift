import Foundation

/// A profile's citation history as a timeline: one point per tracked day, plus year-end
/// estimates from Google Scholar's yearly counts for the years before tracking began, and the
/// moments worth celebrating (citation milestones, h-index increases).
struct CitationTimeline {
    struct Point: Identifiable, Equatable {
        let date: Date
        let citations: Int
        let hIndex: Int?
        let i10Index: Int?
        let citationsByYear: [Int: Int]?
        /// Year-end total estimated from Scholar's per-year counts, before tracking began.
        let isEstimate: Bool

        var id: Date { date }
    }

    struct Moment: Identifiable, Equatable {
        enum Kind: Equatable {
            case citations(Int)
            case hIndex(Int)
        }

        let date: Date
        let kind: Kind
        /// Dated to a year-end estimate rather than an observed refresh.
        let isEstimate: Bool

        var id: String { "\(date.timeIntervalSince1970)-\(kind)" }

        var title: String {
            switch kind {
            case .citations(let count): return "\(count.decimalString) citations"
            case .hIndex(let value): return "h-index \(value)"
            }
        }
    }

    let points: [Point]
    let moments: [Moment]

    var firstTrackedDate: Date? { points.first { !$0.isEstimate }?.date }

    init(records: [CitationRecord], calendar: Calendar = .current) {
        // One point per tracked day: the last record of that day.
        let byDay = Dictionary(grouping: records) { calendar.startOfDay(for: $0.timestamp) }
        let tracked = byDay.values
            .compactMap { $0.max { $0.timestamp < $1.timestamp } }
            .sorted { $0.timestamp < $1.timestamp }
            .map {
                Point(date: $0.timestamp, citations: $0.citationCount, hIndex: $0.hIndex, i10Index: $0.i10Index,
                      citationsByYear: $0.citationsByYear, isEstimate: false)
            }

        var estimates: [Point] = []
        if let first = tracked.first, let byYear = first.citationsByYear {
            let firstYear = calendar.component(.year, from: first.date)
            var running = 0
            for year in byYear.keys.sorted() where year < firstYear {
                // Yearly counts can disagree slightly with the total; never estimate past
                // the first tracked total, so the line only rises.
                running = min(first.citations, running + (byYear[year] ?? 0))
                guard running > 0,
                      let yearEnd = calendar.date(from: DateComponents(year: year, month: 12, day: 31, hour: 12)) else {
                    continue
                }
                let soFar = byYear.filter { $0.key <= year }
                estimates.append(Point(date: yearEnd, citations: running, hIndex: nil, i10Index: nil,
                                       citationsByYear: soFar, isEstimate: true))
            }
        }

        points = estimates + tracked
        moments = Self.findMoments(in: points)
    }

    private static func findMoments(in points: [Point]) -> [Moment] {
        var moments: [Moment] = []
        var previous: Point?
        for point in points {
            let before = previous?.citations ?? 0
            for threshold in CitationManager.citationMilestones where before < threshold && point.citations >= threshold {
                // Crossed before the first tracked day: only known to the year (or the first day).
                let isEstimate = point.isEstimate || (previous?.isEstimate ?? true)
                moments.append(Moment(date: point.date, kind: .citations(threshold), isEstimate: isEstimate))
            }
            if let old = previous?.hIndex, let new = point.hIndex, new > old {
                moments.append(Moment(date: point.date, kind: .hIndex(new), isEstimate: false))
            }
            previous = point
        }
        return moments
    }

    /// The latest point on or before `date`, or the first point when `date` is earlier.
    func point(at date: Date) -> Point? {
        points.last { $0.date <= date } ?? points.first
    }

    /// Citations gained in the `days` before `date`, with how many days the history covers.
    /// Uses tracked points only; nil before tracking began.
    func growth(endingAt date: Date, days: Int) -> (value: Int, coveredDays: Int)? {
        let tracked = points.filter { !$0.isEstimate && $0.date <= date }
        guard let end = tracked.last, let firstTracked = tracked.first else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end.date) ?? end.date
        let base = tracked.last { $0.date <= start } ?? firstTracked
        guard base.date < end.date else { return nil }
        let covered = Calendar.current.dateComponents([.day], from: base.date, to: end.date).day ?? 0
        return (end.citations - base.citations, min(days, max(1, covered)))
    }

    /// The citation milestone reached on the same day as `date`, if any.
    func milestone(on date: Date, calendar: Calendar = .current) -> Int? {
        moments.compactMap { moment -> Int? in
            guard case .citations(let count) = moment.kind,
                  calendar.isDate(moment.date, inSameDayAs: date) else { return nil }
            return count
        }.max()
    }
}
