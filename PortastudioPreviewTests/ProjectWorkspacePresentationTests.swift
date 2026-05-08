//
//  ProjectWorkspacePresentationTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct ProjectWorkspacePresentationTests {
    @Test func inspectorModeRemovedFromWorkspaceModes() {
        let modes = ProjectWorkspaceMode.allCases
        #expect(modes == [.tracks, .timeline])
        #expect(modes.count == 2)
    }

    @Test func headerIncludesAssignedTrackTimelinesInDurationLabel() {
        // Duration must include tracks with timelines, not only unassigned regions.
        let region = TimelineRegion(
            startSample: 0,
            endSample: 192_000,
            lengthSample: 192_000,
            sourceFilename: "ZZ0001_1.wav",
            sourceURL: URL(fileURLWithPath: "/tmp/SONG_0001/ZZ0001_1.wav"),
            evidenceLevel: .hypothesis
        )
        let track = TrackPreview(
            trackNumber: 1,
            candidateWAV: WAVInventoryItem(
                url: URL(fileURLWithPath: "/tmp/SONG_0001/ZZ0001_1.wav"),
                rawFilename: "ZZ0001_1.wav",
                byteCount: nil
            ),
            mixerSetting: nil,
            track1ActiveTakeCandidate: nil,
            timeline: TrackTimeline(trackNumber: 1, regions: [region], evidenceLevel: .hypothesis)
        )
        let project = PortastudioProject(
            folderURL: URL(fileURLWithPath: "/tmp/SONG_0001"),
            validationIssues: [],
            wavInventory: [],
            unassignedAudioRegions: [],   // region is assigned — not here
            tracks: [track],
            edlTableSummary: nil
        )

        let summary = ProjectHeaderSummary(project: project, displayName: nil)

        #expect(summary.durationLabel != "Duration unknown")
    }

    @Test func headerUsesDisplayNameAndDerivedStatus() {
        let project = makeProject(
            validationIssues: [],
            regions: [makeRegion(filename: "ZZ0001_1.wav", startSample: 0, length: 96_000)],
            tracks: [makeTrack(trackNumber: 1, level: LevelMapper.rawUnity, pan: PanMapper.rawCenter, muted: false)]
        )

        let summary = ProjectHeaderSummary(project: project, displayName: "Band Take")

        #expect(summary.title == "Band Take")
        #expect(summary.folderName == "SONG_0001")
        #expect(summary.readOnlyLabel == "Read Only")
        #expect(summary.trackCountLabel == "1 tracks")
        #expect(summary.wavCountLabel == "1 WAV")
        #expect(summary.durationLabel == "2.0s")
        #expect(summary.validationLabel == "Validated")
        #expect(summary.previewLabel == "Preview Available")
    }

    @Test func headerFallsBackWhenDurationAndPreviewAreUnavailable() {
        let project = makeProject(validationIssues: [], regions: [], tracks: [])

        let summary = ProjectHeaderSummary(project: project, displayName: "  ")

        #expect(summary.title == "SONG_0001")
        #expect(summary.durationLabel == "Duration unknown")
        #expect(summary.previewLabel == "No Preview")
    }

    @Test func headerReportsValidationIssues() {
        let project = makeProject(
            validationIssues: [
                ProjectValidationIssue(id: "warning", severity: .warning, message: "warning"),
                ProjectValidationIssue(id: "error", severity: .error, message: "error")
            ],
            regions: [],
            tracks: []
        )

        let summary = ProjectHeaderSummary(project: project, displayName: nil)

        #expect(summary.validationLabel == "2 issues")
        #expect(summary.validationSystemImage == "xmark.octagon.fill")
    }

    @Test func headerReportsWarningOnlyIssues() {
        let project = makeProject(
            validationIssues: [
                ProjectValidationIssue(id: "w1", severity: .warning, message: "Watch out"),
                ProjectValidationIssue(id: "w2", severity: .warning, message: "Also watch out")
            ],
            regions: [],
            tracks: []
        )

        let summary = ProjectHeaderSummary(project: project, displayName: nil)

        #expect(summary.validationLabel == "2 warnings")
        #expect(summary.validationSystemImage == "exclamationmark.triangle.fill")
    }

    @Test func mixerStripMapsTrackDisplayState() {
        let track = makeTrack(
            trackNumber: 3,
            level: LevelMapper.rawUnity,
            pan: PanMapper.rawR2,
            muted: true,
            assigned: true
        )

        let strip = TrackMixerStripPresentation(track: track, displayName: "Lead Vocal", isSelected: true)

        #expect(strip.id == 3)
        #expect(strip.displayName == "Lead Vocal")
        #expect(strip.candidateWAVLabel == "ZZ0003_1.wav")
        #expect(strip.candidateEvidenceLabel == "WAV: Hypothesis")
        #expect(strip.panLabel == "R2")
        #expect(strip.levelLabel == "0 dB")
        #expect(strip.levelPosition > 0.8)
        #expect(strip.isMuted)
        #expect(strip.muteLabel == "Muted")
        #expect(strip.isSelected)
    }

    @Test func mixerStripFallsBackForMissingMixerData() {
        let track = TrackPreview(
            trackNumber: 4,
            candidateWAV: nil,
            mixerSetting: nil,
            track1ActiveTakeCandidate: nil,
            timeline: nil
        )

        let strip = TrackMixerStripPresentation(track: track, displayName: nil, isSelected: false)

        #expect(strip.displayName == "Track 4")
        #expect(strip.candidateWAVLabel == "Unassigned")
        #expect(strip.candidateEvidenceLabel == "No WAV")
        #expect(strip.panLabel == "n/a")
        #expect(strip.levelLabel == "n/a")
        #expect(strip.levelPosition == 0)
        #expect(!strip.isMuted)
    }

    // MARK: - Helpers

    private func makeProject(
        validationIssues: [ProjectValidationIssue],
        regions: [TimelineRegion],
        tracks: [TrackPreview]
    ) -> PortastudioProject {
        PortastudioProject(
            folderURL: URL(fileURLWithPath: "/tmp/SONG_0001"),
            validationIssues: validationIssues,
            wavInventory: [
                WAVInventoryItem(
                    url: URL(fileURLWithPath: "/tmp/SONG_0001/ZZ0001_1.wav"),
                    rawFilename: "ZZ0001_1.wav",
                    byteCount: 128
                )
            ],
            unassignedAudioRegions: regions,
            tracks: tracks,
            edlTableSummary: nil
        )
    }

    private func makeRegion(filename: String, startSample: Int, length: Int) -> TimelineRegion {
        TimelineRegion(
            startSample: startSample,
            endSample: startSample + length,
            lengthSample: length,
            sourceFilename: filename,
            sourceURL: URL(fileURLWithPath: "/tmp/SONG_0001/\(filename)"),
            evidenceLevel: .hypothesis
        )
    }

    private func makeTrack(
        trackNumber: Int,
        level: UInt8,
        pan: UInt8,
        muted: Bool,
        assigned: Bool = false
    ) -> TrackPreview {
        TrackPreview(
            trackNumber: trackNumber,
            candidateWAV: assigned
                ? WAVInventoryItem(
                    url: URL(fileURLWithPath: "/tmp/SONG_0001/ZZ000\(trackNumber)_1.wav"),
                    rawFilename: "ZZ000\(trackNumber)_1.wav",
                    byteCount: 128
                )
                : nil,
            mixerSetting: TrackMixerSetting(
                trackNumber: trackNumber,
                level: MixerSetting(
                    name: "Level",
                    primaryOffset: 0,
                    primaryByte: level,
                    mirrorOffset: nil,
                    mirrorByte: nil,
                    evidenceLevel: .confirmed
                ),
                pan: MixerSetting(
                    name: "Pan",
                    primaryOffset: 1,
                    primaryByte: pan,
                    mirrorOffset: nil,
                    mirrorByte: nil,
                    evidenceLevel: .confirmed
                ),
                mute: MixerSetting(
                    name: "Mute",
                    primaryOffset: 2,
                    primaryByte: muted ? 0x01 : 0x00,
                    mirrorOffset: nil,
                    mirrorByte: nil,
                    evidenceLevel: .observed
                )
            ),
            track1ActiveTakeCandidate: nil,
            timeline: nil
        )
    }
}
