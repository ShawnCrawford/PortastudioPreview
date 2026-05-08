//
//  DeviceCaptureAuditTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct DeviceCaptureAuditTests {
    private let captureRoot = URL(fileURLWithPath: "/Users/shawn/Projects/SwiftUI/PortastudioPreview/Docs/TEST-SONGS")

    @Test func song0086EDLOrderDiffersFromSortedFilenames() throws {
        let songURL = captureRoot.appendingPathComponent("SONG_0086")

        guard FileManager.default.fileExists(atPath: songURL.path) else {
            return
        }

        let summary = try parseEdl(songURL)
        let edlFilenames = summary.fileListEntries.map(\.filename)
        let inventoryFilenames = try WAVInventoryScanner().scan(songURL).map(\.rawFilename)

        #expect(edlFilenames == ["ZZ0002_1.wav", "ZZ0001_1.wav", "ZZ0000_1.wav"])
        #expect(inventoryFilenames == ["ZZ0000_1.wav", "ZZ0001_1.wav", "ZZ0002_1.wav"])
        #expect(Set(edlFilenames) == Set(inventoryFilenames))
    }

    @Test func track1ActiveTakeCandidateChangesAcrossSong0083Through0085() throws {
        guard FileManager.default.fileExists(atPath: captureRoot.path) else {
            return
        }

        #expect(try parseEdl(captureRoot.appendingPathComponent("SONG_0083")).track1ActiveTakeCandidate == 0x00)
        #expect(try parseEdl(captureRoot.appendingPathComponent("SONG_0084")).track1ActiveTakeCandidate == 0x01)
        #expect(try parseEdl(captureRoot.appendingPathComponent("SONG_0085")).track1ActiveTakeCandidate == 0x00)
    }

    @Test func song0084PlayableFilenamesRemainActiveVirtualTake2() throws {
        let songURL = captureRoot.appendingPathComponent("SONG_0084")
        guard FileManager.default.fileExists(atPath: songURL.path) else { return }

        let project = try ProjectPreviewBuilder().build(folderURL: songURL)
        let plan = PreviewPlaybackPlanner.plan(for: project)

        // EDL active-take byte 0x01 selects file-list index 2 (ZZ0002_1.wav).
        // Evidence: Correlated (0x00B01A38 == 0x01).
        #expect(plan.playableFilenames == ["ZZ0002_1.wav"])
    }

    @Test func song0075HasNoPlayableTracksWhenTrack1IsMuted() throws {
        let songURL = captureRoot.appendingPathComponent("SONG_0075")
        guard FileManager.default.fileExists(atPath: songURL.path) else { return }

        let project = try ProjectPreviewBuilder().build(folderURL: songURL)
        let plan = PreviewPlaybackPlanner.plan(for: project)

        // Track 1 mute byte 0x01 at 0x0268; EDL position 0 → Track 1. Evidence: Confirmed.
        #expect(plan.playableFilenames.isEmpty)
        #expect(!plan.hasPlayableTracks)
    }

    @Test func song0086BaselineStillPlaysAllThreeEDLEntries() throws {
        let songURL = captureRoot.appendingPathComponent("SONG_0086")
        guard FileManager.default.fileExists(atPath: songURL.path) else { return }

        let project = try ProjectPreviewBuilder().build(folderURL: songURL)

        // No mutes set; all three EDL entries [ZZ0002_1.wav, ZZ0001_1.wav, ZZ0000_1.wav]
        // should be playable in EDL order. WAVs are now assigned to tracks, so verify
        // via the engine which combines assigned-track output and planner for unassigned.
        let playable = StereoPreviewEngine.playableRegionSourceFilenames(for: project)
        #expect(playable == ["ZZ0002_1.wav", "ZZ0001_1.wav", "ZZ0000_1.wav"])
    }

    @Test func song0090Track2MuteSuppressesMiddleEDLEntry() throws {
        let songURL = captureRoot.appendingPathComponent("SONG_0090")
        guard FileManager.default.fileExists(atPath: songURL.path) else { return }

        let project = try ProjectPreviewBuilder().build(folderURL: songURL)

        // EDL order: [ZZ0002_1.wav, ZZ0001_1.wav, ZZ0000_1.wav].
        // Track 2 mute byte 0x01 at 0x0269. With track assignment, track 2 holds
        // ZZ0001_1.wav and the engine suppresses it directly via isMuted.
        // Evidence: Observed (SONG_0090).
        let playable = StereoPreviewEngine.playableRegionSourceFilenames(for: project)
        #expect(playable == ["ZZ0002_1.wav", "ZZ0000_1.wav"])
        #expect(!playable.contains("ZZ0001_1.wav"))
    }

    @Test func song0084PreviewKeepsOnlyActiveVirtualTake2() throws {
        let songURL = captureRoot.appendingPathComponent("SONG_0084")
        guard FileManager.default.fileExists(atPath: songURL.path) else {
            return
        }

        let project = try ProjectPreviewBuilder().build(folderURL: songURL)

        #expect(StereoPreviewEngine.playableRegionSourceFilenames(for: project) == ["ZZ0002_1.wav"])
    }

    @Test func captureMixerBytesMatchCorrelatedTrack1AndTrack2Offsets() throws {
        guard FileManager.default.fileExists(atPath: captureRoot.path) else {
            return
        }

        try expectTrack1(song: "SONG_0068", level: 0x00, pan: 0x40, mute: 0x00)
        try expectTrack1(song: "SONG_0069", level: 0x11, pan: 0x40, mute: 0x00)
        try expectTrack1(song: "SONG_0070", level: 0x69, pan: 0x40, mute: 0x00)
        try expectTrack1(song: "SONG_0071", level: 0x7F, pan: 0x40, mute: 0x00)
        try expectTrack1(song: "SONG_0072", level: 0x00, pan: 0x01, mute: 0x00)
        try expectTrack1(song: "SONG_0074", level: 0x00, pan: 0x7F, mute: 0x00)
        try expectTrack1(song: "SONG_0075", level: 0x00, pan: 0x40, mute: 0x01)

        let song0090 = try parseSong(captureRoot.appendingPathComponent("SONG_0090"))
        #expect(song0090[1].pan.primaryByte == 0x40)
        #expect(song0090[1].mute?.primaryOffset == 0x0269)
        #expect(song0090[1].mute?.primaryByte == 0x01)
        #expect(song0090[1].mute?.mirrorOffset == 0x0A2E)
        #expect(song0090[1].mute?.mirrorByte == 0x01)

        let song0091 = try parseSong(captureRoot.appendingPathComponent("SONG_0091"))
        #expect(song0091[0].pan.primaryByte == 0x01)
        #expect(song0091[1].pan.primaryByte == 0x7F)
    }

    @Test func delayedCapturesExpose44100DomainTimelineCandidates() throws {
        guard FileManager.default.fileExists(atPath: captureRoot.path) else {
            return
        }

        #expect(try parseEdl(captureRoot.appendingPathComponent("SONG_0077")).timelineAnchors.contains(441_000))
        #expect(try parseEdl(captureRoot.appendingPathComponent("SONG_0078")).timelineAnchors == [441_000, 882_000])
        #expect(try parseEdl(captureRoot.appendingPathComponent("SONG_0079")).timelineAnchors == [441_000])
        #expect(try parseEdl(captureRoot.appendingPathComponent("SONG_0088")).timelineAnchors == [2_646_000])
    }

    @MainActor
    @Test func loadingLocalDeviceCapturesDoesNotModifyCopiedFolders() async throws {
        guard let songURLs = try? FileManager.default.contentsOfDirectory(
            at: captureRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for songURL in songURLs where songURL.lastPathComponent.hasPrefix("SONG_") {
            let before = try FileReadOnlyGuard.snapshot(of: songURL)
            _ = try await ProjectFolderLoader().loadProject(at: songURL)
            let after = try FileReadOnlyGuard.snapshot(of: songURL)

            #expect(after == before, "\(songURL.lastPathComponent) should remain unchanged")
        }
    }

    private func expectTrack1(song: String, level: UInt8, pan: UInt8, mute: UInt8) throws {
        let tracks = try parseSong(captureRoot.appendingPathComponent(song))

        #expect(tracks[0].level.primaryByte == level)
        #expect(tracks[0].level.mirrorByte == level)
        #expect(tracks[0].pan.primaryByte == pan)
        #expect(tracks[0].pan.mirrorByte == pan)
        #expect(tracks[0].mute?.primaryByte == mute)
        #expect(tracks[0].mute?.mirrorByte == mute)
    }

    private func parseSong(_ songURL: URL) throws -> [TrackMixerSetting] {
        try SongSysParser().parse(Data(contentsOf: songURL.appendingPathComponent("song.sys"), options: .mappedIfSafe))
    }

    private func parseEdl(_ songURL: URL) throws -> EdlTableSummary {
        try EdlTableParser().parse(Data(contentsOf: songURL.appendingPathComponent("edltable.sys"), options: .mappedIfSafe))
    }
}
