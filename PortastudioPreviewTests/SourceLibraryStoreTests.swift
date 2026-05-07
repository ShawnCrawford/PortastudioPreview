//
//  SourceLibraryStoreTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

@MainActor
struct SourceLibraryStoreTests {
    @Test func initialStateHasEmptySections() {
        let store = SourceLibraryStore()

        #expect(store.sources.isEmpty)
        #expect(store.individualSongs.isEmpty)
        #expect(store.missingItems.isEmpty)
        #expect(store.selection == nil)
        #expect(store.selectedProject == nil)
        #expect(store.loadError == nil)
    }

    @Test func successfulOpenInsertsSelectsAndExposesLoadedProject() async throws {
        let folder = try TemporaryFolder()
        try writeMinimumSongSys(to: folder.url.appendingPathComponent("song.sys"))
        try writeMinimumEdlTable(to: folder.url.appendingPathComponent("edltable.sys"))

        let store = SourceLibraryStore()
        await store.openIndividualSongFolder(at: folder.url)

        #expect(store.individualSongs.count == 1)
        #expect(store.selectedProject?.folderURL == folder.url)
        #expect(store.loadError == nil)

        guard let song = store.individualSongs.first else {
            Issue.record("Expected one individual song row.")
            return
        }

        #expect(store.selection == .individualSong(song.id))
        #expect(song.loadState == .loaded)
    }

    @Test func reopeningSameFolderUpdatesAndSelectsExistingRow() async throws {
        let folder = try TemporaryFolder()
        try writeMinimumSongSys(to: folder.url.appendingPathComponent("song.sys"))
        try writeMinimumEdlTable(to: folder.url.appendingPathComponent("edltable.sys"))

        let store = SourceLibraryStore()
        await store.openIndividualSongFolder(at: folder.url)
        let firstID = try #require(store.individualSongs.first?.id)

        await store.openIndividualSongFolder(at: folder.url)
        let secondID = try #require(store.individualSongs.first?.id)

        #expect(store.individualSongs.count == 1)
        #expect(firstID == secondID)
        #expect(store.selection == .individualSong(secondID))
    }

    @Test func loadFailureRecordsErrorWithoutWritingToSelectedFolder() async throws {
        let folder = try TemporaryFolder()
        let selectedSongFolder = folder.url.appendingPathComponent("SONG_FAIL", isDirectory: true)
        try FileManager.default.createDirectory(at: selectedSongFolder, withIntermediateDirectories: true)
        try writeMinimumSongSys(to: selectedSongFolder.appendingPathComponent("song.sys"))
        try writeMinimumEdlTable(to: selectedSongFolder.appendingPathComponent("edltable.sys"))
        let before = try FileReadOnlyGuard.snapshot(of: folder.url)

        struct SyntheticLoadFailure: LocalizedError {
            var errorDescription: String? { "Synthetic load failure for testing." }
        }

        let store = SourceLibraryStore(projectLoader: { _ in
            throw SyntheticLoadFailure()
        })
        await store.openIndividualSongFolder(at: selectedSongFolder)
        let after = try FileReadOnlyGuard.snapshot(of: folder.url)

        #expect(after == before)
        #expect(store.selectedProject == nil)
        #expect(store.loadError != nil)
        #expect(store.individualSongs.count == 1)
    }

    @Test func addMediaRootCreatesOneSourceWithNestedSongs() async throws {
        let root = try TemporaryFolder()
        try Data().write(to: root.url.appendingPathComponent("dp-24.sys"))
        let musicURL = root.url.appendingPathComponent("MUSIC", isDirectory: true)
        try makeMinimalSongFolder(in: musicURL, name: "SONG_0001")
        try makeMinimalSongFolder(in: musicURL, name: "SONG_0002")

        let store = SourceLibraryStore(projectLoader: { _ in fatalError("Should not load songs automatically.") })
        await store.addSourceRoot(at: root.url)

        #expect(store.sources.count == 1)
        #expect(store.individualSongs.isEmpty)
        let source = try #require(store.sources.first)
        #expect(source.kind == .mediaRoot)
        #expect(source.songs.count == 2)
        #expect(store.loadError == nil)
        #expect(store.selection == .source(source.id))
    }

    @Test func addBackupRootCreatesBackupSourceRow() async throws {
        let root = try TemporaryFolder()
        let musicURL = root.url.appendingPathComponent("MUSIC", isDirectory: true)
        try makeMinimalSongFolder(in: musicURL, name: "SONG_0001")

        let store = SourceLibraryStore(projectLoader: { _ in fatalError("Should not load songs automatically.") })
        await store.addSourceRoot(at: root.url)

        let source = try #require(store.sources.first)
        #expect(source.kind == .backupRoot)
        #expect(store.loadError == nil)
    }

    @Test func reopeningSameSourceRootUpdatesRowWithoutDuplicate() async throws {
        let root = try TemporaryFolder()
        try Data().write(to: root.url.appendingPathComponent("dp-24.sys"))
        let musicURL = root.url.appendingPathComponent("MUSIC", isDirectory: true)
        try makeMinimalSongFolder(in: musicURL, name: "SONG_0001")

        let store = SourceLibraryStore(projectLoader: { _ in fatalError("Should not load songs.") })
        await store.addSourceRoot(at: root.url)
        let firstID = try #require(store.sources.first?.id)

        try makeMinimalSongFolder(in: musicURL, name: "SONG_0002")
        await store.addSourceRoot(at: root.url)
        let secondID = try #require(store.sources.first?.id)

        #expect(store.sources.count == 1)
        #expect(firstID == secondID)
        #expect(store.sources.first?.songs.count == 2)
    }

    @Test func openingIndividualSongStillInsertsAndSelectsStandaloneSong() async throws {
        let folder = try TemporaryFolder()
        try writeMinimumSongSys(to: folder.url.appendingPathComponent("song.sys"))
        try writeMinimumEdlTable(to: folder.url.appendingPathComponent("edltable.sys"))

        let store = SourceLibraryStore()
        await store.openIndividualSongFolder(at: folder.url)

        #expect(store.individualSongs.count == 1)
        #expect(store.sources.isEmpty)
        #expect(store.selectedProject?.folderURL == folder.url)
    }

    @Test func unsupportedFolderRecordsErrorAndLeavesLibraryStateUnchanged() async throws {
        let folder = try TemporaryFolder()
        // No song.sys, edltable.sys, or MUSIC/ — classifier returns .unsupported

        let store = SourceLibraryStore()
        await store.addSourceRoot(at: folder.url)

        #expect(store.sources.isEmpty)
        #expect(store.individualSongs.isEmpty)
        #expect(store.loadError != nil)
        #expect(store.selection == nil)
    }

    @Test func addSourceRootDoesNotWriteToSelectedFolder() async throws {
        let root = try TemporaryFolder()
        try Data().write(to: root.url.appendingPathComponent("dp-24.sys"))
        let musicURL = root.url.appendingPathComponent("MUSIC", isDirectory: true)
        try makeMinimalSongFolder(in: musicURL, name: "SONG_0001")
        let before = try FileReadOnlyGuard.snapshot(of: root.url)

        let store = SourceLibraryStore(projectLoader: { _ in fatalError("Should not load songs.") })
        await store.addSourceRoot(at: root.url)
        let after = try FileReadOnlyGuard.snapshot(of: root.url)

        #expect(after == before)
    }

    private func makeMinimalSongFolder(in musicURL: URL, name: String) throws {
        let songURL = musicURL.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: songURL, withIntermediateDirectories: true)
        try Data().write(to: songURL.appendingPathComponent("song.sys"))
        try Data().write(to: songURL.appendingPathComponent("edltable.sys"))
    }

    private func writeMinimumSongSys(to url: URL) throws {
        try Data(count: MixerMapOffsets.minimumSongSysLength).write(to: url)
    }

    private func writeMinimumEdlTable(to url: URL) throws {
        try Data(count: EdlTableParser.track1ActiveTakeCandidateOffset + 1).write(to: url)
    }
}
