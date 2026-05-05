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

            PreviewTransportView(project: project)
        }
        .navigationTitle(project.folderName)
    }
}
