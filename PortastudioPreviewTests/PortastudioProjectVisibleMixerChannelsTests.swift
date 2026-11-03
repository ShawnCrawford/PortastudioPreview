//
//  PortastudioProjectVisibleMixerChannelsTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct PortastudioProjectVisibleMixerChannelsTests {
    @Test func emptyProjectHasNoVisibleMixerChannels() {
        let project = makeProject(tracks: [])
        #expect(project.visibleMixerChannels.isEmpty)
    }

    @Test func visibleMixerChannelsKeepRowsWithoutResolvedAudio() {
        let project = makeProject(
            tracks: [
                makeTrack(trackNumber: 1, assigned: true),
                makeTrack(trackNumber: 2, assigned: false),
                makeTrack(trackNumber: 3, assigned: false, includeVirtualTakeOption: true)
            ]
        )

        #expect(project.visibleMixerChannels.map(\.id) == [1, 2, 3])
        #expect(project.visibleMixerChannels[0].memberTrackNumbers == [1])
        #expect(project.visibleMixerChannels[1].memberTrackNumbers == [2])
        #expect(project.visibleMixerChannels[2].memberTrackNumbers == [3])
    }

    @Test func stereoPairKeepsBothPhysicalTracksVisibleWithoutAssignment() {
        let project = makeProject(
            tracks: [
                makeTrack(trackNumber: 9, assigned: false),
                makeTrack(trackNumber: 10, assigned: true)
            ]
        )

        #expect(project.visibleMixerChannels.count == 1)
        #expect(project.visibleMixerChannels[0].id == 9)
        #expect(project.visibleMixerChannels[0].trackNumberLabel == "9/10")
        #expect(project.visibleMixerChannels[0].memberTrackNumbers == [9, 10])
    }

    private func makeProject(tracks: [TrackPreview]) -> PortastudioProject {
        PortastudioProject(
            folderURL: URL(fileURLWithPath: "/tmp/SONG_0001"),
            validationIssues: [],
            wavInventory: [],
            unassignedAudioRegions: [],
            tracks: tracks,
            edlTableSummary: nil
        )
    }

    private func makeTrack(
        trackNumber: Int,
        assigned: Bool,
        includeVirtualTakeOption: Bool = false
    ) -> TrackPreview {
        let wav = WAVInventoryItem(
            url: URL(fileURLWithPath: "/tmp/SONG_0001/ZZ000\(trackNumber)_1.wav"),
            rawFilename: "ZZ000\(trackNumber)_1.wav",
            byteCount: 1_000
        )
        let region = TimelineRegion(
            startSample: 0,
            endSample: 44_100,
            lengthSample: 44_100,
            sourceFilename: wav.rawFilename,
            sourceURL: wav.url,
            evidenceLevel: .hypothesis
        )
        let virtualOption = VirtualTrackOption(
            id: "t\(trackNumber)-vt1",
            takeNumber: 1,
            takeLabel: "VT1",
            wavItem: wav,
            timelineRegion: region,
            evidenceLevel: .correlated
        )

        return TrackPreview(
            trackNumber: trackNumber,
            candidateWAV: assigned ? wav : nil,
            mixerSetting: nil,
            track1ActiveTakeCandidate: nil,
            timeline: nil,
            virtualTrackOptions: includeVirtualTakeOption ? [virtualOption] : [],
            defaultVirtualTrackOptionID: includeVirtualTakeOption ? virtualOption.id : nil
        )
    }
}
