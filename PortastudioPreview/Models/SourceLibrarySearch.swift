//
//  SourceLibrarySearch.swift
//  PortastudioPreview
//

import Foundation

/// Pure, non-mutating search helpers for the source library sidebar.
///
/// ## Filter behavior
/// - A source row is included if the source itself matches the query (all children shown),
///   or if any non-missing child songs match (only matching children shown).
/// - An individual song is included if it matches the query.
/// - A missing item is included if its display name or detail matches the query.
/// - Original arrays are never mutated.
struct SourceLibrarySearch {

    // MARK: - Result

    struct FilterResult {
        let sources: [SourceLibrarySource]
        let individualSongs: [SourceLibrarySong]
        let missingItems: [SourceLibraryMissingItem]

        /// `true` when no items appear in any filtered section.
        var hasAnyResults: Bool {
            !sources.isEmpty || !individualSongs.isEmpty || !missingItems.isEmpty
        }
    }

    // MARK: - Filter

    /// Apply `searchText` to the given library collections.
    ///
    /// Returns original arrays unchanged when `searchText` is blank.
    /// Source songs in the result are filtered to only non-missing entries when the source
    /// matched only through its songs; all songs are preserved when the source itself matched.
    static func filter(
        sources: [SourceLibrarySource],
        individualSongs: [SourceLibrarySong],
        missingItems: [SourceLibraryMissingItem],
        searchText: String
    ) -> FilterResult {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return FilterResult(sources: sources, individualSongs: individualSongs, missingItems: missingItems)
        }

        let filteredSources = sources.compactMap { source -> SourceLibrarySource? in
            if sourceMatches(source, query: query) {
                return source
            }
            let matchingSongs = source.songs.filter { song in
                !song.isMissing && songMatches(song, query: query)
            }
            if !matchingSongs.isEmpty {
                var copy = source
                copy.songs = matchingSongs
                return copy
            }
            return nil
        }

        let filteredSongs = individualSongs.filter { songMatches($0, query: query) }

        let filteredMissing = missingItems.filter { item in
            item.displayName.localizedStandardContains(query)
                || (item.detail?.localizedStandardContains(query) == true)
        }

        return FilterResult(
            sources: filteredSources,
            individualSongs: filteredSongs,
            missingItems: filteredMissing
        )
    }

    // MARK: - Private matchers

    private static func sourceMatches(_ source: SourceLibrarySource, query: String) -> Bool {
        if source.displayName.localizedStandardContains(query) { return true }
        if source.folderURL.path.localizedStandardContains(query) { return true }
        let kindLabel = source.kind == .mediaRoot ? "SD Card" : "Backup"
        if kindLabel.localizedStandardContains(query) { return true }
        return false
    }

    private static func songMatches(_ song: SourceLibrarySong, query: String) -> Bool {
        if song.displayName.localizedStandardContains(query) { return true }
        if song.folderURL.path.localizedStandardContains(query) { return true }
        return false
    }
}
