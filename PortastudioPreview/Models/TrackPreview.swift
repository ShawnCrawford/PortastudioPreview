//
//  TrackPreview.swift
//  PortastudioPreview
//

import Foundation

struct TrackPreview: Identifiable, Hashable, Sendable {
    let trackNumber: Int
    let candidateWAV: WAVInventoryItem?
    let mixerSetting: TrackMixerSetting?
    let track1ActiveTakeCandidate: UInt8?
    let timeline: TrackTimeline?

    var id: Int { trackNumber }

    var candidateWAVEvidence: EvidenceLevel {
        candidateWAV == nil ? .observed : .hypothesis
    }
}
