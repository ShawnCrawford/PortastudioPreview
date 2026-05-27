//
//  MixOverrideRecord.swift
//  PortastudioPreview
//

import Foundation
import SwiftData

/// App-owned preview mix override keyed by song fingerprint and logical mixer channel.
///
/// These values never write back to the Portastudio song folder. They only describe
/// the user's preview mix inside this app.
@Model
final class MixOverrideRecord {
    @Attribute(.unique) var id: UUID
    var songFingerprintString: String
    var logicalChannelTrackNumber: Int
    var levelPosition: Double
    var panPosition: Double
    var isMuted: Bool
    var isSoloed: Bool
    var selectedVirtualTrackOptionID: String?
    var createdAt: Date
    var updatedAt: Date
    var lastKnownSongDisplayName: String?
    var lastKnownSongPath: String?
    var songRecordID: UUID?

    init(
        id: UUID = UUID(),
        songFingerprintString: String,
        logicalChannelTrackNumber: Int,
        levelPosition: Double,
        panPosition: Double,
        isMuted: Bool,
        isSoloed: Bool,
        selectedVirtualTrackOptionID: String?,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastKnownSongDisplayName: String? = nil,
        lastKnownSongPath: String? = nil,
        songRecordID: UUID? = nil
    ) {
        self.id = id
        self.songFingerprintString = songFingerprintString
        self.logicalChannelTrackNumber = logicalChannelTrackNumber
        self.levelPosition = levelPosition
        self.panPosition = panPosition
        self.isMuted = isMuted
        self.isSoloed = isSoloed
        self.selectedVirtualTrackOptionID = selectedVirtualTrackOptionID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastKnownSongDisplayName = lastKnownSongDisplayName
        self.lastKnownSongPath = lastKnownSongPath
        self.songRecordID = songRecordID
    }
}
