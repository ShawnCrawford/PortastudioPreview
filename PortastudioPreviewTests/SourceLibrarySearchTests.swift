//
//  SourceLibrarySearchTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct SourceLibrarySearchTests {

    // MARK: - Helpers

    private func makeSource(
        displayName: String,
        kind: SourceKind = .backupRoot,
        path: String = "/tmp/sources/\(UUID().uuidString)",
        songs: [SourceLibrarySong] = [],
        isMissing: Bool = false
    ) -> SourceLibrarySource {
        SourceLibrarySource(
            folderURL: URL(fileURLWithPath: path),
            kind: kind,
            displayName: displayName,
            songs: songs,
            isMissing: isMissing
        )
    }

    private func makeSong(
        displayName: String,
        path: String = "/tmp/songs/\(UUID().uuidString)",
        isMissing: Bool = false,
        sourceID: UUID? = nil
    ) -> SourceLibrarySong {
        SourceLibrarySong(
            folderURL: URL(fileURLWithPath: path),
            displayName: displayName,
            loadState: .loaded,
            isMissing: isMissing,
            sourceID: sourceID
        )
    }

    private func makeMissingItem(displayName: String, detail: String? = nil) -> SourceLibraryMissingItem {
        SourceLibraryMissingItem(displayName: displayName, detail: detail)
    }

    // MARK: - Empty / blank search

    @Test func emptySearchTextReturnsAllItems() {
        let sources = [makeSource(displayName: "Card"), makeSource(displayName: "Backup")]
        let songs = [makeSong(displayName: "Song A")]
        let missing = [makeMissingItem(displayName: "Missing 1")]

        let result = SourceLibrarySearch.filter(
            sources: sources, individualSongs: songs, missingItems: missing, searchText: ""
        )

        #expect(result.sources.count == sources.count)
        #expect(result.individualSongs.count == songs.count)
        #expect(result.missingItems.count == missing.count)
    }

    @Test func whitespaceOnlySearchTextReturnsAllItems() {
        let sources = [makeSource(displayName: "Card")]
        let result = SourceLibrarySearch.filter(
            sources: sources, individualSongs: [], missingItems: [], searchText: "   "
        )
        #expect(result.sources.count == 1)
    }

    // MARK: - Source display name matching

    @Test func matchesSourceDisplayName() {
        let matching = makeSource(displayName: "My Recording Card")
        let nonMatching = makeSource(displayName: "Studio Backup")

        let result = SourceLibrarySearch.filter(
            sources: [matching, nonMatching], individualSongs: [], missingItems: [],
            searchText: "Recording"
        )

        #expect(result.sources.count == 1)
        #expect(result.sources.first?.id == matching.id)
    }

    @Test func matchesSourceKindLabelSDCard() {
        let sdCard = makeSource(displayName: "Card01", kind: .mediaRoot)
        let backup = makeSource(displayName: "Bkup01", kind: .backupRoot)

        let result = SourceLibrarySearch.filter(
            sources: [sdCard, backup], individualSongs: [], missingItems: [],
            searchText: "SD Card"
        )

        #expect(result.sources.count == 1)
        #expect(result.sources.first?.id == sdCard.id)
    }

    @Test func matchesSourceKindLabelBackup() {
        let sdCard = makeSource(displayName: "Card01", kind: .mediaRoot)
        let backup = makeSource(displayName: "Bkup01", kind: .backupRoot)

        let result = SourceLibrarySearch.filter(
            sources: [sdCard, backup], individualSongs: [], missingItems: [],
            searchText: "backup"
        )

        #expect(result.sources.count == 1)
        #expect(result.sources.first?.id == backup.id)
    }

    @Test func matchesSourcePathFragment() {
        let matching = makeSource(displayName: "Card", path: "/Volumes/DPSD/MUSIC")
        let nonMatching = makeSource(displayName: "Other", path: "/Users/me/recordings")

        let result = SourceLibrarySearch.filter(
            sources: [matching, nonMatching], individualSongs: [], missingItems: [],
            searchText: "DPSD"
        )

        #expect(result.sources.count == 1)
        #expect(result.sources.first?.id == matching.id)
    }

    // MARK: - Source-matched shows all children

    @Test func sourceMatchedDirectlyShowsAllChildren() {
        let song1 = makeSong(displayName: "SONG_0001")
        let song2 = makeSong(displayName: "SONG_0002")
        let source = makeSource(displayName: "MyCard", songs: [song1, song2])

        let result = SourceLibrarySearch.filter(
            sources: [source], individualSongs: [], missingItems: [],
            searchText: "MyCard"
        )

        let resultSongs = result.sources.first?.songs ?? []
        #expect(resultSongs.count == 2)
    }

    // MARK: - Nested song matching shows only matching children

    @Test func matchesNestedSongDisplayNameKeepsParentVisible() {
        let matchingSong = makeSong(displayName: "Guitar Take")
        let otherSong = makeSong(displayName: "Drum Loop")
        let source = makeSource(displayName: "MyCard", songs: [matchingSong, otherSong])

        let result = SourceLibrarySearch.filter(
            sources: [source], individualSongs: [], missingItems: [],
            searchText: "Guitar"
        )

        #expect(result.sources.count == 1)
        #expect(result.sources.first?.id == source.id)
        let resultSongs = result.sources.first?.songs ?? []
        #expect(resultSongs.count == 1)
        #expect(resultSongs.first?.id == matchingSong.id)
    }

    @Test func matchesNestedSongPathKeepsParentVisible() {
        let matchingSong = makeSong(displayName: "SONG_0001", path: "/Volumes/card/MUSIC/SONG_0001")
        let otherSong = makeSong(displayName: "SONG_0002", path: "/Volumes/card/MUSIC/SONG_0002")
        let source = makeSource(displayName: "Card", songs: [matchingSong, otherSong])

        let result = SourceLibrarySearch.filter(
            sources: [source], individualSongs: [], missingItems: [],
            searchText: "SONG_0001"
        )

        let resultSongs = result.sources.first?.songs ?? []
        #expect(resultSongs.count == 1)
        #expect(resultSongs.first?.id == matchingSong.id)
    }

    @Test func missingNestedSongIsNotIncludedInSearchResults() {
        let normalSong = makeSong(displayName: "SONG_0001")
        let missingSong = makeSong(displayName: "SONG_0002", isMissing: true)
        let source = makeSource(displayName: "Card", songs: [normalSong, missingSong])

        // Search for "SONG" — both songs have names matching, but missing song should be excluded
        let result = SourceLibrarySearch.filter(
            sources: [source], individualSongs: [], missingItems: [],
            searchText: "SONG"
        )

        let resultSongs = result.sources.first?.songs ?? []
        #expect(!resultSongs.contains { $0.isMissing })
    }

    @Test func noNestedSongMatchAndNoSourceMatchExcludesSource() {
        let source = makeSource(displayName: "Alpha Card", songs: [makeSong(displayName: "Beta Song")])

        let result = SourceLibrarySearch.filter(
            sources: [source], individualSongs: [], missingItems: [],
            searchText: "Gamma"
        )

        #expect(result.sources.isEmpty)
    }

    // MARK: - Individual song matching

    @Test func matchesIndividualSongDisplayName() {
        let matching = makeSong(displayName: "Acoustic Session")
        let other = makeSong(displayName: "Electric Mix")

        let result = SourceLibrarySearch.filter(
            sources: [], individualSongs: [matching, other], missingItems: [],
            searchText: "Acoustic"
        )

        #expect(result.individualSongs.count == 1)
        #expect(result.individualSongs.first?.id == matching.id)
    }

    @Test func matchesIndividualSongPath() {
        let matching = makeSong(displayName: "Song", path: "/Users/me/projects/sessions/demo")
        let other = makeSong(displayName: "Song", path: "/Volumes/card/MUSIC/SONG_0001")

        let result = SourceLibrarySearch.filter(
            sources: [], individualSongs: [matching, other], missingItems: [],
            searchText: "sessions"
        )

        #expect(result.individualSongs.count == 1)
        #expect(result.individualSongs.first?.id == matching.id)
    }

    // MARK: - Missing items

    @Test func matchesMissingItemDisplayName() {
        let matching = makeMissingItem(displayName: "Lost Recording")
        let other = makeMissingItem(displayName: "Available Track")

        let result = SourceLibrarySearch.filter(
            sources: [], individualSongs: [], missingItems: [matching, other],
            searchText: "Lost"
        )

        #expect(result.missingItems.count == 1)
        #expect(result.missingItems.first?.id == matching.id)
    }

    @Test func matchesMissingItemDetail() {
        let matching = makeMissingItem(displayName: "Folder", detail: "/Volumes/OldDrive/MUSIC")
        let other = makeMissingItem(displayName: "OtherFolder", detail: "/Users/me/backup")

        let result = SourceLibrarySearch.filter(
            sources: [], individualSongs: [], missingItems: [matching, other],
            searchText: "OldDrive"
        )

        #expect(result.missingItems.count == 1)
        #expect(result.missingItems.first?.id == matching.id)
    }

    // MARK: - No results

    @Test func unmatchedTextProducesEmptyResult() {
        let source = makeSource(displayName: "MyCard")
        let song = makeSong(displayName: "MySong")
        let item = makeMissingItem(displayName: "MyItem")

        let result = SourceLibrarySearch.filter(
            sources: [source], individualSongs: [song], missingItems: [item],
            searchText: "zzzzzz"
        )

        #expect(!result.hasAnyResults)
    }

    @Test func hasAnyResultsIsTrueWhenAtLeastOneItemMatches() {
        let song = makeSong(displayName: "Acoustic")
        let result = SourceLibrarySearch.filter(
            sources: [], individualSongs: [song], missingItems: [],
            searchText: "Acoustic"
        )
        #expect(result.hasAnyResults)
    }

    // MARK: - Mutation safety

    @Test func originalSourceArrayIsNotMutated() {
        var source = makeSource(displayName: "Original", songs: [
            makeSong(displayName: "SONG_0001"),
            makeSong(displayName: "SONG_0002")
        ])
        let originalSongCount = source.songs.count
        let originalID = source.id

        let result = SourceLibrarySearch.filter(
            sources: [source], individualSongs: [], missingItems: [],
            searchText: "SONG_0001"
        )

        // Result has filtered songs, but original struct is unchanged
        #expect(source.songs.count == originalSongCount)
        #expect(source.id == originalID)
        // Silence unused variable warning
        _ = result
    }

    // MARK: - Case insensitivity (localizedStandardContains behavior)

    @Test func searchIsEffectivelyCaseInsensitive() {
        let source = makeSource(displayName: "My Recording Card")

        let resultLower = SourceLibrarySearch.filter(
            sources: [source], individualSongs: [], missingItems: [],
            searchText: "recording"
        )
        let resultUpper = SourceLibrarySearch.filter(
            sources: [source], individualSongs: [], missingItems: [],
            searchText: "RECORDING"
        )

        #expect(resultLower.sources.count == 1)
        #expect(resultUpper.sources.count == 1)
    }
}
