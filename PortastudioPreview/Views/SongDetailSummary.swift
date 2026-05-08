//
//  SongDetailSummary.swift
//  PortastudioPreview
//

import Foundation

/// A pure read-only summary derived from a `PortastudioProject` for use by the Overview section
/// of `ProjectDetailView`. Keeps display logic out of the view body.
struct SongDetailSummary {
    let folderName: String
    let folderPath: String

    let trackCount: Int
    let assignedTrackCount: Int
    let wavCount: Int

    let validationIssueCount: Int
    let hasErrors: Bool

    let unassignedRegionCount: Int

    let edlFileListCount: Int
    let timelineCandidateCount: Int

    let previewAvailable: Bool

    init(project: PortastudioProject) {
        folderName = project.folderName
        folderPath = project.folderURL.path

        trackCount = project.visibleMixerChannels.count
        assignedTrackCount = project.visibleMixerChannels.filter { $0.controlTrack?.candidateWAV != nil }.count
        wavCount = project.wavInventory.count

        validationIssueCount = project.validationIssues.count
        hasErrors = project.validationIssues.contains { $0.severity == .error }

        unassignedRegionCount = project.unassignedAudioRegions.count

        edlFileListCount = project.edlTableSummary?.fileListEntries.count ?? 0
        timelineCandidateCount = project.edlTableSummary?.timelineCandidates.count ?? 0

        previewAvailable = StereoPreviewEngine.hasPlayableTracks(project)
    }
}
