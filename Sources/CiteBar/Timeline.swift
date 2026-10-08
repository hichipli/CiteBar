import Foundation

/// A profile's citation history as a timeline: one point per tracked day, plus estimates from
/// Google Scholar's yearly counts for the years before tracking began, and the moments worth
/// celebrating (citation milestones, h-index increases).
struct CitationTimeline {
    struct Point: Identifiable, Equatable {
        let date: Date
        let citations: Int
        let hIndex: Int?
        let i10Index: Int?
        let citationsByYear: [Int: Int]?
        /// Estimated from Scholar's per-year counts, before tracking began.
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
        /// Dated by estimate rather than seen on a refresh.
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

        // Before tracking began, estimate year-end totals from Scholar's per-year counts. The latest
        // counts are the most complete (records from older versions have none), and they're scaled
        // to add up to that record's total, which also includes citations Scholar gives no year.
        var estimates: [Point] = []
        var origin: Point?
        if let first = tracked.first,
           let latest = tracked.last(where: { !($0.citationsByYear ?? [:]).isEmpty }),
           let byYear = latest.citationsByYear,
           let startYear = byYear.filter({ $0.value > 0 }).keys.min(),
           let start = calendar.date(from: DateComponents(year: startYear, month: 1, day: 1)),
           start < first.date {
            let scale = Double(latest.citations) / Double(byYear.values.reduce(0, +))
            origin = Point(date: start, citations: 0, hIndex: nil, i10Index: nil, citationsByYear: [:], isEstimate: true)
            var running = 0
            for year in startYear..<calendar.component(.year, from: first.date) {
                running += byYear[year] ?? 0
                guard let yearEnd = calendar.date(from: DateComponents(year: year, month: 12, day: 31, hour: 12)) else {
                    continue
                }
                // Never past the first tracked total, so the line only rises.
                let total = min(first.citations, Int((Double(running) * scale).rounded()))
                estimates.append(Point(date: yearEnd, citations: total, hIndex: nil, i10Index: nil,
                                       citationsByYear: byYear.filter { $0.key <= year }, isEstimate: true))
            }
        }

        let found = Self.findMoments(in: estimates + tracked, after: origin, calendar: calendar)
        points = (estimates + tracked + found.crossings).sorted { $0.date < $1.date }
        moments = found.moments
    }

    /// Citation milestones and h-index increases. A milestone passed on an estimated stretch gets
    /// a point of its own, dated as if citations came in evenly between its neighbours. Without
    /// an estimated past, milestones already passed on the first tracked day are left out: their
    /// dates are unknown.
    private static func findMoments(in points: [Point], after origin: Point?,
                                     calendar: Calendar) -> (moments: [Moment], crossings: [Point]) {
        var moments: [Moment] = []
        var crossings: [Point] = []
        var previous = origin
        // Scholar's numbers sometimes dip and recover; only new highs count.
        var bestCitations = origin?.citations ?? 0
        var bestHIndex = 0
        for point in points {
            defer {
                previous = point
                bestCitations = max(bestCitations, point.citations)
                bestHIndex = max(bestHIndex, point.hIndex ?? 0)
            }
            guard let previous else { continue }
            let isEstimate = previous.isEstimate || point.isEstimate
            for threshold in CitationManager.citationMilestones
            where bestCitations < threshold && point.citations >= threshold {
                var date = point.date
                if isEstimate && threshold < point.citations {
                    let fraction = Double(threshold - previous.citations) / Double(point.citations - previous.citations)
                    date = previous.date.addingTimeInterval(point.date.timeIntervalSince(previous.date) * fraction)
                    var byYear = previous.citationsByYear ?? [:]
                    byYear[calendar.component(.year, from: date), default: 0] += threshold - previous.citations
                    crossings.append(Point(date: date, citations: threshold, hIndex: nil, i10Index: nil,
                                           citationsByYear: byYear, isEstimate: true))
                }
                moments.append(Moment(date: date, kind: .citations(threshold), isEstimate: isEstimate))
            }
            if bestHIndex > 0, let new = point.hIndex, new > bestHIndex {
                moments.append(Moment(date: point.date, kind: .hIndex(new), isEstimate: false))
            }
        }
        return (moments, crossings)
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
