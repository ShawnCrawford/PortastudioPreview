//
//  FingerprintModels.swift
//  PortastudioPreview
//

import Foundation

// MARK: - Match State

/// Confidence level of the identity match for a remembered source or song.
///
/// Phase 4 implements `.exact`, `.changedSinceLastSeen`, and `.unknown`.
/// `.ambiguous` is reserved for a future copied-source detection pass.
enum FingerprintMatchState: String, Codable, Sendable, Hashable {
    /// Computed aggregate fingerprint matches the stored aggregate exactly.
    case exact
    /// Remembered record resolved but key-file bytes, WAV count, or WAV sizes changed.
    case changedSinceLastSeen
    /// Reserved for future copied-source detection; not actively resolved in Phase 4.
    case ambiguous
    /// Location is missing or key inputs cannot be read; no comparison possible.
    case unknown
}

// MARK: - File Fingerprint

/// SHA-256 fingerprint of a small key file (dp-24.sys, song.sys, edltable.sys).
/// WAV files are never hashed by content — only their metadata is captured.
struct FileFingerprint: Hashable, Sendable {
    let filename: String
    let byteCount: Int
    let modificationDate: Date?
    /// Lowercase hex-encoded SHA-256 digest of the file's bytes.
    let sha256Hex: String
}

// MARK: - WAV Inventory Fingerprint

/// Metadata-only summary of a song folder's visible WAV files.
/// File contents are never hashed; identity uses relative path, byte count, and modification date.
struct WAVInventoryFingerprint: Hashable, Sendable {
    struct Entry: Hashable, Sendable {
        /// Lowercased relative path from the song folder root (for case-insensitive normalization).
        let relativePath: String
        let byteCount: Int
        let modificationDate: Date?
    }

    let visibleWAVCount: Int
    let totalVisibleWAVBytes: Int
    /// Sorted entries, normalized to lowercase relative paths.
    let entries: [Entry]
    /// Deterministic summary string encoding count, total bytes, and per-entry path:bytes.
    let summaryString: String
}

// MARK: - Song Fingerprint

/// Identity fingerprint for a single song folder.
struct SongFingerprint: Hashable, Sendable {
    let folderName: String
    let songSysFingerprint: FileFingerprint?
    let edlTableFingerprint: FileFingerprint?
    let wavInventory: WAVInventoryFingerprint
    /// Deterministic aggregate combining all sub-fingerprints.
    let aggregateString: String
    let generatedAt: Date
}

// MARK: - Source Fingerprint

/// Identity fingerprint for a source root (SD card or backup root).
struct SourceFingerprint: Hashable, Sendable {
    let folderName: String
    let pathDisplayString: String
    let kind: SourceKind
    let hasMusicFolder: Bool
    let dp24SysFingerprint: FileFingerprint?
    let songCount: Int
    /// Fingerprints of all visible song folders, sorted by folder name.
    let songSummaries: [SongFingerprint]
    /// Deterministic aggregate combining all sub-fingerprints.
    let aggregateString: String
    let generatedAt: Date
}
