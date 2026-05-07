//
//  SourceLibrarySidebarView.swift
//  PortastudioPreview
//

import AppKit
import SwiftUI

struct SourceLibrarySidebarView: View {
    @Bindable var store: SourceLibraryStore
    @State private var searchText = ""

    private var filtered: SourceLibrarySearch.FilterResult {
        SourceLibrarySearch.filter(
            sources: store.sources,
            individualSongs: store.individualSongs,
            missingItems: store.missingItems,
            searchText: searchText
        )
    }

    private var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        List(selection: $store.selection) {
            sourcesSection
            individualSongsSection
            missingSection

            if isSearchActive && !filtered.hasAnyResults {
                noResultsSection
            }

            if let error = store.loadError {
                Section("Load Error") {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search Sources and Songs")
        .accessibilityIdentifier("sidebar-source-list")
    }

    // MARK: - SD Cards & Backups

    private var sourcesSection: some View {
        Section("SD Cards & Backups") {
            let availableInFilter = filtered.sources.filter { !$0.isMissing }
            if availableInFilter.isEmpty && !isSearchActive {
                mutedEmptyRow("No sources added")
                    .accessibilityLabel("No sources added")
            } else {
                ForEach($store.sources) { $source in
                    if !source.isMissing && filteredSourceIsVisible(source) {
                        let visibleSongs = filteredSongs(for: source)
                        DisclosureGroup(isExpanded: $source.isExpanded) {
                            if visibleSongs.isEmpty {
                                mutedEmptyRow("No songs found")
                                    .accessibilityLabel("No songs found in \(source.displayName)")
                            } else {
                                ForEach(visibleSongs) { song in
                                    SourceLibrarySongRow(song: song)
                                        .tag(SourceLibrarySelection.individualSong(song.id))
                                        .accessibilityLabel(sourceSongAccessibilityLabel(song))
                                        .contextMenu {
                                            Button("Reveal in Finder") {
                                                NSWorkspace.shared.activateFileViewerSelecting([song.folderURL])
                                            }
                                        }
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Label(source.displayName, systemImage: sourceIcon(for: source.kind))
                                Text(sourceSecondaryLabel(for: source))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(SourceLibrarySelection.source(source.id))
                        .accessibilityLabel(sourceAccessibilityLabel(source))
                        .accessibilityHint("Select to browse songs")
                        .contextMenu {
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([source.folderURL])
                            }
                            Divider()
                            Button("Forget", role: .destructive) {
                                store.forgetSource(id: source.id)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Individual Songs

    private var individualSongsSection: some View {
        Section("Individual Songs") {
            let available = filtered.individualSongs.filter { !$0.isMissing }
            if available.isEmpty && !isSearchActive {
                mutedEmptyRow("No songs opened")
                    .accessibilityLabel("No individual songs opened")
            } else {
                ForEach(available) { song in
                    SourceLibrarySongRow(song: song)
                        .tag(SourceLibrarySelection.individualSong(song.id))
                        .accessibilityLabel(individualSongAccessibilityLabel(song))
                        .contextMenu {
                            Button("Reveal in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([song.folderURL])
                            }
                            Divider()
                            Button("Forget", role: .destructive) {
                                store.forgetSong(id: song.id)
                            }
                        }
                }
            }
        }
    }

    // MARK: - Missing

    private var missingSection: some View {
        Section("Missing") {
            let missingSources = filtered.sources.filter(\.isMissing)
            let missingSongs = filtered.individualSongs.filter(\.isMissing)
            let missingOther = filtered.missingItems

            if missingSources.isEmpty && missingSongs.isEmpty && missingOther.isEmpty && !isSearchActive {
                mutedEmptyRow("No missing items")
                    .accessibilityLabel("No missing items")
            } else {
                ForEach(missingSources) { source in
                    MissingSourceRow(source: source)
                        .tag(SourceLibrarySelection.source(source.id))
                        .accessibilityLabel("Missing \(source.kind == .mediaRoot ? "SD Card" : "Backup"): \(source.displayName)")
                        .accessibilityHint("Use context menu to relocate or forget")
                        .accessibilityIdentifier("missing-source-\(source.id)")
                        .contextMenu {
                            Button("Relocate...") { performRelocateSource(source) }
                            Divider()
                            Button("Forget", role: .destructive) {
                                store.forgetSource(id: source.id)
                            }
                        }
                }
                ForEach(missingSongs) { song in
                    MissingSongRow(song: song)
                        .tag(SourceLibrarySelection.individualSong(song.id))
                        .accessibilityLabel("Missing song: \(song.displayName)")
                        .accessibilityHint("Use context menu to relocate or forget")
                        .accessibilityIdentifier("missing-song-\(song.id)")
                        .contextMenu {
                            Button("Relocate...") { performRelocateSong(song) }
                            Divider()
                            Button("Forget", role: .destructive) {
                                store.forgetSong(id: song.id)
                            }
                        }
                }
                ForEach(missingOther) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Label(item.displayName, systemImage: "questionmark.folder")
                        if let detail = item.detail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(SourceLibrarySelection.missingItem(item.id))
                    .accessibilityLabel("Missing item: \(item.displayName)")
                    .accessibilityIdentifier("missing-item-\(item.id)")
                }
            }
        }
    }

    // MARK: - No Results

    private var noResultsSection: some View {
        Section {
            Label("No results for \"\(searchText)\"", systemImage: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityLabel("No results for search: \(searchText)")
        }
    }

    // MARK: - Helpers

    private func mutedEmptyRow(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
    }

    private func sourceIcon(for kind: SourceKind) -> String {
        switch kind {
        case .mediaRoot: return "externaldrive"
        case .backupRoot: return "archivebox"
        }
    }

    private func sourceSecondaryLabel(for source: SourceLibrarySource) -> String {
        let kindName: String
        switch source.kind {
        case .mediaRoot: kindName = "SD Card"
        case .backupRoot: kindName = "Backup"
        }
        var label = "\(kindName) · \(source.folderURL.path)"
        if let matchLabel = fingerprintMatchStateLabel(source.matchState) {
            label += " · \(matchLabel)"
        }
        return label
    }

    /// Returns `true` if the source should be visible given the current search filter.
    private func filteredSourceIsVisible(_ source: SourceLibrarySource) -> Bool {
        filtered.sources.contains { $0.id == source.id }
    }

    /// Returns songs to display under a source row, respecting the current search filter.
    private func filteredSongs(for source: SourceLibrarySource) -> [SourceLibrarySong] {
        guard isSearchActive else {
            return source.songs.filter { !$0.isMissing }
        }
        return filtered.sources.first(where: { $0.id == source.id })?.songs ?? []
    }

    // MARK: - Accessibility label helpers

    private func sourceAccessibilityLabel(_ source: SourceLibrarySource) -> String {
        let kindName = source.kind == .mediaRoot ? "SD Card" : "Backup"
        let songCount = source.songs.filter { !$0.isMissing }.count
        var label = "\(source.displayName), \(kindName), \(songCount) song\(songCount == 1 ? "" : "s")"
        if let matchLabel = fingerprintMatchStateLabel(source.matchState) {
            label += ", \(matchLabel)"
        }
        return label
    }

    private func sourceSongAccessibilityLabel(_ song: SourceLibrarySong) -> String {
        var label = song.displayName
        if case .loaded = song.loadState, let matchLabel = fingerprintMatchStateLabel(song.matchState) {
            label += ", \(matchLabel)"
        } else if case .loading = song.loadState {
            label += ", loading"
        } else if case .failed = song.loadState {
            label += ", load failed"
        }
        return label
    }

    private func individualSongAccessibilityLabel(_ song: SourceLibrarySong) -> String {
        sourceSongAccessibilityLabel(song)
    }

    private func performRelocateSource(_ source: SourceLibrarySource) {
        let panel = NSOpenPanel()
        panel.title = "Locate SD Card or Backup Root"
        panel.prompt = "Relocate"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await store.relocateSource(id: source.id, to: url) }
    }

    private func performRelocateSong(_ song: SourceLibrarySong) {
        let panel = NSOpenPanel()
        panel.title = "Locate Song Folder"
        panel.prompt = "Relocate"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await store.relocateSong(id: song.id, to: url) }
    }
}

// MARK: - Row Views

private struct SourceLibrarySongRow: View {
    let song: SourceLibrarySong

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(song.displayName, systemImage: "music.note")
            Text(secondaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var secondaryText: String {
        var base: String
        switch song.loadState {
        case .loading: base = "Loading..."
        case .loaded: base = song.folderURL.path
        case let .failed(message): base = "Failed: \(message)"
        }
        if case .loaded = song.loadState, let matchLabel = fingerprintMatchStateLabel(song.matchState) {
            base += " · \(matchLabel)"
        }
        return base
    }
}

private struct MissingSourceRow: View {
    let source: SourceLibrarySource

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(source.displayName, systemImage: missingIcon)
                .foregroundStyle(.secondary)
            Text("Missing · \(source.folderURL.lastPathComponent)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var missingIcon: String {
        switch source.kind {
        case .mediaRoot: return "externaldrive.badge.questionmark"
        case .backupRoot: return "archivebox"
        }
    }
}

private struct MissingSongRow: View {
    let song: SourceLibrarySong

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(song.displayName, systemImage: "questionmark.folder")
                .foregroundStyle(.secondary)
            Text("Missing · \(song.folderURL.lastPathComponent)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private func fingerprintMatchStateLabel(_ state: FingerprintMatchState?) -> String? {
    switch state {
    case .exact: return "Exact match"
    case .changedSinceLastSeen: return "Changed since last seen"
    case .ambiguous: return "Ambiguous"
    case .unknown, nil: return nil
    }
}

