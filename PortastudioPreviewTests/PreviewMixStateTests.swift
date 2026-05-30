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

    @Test func initializesMuteStateFromParsedSongBytes() {
        let state = PreviewMixState(project: makeProject(panBytes: [0x40], muteBytes: [0x01]))

        #expect(state.isMuted(for: 1))
        #expect(state.trackMuteOverrides[1] == true)
    }

    @Test func setMutedUpdatesTrackMuteOverride() {
        let state = PreviewMixState(project: makeProject(panBytes: [0x40], muteBytes: [0x00]))

        state.setMuted(true, for: 1)

        #expect(state.isMuted(for: 1))
        #expect(state.trackMuteOverrides[1] == true)
    }

    @Test func stereoPairSharesSingleOverrideEntry() {
        let tracks = [
            makeTrack(trackNumber: 9, panByte: 0x40, muteByte: 0x00),
            makeTrack(trackNumber: 10, panByte: 0x40, muteByte: 0x00)
        ]
        let project = PortastudioProject(
            folderURL: URL(fileURLWithPath: "/tmp/SONG_mixstate_pair"),
            validationIssues: [],
            wavInventory: [],
            unassignedAudioRegions: [],
            tracks: tracks,
            edlTableSummary: nil
        )
        let state = PreviewMixState(project: project)

        state.setPanPosition(0.25, for: 9)
        #expect(state.panPosition(for: 10) == 0.25)
        #expect(state.trackPanOverrides[9] == 0.25)
        #expect(state.trackPanOverrides[10] == nil)

        state.setMuted(true, for: 10)
        #expect(state.isMuted(for: 9))
        #expect(state.trackMuteOverrides[9] == true)
        #expect(state.trackMuteOverrides[10] == nil)
    }

    private func makeProject(panBytes: [UInt8]) -> PortastudioProject {
        makeProject(panBytes: panBytes, muteBytes: Array(repeating: 0x00, count: panBytes.count))
    }

    private func makeProject(panBytes: [UInt8], muteBytes: [UInt8]) -> PortastudioProject {
        let tracks = panBytes.enumerated().map { index, panByte in
            makeTrack(
                trackNumber: index + 1,
                panByte: panByte,
                muteByte: muteBytes.indices.contains(index) ? muteBytes[index] : 0x00
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

    private func makeTrack(trackNumber: Int, panByte: UInt8, muteByte: UInt8) -> TrackPreview {
        let wav = WAVInventoryItem(
            url: URL(fileURLWithPath: "/tmp/SONG_mixstate/ZZ000\(trackNumber)_1.wav"),
            rawFilename: "ZZ000\(trackNumber)_1.wav",
            byteCount: 1_000
        )
        return TrackPreview(
            trackNumber: trackNumber,
            candidateWAV: wav,
            mixerSetting: TrackMixerSetting(
                trackNumber: trackNumber,
                level: setting(name: "Level", primaryOffset: 0x00C4, primaryByte: 0x6A),
                pan: setting(name: "Pan", primaryOffset: 0x00C6, primaryByte: panByte),
                mute: setting(
                    name: "Mute",
                    primaryOffset: 0x0268,
                    primaryByte: muteByte
                )
            ),
            track1ActiveTakeCandidate: nil,
            timeline: nil
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
