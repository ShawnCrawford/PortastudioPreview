//
//  SourceLibrarySidebarView.swift
//  PortastudioPreview
//

import AppKit
import SwiftUI

struct SourceLibrarySidebarView: View {
    @Bindable var store: SourceLibraryStore

    var body: some View {
        List(selection: $store.selection) {
            sourcesSection
            individualSongsSection
            missingSection

            if let error = store.loadError {
                Section("Load Error") {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - SD Cards & Backups

    private var sourcesSection: some View {
        Section("SD Cards & Backups") {
            let available = store.sources.filter { !$0.isMissing }
            if available.isEmpty {
                mutedEmptyRow("No sources added")
            } else {
                ForEach($store.sources) { $source in
                    if !source.isMissing {
                        DisclosureGroup(isExpanded: $source.isExpanded) {
                            if source.songs.isEmpty {
                                mutedEmptyRow("No songs found")
                            } else {
                                ForEach(source.songs.filter { !$0.isMissing }) { song in
                                    SourceLibrarySongRow(song: song)
                                        .tag(SourceLibrarySelection.individualSong(song.id))
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
            let available = store.individualSongs.filter { !$0.isMissing }
            if available.isEmpty {
                mutedEmptyRow("No songs opened")
            } else {
                ForEach(available) { song in
                    SourceLibrarySongRow(song: song)
                        .tag(SourceLibrarySelection.individualSong(song.id))
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
            let missingSources = store.sources.filter(\.isMissing)
            let missingSongs = store.individualSongs.filter(\.isMissing)

            if missingSources.isEmpty && missingSongs.isEmpty && store.missingItems.isEmpty {
                mutedEmptyRow("No missing items")
            } else {
                ForEach(missingSources) { source in
                    MissingSourceRow(source: source)
                        .tag(SourceLibrarySelection.source(source.id))
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
                        .contextMenu {
                            Button("Relocate...") { performRelocateSong(song) }
                            Divider()
                            Button("Forget", role: .destructive) {
                                store.forgetSong(id: song.id)
                            }
                        }
                }
                ForEach(store.missingItems) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Label(item.displayName, systemImage: "questionmark.folder")
                        if let detail = item.detail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(SourceLibrarySelection.missingItem(item.id))
                }
            }
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
        return "\(kindName) · \(source.folderURL.path)"
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
        switch song.loadState {
        case .loading: return "Loading..."
        case .loaded: return song.folderURL.path
        case let .failed(message): return "Failed: \(message)"
        }
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

