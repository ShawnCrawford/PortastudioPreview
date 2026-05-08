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

    @Test func panMapperNormalizedPositionUsesConfirmedAnchors() {
        #expect(PanMapper.normalizedPosition(for: 0x01) == -1.0)
        #expect(PanMapper.normalizedPosition(for: 0x40) == 0.0)
        #expect(PanMapper.normalizedPosition(for: 0x7F) == 1.0)
    }

    @Test func assignedTrackPlaybackUsesParsedPanBeforeAnyOverride() {
        let project = makeAssignedTrackProject(pan: 0x01)

        #expect(StereoPreviewEngine.playableRegionPans(for: project) == [-1.0])
    }

    @Test func userPanOverrideTakesPrecedenceForAssignedTrackPlayback() {
        let project = makeAssignedTrackProject(pan: 0x01)

        #expect(StereoPreviewEngine.playableRegionPans(for: project, trackPanOverrides: [1: 0.5]) == [0.5])
    }

    @Test func panOverridesClampToFullLeftCenterAndFullRight() {
        let project = makeAssignedTrackProject(pan: 0x40)

        #expect(StereoPreviewEngine.playableRegionPans(for: project, trackPanOverrides: [1: -2.0]) == [-1.0])
        #expect(StereoPreviewEngine.playableRegionPans(for: project, trackPanOverrides: [1: 0.0]) == [0.0])
        #expect(StereoPreviewEngine.playableRegionPans(for: project, trackPanOverrides: [1: 2.0]) == [1.0])
    }

    @Test func unassignedRegionPlaybackStaysCentered() {
        let project = makeProject(
            activeTakeCandidate: nil,
            regions: [timelineRegion(filename: "ZZ0000_1.wav")]
        )

        #expect(StereoPreviewEngine.playableRegionPans(for: project, trackPanOverrides: [1: -1.0]) == [0.0])
    }

    @Test func approximateVolumeUsesConfirmedSongLevelScale() {
        #expect(StereoPreviewEngine.approximateVolume(for: makeTrackPreview(mute: 0x00, pan: 0x40, level: 0x00)) == 0.0)
        #expect(abs(StereoPreviewEngine.approximateVolume(for: makeTrackPreview(mute: 0x00, pan: 0x40, level: 0x6A)) - 1.0) < 0.0001)
        #expect(abs(StereoPreviewEngine.approximateVolume(for: makeTrackPreview(mute: 0x00, pan: 0x40, level: 0x7F)) - 1.9952623) < 0.0001)
    }

    @Test func overrideVolumeUsesWorkspaceFaderPosition() {
        let track = makeTrackPreview(mute: 0x00, pan: 0x40, level: 0x6A)

        #expect(abs(StereoPreviewEngine.approximateVolume(for: track, overrideLevelPosition: 0) - 0.0) < 0.0001)
        #expect(abs(StereoPreviewEngine.approximateVolume(for: track, overrideLevelPosition: 1) - 1.9952623) < 0.0001)
    }

    @Test func timelineStartSamplesPreserveAbsoluteTrackOffsets() {
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

        let startSamples = StereoPreviewEngine.timelineStartSamples(for: [delayedTrack, laterTrack])

        #expect(startSamples[5] == 2_457_600)
        #expect(startSamples[6] == 2_911_520)
    }

    @Test func timelineStartSamplesKeepUntimedTracksAtZero() {
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

        let startSamples = StereoPreviewEngine.timelineStartSamples(for: [untimedTrack, timedTrack])

        #expect(startSamples[1] == 0)
        #expect(startSamples[2] == 820_800)
    }

    @Test func unassignedPlaybackKeepsOnlyTrack1ActiveVirtualTakeWhenKnown() {
        let project = makeProject(
            activeTakeCandidate: 0x01,
            regions: [
                timelineRegion(filename: "ZZ0000_1.wav"),
                timelineRegion(filename: "ZZ0003_1.wav"),
                timelineRegion(filename: "ZZ0003_2.wav")
            ]
        )

        #expect(StereoPreviewEngine.playableRegionSourceFilenames(for: project) == ["ZZ0000_1.wav", "ZZ0003_2.wav"])
    }

    @Test func unassignedPlaybackLeavesAmbiguousMultipleTakeGroupsUnfiltered() {
        let project = makeProject(
            activeTakeCandidate: 0x01,
            regions: [
                timelineRegion(filename: "ZZ0000_1.wav"),
                timelineRegion(filename: "ZZ0000_2.wav"),
                timelineRegion(filename: "ZZ0001_1.wav"),
                timelineRegion(filename: "ZZ0001_2.wav")
            ]
        )

        #expect(
            StereoPreviewEngine.playableRegionSourceFilenames(for: project) == [
                "ZZ0000_1.wav",
                "ZZ0000_2.wav",
                "ZZ0001_1.wav",
                "ZZ0001_2.wav"
            ]
        )
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

    private func makeProject(activeTakeCandidate: UInt8?, regions: [TimelineRegion]) -> PortastudioProject {
        PortastudioProject(
            folderURL: URL(fileURLWithPath: "/tmp/project"),
            validationIssues: [],
            wavInventory: [],
            unassignedAudioRegions: regions,
            tracks: [],
            edlTableSummary: activeTakeCandidate.map { activeTakeCandidate in
                EdlTableSummary(
                    track1ActiveTakeCandidate: activeTakeCandidate,
                    activeTakeCandidateOffset: EdlTableParser.track1ActiveTakeCandidateOffset,
                    evidenceLevel: .correlated,
                    fileListEntries: [],
                    timelineAnchors: [],
                    timelineCandidates: []
                )
            }
        )
    }

    private func makeAssignedTrackProject(pan: UInt8) -> PortastudioProject {
        PortastudioProject(
            folderURL: URL(fileURLWithPath: "/tmp/project"),
            validationIssues: [],
            wavInventory: [],
            unassignedAudioRegions: [],
            tracks: [
                TrackPreview(
                    trackNumber: 1,
                    candidateWAV: wavInventoryItem(),
                    mixerSetting: TrackMixerSetting(
                        trackNumber: 1,
                        level: setting(name: "Level", primaryOffset: 0x00C4, primaryByte: 0x6A),
                        pan: setting(name: "Pan", primaryOffset: 0x00C6, primaryByte: pan),
                        mute: setting(name: "Mute", primaryOffset: 0x0268, primaryByte: 0x00)
                    ),
                    track1ActiveTakeCandidate: nil,
                    timeline: trackTimeline(trackNumber: 1, startSample: 0)
                )
            ],
            edlTableSummary: nil
        )
    }

    private func timelineRegion(filename: String) -> TimelineRegion {
        TimelineRegion(
            startSample: 0,
            endSample: nil,
            lengthSample: nil,
            sourceFilename: filename,
            sourceURL: URL(fileURLWithPath: "/tmp/\(filename)"),
            evidenceLevel: .hypothesis
        )
    }
}
