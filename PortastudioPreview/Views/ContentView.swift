//
//  ContentView.swift
//  PortastudioPreview
//

import AppKit
import SwiftUI

struct ContentView: View {
    @State private var project: PortastudioProject?
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        NavigationSplitView {
            ProjectSummaryView(project: project, isLoading: isLoading, loadError: loadError)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            if let project {
                ProjectDetailView(project: project)
            } else {
                ProjectOpenView(openAction: openProjectFolder)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: openProjectFolder) {
                    Label("Open Project Folder", systemImage: "folder")
                }
            }
        }
        .focusedValue(\.openProjectAction, openProjectFolder)
    }

    private func openProjectFolder() {
        let panel = NSOpenPanel()
        panel.title = "Open DP-32SD Project Folder"
        panel.prompt = "Open"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        loadProject(at: url)
    }

    private func loadProject(at url: URL) {
        isLoading = true
        loadError = nil

        Task {
            do {
                let loadedProject = try await ProjectFolderLoader().loadProject(at: url)
                project = loadedProject
                isLoading = false
            } catch {
                project = nil
                loadError = error.localizedDescription
                isLoading = false
            }
        }
    }
}

#Preview {
    ContentView()
}
