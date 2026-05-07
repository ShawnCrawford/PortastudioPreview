//
//  ContentView.swift
//  PortastudioPreview
//

import AppKit
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ContentViewBody(modelContext: modelContext)
    }
}

@MainActor
private struct ContentViewBody: View {
    @State private var store: SourceLibraryStore
    @State private var annotationStore: TrackAnnotationStore

    init(modelContext: ModelContext) {
        _store = State(wrappedValue: SourceLibraryStore(modelContext: modelContext))
        _annotationStore = State(wrappedValue: TrackAnnotationStore(modelContext: modelContext))
    }

    var body: some View {
        NavigationSplitView {
            SourceLibrarySidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let project = store.selectedProject {
                ProjectDetailView(project: project, annotationStore: annotationStore)
            } else if case .source(let sourceID) = store.selection,
                      let source = store.sources.first(where: { $0.id == sourceID }) {
                SourceSelectedView(source: source)
            } else {
                ProjectOpenView(openAction: openIndividualSongFolder, addSourceAction: addSourceRoot)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addSourceRoot) {
                    Label("Add SD Card or Backup...", systemImage: "externaldrive.badge.plus")
                }
                .help("Scan an SD card root or backup folder and browse all its songs")
                .accessibilityIdentifier("toolbar-add-source")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: openIndividualSongFolder) {
                    Label("Open Individual Song...", systemImage: "folder")
                }
                .help("Load a single DP-32SD song project folder")
                .accessibilityIdentifier("toolbar-open-song")
            }
        }
        .task {
            await store.hydrateFromPersistence()
        }
        .task(id: store.selection) {
            await store.loadIfSourceSong()
        }
        .task(id: store.selectedProject?.folderURL) {
            annotationStore.load(context: store.selectedSongAnnotationContext())
        }
        .focusedValue(\.openProjectAction, openIndividualSongFolder)
        .focusedValue(\.addSourceAction, addSourceRoot)
    }

    private func addSourceRoot() {
        let panel = NSOpenPanel()
        panel.title = "Add SD Card or Backup Root"
        panel.prompt = "Add"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        Task {
            await store.addSourceRoot(at: url)
        }
    }

    private func openIndividualSongFolder() {
        let panel = NSOpenPanel()
        panel.title = "Open DP-32SD Song Folder"
        panel.prompt = "Open"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        Task {
            await store.openIndividualSongFolder(at: url)
        }
    }
}

#Preview {
    ContentView()
}

// MARK: - Source Selected View

/// Detail shown when a source root is selected but no song has been loaded yet.
struct SourceSelectedView: View {
    let source: SourceLibrarySource

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: sourceIcon)
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text(source.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(kindLabel)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Path").foregroundStyle(.secondary)
                    Text(source.folderURL.path)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                GridRow {
                    Text("Songs").foregroundStyle(.secondary)
                    Text("\(availableSongCount)")
                }
                if let matchLabel = matchStateLabel {
                    GridRow {
                        Text("Identity").foregroundStyle(.secondary)
                        Text(matchLabel)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: 400)

            Text("Select a song in the sidebar to load it.")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle(source.displayName)
        .accessibilityLabel("Source: \(source.displayName), \(kindLabel), \(availableSongCount) songs")
    }

    private var sourceIcon: String {
        switch source.kind {
        case .mediaRoot: return "externaldrive"
        case .backupRoot: return "archivebox"
        }
    }

    private var kindLabel: String {
        source.kind == .mediaRoot ? "SD Card" : "Backup"
    }

    private var availableSongCount: Int {
        source.songs.filter { !$0.isMissing }.count
    }

    private var matchStateLabel: String? {
        switch source.matchState {
        case .exact: return "Exact match"
        case .changedSinceLastSeen: return "Changed since last seen"
        case .ambiguous: return "Ambiguous"
        case .unknown, nil: return nil
        }
    }
}
