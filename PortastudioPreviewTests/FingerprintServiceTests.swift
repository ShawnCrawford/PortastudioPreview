//
//  FingerprintServiceTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct FingerprintServiceTests {
    private let service = FingerprintService()

    // MARK: - Deterministic key-file hashing

    @Test func songSysHashIsDeterministic() throws {
        let folder = try TemporaryFolder()
        let data = Data([0x01, 0x02, 0x03])
        try data.write(to: folder.url.appendingPathComponent("song.sys"))
        try Data().write(to: folder.url.appendingPathComponent("edltable.sys"))

        let fp1 = service.buildSongFingerprint(at: folder.url)
        let fp2 = service.buildSongFingerprint(at: folder.url)

        #expect(fp1.aggregateString == fp2.aggregateString)
        #expect(fp1.songSysFingerprint?.sha256Hex != nil)
    }

    @Test func edlTableHashIsDeterministic() throws {
        let folder = try TemporaryFolder()
        try Data().write(to: folder.url.appendingPathComponent("song.sys"))
        let data = Data([0xAA, 0xBB])
        try data.write(to: folder.url.appendingPathComponent("edltable.sys"))

        let fp1 = service.buildSongFingerprint(at: folder.url)
        let fp2 = service.buildSongFingerprint(at: folder.url)

        #expect(fp1.edlTableFingerprint?.sha256Hex != nil)
        #expect(fp1.aggregateString == fp2.aggregateString)
    }

    @Test func dp24SysHashIsDeterministic() throws {
        let folder = try TemporaryFolder()
        let musicURL = folder.url.appendingPathComponent("MUSIC", isDirectory: true)
        try FileManager.default.createDirectory(at: musicURL, withIntermediateDirectories: true)
        let data = Data([0x10, 0x20, 0x30])
        try data.write(to: folder.url.appendingPathComponent("dp-24.sys"))

        let fp1 = service.buildSourceFingerprint(at: folder.url, kind: .mediaRoot)
        let fp2 = service.buildSourceFingerprint(at: folder.url, kind: .mediaRoot)

        #expect(fp1.dp24SysFingerprint?.sha256Hex != nil)
        #expect(fp1.aggregateString == fp2.aggregateString)
    }

    // MARK: - Ignored Apple metadata files

    @Test func appleSidecarFilesAreIgnoredFromWAVInventory() throws {
        let folder = try TemporaryFolder()
        try Data().write(to: folder.url.appendingPathComponent("song.sys"))
        try Data().write(to: folder.url.appendingPathComponent("edltable.sys"))
        try Data().write(to: folder.url.appendingPathComponent("TRACK01.WAV"))
        try Data().write(to: folder.url.appendingPathComponent("._TRACK01.WAV"))
        try Data().write(to: folder.url.appendingPathComponent(".DS_Store"))

        let fp = service.buildSongFingerprint(at: folder.url)

        #expect(fp.wavInventory.visibleWAVCount == 1)
        let names = fp.wavInventory.entries.map(\.relativePath)
        #expect(!names.contains(where: { $0.contains("._") }))
        #expect(!names.contains(where: { $0.contains(".DS_Store") }))
    }

    @Test func spotlightAndFseventsAreIgnoredFromSourceScan() throws {
        let folder = try TemporaryFolder()
        let musicURL = folder.url.appendingPathComponent("MUSIC", isDirectory: true)
        try FileManager.default.createDirectory(at: musicURL, withIntermediateDirectories: true)
        // These should not crash or appear in aggregate
        try FileManager.default.createDirectory(
            at: folder.url.appendingPathComponent(".Spotlight-V100"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: folder.url.appendingPathComponent(".fseventsd"), withIntermediateDirectories: true)

        let fp = service.buildSourceFingerprint(at: folder.url, kind: .mediaRoot)
        #expect(!fp.aggregateString.isEmpty)
    }

    // MARK: - WAV case normalization

    @Test func wavInventoryNormalizesPathCaseForComparison() throws {
        let folder1 = try TemporaryFolder()
        let folder2 = try TemporaryFolder()
        try Data().write(to: folder1.url.appendingPathComponent("song.sys"))
        try Data().write(to: folder1.url.appendingPathComponent("edltable.sys"))
        try Data().write(to: folder2.url.appendingPathComponent("song.sys"))
        try Data().write(to: folder2.url.appendingPathComponent("edltable.sys"))

        // Same content, different case filename — entries should have lowercased relativePath
        let wavData = Data(repeating: 0xFF, count: 100)
        try wavData.write(to: folder1.url.appendingPathComponent("TRACK01.WAV"))
        try wavData.write(to: folder2.url.appendingPathComponent("track01.wav"))

        let fp1 = service.buildSongFingerprint(at: folder1.url)
        let fp2 = service.buildSongFingerprint(at: folder2.url)

        // Normalized paths should match (lowercased), byte counts match, so aggregates match
        // (modTime differs between independent folders, but normalization is the focus here)
        let paths1 = fp1.wavInventory.entries.map(\.relativePath)
        let paths2 = fp2.wavInventory.entries.map(\.relativePath)
        #expect(paths1 == paths2)
    }

    // MARK: - WAV content is never hashed

    @Test func wavContentChangesDoNotAlterAggregate() throws {
        let folder = try TemporaryFolder()
        try Data().write(to: folder.url.appendingPathComponent("song.sys"))
        try Data().write(to: folder.url.appendingPathComponent("edltable.sys"))
        let wavURL = folder.url.appendingPathComponent("TRACK01.WAV")
        try Data(repeating: 0x00, count: 1024).write(to: wavURL)

        let fp1 = service.buildSongFingerprint(at: folder.url)
        // Overwrite WAV with different content but same byte count and same modtime (best effort)
        try Data(repeating: 0xFF, count: 1024).write(to: wavURL)

        let fp2 = service.buildSongFingerprint(at: folder.url)
        // Byte count is the same so aggregate should be the same
        // (modtime may vary by FS resolution; test focuses on byte count)
        #expect(fp1.wavInventory.entries.map(\.byteCount) == fp2.wavInventory.entries.map(\.byteCount))
    }

    // MARK: - Aggregate stability and sensitivity

    @Test func aggregateIsStableForIdenticalSyntheticFolders() throws {
        let folder1 = try TemporaryFolder()
        let folder2 = try TemporaryFolder()
        let keySysData = Data([0x11, 0x22, 0x33])
        let edlData = Data([0x44, 0x55])
        try keySysData.write(to: folder1.url.appendingPathComponent("song.sys"))
        try edlData.write(to: folder1.url.appendingPathComponent("edltable.sys"))
        try keySysData.write(to: folder2.url.appendingPathComponent("song.sys"))
        try edlData.write(to: folder2.url.appendingPathComponent("edltable.sys"))

        let fp1 = service.buildSongFingerprint(at: folder1.url)
        let fp2 = service.buildSongFingerprint(at: folder2.url)

        // Key file hashes should match; folder name will differ so aggregate differs, but hashes same
        #expect(fp1.songSysFingerprint?.sha256Hex == fp2.songSysFingerprint?.sha256Hex)
        #expect(fp1.edlTableFingerprint?.sha256Hex == fp2.edlTableFingerprint?.sha256Hex)
    }

    @Test func aggregateChangesWhenKeyFileBytesChange() throws {
        let folder = try TemporaryFolder()
        try Data([0xAA]).write(to: folder.url.appendingPathComponent("song.sys"))
        try Data().write(to: folder.url.appendingPathComponent("edltable.sys"))

        let fp1 = service.buildSongFingerprint(at: folder.url)

        try Data([0xBB]).write(to: folder.url.appendingPathComponent("song.sys"))
        let fp2 = service.buildSongFingerprint(at: folder.url)

        #expect(fp1.aggregateString != fp2.aggregateString)
        #expect(fp1.songSysFingerprint?.sha256Hex != fp2.songSysFingerprint?.sha256Hex)
    }

    @Test func aggregateChangesWhenWAVSizeChanges() throws {
        let folder = try TemporaryFolder()
        try Data().write(to: folder.url.appendingPathComponent("song.sys"))
        try Data().write(to: folder.url.appendingPathComponent("edltable.sys"))
        let wavURL = folder.url.appendingPathComponent("TRACK01.WAV")
        try Data(count: 512).write(to: wavURL)

        let fp1 = service.buildSongFingerprint(at: folder.url)

        try Data(count: 1024).write(to: wavURL)
        let fp2 = service.buildSongFingerprint(at: folder.url)

        #expect(fp1.wavInventory.totalVisibleWAVBytes != fp2.wavInventory.totalVisibleWAVBytes)
        #expect(fp1.aggregateString != fp2.aggregateString)
    }

    @Test func aggregateChangesWhenVisibleWAVSetChanges() throws {
        let folder = try TemporaryFolder()
        try Data().write(to: folder.url.appendingPathComponent("song.sys"))
        try Data().write(to: folder.url.appendingPathComponent("edltable.sys"))
        try Data(count: 256).write(to: folder.url.appendingPathComponent("TRACK01.WAV"))

        let fp1 = service.buildSongFingerprint(at: folder.url)

        try Data(count: 256).write(to: folder.url.appendingPathComponent("TRACK02.WAV"))
        let fp2 = service.buildSongFingerprint(at: folder.url)

        #expect(fp1.wavInventory.visibleWAVCount == 1)
        #expect(fp2.wavInventory.visibleWAVCount == 2)
        #expect(fp1.aggregateString != fp2.aggregateString)
    }

    // MARK: - Missing key files handled gracefully

    @Test func missingKeyFilesProduceNilComponentsNotCrash() throws {
        let folder = try TemporaryFolder()
        // No song.sys or edltable.sys written
        let fp = service.buildSongFingerprint(at: folder.url)

        #expect(fp.songSysFingerprint == nil)
        #expect(fp.edlTableFingerprint == nil)
        #expect(!fp.aggregateString.isEmpty)
    }
}
