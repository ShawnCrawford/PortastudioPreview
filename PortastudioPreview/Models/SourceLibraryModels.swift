//
//  SourceLibraryModels.swift
//  PortastudioPreview
//

import Foundation

enum SourceLibrarySelection: Hashable {
    case source(SourceLibrarySource.ID)
    case individualSong(SourceLibrarySong.ID)
    case missingItem(SourceLibraryMissingItem.ID)
}

enum SourceKind: Hashable, Sendable {
    case mediaRoot
    case backupRoot
}

struct SourceLibrarySource: Identifiable, Hashable, Sendable {
    enum LoadState: Hashable, Sendable {
        case loading
        case loaded
        case failed(message: String)
    }

    let id: UUID
    var folderURL: URL
    var kind: SourceKind
    var displayName: String
    var songs: [SourceLibrarySong]
    var isExpanded: Bool
    var loadState: LoadState
    var isMissing: Bool
    var bookmarkData: Data?
    /// Identity match state computed from stored vs current fingerprint; nil before first fingerprint pass.
    var matchState: FingerprintMatchState?

    init(
        id: UUID = UUID(),
        folderURL: URL,
        kind: SourceKind,
        displayName: String,
        songs: [SourceLibrarySong] = [],
        isExpanded: Bool = true,
        loadState: LoadState = .loaded,
        isMissing: Bool = false,
        bookmarkData: Data? = nil,
        matchState: FingerprintMatchState? = nil
    ) {
        self.id = id
        self.folderURL = folderURL
        self.kind = kind
        self.displayName = displayName
        self.songs = songs
        self.isExpanded = isExpanded
        self.loadState = loadState
        self.isMissing = isMissing
        self.bookmarkData = bookmarkData
        self.matchState = matchState
    }
}

struct SourceLibrarySong: Identifiable, Hashable, Sendable {
    enum LoadState: Hashable, Sendable {
        case loading
        case loaded
        case failed(message: String)
    }

    let id: UUID
    var folderURL: URL
    var displayName: String
    var loadState: LoadState
    var isMissing: Bool
    var bookmarkData: Data?
    /// Non-nil for songs nested under a source root; the value is the parent source's `id`.
    var sourceID: UUID?
    /// Identity match state computed from stored vs current fingerprint; nil before first fingerprint pass.
    var matchState: FingerprintMatchState?

    init(
        id: UUID = UUID(),
        folderURL: URL,
        displayName: String,
        loadState: LoadState,
        isMissing: Bool = false,
        bookmarkData: Data? = nil,
        sourceID: UUID? = nil,
        matchState: FingerprintMatchState? = nil
    ) {
        self.id = id
        self.folderURL = folderURL
        self.displayName = displayName
        self.loadState = loadState
        self.isMissing = isMissing
        self.bookmarkData = bookmarkData
        self.sourceID = sourceID
        self.matchState = matchState
    }
}

struct SourceLibraryMissingItem: Identifiable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var detail: String?

    init(id: UUID = UUID(), displayName: String, detail: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.detail = detail
    }
}
