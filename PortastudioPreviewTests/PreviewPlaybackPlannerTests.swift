//
//  PreviewPlaybackPlannerTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct PreviewPlaybackPlannerTests {

    // MARK: - Edge cases: missing data

    @Test func emptyUnassignedRegionsProducesEmptyPlan() {
        let project = makeProject(regions: [], tracks: [])
        let plan = PreviewPlaybackPlanner.plan(for: project)

        #expect(plan.playableFilenames.isEmpty)
        #expect(plan.suppressedFilenames.isEmpty)
        #expect(!plan.hasPlayableTracks)
    }

    @Test func missingEdlSummaryPlaysAllRegions() {
        // No edltable.sys → no active-take filtering and no mute info.
        let project = makeProject(
            regions: [region("ZZ0000_1.wav"), region("ZZ0001_1.wav")],
            tracks: [],
            edlSummary: nil
        )
        let plan = PreviewPlaybackPlanner.plan(for: project)

        #expect(plan.playableFilenames == ["ZZ0000_1.wav", "ZZ0001_1.wav"])
        #expect(plan.suppressedFilenames.isEmpty)
    }

    @Test func missingMixerSettingsPlaysAllRegions() {
        // song.sys missing → tracks have no mixerSetting → no mute suppression.
        let project = makeProject(
            regions: [region("ZZ0000_1.wav"), region("ZZ0001_1.wav")],
            tracks: [trackWithNoMixer(trackNumber: 1), trackWithNoMixer(trackNumber: 2)]
        )
        let plan = PreviewPlaybackPlanner.plan(for: project)

        #expect(plan.playableFilenames == ["ZZ0000_1.wav", "ZZ0001_1.wav"])
        #expect(plan.suppressedFilenames.isEmpty)
    }

    @Test func emptyWAVInventoryProducesEmptyPlan() {
        let project = makeProject(regions: [], tracks: [])
        let plan = PreviewPlaybackPlanner.plan(for: project)

        #expect(!plan.hasPlayableTracks)
    }

    // MARK: - Mute suppression

    @Test func track1MuteByteNonZeroSuppressesFirstEDLPosition() {
        let project = makeProject(
            regions: [region("ZZ0000_1.wav"), region("ZZ0001_1.wav")],
            tracks: [
                trackWithMute(trackNumber: 1, mute: 0x01),
                trackWithMute(trackNumber: 2, mute: 0x00)
            ]
        )
        let plan = PreviewPlaybackPlanner.plan(for: project)

        #expect(plan.playableFilenames == ["ZZ0001_1.wav"])
        #expect(plan.suppressedFilenames == ["ZZ0000_1.wav"])
        #expect(plan.suppressedEntries.first?.reason == .track1Mute)
    }

    @Test func track2MuteByteNonZeroSuppressesSecondEDLPosition() {
        let project = makeProject(
            regions: [
                region("ZZ0002_1.wav"),
                region("ZZ0001_1.wav"),
                region("ZZ0000_1.wav")
            ],
            tracks: [
                trackWithMute(trackNumber: 1, mute: 0x00),
                trackWithMute(trackNumber: 2, mute: 0x01),
                trackWithMute(trackNumber: 3, mute: 0x00)
            ]
        )
        let plan = PreviewPlaybackPlanner.plan(for: project)

        #expect(plan.playableFilenames == ["ZZ0002_1.wav", "ZZ0000_1.wav"])
        #expect(plan.suppressedFilenames == ["ZZ0001_1.wav"])
        #expect(plan.suppressedEntries.first?.reason == .track2Mute)
    }

    @Test func track3MuteDoesNotSuppressThirdEDLPositionBeyondEvidencedMapping() {
        // No evidence-backed EDL-position mapping beyond track 2 in v1.
        let project = makeProject(
            regions: [
                region("ZZ0002_1.wav"),
                region("ZZ0001_1.wav"),
                region("ZZ0000_1.wav")
            ],
            tracks: [
                trackWithMute(trackNumber: 1, mute: 0x00),
                trackWithMute(trackNumber: 2, mute: 0x00),
                trackWithMute(trackNumber: 3, mute: 0x01)
            ]
        )
        let plan = PreviewPlaybackPlanner.plan(for: project)

        #expect(plan.playableFilenames == ["ZZ0002_1.wav", "ZZ0001_1.wav", "ZZ0000_1.wav"])
        #expect(plan.suppressedFilenames.isEmpty)
    }

    @Test func allTracksWithinEvidenceMutedProducesEmptyPlan() {
        let project = makeProject(
            regions: [region("ZZ0000_1.wav")],
            tracks: [trackWithMute(trackNumber: 1, mute: 0x01)]
        )
        let plan = PreviewPlaybackPlanner.plan(for: project)

        #expect(!plan.hasPlayableTracks)
        #expect(plan.suppressedFilenames == ["ZZ0000_1.wav"])
        #expect(plan.suppressedEntries.first?.reason == .track1Mute)
    }

    // MARK: - Virtual-take filtering

    @Test func sameStemVirtualTakeFilterSelectsActiveByTakeByte() {
        let project = makeProject(
            regions: [
                region("ZZ0000_1.wav"),
                region("ZZ0003_1.wav"),
                region("ZZ0003_2.wav")
            ],
            tracks: [],
            activeTakeCandidate: 0x01
        )
        let plan = PreviewPlaybackPlanner.plan(for: project)

        #expect(plan.playableFilenames == ["ZZ0000_1.wav", "ZZ0003_2.wav"])
        #expect(plan.suppressedFilenames == ["ZZ0003_1.wav"])
        #expect(plan.suppressedEntries.first?.reason == .track1ActiveVirtualTake)
    }

    @Test func ambiguousMultiTakeGroupsSkipVirtualTakeFiltering() {
        // Two stems each with two takes: ambiguous, no virtual-take filtering applied.
        let project = makeProject(
            regions: [
                region("ZZ0000_1.wav"),
                region("ZZ0000_2.wav"),
                region("ZZ0001_1.wav"),
                region("ZZ0001_2.wav")
            ],
            tracks: [],
            activeTakeCandidate: 0x01
        )
        let plan = PreviewPlaybackPlanner.plan(for: project)

        #expect(plan.playableFilenames.count == 4)
        #expect(plan.suppressedFilenames.isEmpty)
    }

    @Test func activeTakeCandidateZeroSkipsVirtualTakeFiltering() {
        // active-take byte 0x00 means first take is selected; no alternatives to suppress.
        let project = makeProject(
            regions: [region("ZZ0000_1.wav"), region("ZZ0000_2.wav")],
            tracks: [],
            activeTakeCandidate: 0x00
        )
        let plan = PreviewPlaybackPlanner.plan(for: project)

        // Only one stem but active-take byte 0x00 → activeTakeNumber = 1 = ZZ0000_1.wav
        #expect(plan.playableFilenames == ["ZZ0000_1.wav"])
        #expect(plan.suppressedFilenames == ["ZZ0000_2.wav"])
    }

    // MARK: - Combined filtering and mute

    @Test func virtualTakeFilterAppliedBeforeMuteSuppression() {
        // After virtual-take filtering selects ZZ0002_1.wav, mute suppression on track 1
        // (EDL position 0 after filtering) should suppress it, leaving no playable tracks.
        let project = makeProject(
            regions: [region("ZZ0002_1.wav"), region("ZZ0002_2.wav")],
            tracks: [trackWithMute(trackNumber: 1, mute: 0x01)],
            activeTakeCandidate: 0x01
        )
        let plan = PreviewPlaybackPlanner.plan(for: project)

        // Virtual-take filter: ZZ0002_2.wav suppressed (take1ActiveVirtualTake).
        // Mute suppression: ZZ0002_1.wav at position 0 → track 1 muted.
        #expect(!plan.hasPlayableTracks)
        #expect(plan.suppressedFilenames.sorted() == ["ZZ0002_1.wav", "ZZ0002_2.wav"])
    }

    // MARK: - Helpers

    private func region(_ filename: String) -> TimelineRegion {
        TimelineRegion(
            startSample: 0,
            endSample: nil,
            lengthSample: nil,
            sourceFilename: filename,
            sourceURL: URL(fileURLWithPath: "/tmp/\(filename)"),
            evidenceLevel: .hypothesis
        )
    }

    private func trackWithNoMixer(trackNumber: Int) -> TrackPreview {
        TrackPreview(
            trackNumber: trackNumber,
            candidateWAV: nil,
            mixerSetting: nil,
            track1ActiveTakeCandidate: nil,
            timeline: nil
        )
    }

    private func trackWithMute(trackNumber: Int, mute: UInt8) -> TrackPreview {
        TrackPreview(
            trackNumber: trackNumber,
            candidateWAV: nil,
            mixerSetting: TrackMixerSetting(
                trackNumber: trackNumber,
                level: MixerSetting(
                    name: "Level",
                    primaryOffset: 0x00C4,
                    primaryByte: 0x00,
                    mirrorOffset: nil,
                    mirrorByte: nil,
                    evidenceLevel: .correlated
                ),
                pan: MixerSetting(
                    name: "Pan",
                    primaryOffset: 0x00C6,
                    primaryByte: 0x40,
                    mirrorOffset: nil,
                    mirrorByte: nil,
                    evidenceLevel: .correlated
                ),
                mute: MixerSetting(
                    name: "Mute",
                    primaryOffset: 0x0268,
                    primaryByte: mute,
                    mirrorOffset: nil,
                    mirrorByte: nil,
                    evidenceLevel: .correlated
                )
            ),
            track1ActiveTakeCandidate: nil,
            timeline: nil
        )
    }

    private func makeProject(
        regions: [TimelineRegion],
        tracks: [TrackPreview],
        edlSummary: EdlTableSummary? = EdlTableSummary(
            track1ActiveTakeCandidate: 0x00,
            activeTakeCandidateOffset: EdlTableParser.track1ActiveTakeCandidateOffset,
            evidenceLevel: .correlated,
            fileListEntries: [],
            timelineAnchors: [],
            timelineCandidates: []
        ),
        activeTakeCandidate: UInt8? = nil
    ) -> PortastudioProject {
        let summary: EdlTableSummary?
        if let activeTakeCandidate {
            summary = EdlTableSummary(
                track1ActiveTakeCandidate: activeTakeCandidate,
                activeTakeCandidateOffset: EdlTableParser.track1ActiveTakeCandidateOffset,
                evidenceLevel: .correlated,
                fileListEntries: [],
                timelineAnchors: [],
                timelineCandidates: []
            )
        } else {
            summary = edlSummary
        }

        return PortastudioProject(
            folderURL: URL(fileURLWithPath: "/tmp/project"),
            validationIssues: [],
            wavInventory: [],
            unassignedAudioRegions: regions,
            tracks: tracks,
            edlTableSummary: summary
        )
    }
}
