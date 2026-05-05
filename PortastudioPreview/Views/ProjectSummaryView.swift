//
//  ProjectSummaryView.swift
//  PortastudioPreview
//

import SwiftUI

struct ProjectSummaryView: View {
    let project: PortastudioProject?
    let isLoading: Bool
    let loadError: String?

    var body: some View {
        List {
            Section("Project") {
                if let project {
                    Label(project.folderName, systemImage: "folder")
                    Label("\(project.wavInventory.count) WAV files", systemImage: "waveform")
                    Label("\(project.validationIssues.count) validation issues", systemImage: "exclamationmark.triangle")
                } else if isLoading {
                    Label("Loading...", systemImage: "hourglass")
                } else {
                    Label("No folder open", systemImage: "folder")
                }
            }

            if let loadError {
                Section("Load Error") {
                    Text(loadError)
                        .foregroundStyle(.red)
                }
            }
        }
        .listStyle(.sidebar)
    }
}
