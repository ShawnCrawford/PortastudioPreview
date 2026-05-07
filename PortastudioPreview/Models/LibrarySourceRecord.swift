//
//  LibrarySourceRecord.swift
//  PortastudioPreview
//

import Foundation
import SwiftData

@Model
final class LibrarySourceRecord {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var kindRawValue: String
    var lastKnownPath: String
    var bookmarkData: Data?
    var isMissing: Bool
    var lastSeenAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \LibrarySongRecord.source) var songs: [LibrarySongRecord]

    init(
        id: UUID = UUID(),
        displayName: String,
        kindRawValue: String,
        lastKnownPath: String,
        bookmarkData: Data? = nil,
        isMissing: Bool = false,
        lastSeenAt: Date? = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.kindRawValue = kindRawValue
        self.lastKnownPath = lastKnownPath
        self.bookmarkData = bookmarkData
        self.isMissing = isMissing
        self.lastSeenAt = lastSeenAt
        self.songs = []
    }

    var sourceKind: SourceKind? {
        switch kindRawValue {
        case "mediaRoot": return .mediaRoot
        case "backupRoot": return .backupRoot
        default: return nil
        }
    }
}
