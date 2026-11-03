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
    #if DEBUG
    private let uiTestMixerWorkspaceEnabled = ProcessInfo.processInfo.arguments.contains("--ui-test-mixer-workspace")
    #endif

    init(modelContext: ModelContext) {
        _store = State(wrappedValue: SourceLibraryStore(modelContext: modelContext))
        _annotationStore = State(wrappedValue: TrackAnnotationStore(modelContext: modelContext))
    }

    var body: some View {
        #if DEBUG
        if uiTestMixerWorkspaceEnabled {
            UITestMixerWorkspaceHostView()
                .accessibilityIdentifier("ui-test-mixer-workspace")
        } else {
            mainContent
        }
        #else
        mainContent
        #endif
    }

    private var mainContent: some View {
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
                    Label("Add Audio Source...", systemImage: "externaldrive.badge.plus")
                }
                .help("Browse songs from an SD card or backup folder")
                .accessibilityIdentifier("toolbar-add-source")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: openIndividualSongFolder) {
                    Label("Open Individual Song...", systemImage: "folder")
                }
                .help("Open one song folder")
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
        panel.title = "Add Audio Source"
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
        panel.title = "Open Song Folder"
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

#if DEBUG
@MainActor
private struct UITestMixerWorkspaceHostView: View {
    @State private var selectedTrackID: TrackPreview.ID?
    @State private var selectedRegionID: TimelineRegion.ID?
    @State private var selectedVirtualTrackIDs: [Int: VirtualTrackOption.ID] = [:]
    @State private var fixture = PreviewFixtures.mixerWorkspace()

    var body: some View {
        ProjectWorkspaceView(
            project: fixture.project,
            annotationStore: fixture.annotationStore,
            selectedTrackID: $selectedTrackID,
            selectedRegionID: $selectedRegionID,
            playbackController: fixture.playbackController,
            mixState: fixture.mixState,
            selectedVirtualTrackIDs: $selectedVirtualTrackIDs,
            canSelectPreviousChannel: false,
            canSelectNextChannel: !fixture.project.visibleMixerChannels.isEmpty,
            selectPreviousChannelAction: {},
            selectNextChannelAction: {},
            playAction: {},
            stopAction: {},
            resetAllAction: {},
            reloadPlaybackPreservingPositionAction: {}
        )
        .task {
            selectedVirtualTrackIDs = fixture.selectedVirtualTrackIDs
        }
    }
}
#endif

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

}
