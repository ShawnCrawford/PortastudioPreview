//
//  PortastudioProject.swift
//  PortastudioPreview
//

import Foundation

struct PortastudioProject: Sendable {
    let folderURL: URL
    let validationIssues: [ProjectValidationIssue]
    let wavInventory: [WAVInventoryItem]
    let unassignedAudioRegions: [TimelineRegion]
    let tracks: [TrackPreview]
    let edlTableSummary: EdlTableSummary?

    var folderName: String {
        folderURL.lastPathComponent
    }
}
