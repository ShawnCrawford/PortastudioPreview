//
//  TrackAnnotationRecord.swift
//  PortastudioPreview
//

import Foundation
import SwiftData

/// App-owned SwiftData record for a single track label, keyed by song fingerprint + track number.
///
/// Source folders are never touched; annotations live exclusively in the app's SwiftData store.
/// The durable lookup key is `songFingerprintString + trackNumber`, not the UUID id.
@Model
final class TrackAnnotationRecord {
    @Attribute(.unique) var id: UUID
    /// Aggregate song fingerprint string — the primary key component.
    var songFingerprintString: String
    /// Physical track number (1-based) — the secondary key component.
    var trackNumber: Int
    /// User-supplied track label; empty strings are never persisted (upsert trims and deletes empties).
    var trackName: String
    var createdAt: Date
    var updatedAt: Date
    /// Snapshot of the song display name at save time; informational only.
    var lastKnownSongDisplayName: String?
    /// Snapshot of the song folder path at save time; informational only.
    var lastKnownSongPath: String?
    /// Reference to `LibrarySongRecord.id` for direct lookup diagnostics; not the durable key.
    var songRecordID: UUID?

    init(
        id: UUID = UUID(),
        songFingerprintString: String,
        trackNumber: Int,
        trackName: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastKnownSongDisplayName: String? = nil,
        lastKnownSongPath: String? = nil,
        songRecordID: UUID? = nil
    ) {
        self.id = id
        self.songFingerprintString = songFingerprintString
        self.trackNumber = trackNumber
        self.trackName = trackName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastKnownSongDisplayName = lastKnownSongDisplayName
        self.lastKnownSongPath = lastKnownSongPath
        self.songRecordID = songRecordID
    }
}
