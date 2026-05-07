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

    // MARK: - Phase 4: Fingerprint Fields

    /// Aggregate fingerprint string computed at last scan; nil until first fingerprint pass.
    var aggregateFingerprintString: String?
    /// Normalized WAV inventory summary string (path:bytes entries); nil until first fingerprint pass.
    var wavInventorySummaryString: String?
    /// Date when the stored fingerprint was last computed.
    var fingerprintGeneratedAt: Date?
    /// Raw value of `FingerprintMatchState` set during hydration or explicit re-scan.
    var matchStateRawValue: String?

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
