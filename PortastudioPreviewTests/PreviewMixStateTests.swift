//
//  PreviewMixStateTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

@MainActor
struct PreviewMixStateTests {
    @Test func initializesPanFromParsedSongBytes() {
        let project = makeProject(panBytes: [0x01, 0x40, 0x7F])
        let state = PreviewMixState(project: project)

        #expect(state.panPosition(for: 1) == -1.0)
        #expect(state.panPosition(for: 2) == 0.0)
        #expect(state.panPosition(for: 3) == 1.0)
    }

    @Test func setPanPositionClampsToSupportedRange() {
        let state = PreviewMixState(project: makeProject(panBytes: [0x40]))

        state.setPanPosition(-2.0, for: 1)
        #expect(state.panPosition(for: 1) == -1.0)

        state.setPanPosition(0.0, for: 1)
        #expect(state.panPosition(for: 1) == 0.0)

        state.setPanPosition(2.0, for: 1)
        #expect(state.panPosition(for: 1) == 1.0)
    }

    @Test func creatingStateForNewSongResetsPreviewPanOverrides() {
        let firstSong = makeProject(panBytes: [0x40])
        let secondSong = makeProject(panBytes: [0x01])

        let firstState = PreviewMixState(project: firstSong)
        firstState.setPanPosition(0.8, for: 1)
        #expect(firstState.trackPanOverrides[1] == 0.8)

        let secondState = PreviewMixState(project: secondSong)
        #expect(secondState.panPosition(for: 1) == -1.0)
        #expect(secondState.trackPanOverrides[1] == -1.0)
    }

    private func makeProject(panBytes: [UInt8]) -> PortastudioProject {
        let tracks = panBytes.enumerated().map { index, panByte in
            TrackPreview(
                trackNumber: index + 1,
                candidateWAV: nil,
                mixerSetting: TrackMixerSetting(
                    trackNumber: index + 1,
                    level: setting(name: "Level", primaryOffset: 0x00C4, primaryByte: 0x6A),
                    pan: setting(name: "Pan", primaryOffset: 0x00C6, primaryByte: panByte),
                    mute: setting(name: "Mute", primaryOffset: 0x0268, primaryByte: 0x00)
                ),
                track1ActiveTakeCandidate: nil,
                timeline: nil
            )
        }

        return PortastudioProject(
            folderURL: URL(fileURLWithPath: "/tmp/SONG_mixstate"),
            validationIssues: [],
            wavInventory: [],
            unassignedAudioRegions: [],
            tracks: tracks,
            edlTableSummary: nil
        )
    }

    private func setting(name: String, primaryOffset: Int, primaryByte: UInt8) -> MixerSetting {
        MixerSetting(
            name: name,
            primaryOffset: primaryOffset,
            primaryByte: primaryByte,
            mirrorOffset: nil,
            mirrorByte: nil,
            evidenceLevel: .correlated
        )
    }
}
