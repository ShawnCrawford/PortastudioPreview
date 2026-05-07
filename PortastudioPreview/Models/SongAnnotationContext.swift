//
//  SongAnnotationContext.swift
//  PortastudioPreview
//

import Foundation

/// Value context for a selected song, used to key and scope app-owned track annotations.
///
/// Passed from `SourceLibraryStore` into `TrackAnnotationStore` whenever the selected
/// song changes. All annotation writes are scoped to `songFingerprintString + trackNumber`.
struct SongAnnotationContext: Equatable {
    /// SwiftData record ID of the matching `LibrarySongRecord`; used for display-name override lookups.
    let songRecordID: UUID
    /// Aggregate fingerprint string persisted in `LibrarySongRecord`; the durable annotation key.
    let songFingerprintString: String
    /// The folder URL of the selected song (app-owned; never written to).
    let folderURL: URL
    /// Display name derived from the folder path.
    let folderDerivedDisplayName: String
    /// App-owned override set by the user; nil if no override has been saved.
    var displayNameOverride: String?
    /// Identity match state computed during the last fingerprint pass.
    let matchState: FingerprintMatchState?

    /// The display name shown in the UI: override (if non-empty) falling back to the folder name.
    var effectiveDisplayName: String {
        let trimmed = displayNameOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? folderDerivedDisplayName : trimmed
    }

    /// Labels may be edited only when the song fingerprint is exact and non-empty.
    var isEditable: Bool {
        !songFingerprintString.isEmpty && matchState == .exact
    }
}
