//
//  ProjectPreviewBuilderTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct ProjectPreviewBuilderTests {
    @Test func inferredStartSamplesPairImplicitZeroWithDelayedAnchors() {
        let starts = ProjectPreviewBuilder.inferredStartSamples(
            wavCount: 3,
            timelineAnchors: [882_000, 441_000]
        )

        #expect(starts == [0, 441_000, 882_000])
    }

    @Test func inferredStartSamplesPreserveSingleDelayedRegionSilence() {
        let starts = ProjectPreviewBuilder.inferredStartSamples(
            wavCount: 1,
            timelineAnchors: [441_000]
        )

        #expect(starts == [441_000])
    }

    @Test func inferredStartSamplesDefaultToZeroWhenTimelinePairingIsAmbiguous() {
        let starts = ProjectPreviewBuilder.inferredStartSamples(
            wavCount: 3,
            timelineAnchors: [441_000]
        )

        #expect(starts == [0, 0, 0])
    }

    @Test func builderDoesNotAssignSortedWAVInventoryToPhysicalTracks() throws {
        let folder = try TemporaryFolder()
        try Data(count: MixerMapOffsets.minimumSongSysLength).write(to: folder.url.appendingPathComponent("song.sys"))
        try writeEdlTable(
            fileList: ["ZZ0002_1.wav", "ZZ0001_1.wav", "ZZ0000_1.wav"],
            to: folder.url.appendingPathComponent("edltable.sys")
        )
        try Data([0x01]).write(to: folder.url.appendingPathComponent("ZZ0000_1.wav"))
        try Data([0x02]).write(to: folder.url.appendingPathComponent("ZZ0001_1.wav"))
        try Data([0x03]).write(to: folder.url.appendingPathComponent("ZZ0002_1.wav"))

        let project = try ProjectPreviewBuilder().build(folderURL: folder.url)

        #expect(project.tracks.allSatisfy { track in
            if case nil = track.candidateWAV {
                return true
            }
            return false
        })
        #expect(project.tracks.allSatisfy { track in
            if case nil = track.timeline {
                return true
            }
            return false
        })
        #expect(project.unassignedAudioRegions.map(\.sourceFilename) == ["ZZ0002_1.wav", "ZZ0001_1.wav", "ZZ0000_1.wav"])
        #expect(StereoPreviewEngine.hasPlayableTracks(project))
    }

    @Test func builderPairsImplicitZeroRegionWithDelayedTimelineAnchor() throws {
        let folder = try TemporaryFolder()
        try Data(count: MixerMapOffsets.minimumSongSysLength).write(to: folder.url.appendingPathComponent("song.sys"))
        try writeEdlTable(
            fileList: ["ZZ0000_1.wav", "ZZ0001_1.wav"],
            timelineAnchors: [441_000],
            to: folder.url.appendingPathComponent("edltable.sys")
        )
        try Data([0x01]).write(to: folder.url.appendingPathComponent("ZZ0000_1.wav"))
        try Data([0x02]).write(to: folder.url.appendingPathComponent("ZZ0001_1.wav"))

        let project = try ProjectPreviewBuilder().build(folderURL: folder.url)

        #expect(project.unassignedAudioRegions.map(\.sourceFilename) == ["ZZ0000_1.wav", "ZZ0001_1.wav"])
        #expect(project.unassignedAudioRegions.map(\.startSample) == [0, 441_000])
    }

    // MARK: - Sequential start-time helpers

    @Test func wavStemAndSuffixParsesStandardZZFilename() {
        let result = ProjectPreviewBuilder.wavStemAndSuffix("ZZ0008_2.wav")
        #expect(result?.stem == "ZZ0008")
        #expect(result?.suffix == 2)
    }

    @Test func wavStemAndSuffixReturnsPrimaryForTakeOne() {
        let result = ProjectPreviewBuilder.wavStemAndSuffix("ZZ0000_1.wav")
        #expect(result?.stem == "ZZ0000")
        #expect(result?.suffix == 1)
    }

    @Test func wavStemAndSuffixReturnsNilForNonMatchingName() {
        #expect(ProjectPreviewBuilder.wavStemAndSuffix("song.sys") == nil)
        #expect(ProjectPreviewBuilder.wavStemAndSuffix("ZZ0000.wav") == nil)
    }

    @Test func anyBoundaryFoundInEdlReturnsTrueWhenValuePresent() {
        var data = Data(count: 0x42000)
        // Write 252399 (0x0003D9EF) at offset 0x41950 in LE
        let offset = 0x41950
        data[offset] = 0xEF
        data[offset + 1] = 0xD9
        data[offset + 2] = 0x03
        data[offset + 3] = 0x00

        #expect(ProjectPreviewBuilder.anyBoundaryFoundInEdl([252399], data: data))
    }

    @Test func anyBoundaryFoundInEdlReturnsTrueForValueWithinTolerance() {
        var data = Data(count: 0x42000)
        let offset = 0x41950
        // Write 252401 when searching for 252399 (diff = 2, within ±5)
        let val: UInt32 = 252401
        data[offset] = UInt8(val & 0xFF)
        data[offset + 1] = UInt8((val >> 8) & 0xFF)
        data[offset + 2] = UInt8((val >> 16) & 0xFF)
        data[offset + 3] = 0x00

        #expect(ProjectPreviewBuilder.anyBoundaryFoundInEdl([252399], data: data))
    }

    @Test func anyBoundaryFoundInEdlReturnsFalseWhenAbsent() {
        let data = Data(count: 0x42000)
        #expect(!ProjectPreviewBuilder.anyBoundaryFoundInEdl([252399], data: data))
    }

    // MARK: - Local integration: PONG_0096 sequential start times

    @Test func pong0096SequentialStartTimesAreAppliedWhenBinaryConfirmed() throws {
        let captureRoot = URL(fileURLWithPath: "/Users/shawn/Projects/SwiftUI/PortastudioPreview/Docs/TEST-SONGS")
        let songURL = captureRoot.appendingPathComponent("PONG_0096")

        guard FileManager.default.fileExists(atPath: songURL.appendingPathComponent("edltable.sys").path),
              FileManager.default.fileExists(atPath: songURL.appendingPathComponent("ZZ0000_1.wav").path) else {
            return
        }

        let project = try ProjectPreviewBuilder().build(folderURL: songURL)

        // ZZ0000_1 should start at 0 and ZZ0001_1 should start after it.
        let regions = project.unassignedAudioRegions
        #expect(!regions.isEmpty)

        let zz0000 = regions.first(where: { $0.sourceFilename == "ZZ0000_1.wav" })
        let zz0001 = regions.first(where: { $0.sourceFilename == "ZZ0001_1.wav" })
        #expect(zz0000?.startSample == 0)
        // ZZ0001_1 must start after ZZ0000_1 ends (sequential layout).
        let zz0000End = zz0000?.endSample ?? 0
        #expect((zz0001?.startSample ?? 0) >= zz0000End - 442)

        // Stereo pairs share their primary file's start position.
        let zz0008_1 = regions.first(where: { $0.sourceFilename == "ZZ0008_1.wav" })
        let zz0008_2 = regions.first(where: { $0.sourceFilename == "ZZ0008_2.wav" })
        if let s1 = zz0008_1?.startSample, let s2 = zz0008_2?.startSample {
            #expect(s1 == s2)
        }
    }

    private func writeEdlTable(fileList: [String], timelineAnchors: [UInt32] = [], to url: URL) throws {
        let text = "File List\0" + fileList.joined(separator: "\0") + "\0"
        var data = Data(count: EdlTableParser.track1ActiveTakeCandidateOffset + 1)
        data.replaceSubrange(0x100..<(0x100 + text.utf8.count), with: text.utf8)

        for (index, anchor) in timelineAnchors.enumerated() {
            writeUInt32LE(anchor, to: &data, at: 0x41858 + index * 0x40)
        }

        try data.write(to: url)
    }

    private func writeUInt32LE(_ value: UInt32, to data: inout Data, at offset: Int) {
        data[offset] = UInt8(value & 0xFF)
        data[offset + 1] = UInt8((value >> 8) & 0xFF)
        data[offset + 2] = UInt8((value >> 16) & 0xFF)
        data[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}
