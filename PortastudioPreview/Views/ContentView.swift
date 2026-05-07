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
            } else {
                ProjectOpenView(openAction: openIndividualSongFolder, addSourceAction: addSourceRoot)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addSourceRoot) {
                    Label("Add SD Card or Backup...", systemImage: "externaldrive.badge.plus")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: openIndividualSongFolder) {
                    Label("Open Individual Song...", systemImage: "folder")
                }
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
