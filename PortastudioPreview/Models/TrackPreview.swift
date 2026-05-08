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

    /// UI-facing activity signal.
    ///
    /// A track is considered active when the preview pipeline found an inferred WAV/timeline
    /// assignment for it, or when Track 1 exposes a non-zero active-take selector byte.
    /// The latter keeps virtual-take songs from collapsing to an empty track surface.
    var isActiveTrackCandidate: Bool {
        candidateWAV != nil || timeline != nil || (track1ActiveTakeCandidate ?? 0) > 0
    }
}
