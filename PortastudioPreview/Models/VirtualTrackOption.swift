//
//  VirtualTrackOption.swift
//  PortastudioPreview
//

import Foundation

struct VirtualTrackOption: Identifiable, Hashable, Sendable {
    typealias ID = String

    let id: ID
    let takeNumber: Int
    let takeLabel: String
    let wavItem: WAVInventoryItem
    let timelineRegion: TimelineRegion
    let evidenceLevel: EvidenceLevel
}
