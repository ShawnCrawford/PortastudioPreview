//
//  TrackAnnotationStore.swift
//  PortastudioPreview
//

import Foundation
import Observation
import SwiftData

/// Main-actor service for loading and persisting app-owned track labels.
///
/// Owns the current `SongAnnotationContext` and a cache of `TrackAnnotationRecord` rows
/// for the current song fingerprint. All writes target SwiftData only; source folders
/// are never read or written through this store.
@MainActor
@Observable
final class TrackAnnotationStore {
    /// The annotation context for the currently selected song, or nil when no song is selected.
    private(set) var annotationContext: SongAnnotationContext?

    private var annotations: [Int: TrackAnnotationRecord] = [:]
    private var modelContext: ModelContext?

    init(modelContext: ModelContext? = nil) {
        self.modelContext = modelContext
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Context Loading

    /// Load annotations for the given context, replacing any previously loaded song.
    ///
    /// Pass `nil` to clear the current context (e.g., when no song is selected).
    func load(context: SongAnnotationContext?) {
        annotationContext = context
        annotations = [:]
        guard let context, !context.songFingerprintString.isEmpty,
              let modelContext else { return }

        let fp = context.songFingerprintString
        let descriptor = FetchDescriptor<TrackAnnotationRecord>(
            predicate: #Predicate { $0.songFingerprintString == fp }
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        annotations = Dictionary(uniqueKeysWithValues: records.map { ($0.trackNumber, $0) })
    }

    // MARK: - Track Name Access

    /// Returns the saved track name for the given track number, or nil when none is set.
    func trackName(for trackNumber: Int) -> String? {
        let name = annotations[trackNumber]?.trackName
        return name?.isEmpty == false ? name : nil
    }

    // MARK: - Track Name Mutation

    /// Saves the given name for the track. Trims whitespace; an empty string deletes the record.
    ///
    /// Does nothing when the current context is not editable (missing or non-exact fingerprint).
    func setTrackName(_ name: String, for trackNumber: Int) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let ctx = annotationContext, ctx.isEditable else { return }

        if trimmed.isEmpty {
            clearTrackName(for: trackNumber)
            return
        }

        guard let modelContext else { return }

        if let existing = annotations[trackNumber] {
            existing.trackName = trimmed
            existing.updatedAt = Date()
            existing.lastKnownSongDisplayName = ctx.folderDerivedDisplayName
            existing.lastKnownSongPath = ctx.folderURL.path
        } else {
            let record = TrackAnnotationRecord(
                songFingerprintString: ctx.songFingerprintString,
                trackNumber: trackNumber,
                trackName: trimmed,
                lastKnownSongDisplayName: ctx.folderDerivedDisplayName,
                lastKnownSongPath: ctx.folderURL.path,
                songRecordID: ctx.songRecordID
            )
            modelContext.insert(record)
            annotations[trackNumber] = record
        }
        try? modelContext.save()
    }

    /// Removes the track-name annotation for the given track number.
    func clearTrackName(for trackNumber: Int) {
        guard let modelContext, let existing = annotations[trackNumber] else { return }
        modelContext.delete(existing)
        annotations.removeValue(forKey: trackNumber)
        try? modelContext.save()
    }

    // MARK: - Song Display Name Override

    /// Saves an optional display-name override for the current song to its `LibrarySongRecord`.
    ///
    /// Passing nil or a whitespace-only string clears the override, reverting to the folder name.
    /// Does nothing when the current context has no model context or song record path.
    func setSongDisplayNameOverride(_ name: String?) {
        guard let ctx = annotationContext, let modelContext else { return }

        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let override: String? = (trimmed?.isEmpty == false) ? trimmed : nil

        let path = ctx.folderURL.path
        let descriptor = FetchDescriptor<LibrarySongRecord>(
            predicate: #Predicate { $0.lastKnownPath == path }
        )
        if let record = try? modelContext.fetch(descriptor).first {
            record.displayNameOverride = override
            try? modelContext.save()
        }

        annotationContext?.displayNameOverride = override
    }
}
