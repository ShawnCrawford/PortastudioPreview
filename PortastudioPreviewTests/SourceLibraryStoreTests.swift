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

    private func writeMinimumSongSys(to url: URL) throws {
        try Data(count: MixerMapOffsets.minimumSongSysLength).write(to: url)
    }

    private func writeMinimumEdlTable(to url: URL) throws {
        try Data(count: EdlTableParser.track1ActiveTakeCandidateOffset + 1).write(to: url)
    }
}
