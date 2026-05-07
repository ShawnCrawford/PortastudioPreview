//
//  ContentView.swift
//  PortastudioPreview
//

import AppKit
import SwiftUI

struct ContentView: View {
    @State private var sourceLibraryStore = SourceLibraryStore()

    var body: some View {
        NavigationSplitView {
            SourceLibrarySidebarView(store: sourceLibraryStore)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let project = sourceLibraryStore.selectedProject {
                ProjectDetailView(project: project)
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
        .task(id: sourceLibraryStore.selection) {
            await sourceLibraryStore.loadIfSourceSong()
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
            await sourceLibraryStore.addSourceRoot(at: url)
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
            await sourceLibraryStore.openIndividualSongFolder(at: url)
        }
    }
}

#Preview {
    ContentView()
}
