//
//  PortastudioProject.swift
//  PortastudioPreview
//

import Foundation

struct PortastudioProject {
    let folderURL: URL
    let validationIssues: [ProjectValidationIssue]
    let wavInventory: [WAVInventoryItem]
    let tracks: [TrackPreview]
    let edlTableSummary: EdlTableSummary?

    var folderName: String {
        folderURL.lastPathComponent
    }
}
