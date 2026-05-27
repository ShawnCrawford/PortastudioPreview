//
//  TrackAnnotationStoreTests.swift
//  PortastudioPreviewTests
//

import Foundation
import SwiftData
import Testing
@testable import PortastudioPreview

@MainActor
struct TrackAnnotationStoreTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([LibrarySourceRecord.self, LibrarySongRecord.self, TrackAnnotationRecord.self, MixOverrideRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func makeContext(fingerprint: String = "fp-test-001") -> SongAnnotationContext {
        SongAnnotationContext(
            songRecordID: UUID(),
            songFingerprintString: fingerprint,
            folderURL: URL(fileURLWithPath: "/tmp/SONG_0001"),
            folderDerivedDisplayName: "SONG_0001",
            displayNameOverride: nil,
            matchState: .exact
        )
    }

    // MARK: - Empty context

    @Test func emptyContextReturnsNoLabels() throws {
        let container = try makeContainer()
        let store = TrackAnnotationStore(modelContext: container.mainContext)
        store.load(context: nil)

        #expect(store.trackName(for: 1) == nil)
        #expect(store.trackName(for: 16) == nil)
    }

    // MARK: - Save and fetch

    @Test func savingTrackNameCreatesOneRecord() throws {
        let container = try makeContainer()
        let store = TrackAnnotationStore(modelContext: container.mainContext)
        store.load(context: makeContext())

        store.setTrackName("Drums", for: 1)

        #expect(store.trackName(for: 1) == "Drums")

        let desc = FetchDescriptor<TrackAnnotationRecord>()
        let records = try container.mainContext.fetch(desc)
        #expect(records.count == 1)
        #expect(records.first?.trackName == "Drums")
        #expect(records.first?.trackNumber == 1)
    }

    @Test func savingTrackNameTrimsWhitespace() throws {
        let container = try makeContainer()
        let store = TrackAnnotationStore(modelContext: container.mainContext)
        store.load(context: makeContext())

        store.setTrackName("  Bass  ", for: 2)

        #expect(store.trackName(for: 2) == "Bass")
    }

    // MARK: - Upsert

    @Test func savingTheSameTrackAgainUpdatesExistingRecord() throws {
        let container = try makeContainer()
        let store = TrackAnnotationStore(modelContext: container.mainContext)
        store.load(context: makeContext())

        store.setTrackName("Drums", for: 1)
        store.setTrackName("Kick", for: 1)

        #expect(store.trackName(for: 1) == "Kick")

        let desc = FetchDescriptor<TrackAnnotationRecord>()
        let records = try container.mainContext.fetch(desc)
        #expect(records.count == 1)
        #expect(records.first?.trackName == "Kick")
    }

    // MARK: - Clear

    @Test func clearingATrackNameRemovesTheRecord() throws {
        let container = try makeContainer()
        let store = TrackAnnotationStore(modelContext: container.mainContext)
        store.load(context: makeContext())

        store.setTrackName("Guitar", for: 3)
        #expect(store.trackName(for: 3) == "Guitar")

        store.clearTrackName(for: 3)
        #expect(store.trackName(for: 3) == nil)

        let desc = FetchDescriptor<TrackAnnotationRecord>()
        let records = try container.mainContext.fetch(desc)
        #expect(records.isEmpty)
    }

    @Test func savingEmptyStringActsAsClear() throws {
        let container = try makeContainer()
        let store = TrackAnnotationStore(modelContext: container.mainContext)
        store.load(context: makeContext())

        store.setTrackName("Vocals", for: 4)
        store.setTrackName("   ", for: 4)

        #expect(store.trackName(for: 4) == nil)
    }

    // MARK: - Track number isolation

    @Test func differentTrackNumbersDoNotCollide() throws {
        let container = try makeContainer()
        let store = TrackAnnotationStore(modelContext: container.mainContext)
        store.load(context: makeContext())

        store.setTrackName("Track One", for: 1)
        store.setTrackName("Track Two", for: 2)

        #expect(store.trackName(for: 1) == "Track One")
        #expect(store.trackName(for: 2) == "Track Two")
        #expect(store.trackName(for: 3) == nil)
    }

    // MARK: - Cross-song isolation

    @Test func labelsWithDifferentFingerprintsDoNotBleedAcrossSongs() throws {
        let container = try makeContainer()

        let storeA = TrackAnnotationStore(modelContext: container.mainContext)
        storeA.load(context: makeContext(fingerprint: "fp-song-A"))
        storeA.setTrackName("Snare", for: 1)

        let storeB = TrackAnnotationStore(modelContext: container.mainContext)
        storeB.load(context: makeContext(fingerprint: "fp-song-B"))
        storeB.setTrackName("Hat", for: 1)

        // Reload A fresh from persistence
        let storeA2 = TrackAnnotationStore(modelContext: container.mainContext)
        storeA2.load(context: makeContext(fingerprint: "fp-song-A"))
        #expect(storeA2.trackName(for: 1) == "Snare")

        // Reload B fresh from persistence
        let storeB2 = TrackAnnotationStore(modelContext: container.mainContext)
        storeB2.load(context: makeContext(fingerprint: "fp-song-B"))
        #expect(storeB2.trackName(for: 1) == "Hat")
    }

    // MARK: - Persistence reload

    @Test func reloadedStorePreviouslySavedLabels() throws {
        let container = try makeContainer()
        let ctx = makeContext(fingerprint: "fp-persist-001")

        let store1 = TrackAnnotationStore(modelContext: container.mainContext)
        store1.load(context: ctx)
        store1.setTrackName("Keys", for: 5)

        let store2 = TrackAnnotationStore(modelContext: container.mainContext)
        store2.load(context: ctx)

        #expect(store2.trackName(for: 5) == "Keys")
    }

    // MARK: - Non-editable context

    @Test func missingFingerprintDisablesWrites() throws {
        let container = try makeContainer()
        let store = TrackAnnotationStore(modelContext: container.mainContext)
        let emptyFPContext = SongAnnotationContext(
            songRecordID: UUID(),
            songFingerprintString: "",
            folderURL: URL(fileURLWithPath: "/tmp/SONG_NO_FP"),
            folderDerivedDisplayName: "SONG_NO_FP",
            displayNameOverride: nil,
            matchState: .unknown
        )
        store.load(context: emptyFPContext)

        store.setTrackName("Should Not Save", for: 1)

        #expect(store.trackName(for: 1) == nil)

        let desc = FetchDescriptor<TrackAnnotationRecord>()
        let records = try container.mainContext.fetch(desc)
        #expect(records.isEmpty)
    }

    @Test func changedFingerprintContextIsNotEditable() throws {
        let container = try makeContainer()
        let store = TrackAnnotationStore(modelContext: container.mainContext)
        let changedCtx = SongAnnotationContext(
            songRecordID: UUID(),
            songFingerprintString: "fp-changed",
            folderURL: URL(fileURLWithPath: "/tmp/SONG_CHANGED"),
            folderDerivedDisplayName: "SONG_CHANGED",
            displayNameOverride: nil,
            matchState: .changedSinceLastSeen
        )
        store.load(context: changedCtx)

        store.setTrackName("Should Not Save", for: 1)

        #expect(store.trackName(for: 1) == nil)
    }

    // MARK: - Song display name override

    @Test func songDisplayNameOverridePersistsAndFallsBack() throws {
        let container = try makeContainer()

        // Insert a LibrarySongRecord so the override can be stored
        let songRecord = LibrarySongRecord(
            id: UUID(),
            displayName: "SONG_0001",
            lastKnownPath: "/tmp/SONG_0001",
            isStandalone: true
        )
        container.mainContext.insert(songRecord)
        try container.mainContext.save()

        let ctx = SongAnnotationContext(
            songRecordID: songRecord.id,
            songFingerprintString: "fp-display-test",
            folderURL: URL(fileURLWithPath: "/tmp/SONG_0001"),
            folderDerivedDisplayName: "SONG_0001",
            displayNameOverride: nil,
            matchState: .exact
        )

        let store = TrackAnnotationStore(modelContext: container.mainContext)
        store.load(context: ctx)
        store.setSongDisplayNameOverride("My Band Demo")

        #expect(store.annotationContext?.displayNameOverride == "My Band Demo")
        #expect(store.annotationContext?.effectiveDisplayName == "My Band Demo")

        // Verify the record was updated in SwiftData
        let desc = FetchDescriptor<LibrarySongRecord>()
        let records = try container.mainContext.fetch(desc)
        #expect(records.first?.displayNameOverride == "My Band Demo")

        // Clear the override
        store.setSongDisplayNameOverride(nil)
        #expect(store.annotationContext?.displayNameOverride == nil)
        #expect(store.annotationContext?.effectiveDisplayName == "SONG_0001")
    }

    // MARK: - Read-only source folder guarantee

    @Test func editingLabelsDoesNotModifySourceFolder() throws {
        let container = try makeContainer()
        let folder = try TemporaryFolder()

        // Write minimal song files to simulate a real song folder
        try Data(count: 512).write(to: folder.url.appendingPathComponent("song.sys"))
        try Data(count: 64).write(to: folder.url.appendingPathComponent("edltable.sys"))

        let before = try FileReadOnlyGuard.snapshot(of: folder.url)

        let ctx = SongAnnotationContext(
            songRecordID: UUID(),
            songFingerprintString: "fp-readonly-guard",
            folderURL: folder.url,
            folderDerivedDisplayName: folder.url.lastPathComponent,
            displayNameOverride: nil,
            matchState: .exact
        )

        let store = TrackAnnotationStore(modelContext: container.mainContext)
        store.load(context: ctx)
        store.setTrackName("Test Track", for: 1)
        store.clearTrackName(for: 1)

        let after = try FileReadOnlyGuard.snapshot(of: folder.url)
        #expect(after == before)
    }

    // MARK: - Phase 8: Nil context disables writes

    @Test func nilContextDisablesAllWrites() throws {
        let container = try makeContainer()
        let store = TrackAnnotationStore(modelContext: container.mainContext)
        store.load(context: nil)

        store.setTrackName("Should Not Save", for: 1)

        #expect(store.trackName(for: 1) == nil)

        let desc = FetchDescriptor<TrackAnnotationRecord>()
        let records = try container.mainContext.fetch(desc)
        #expect(records.isEmpty)
    }

    // MARK: - Phase 8: Ambiguous match state disables writes

    @Test func ambiguousMatchStateDisablesWrites() throws {
        let container = try makeContainer()
        let store = TrackAnnotationStore(modelContext: container.mainContext)
        let ambiguousCtx = SongAnnotationContext(
            songRecordID: UUID(),
            songFingerprintString: "fp-ambiguous",
            folderURL: URL(fileURLWithPath: "/tmp/SONG_AMBIGUOUS"),
            folderDerivedDisplayName: "SONG_AMBIGUOUS",
            displayNameOverride: nil,
            matchState: .ambiguous
        )
        store.load(context: ambiguousCtx)

        store.setTrackName("Should Not Save", for: 1)

        #expect(store.trackName(for: 1) == nil)

        let desc = FetchDescriptor<TrackAnnotationRecord>()
        let records = try container.mainContext.fetch(desc)
        #expect(records.isEmpty)
    }

    // MARK: - Phase 8: Clearing labels is app-owned only

    @Test func clearingLabelsAndDisplayNameOverrideIsAppOwnedOnly() throws {
        let container = try makeContainer()

        let songRecord = LibrarySongRecord(
            id: UUID(),
            displayName: "SONG_0001",
            lastKnownPath: "/tmp/SONG_0001",
            isStandalone: true
        )
        container.mainContext.insert(songRecord)
        try container.mainContext.save()

        let folder = try TemporaryFolder()
        try Data(count: 64).write(to: folder.url.appendingPathComponent("song.sys"))

        let before = try FileReadOnlyGuard.snapshot(of: folder.url)

        let ctx = SongAnnotationContext(
            songRecordID: songRecord.id,
            songFingerprintString: "fp-clear-test",
            folderURL: folder.url,
            folderDerivedDisplayName: "SONG_0001",
            displayNameOverride: nil,
            matchState: .exact
        )

        let store = TrackAnnotationStore(modelContext: container.mainContext)
        store.load(context: ctx)
        store.setTrackName("Bass", for: 2)
        store.setSongDisplayNameOverride("My Session")
        store.clearTrackName(for: 2)
        store.setSongDisplayNameOverride(nil)

        let after = try FileReadOnlyGuard.snapshot(of: folder.url)
        #expect(after == before)

        // All writes went to SwiftData, not the source folder
        let annDesc = FetchDescriptor<TrackAnnotationRecord>()
        let records = try container.mainContext.fetch(annDesc)
        #expect(records.isEmpty) // cleared
        let songDesc = FetchDescriptor<LibrarySongRecord>()
        let songs = try container.mainContext.fetch(songDesc)
        #expect(songs.first?.displayNameOverride == nil) // cleared
    }
}
