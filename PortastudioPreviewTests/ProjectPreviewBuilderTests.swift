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
