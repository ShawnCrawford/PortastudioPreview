//
//  ProjectPreviewBuilderTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct ProjectPreviewBuilderTests {
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

    private func writeEdlTable(fileList: [String], to url: URL) throws {
        let text = "File List\0" + fileList.joined(separator: "\0") + "\0"
        var data = Data(count: EdlTableParser.track1ActiveTakeCandidateOffset + 1)
        data.replaceSubrange(0x100..<(0x100 + text.utf8.count), with: text.utf8)
        try data.write(to: url)
    }
}
