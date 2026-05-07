//
//  SongDetailSummaryTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct SongDetailSummaryTests {
    @Test func summarizesCountsForPopulatedProject() {
        let project = makeProject(
            tracks: [
                makeTrack(trackNumber: 1, assigned: true),
                makeTrack(trackNumber: 2, assigned: false),
                makeTrack(trackNumber: 3, assigned: true)
            ],
            wavInventoryCount: 4,
            validationIssues: [
                ProjectValidationIssue(id: "w1", severity: .warning, message: "warning"),
                ProjectValidationIssue(id: "e1", severity: .error, message: "error")
            ],
            unassignedRegions: [
                makeRegion(filename: "ZZ0000_1.wav", startSample: 0),
                makeRegion(filename: "ZZ0001_1.wav", startSample: 48_000)
            ],
            edlSummary: makeEdlSummary(fileListCount: 3, timelineCandidateCount: 2)
        )

        let summary = SongDetailSummary(project: project)

        #expect(summary.trackCount == 3)
        #expect(summary.assignedTrackCount == 2)
        #expect(summary.wavCount == 4)
        #expect(summary.validationIssueCount == 2)
        #expect(summary.hasErrors)
        #expect(summary.unassignedRegionCount == 2)
        #expect(summary.edlFileListCount == 3)
        #expect(summary.timelineCandidateCount == 2)
        #expect(summary.previewAvailable)
    }

    @Test func summarizesCountsForEmptyProjectAndNoPreview() {
        let project = makeProject(
            tracks: [],
            wavInventoryCount: 0,
            validationIssues: [],
            unassignedRegions: [],
            edlSummary: nil
        )

        let summary = SongDetailSummary(project: project)

        #expect(summary.trackCount == 0)
        #expect(summary.assignedTrackCount == 0)
        #expect(summary.wavCount == 0)
        #expect(summary.validationIssueCount == 0)
        #expect(!summary.hasErrors)
        #expect(summary.unassignedRegionCount == 0)
        #expect(summary.edlFileListCount == 0)
        #expect(summary.timelineCandidateCount == 0)
        #expect(!summary.previewAvailable)
    }

    // MARK: - Helpers

    private func makeProject(
        tracks: [TrackPreview],
        wavInventoryCount: Int,
        validationIssues: [ProjectValidationIssue],
        unassignedRegions: [TimelineRegion],
        edlSummary: EdlTableSummary?
    ) -> PortastudioProject {
        PortastudioProject(
            folderURL: URL(fileURLWithPath: "/tmp/SONG_0001"),
            validationIssues: validationIssues,
            wavInventory: (0..<wavInventoryCount).map {
                WAVInventoryItem(
                    url: URL(fileURLWithPath: "/tmp/SONG_0001/ZZ\($0)_1.wav"),
                    rawFilename: "ZZ\($0)_1.wav",
                    byteCount: 1000
                )
            },
            unassignedAudioRegions: unassignedRegions,
            tracks: tracks,
            edlTableSummary: edlSummary
        )
    }

    private func makeTrack(trackNumber: Int, assigned: Bool) -> TrackPreview {
        TrackPreview(
            trackNumber: trackNumber,
            candidateWAV: assigned
                ? WAVInventoryItem(
                    url: URL(fileURLWithPath: "/tmp/SONG_0001/ZZ000\(trackNumber)_1.wav"),
                    rawFilename: "ZZ000\(trackNumber)_1.wav",
                    byteCount: 1000
                )
                : nil,
            mixerSetting: nil,
            track1ActiveTakeCandidate: nil,
            timeline: nil
        )
    }

    private func makeRegion(filename: String, startSample: Int) -> TimelineRegion {
        TimelineRegion(
            startSample: startSample,
            endSample: startSample + 48_000,
            lengthSample: nil,
            sourceFilename: filename,
            sourceURL: URL(fileURLWithPath: "/tmp/SONG_0001/\(filename)"),
            evidenceLevel: .hypothesis
        )
    }

    private func makeEdlSummary(fileListCount: Int, timelineCandidateCount: Int) -> EdlTableSummary {
        EdlTableSummary(
            track1ActiveTakeCandidate: 0x00,
            activeTakeCandidateOffset: 0,
            evidenceLevel: .correlated,
            fileListEntries: (0..<fileListCount).map { index in
                EdlFileListEntry(fileID: index, filename: "ZZ\(index)_1.wav", evidenceLevel: .correlated)
            },
            timelineAnchors: [],
            timelineCandidates: (0..<timelineCandidateCount).map { index in
                EdlTimelineCandidate(representativeSample: index * 48_000, rawSamples: [index * 48_000], evidenceLevel: .hypothesis)
            }
        )
    }
}
