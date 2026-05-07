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

struct SourceLibrarySource: Identifiable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var songs: [SourceLibrarySong]
    var isExpanded: Bool

    init(id: UUID = UUID(), displayName: String, songs: [SourceLibrarySong] = [], isExpanded: Bool = true) {
        self.id = id
        self.displayName = displayName
        self.songs = songs
        self.isExpanded = isExpanded
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

    init(id: UUID = UUID(), folderURL: URL, displayName: String, loadState: LoadState) {
        self.id = id
        self.folderURL = folderURL
        self.displayName = displayName
        self.loadState = loadState
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
