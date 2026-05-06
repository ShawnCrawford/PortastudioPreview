//
//  ProjectDetailView.swift
//  PortastudioPreview
//

import SwiftUI

struct ProjectDetailView: View {
    let project: PortastudioProject

    var body: some View {
        VStack(spacing: 0) {
            ValidationIssuesView(issues: project.validationIssues)

            Divider()

            TrackTableView(tracks: project.tracks)

            Divider()

            UnassignedAudioRegionsView(regions: project.unassignedAudioRegions)

            Divider()

            PreviewTransportView(project: project)
        }
        .navigationTitle(project.folderName)
    }
}

private struct UnassignedAudioRegionsView: View {
    let regions: [TimelineRegion]

    var body: some View {
        Table(regions) {
            TableColumn("Unassigned WAV") { region in
                Text(region.sourceFilename ?? "Unknown")
            }
            .width(min: 150, ideal: 220)

            TableColumn("Start") { region in
                Text("\(region.startSample)")
                    .font(.system(.caption, design: .monospaced))
            }
            .width(96)

            TableColumn("Length") { region in
                Text(region.resolvedLengthSample.map(String.init) ?? "n/a")
                    .foregroundStyle(region.resolvedLengthSample == nil ? .secondary : .primary)
                    .font(.system(.caption, design: .monospaced))
            }
            .width(96)

            TableColumn("Evidence") { region in
                Text(region.evidenceLevel.rawValue)
            }
            .width(100)
        }
        .frame(minHeight: 96, idealHeight: 140)
    }
}
