//
//  ResearchSampleAuditTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct ResearchSampleAuditTests {
    private let sampleRoot = URL(fileURLWithPath: "/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/TestProjects/DP-32SD")

    @Test func edlFileListOrderCanDifferFromSortedWAVInventory() throws {
        let sampleURL = sampleRoot.appendingPathComponent("MVP-LEVEL-001")

        guard FileManager.default.fileExists(atPath: sampleURL.path) else {
            return
        }

        let summary = try EdlTableParser().parse(Data(contentsOf: sampleURL.appendingPathComponent("edltable.sys"), options: .mappedIfSafe))
        let edlFilenames = summary.fileListEntries.map(\.filename)
        let inventoryFilenames = try WAVInventoryScanner().scan(sampleURL).map(\.rawFilename)

        #expect(edlFilenames == ["ZZ0003_2.wav", "ZZ0003_1.wav", "ZZ0002_1.wav", "ZZ0001_1.wav", "ZZ0000_1.wav"])
        #expect(inventoryFilenames == ["ZZ0000_1.wav", "ZZ0001_1.wav", "ZZ0002_1.wav", "ZZ0003_1.wav", "ZZ0003_2.wav"])
        #expect(Set(edlFilenames) == Set(inventoryFilenames))
    }

    @Test func populatedResearchSamplesHaveMatchingEDLAndWAVFilenameSets() throws {
        for sampleName in populatedSampleNames {
            let sampleURL = sampleRoot.appendingPathComponent(sampleName)

            guard FileManager.default.fileExists(atPath: sampleURL.path) else {
                continue
            }

            let summary = try EdlTableParser().parse(Data(contentsOf: sampleURL.appendingPathComponent("edltable.sys"), options: .mappedIfSafe))
            let edlFilenames = Set(summary.fileListEntries.map { $0.filename.lowercased() })
            let inventoryFilenames = Set(try WAVInventoryScanner().scan(sampleURL).map { $0.rawFilename.lowercased() })

            #expect(edlFilenames == inventoryFilenames, "\(sampleName) EDL file list should match WAV inventory as a set")
        }
    }

    @Test func mixerAnchorSamplesExposeExpectedTrack1Bytes() throws {
        try expectTrack1Bytes(sampleName: "MVP-LEVEL-001", level: 0x3E, pan: 0x40, mute: 0x00)
        try expectTrack1Bytes(sampleName: "MVP-PAN-001", level: 0x00, pan: 0x01, mute: 0x00)
        try expectTrack1Bytes(sampleName: "MVP-MUTE-001", level: 0x00, pan: 0x40, mute: 0x01)
    }

    @Test func mixmapSampleExposesRepeatedFirstEightLevelPanRows() throws {
        let sampleURL = sampleRoot.appendingPathComponent("MVP-MIXMAP-001")

        guard FileManager.default.fileExists(atPath: sampleURL.path) else {
            return
        }

        let tracks = try SongSysParser().parse(Data(contentsOf: sampleURL.appendingPathComponent("song.sys"), options: .mappedIfSafe))

        #expect(tracks.prefix(8).map { $0.level.primaryByte } == [0x04, 0x23, 0x3D, 0x54, 0x6A, 0x03, 0x54, 0x3B])
        #expect(tracks.prefix(8).map { $0.pan.primaryByte } == [0x01, 0x20, 0x40, 0x60, 0x7F, 0x30, 0x40, 0x50])
        #expect(tracks.prefix(8).allSatisfy { !$0.level.hasMirrorMismatch && !$0.pan.hasMirrorMismatch })
    }

    @MainActor
    @Test func loadingResearchSamplesDoesNotModifySourceFolders() async throws {
        for sampleName in allSampleNames {
            let sampleURL = sampleRoot.appendingPathComponent(sampleName)

            guard FileManager.default.fileExists(atPath: sampleURL.path) else {
                continue
            }

            let before = try FileReadOnlyGuard.snapshot(of: sampleURL)
            _ = try await ProjectFolderLoader().loadProject(at: sampleURL)
            let after = try FileReadOnlyGuard.snapshot(of: sampleURL)

            #expect(after == before, "\(sampleName) should remain byte-for-byte untouched by preview loading")
        }
    }

    private var populatedSampleNames: [String] {
        [
            "MVP-BASE-001",
            "MVP-TAKE-001",
            "MVP-MUTE-001",
            "MVP-PAN-001",
            "MVP-LEVEL-001",
            "SONG_0058-old",
            "SONG_0058-edit-001",
            "SONG_0058-edit-002",
            "TONG_0055",
        ]
    }

    private var allSampleNames: [String] {
        populatedSampleNames + [
            "MVP-BASE-ORIGINAL",
            "MVP-MIXMAP",
            "MVP-MIXMAP-001",
        ]
    }

    private func expectTrack1Bytes(sampleName: String, level: UInt8, pan: UInt8, mute: UInt8) throws {
        let sampleURL = sampleRoot.appendingPathComponent(sampleName)

        guard FileManager.default.fileExists(atPath: sampleURL.path) else {
            return
        }

        let track1 = try #require(try SongSysParser()
            .parse(Data(contentsOf: sampleURL.appendingPathComponent("song.sys"), options: .mappedIfSafe))
            .first)

        #expect(track1.level.primaryByte == level)
        #expect(track1.level.mirrorByte == level)
        #expect(track1.pan.primaryByte == pan)
        #expect(track1.pan.mirrorByte == pan)
        #expect(track1.mute?.primaryByte == mute)
        #expect(track1.mute?.mirrorByte == mute)
    }
}
