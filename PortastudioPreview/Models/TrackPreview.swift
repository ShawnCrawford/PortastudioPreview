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
    let virtualTrackOptions: [VirtualTrackOption]
    let defaultVirtualTrackOptionID: VirtualTrackOption.ID?
    let assignmentEvidence: EvidenceLevel

    init(
        trackNumber: Int,
        candidateWAV: WAVInventoryItem?,
        mixerSetting: TrackMixerSetting?,
        track1ActiveTakeCandidate: UInt8?,
        timeline: TrackTimeline?,
        virtualTrackOptions: [VirtualTrackOption] = [],
        defaultVirtualTrackOptionID: VirtualTrackOption.ID? = nil,
        assignmentEvidence: EvidenceLevel = .correlated
    ) {
        self.trackNumber = trackNumber
        self.candidateWAV = candidateWAV
        self.mixerSetting = mixerSetting
        self.track1ActiveTakeCandidate = track1ActiveTakeCandidate
        self.timeline = timeline
        self.virtualTrackOptions = virtualTrackOptions
        self.defaultVirtualTrackOptionID = defaultVirtualTrackOptionID
        self.assignmentEvidence = assignmentEvidence
    }

    var id: Int { trackNumber }

    var candidateWAVEvidence: EvidenceLevel {
        candidateWAV == nil ? .observed : assignmentEvidence
    }

    var showsVirtualTrackPicker: Bool {
        virtualTrackOptions.count > 1
    }

    var defaultVirtualTrackOption: VirtualTrackOption? {
        if let defaultVirtualTrackOptionID,
           let option = virtualTrackOptions.first(where: { $0.id == defaultVirtualTrackOptionID }) {
            return option
        }
        return virtualTrackOptions.first
    }

    func selectedVirtualTrackOption(selectedOptionID: VirtualTrackOption.ID?) -> VirtualTrackOption? {
        if let selectedOptionID,
           let selected = virtualTrackOptions.first(where: { $0.id == selectedOptionID }) {
            return selected
        }
        return defaultVirtualTrackOption
    }

    /// UI-facing activity signal.
    ///
    /// A track is considered active when the preview pipeline found an inferred WAV/timeline
    /// assignment for it. Selector bytes alone do not establish a physical track assignment.
    var isActiveTrackCandidate: Bool {
        candidateWAV != nil || timeline != nil || !virtualTrackOptions.isEmpty
    }
}
