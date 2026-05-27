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
            return MixerChannel(leadingTrackNumber: leadingTrackNumber, memberTracks: members)
        }
    }
}
