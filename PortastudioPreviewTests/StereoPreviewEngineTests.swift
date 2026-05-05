//
//  StereoPreviewEngineTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct StereoPreviewEngineTests {
    @Test func track1MuteByteDisablesPlayableTrack() {
        let track = makeTrackPreview(mute: 0x01, pan: 0x40, level: 0x7F)

        #expect(StereoPreviewEngine.isMuted(track))
    }

    @Test func missingMuteByteDoesNotDisableOtherTracks() {
        let track = TrackPreview(
            trackNumber: 2,
            candidateWAV: wavInventoryItem(),
            mixerSetting: TrackMixerSetting(
                trackNumber: 2,
                level: setting(name: "Level", primaryOffset: 0x00D8, primaryByte: 0x7F),
                pan: setting(name: "Pan", primaryOffset: 0x00DA, primaryByte: 0x40),
                mute: nil
            ),
            track1ActiveTakeCandidate: nil
        )

        #expect(!StereoPreviewEngine.isMuted(track))
    }

    @Test func approximatePanMapsCenterAndEdges() {
        #expect(StereoPreviewEngine.approximatePan(for: makeTrackPreview(mute: 0x00, pan: 0x40, level: 0x7F)) == 0.0)
        #expect(StereoPreviewEngine.approximatePan(for: makeTrackPreview(mute: 0x00, pan: 0x00, level: 0x7F)) == -1.0)
        #expect(StereoPreviewEngine.approximatePan(for: makeTrackPreview(mute: 0x00, pan: 0x80, level: 0x7F)) == 1.0)
    }

    @Test func approximateVolumeTreatsRawZeroAsUnityUntilScaleIsKnown() {
        #expect(StereoPreviewEngine.approximateVolume(for: makeTrackPreview(mute: 0x00, pan: 0x40, level: 0x00)) == 1.0)
        #expect(StereoPreviewEngine.approximateVolume(for: makeTrackPreview(mute: 0x00, pan: 0x40, level: 0x7F)) == 1.0)
        #expect(StereoPreviewEngine.approximateVolume(for: makeTrackPreview(mute: 0x00, pan: 0x40, level: 0xFF)) == 1.5)
    }

    private func makeTrackPreview(mute: UInt8, pan: UInt8, level: UInt8) -> TrackPreview {
        TrackPreview(
            trackNumber: 1,
            candidateWAV: wavInventoryItem(),
            mixerSetting: TrackMixerSetting(
                trackNumber: 1,
                level: setting(name: "Level", primaryOffset: 0x00C4, primaryByte: level),
                pan: setting(name: "Pan", primaryOffset: 0x00C6, primaryByte: pan),
                mute: setting(name: "Mute", primaryOffset: 0x0268, primaryByte: mute)
            ),
            track1ActiveTakeCandidate: nil
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

    private func wavInventoryItem() -> WAVInventoryItem {
        WAVInventoryItem(
            url: URL(fileURLWithPath: "/tmp/ZZ0000_1.wav"),
            rawFilename: "ZZ0000_1.wav",
            byteCount: nil
        )
    }
}
