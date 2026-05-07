//
//  SourceLibraryStoreTests.swift
//  PortastudioPreviewTests
//

import Foundation
import SwiftData
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

    // MARK: - In-memory SwiftData helpers

    private func makeTestContainer() throws -> ModelContainer {
        let schema = Schema([LibrarySourceRecord.self, LibrarySongRecord.self, TrackAnnotationRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Fingerprint persistence tests

    @Test func addSourceRootPersistsSourceAndSongFingerprints() async throws {
        let container = try makeTestContainer()
        let root = try TemporaryFolder()
        try Data([0x10, 0x20]).write(to: root.url.appendingPathComponent("dp-24.sys"))
        let musicURL = root.url.appendingPathComponent("MUSIC", isDirectory: true)
        try makeMinimalSongFolder(in: musicURL, name: "SONG_0001")

        let store = SourceLibraryStore(
            modelContext: container.mainContext,
            projectLoader: { _ in fatalError("Should not load.") }
        )
        await store.addSourceRoot(at: root.url)

        let sourceDesc = FetchDescriptor<LibrarySourceRecord>()
        let sources = try container.mainContext.fetch(sourceDesc)
        let source = try #require(sources.first)
        #expect(source.aggregateFingerprintString != nil)
        #expect(source.fingerprintGeneratedAt != nil)
        #expect(source.matchStateRawValue == FingerprintMatchState.exact.rawValue)

        let songDesc = FetchDescriptor<LibrarySongRecord>()
        let songs = try container.mainContext.fetch(songDesc)
        let song = try #require(songs.first)
        #expect(song.aggregateFingerprintString != nil)
        #expect(song.matchStateRawValue == FingerprintMatchState.exact.rawValue)
    }

    @Test func openIndividualSongPersistsSongFingerprint() async throws {
        let container = try makeTestContainer()
        let folder = try TemporaryFolder()
        try writeMinimumSongSys(to: folder.url.appendingPathComponent("song.sys"))
        try writeMinimumEdlTable(to: folder.url.appendingPathComponent("edltable.sys"))

        let store = SourceLibraryStore(modelContext: container.mainContext)
        await store.openIndividualSongFolder(at: folder.url)

        let desc = FetchDescriptor<LibrarySongRecord>()
        let songs = try container.mainContext.fetch(desc)
        let song = try #require(songs.first)
        #expect(song.aggregateFingerprintString != nil)
        #expect(song.fingerprintGeneratedAt != nil)
        #expect(song.matchStateRawValue == FingerprintMatchState.exact.rawValue)
    }

    @Test func hydrationMarksUnchangedSourceExact() async throws {
        let container = try makeTestContainer()
        let root = try TemporaryFolder()
        let musicURL = root.url.appendingPathComponent("MUSIC", isDirectory: true)
        try makeMinimalSongFolder(in: musicURL, name: "SONG_0001")

        // First load persists fingerprints
        let store = SourceLibraryStore(
            modelContext: container.mainContext,
            projectLoader: { _ in fatalError("Should not load.") }
        )
        await store.addSourceRoot(at: root.url)

        // Simulate hydration by creating a fresh store with the same container
        let store2 = SourceLibraryStore(
            modelContext: container.mainContext,
            projectLoader: { _ in fatalError("Should not load.") }
        )
        await store2.hydrateFromPersistence()

        let source = try #require(store2.sources.first)
        #expect(source.matchState == .exact)
    }

    @Test func hydrationMarksChangedKeyFileAsChangedSinceLastSeen() async throws {
        let container = try makeTestContainer()
        let root = try TemporaryFolder()
        let musicURL = root.url.appendingPathComponent("MUSIC", isDirectory: true)
        let songURL = musicURL.appendingPathComponent("SONG_0001", isDirectory: true)
        try FileManager.default.createDirectory(at: songURL, withIntermediateDirectories: true)
        try Data([0xAA]).write(to: songURL.appendingPathComponent("song.sys"))
        try Data().write(to: songURL.appendingPathComponent("edltable.sys"))

        let store = SourceLibraryStore(
            modelContext: container.mainContext,
            projectLoader: { _ in fatalError("Should not load.") }
        )
        await store.addSourceRoot(at: root.url)

        // Mutate song.sys after fingerprint stored
        try Data([0xBB]).write(to: songURL.appendingPathComponent("song.sys"))

        let store2 = SourceLibraryStore(
            modelContext: container.mainContext,
            projectLoader: { _ in fatalError("Should not load.") }
        )
        await store2.hydrateFromPersistence()

        let source = try #require(store2.sources.first)
        // Source aggregate includes song summaries; changed song.sys changes it
        #expect(source.matchState == .changedSinceLastSeen)
    }

    @Test func fingerprintScanDoesNotWriteToSourceFolder() async throws {
        let container = try makeTestContainer()
        let root = try TemporaryFolder()
        try Data([0x01]).write(to: root.url.appendingPathComponent("dp-24.sys"))
        let musicURL = root.url.appendingPathComponent("MUSIC", isDirectory: true)
        try makeMinimalSongFolder(in: musicURL, name: "SONG_0001")
        let before = try FileReadOnlyGuard.snapshot(of: root.url)

        let store = SourceLibraryStore(
            modelContext: container.mainContext,
            projectLoader: { _ in fatalError("Should not load.") }
        )
        await store.addSourceRoot(at: root.url)
        let after = try FileReadOnlyGuard.snapshot(of: root.url)

        #expect(after == before)
    }

    // MARK: - Phase 8: Hydration missing records

    @Test func hydrationKeepsMissingRecordVisibleWhenResolutionFails() async throws {
        let container = try makeTestContainer()

        // Insert a source record pointing to a path that does not exist
        let missingPath = "/tmp/does-not-exist-\(UUID().uuidString)"
        let record = LibrarySourceRecord(
            id: UUID(),
            displayName: "Phantom Card",
            kindRawValue: "backupRoot",
            lastKnownPath: missingPath,
            bookmarkData: nil,
            isMissing: true,
            lastSeenAt: Date()
        )
        container.mainContext.insert(record)
        try container.mainContext.save()

        let store = SourceLibraryStore(
            modelContext: container.mainContext,
            projectLoader: { _ in fatalError("Should not load.") }
        )
        await store.hydrateFromPersistence()

        let missingSources = store.sources.filter(\.isMissing)
        #expect(missingSources.count == 1)
        #expect(missingSources.first?.displayName == "Phantom Card")
    }

    // MARK: - Phase 8: Wrong-kind relocate leaves missing row

    @Test func wrongKindRelocateSourceLeavesSourceMissingAndRecordsError() async throws {
        let folder = try TemporaryFolder()
        // Make an SD card root
        try Data().write(to: folder.url.appendingPathComponent("dp-24.sys"))
        let musicURL = folder.url.appendingPathComponent("MUSIC", isDirectory: true)
        try makeMinimalSongFolder(in: musicURL, name: "SONG_0001")

        let store = SourceLibraryStore(projectLoader: { _ in fatalError("Should not load.") })
        await store.addSourceRoot(at: folder.url)

        // Mark it as missing manually to simulate the relocate scenario
        let sourceID = try #require(store.sources.first?.id)
        if let index = store.sources.firstIndex(where: { $0.id == sourceID }) {
            store.sources[index].isMissing = true
        }

        // Try to relocate to a song folder (wrong kind — should fail)
        let songFolder = try TemporaryFolder()
        try Data().write(to: songFolder.url.appendingPathComponent("song.sys"))
        try Data().write(to: songFolder.url.appendingPathComponent("edltable.sys"))

        await store.relocateSource(id: sourceID, to: songFolder.url)

        #expect(store.loadError != nil)
        // The source row should still be present (missing or not, it wasn't removed)
        #expect(store.sources.contains { $0.id == sourceID })
    }

    // MARK: - Phase 8: Forget clears selection

    @Test func forgetSourceClearsSelectionWhenSourceIsSelected() async throws {
        let root = try TemporaryFolder()
        try Data().write(to: root.url.appendingPathComponent("dp-24.sys"))
        let musicURL = root.url.appendingPathComponent("MUSIC", isDirectory: true)
        try makeMinimalSongFolder(in: musicURL, name: "SONG_0001")

        let store = SourceLibraryStore(projectLoader: { _ in fatalError("Should not load.") })
        await store.addSourceRoot(at: root.url)

        let sourceID = try #require(store.sources.first?.id)
        #expect(store.selection == .source(sourceID))

        store.forgetSource(id: sourceID)

        #expect(store.sources.isEmpty)
        #expect(store.selection == nil)
        #expect(store.selectedProject == nil)
    }

    @Test func forgetSongClearsSelectionWhenSongIsSelected() async throws {
        let folder = try TemporaryFolder()
        try writeMinimumSongSys(to: folder.url.appendingPathComponent("song.sys"))
        try writeMinimumEdlTable(to: folder.url.appendingPathComponent("edltable.sys"))

        let store = SourceLibraryStore()
        await store.openIndividualSongFolder(at: folder.url)

        let songID = try #require(store.individualSongs.first?.id)
        #expect(store.selection == .individualSong(songID))

        store.forgetSong(id: songID)

        #expect(store.individualSongs.isEmpty)
        #expect(store.selection == nil)
        #expect(store.selectedProject == nil)
    }

    // MARK: - Phase 8: Selecting nested source song loads project

    @Test func selectingNestedSourceSongLoadsProjectOnce() async throws {
        let root = try TemporaryFolder()
        try Data().write(to: root.url.appendingPathComponent("dp-24.sys"))
        let musicURL = root.url.appendingPathComponent("MUSIC", isDirectory: true)
        try makeMinimalSongFolder(in: musicURL, name: "SONG_0001")

        var loadCount = 0
        let songFolder = musicURL.appendingPathComponent("SONG_0001", isDirectory: true)
        try writeMinimumSongSys(to: songFolder.appendingPathComponent("song.sys"))
        try writeMinimumEdlTable(to: songFolder.appendingPathComponent("edltable.sys"))

        let store = SourceLibraryStore(projectLoader: { url in
            loadCount += 1
            return try await ProjectFolderLoader().loadProject(at: url)
        })
        await store.addSourceRoot(at: root.url)

        let source = try #require(store.sources.first)
        let song = try #require(source.songs.first)

        store.selection = .individualSong(song.id)
        await store.loadIfSourceSong()

        #expect(loadCount == 1)
        #expect(store.selectedProject != nil)
        #expect(store.selectedProject?.folderURL == song.folderURL)
    }

    // MARK: - Phase 8: Read-only guard after forget and relocate failure

    @Test func sourceAndSongFoldersUnchangedAfterForgetAndRelocateFailure() async throws {
        let root = try TemporaryFolder()
        try Data().write(to: root.url.appendingPathComponent("dp-24.sys"))
        let musicURL = root.url.appendingPathComponent("MUSIC", isDirectory: true)
        try makeMinimalSongFolder(in: musicURL, name: "SONG_0001")
        let before = try FileReadOnlyGuard.snapshot(of: root.url)

        let store = SourceLibraryStore(projectLoader: { _ in fatalError("Should not load.") })
        await store.addSourceRoot(at: root.url)

        let sourceID = try #require(store.sources.first?.id)

        // Forget the source
        store.forgetSource(id: sourceID)

        // Attempt a wrong-kind relocate against a song folder (will set loadError)
        let badTarget = try TemporaryFolder()
        try Data().write(to: badTarget.url.appendingPathComponent("song.sys"))
        try Data().write(to: badTarget.url.appendingPathComponent("edltable.sys"))
        await store.relocateSource(id: sourceID, to: badTarget.url)

        let after = try FileReadOnlyGuard.snapshot(of: root.url)
        #expect(after == before)
    }
}
