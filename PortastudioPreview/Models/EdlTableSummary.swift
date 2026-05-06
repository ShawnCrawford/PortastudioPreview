//
//  EdlTableSummary.swift
//  PortastudioPreview
//

import Foundation

struct EdlTableSummary: Equatable {
    let track1ActiveTakeCandidate: UInt8
    let activeTakeCandidateOffset: Int
    let evidenceLevel: EvidenceLevel
    let fileListEntries: [EdlFileListEntry]
    let timelineAnchors: [Int]
}
