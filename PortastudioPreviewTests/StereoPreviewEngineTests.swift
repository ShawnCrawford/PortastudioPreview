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
            track1ActiveTakeCandidate: nil,
            timeline: nil
        )

        #expect(!StereoPreviewEngine.isMuted(track))
    }

    @Test func approximatePanMapsCenterAndEdges() {
        #expect(StereoPreviewEngine.approximatePan(for: makeTrackPreview(mute: 0x00, pan: 0x40, level: 0x7F)) == 0.0)
        #expect(StereoPreviewEngine.approximatePan(for: makeTrackPreview(mute: 0x00, pan: 0x01, level: 0x7F)) == -1.0)
        #expect(StereoPreviewEngine.approximatePan(for: makeTrackPreview(mute: 0x00, pan: 0x7F, level: 0x7F)) == 1.0)
    }

    @Test func approximateVolumeTreatsRawZeroAsUnityUntilScaleIsKnown() {
        #expect(StereoPreviewEngine.approximateVolume(for: makeTrackPreview(mute: 0x00, pan: 0x40, level: 0x00)) == 1.0)
        #expect(StereoPreviewEngine.approximateVolume(for: makeTrackPreview(mute: 0x00, pan: 0x40, level: 0x7F)) == 1.0)
        #expect(StereoPreviewEngine.approximateVolume(for: makeTrackPreview(mute: 0x00, pan: 0x40, level: 0xFF)) == 1.5)
    }

    @Test func normalizedStartSamplesShiftsEarliestTrackToZero() {
        let delayedTrack = TrackPreview(
            trackNumber: 5,
            candidateWAV: wavInventoryItem(),
            mixerSetting: nil,
            track1ActiveTakeCandidate: nil,
            timeline: trackTimeline(trackNumber: 5, startSample: 2_457_600)
        )

        let laterTrack = TrackPreview(
            trackNumber: 6,
            candidateWAV: wavInventoryItem(),
            mixerSetting: nil,
            track1ActiveTakeCandidate: nil,
            timeline: trackTimeline(trackNumber: 6, startSample: 2_911_520)
        )

        let normalized = StereoPreviewEngine.normalizedStartSamples(for: [delayedTrack, laterTrack])

        #expect(normalized[5] == 0)
        #expect(normalized[6] == 453_920)
    }

    @Test func normalizedStartSamplesKeepsUntimedTracksAtZero() {
        let untimedTrack = TrackPreview(
            trackNumber: 1,
            candidateWAV: wavInventoryItem(),
            mixerSetting: nil,
            track1ActiveTakeCandidate: nil,
            timeline: nil
        )

        let timedTrack = TrackPreview(
            trackNumber: 2,
            candidateWAV: wavInventoryItem(),
            mixerSetting: nil,
            track1ActiveTakeCandidate: nil,
            timeline: trackTimeline(trackNumber: 2, startSample: 820_800)
        )

        let normalized = StereoPreviewEngine.normalizedStartSamples(for: [untimedTrack, timedTrack])

        #expect(normalized[1] == 0)
        #expect(normalized[2] == 820_800)
    }

    @Test func completionCoordinatorFiresOnceAfterAllTracksComplete() {
        let coordinator = PlaybackCompletionCoordinator()
        let playbackID = UUID()
        var completionCount = 0

        coordinator.configure(playbackID: playbackID, expectedCompletions: 2) {
            completionCount += 1
        }

        let first = coordinator.markCompletion(for: playbackID)
        let second = coordinator.markCompletion(for: playbackID)
        let third = coordinator.markCompletion(for: playbackID)

        first?()
        second?()
        third?()

        #expect(completionCount == 1)
    }

    @Test func completionCoordinatorIgnoresCallbacksAfterStopInvalidation() {
        let coordinator = PlaybackCompletionCoordinator()
        let playbackID = UUID()
        var completionCount = 0

        coordinator.configure(playbackID: playbackID, expectedCompletions: 1) {
            completionCount += 1
        }
        coordinator.invalidate(playbackID: playbackID)

        let completion = coordinator.markCompletion(for: playbackID)
        completion?()

        #expect(completionCount == 0)
    }

    @Test func completionCoordinatorIgnoresStalePlaybackCallbacks() {
        let coordinator = PlaybackCompletionCoordinator()
        let stalePlaybackID = UUID()
        let activePlaybackID = UUID()
        var completionCount = 0

        coordinator.configure(playbackID: stalePlaybackID, expectedCompletions: 1) {
            completionCount += 1
        }
        coordinator.configure(playbackID: activePlaybackID, expectedCompletions: 1) {
            completionCount += 1
        }

        let stale = coordinator.markCompletion(for: stalePlaybackID)
        let active = coordinator.markCompletion(for: activePlaybackID)

        stale?()
        active?()

        #expect(completionCount == 1)
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

    private func wavInventoryItem() -> WAVInventoryItem {
        WAVInventoryItem(
            url: URL(fileURLWithPath: "/tmp/ZZ0000_1.wav"),
            rawFilename: "ZZ0000_1.wav",
            byteCount: nil
        )
    }

    private func trackTimeline(trackNumber: Int, startSample: Int) -> TrackTimeline {
        TrackTimeline(
            trackNumber: trackNumber,
            regions: [
                TimelineRegion(
                    startSample: startSample,
                    endSample: nil,
                    lengthSample: nil,
                    sourceFilename: "ZZ0000_1.wav",
                    sourceURL: URL(fileURLWithPath: "/tmp/ZZ0000_1.wav"),
                    evidenceLevel: .hypothesis
                )
            ],
            evidenceLevel: .hypothesis
        )
    }
}
