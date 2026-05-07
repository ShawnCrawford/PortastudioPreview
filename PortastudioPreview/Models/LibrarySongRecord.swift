//
//  LibrarySongRecord.swift
//  PortastudioPreview
//

import Foundation
import SwiftData

@Model
final class LibrarySongRecord {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var lastKnownPath: String
    var bookmarkData: Data?
    var isMissing: Bool
    /// `true` for songs opened individually; `false` for songs nested under a source root.
    var isStandalone: Bool
    var lastSeenAt: Date?
    var source: LibrarySourceRecord?

    init(
        id: UUID = UUID(),
        displayName: String,
        lastKnownPath: String,
        bookmarkData: Data? = nil,
        isMissing: Bool = false,
        isStandalone: Bool = false,
        lastSeenAt: Date? = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.lastKnownPath = lastKnownPath
        self.bookmarkData = bookmarkData
        self.isMissing = isMissing
        self.isStandalone = isStandalone
        self.lastSeenAt = lastSeenAt
    }
}
