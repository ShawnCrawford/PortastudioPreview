//
//  SourceLibrarySidebarView.swift
//  PortastudioPreview
//

import SwiftUI

struct SourceLibrarySidebarView: View {
    @Bindable var store: SourceLibraryStore

    var body: some View {
        List(selection: $store.selection) {
            Section("SD Cards & Backups") {
                if store.sources.isEmpty {
                    mutedEmptyRow("No sources added")
                } else {
                    ForEach($store.sources) { $source in
                        DisclosureGroup(isExpanded: $source.isExpanded) {
                            if source.songs.isEmpty {
                                mutedEmptyRow("No songs found")
                            } else {
                                ForEach(source.songs) { song in
                                    SourceLibrarySongRow(song: song)
                                        .tag(SourceLibrarySelection.individualSong(song.id))
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
                    }
                }
            }

            Section("Individual Songs") {
                if store.individualSongs.isEmpty {
                    mutedEmptyRow("No songs opened")
                } else {
                    ForEach(store.individualSongs) { song in
                        SourceLibrarySongRow(song: song)
                            .tag(SourceLibrarySelection.individualSong(song.id))
                    }
                }
            }

            Section("Missing") {
                if store.missingItems.isEmpty {
                    mutedEmptyRow("No missing items")
                } else {
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

    private func mutedEmptyRow(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
    }

    private func sourceIcon(for kind: SourceKind) -> String {
        switch kind {
        case .mediaRoot:
            return "externaldrive"
        case .backupRoot:
            return "archivebox"
        }
    }

    private func sourceSecondaryLabel(for source: SourceLibrarySource) -> String {
        let kindName: String
        switch source.kind {
        case .mediaRoot:
            kindName = "SD Card"
        case .backupRoot:
            kindName = "Backup"
        }
        return "\(kindName) · \(source.folderURL.path)"
    }
}

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
        case .loading:
            return "Loading..."
        case .loaded:
            return song.folderURL.path
        case let .failed(message):
            return "Failed: \(message)"
        }
    }
}
