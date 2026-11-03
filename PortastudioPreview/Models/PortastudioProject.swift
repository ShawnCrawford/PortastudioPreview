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

    /// Automatic playback stays disabled until each file's physical track, active take,
    /// and saved region start can be resolved without borrowing Track 1's selector.
    var playbackLimitation: String? {
        guard wavInventory.count == 1,
              edlTableSummary?.fileListEntries.count == 1,
              unassignedAudioRegions.isEmpty,
              tracks.filter({ $0.candidateWAV != nil }).count == 1 else {
            return "Playback withheld: active takes and track assignment are unresolved."
        }

        guard let track = tracks.first(where: {
                  $0.timeline?.regions.first?.startSample != nil
                      && $0.timeline?.regions.first?.evidenceLevel == .confirmed
              }),
              track.assignmentEvidence == .confirmed,
              track.timeline?.evidenceLevel == .confirmed,
              track.virtualTrackOptions.first?.evidenceLevel == .confirmed,
              let mute = track.mixerSetting?.mute,
              mute.evidenceLevel == .confirmed,
              !mute.hasMirrorMismatch else {
            return "Playback withheld: track, take, timing, or mute evidence is unresolved."
        }

        return nil
    }

    var visibleTracks: [TrackPreview] {
        tracks.filter(\.isActiveTrackCandidate)
    }

    var visibleMixerChannels: [MixerChannel] {
        let tracksByNumber = Dictionary(uniqueKeysWithValues: tracks.map { ($0.trackNumber, $0) })

        return MixerChannelLayout.allLeadingTrackNumbers.compactMap { leadingTrackNumber in
            let members = MixerChannelLayout.memberTrackNumbers(forLeadingTrackNumber: leadingTrackNumber)
                .compactMap { tracksByNumber[$0] }
            guard !members.isEmpty else {
                return nil
            }
            return MixerChannel(
                leadingTrackNumber: leadingTrackNumber,
                memberTracks: members,
                hasUnassignedAudio: !unassignedAudioRegions.isEmpty
            )
        }
    }
}
