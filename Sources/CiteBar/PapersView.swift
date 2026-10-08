import SwiftUI

/// All of a profile's papers, searchable and sortable. Starring a paper watches it: it shows in
/// the panel under that profile, and its gains come first in notifications.
struct PapersView: View {
    @ObservedObject var model: DashboardModel
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State var profileID: String

    @State private var profilePapers: ProfilePapers?
    @State private var isLoaded = false
    @State private var query = ""
    @State private var sort = Sort.mostCited

    private enum Sort: String, CaseIterable, Identifiable {
        case mostCited = "Most cited"
        case newest = "Newest"
        var id: Self { self }
    }

    private var entry: DashboardModel.Entry? {
        model.entries.first { $0.id == profileID }
    }

    private var rows: [ScholarPaper] {
        let papers = profilePapers?.papers ?? []
        let matches = query.isEmpty ? papers : papers.filter { $0.title.localizedCaseInsensitiveContains(query) }
        switch sort {
        case .mostCited:
            return matches.sorted { ($0.citations, $1.title) > ($1.citations, $0.title) }
        case .newest:
            return matches.sorted { ($0.year ?? 0, $0.citations) > ($1.year ?? 0, $1.citations) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)

            Divider()

            if !isLoaded {
                Spacer()
            } else if (profilePapers?.papers ?? []).isEmpty {
                emptyState
            } else {
                List(rows, id: \.id) { paper in
                    PaperRow(
                        paper: paper,
                        isWatched: settingsManager.settings.watchedPaperIDs.contains(paper.id),
                        lastChange: profilePapers?.lastChanges?[paper.id],
                        hIndexNeed: entry?.metrics?.nextHIndexStep.flatMap { step in
                            step.needs.first { $0.paper.id == paper.id }.map { (step.target, $0.needed) }
                        },
                        toggleWatch: { toggleWatch(paper) }
                    )
                }
                .listStyle(.inset(alternatesRowBackgrounds: false))
            }

            Divider()

            Text("Star a paper to watch it: it appears in the menu bar panel, and its new citations come first in notifications. Double-click a paper to open it on Google Scholar.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
        }
        .frame(width: 640, height: 580)
        .task(id: profileID) {
            isLoaded = false
            profilePapers = await (NSApp.delegate as? AppDelegate)?.citationManager?.storageManager.getProfilePapers(for: profileID)
            isLoaded = true
        }
        .onExitCommand { NSApp.keyWindow?.close() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Papers")
                    .font(Theme.serif(26, .medium))
                if let count = profilePapers?.papers.count, count > 0 {
                    Text("\(count) on Google Scholar")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if model.entries.count > 1 {
                    Picker("Profile", selection: $profileID) {
                        ForEach(model.entries) { entry in
                            Text(entry.profile.name).tag(entry.id)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                    TextField("Search titles", text: $query)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                Picker("Sort", selection: $sort) {
                    ForEach(Sort.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Text("No paper list yet")
                .font(Theme.serif(18, .medium))
            Text("CiteBar reads a profile's papers when it refreshes. Refresh once and they'll appear here.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Refresh Now") {
                (NSApp.delegate as? AppDelegate)?.refreshCitations()
            }
            .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
    }

    private func toggleWatch(_ paper: ScholarPaper) {
        let watched = settingsManager.settings.watchedPaperIDs.contains(paper.id)
        settingsManager.setWatched(!watched, paperID: paper.id)
        (NSApp.delegate as? AppDelegate)?.updateMenuBarDisplay()
    }
}

private struct PaperRow: View {
    let paper: ScholarPaper
    let isWatched: Bool
    let lastChange: PaperChange?
    /// (target h-index, citations this paper still needs) when it is on the margin.
    let hIndexNeed: (target: Int, needed: Int)?
    let toggleWatch: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button(action: toggleWatch) {
                Image(systemName: isWatched ? "star.fill" : "star")
                    .foregroundStyle(isWatched ? Theme.accent : Color.secondary.opacity(0.6))
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help(isWatched ? "Stop watching this paper" : "Watch this paper in the menu bar panel")

            VStack(alignment: .leading, spacing: 3) {
                Text(paper.title)
                    .font(.system(size: 13))
                    .lineLimit(2)
                HStack(spacing: 10) {
                    if let year = paper.year {
                        Text(String(year))
                    }
                    if let hIndexNeed {
                        Label(
                            "\(hIndexNeed.needed) more for h-index \(hIndexNeed.target)",
                            systemImage: "scope"
                        )
                        .foregroundStyle(Theme.accent)
                    }
                    if let lastChange {
                        Text("+\(lastChange.delta) on \(lastChange.date.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(paper.citations.decimalString)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .help("\(paper.citations) citations")
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { open(paper.scholarURL) }
        .contextMenu {
            Button(isWatched ? "Stop Watching" : "Watch", action: toggleWatch)
            Divider()
            Button("Open on Google Scholar") { open(paper.scholarURL) }
            if let citedBy = paper.citedByURL {
                Button("See Who Cited It") { open(citedBy) }
            }
        }
    }

    private func open(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
