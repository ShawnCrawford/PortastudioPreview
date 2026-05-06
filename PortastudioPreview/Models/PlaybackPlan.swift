//
//  PlaybackPlan.swift
//  PortastudioPreview
//

import Foundation

/// The reason a WAV region was excluded from playback.
///
/// Evidence levels:
/// - `track1ActiveVirtualTake`: Correlated – active-take byte at 0x00B01A38 selects the active
///   take from same-stem alternatives or the EDL file list (SONG_0083–0085).
/// - `track1Mute`: Confirmed – Track 1 mute byte 0x01 at 0x0268 in SONG_0075 produces no
///   audible output on the device.
/// - `track2Mute`: Observed – Track 2 mute byte 0x01 at 0x0269 in SONG_0090 silences the
///   second EDL entry. EDL-position-to-track mapping is Hypothesis.
/// - `unsupportedMapping`: EDL position beyond confirmed track coverage; not used for suppression
///   in v1 — regions remain playable.
enum PlaybackSuppressionReason: String, Sendable {
    case track1ActiveVirtualTake
    case track1Mute
    case track2Mute
    case unsupportedMapping
}

struct SuppressedPlaybackEntry: Sendable {
    let filename: String
    let reason: PlaybackSuppressionReason
}

struct ScheduledPlaybackRegion: Sendable {
    let filename: String
    let url: URL
    let startSample: Int
    /// Unity gain (1.0) for all v1 unassigned regions. Pan/level deferred until
    /// track-to-WAV mapping evidence is stronger.
    let volume: Float
    let pan: Float
}

/// The output of `PreviewPlaybackPlanner.plan(for:)`.
///
/// `playableRegions` holds WAV regions that should be scheduled for playback.
/// `suppressedEntries` holds regions excluded by active-take filtering or mute state,
/// along with the decision reason.
struct PlaybackPlan: Sendable {
    let playableRegions: [ScheduledPlaybackRegion]
    let suppressedEntries: [SuppressedPlaybackEntry]

    var hasPlayableTracks: Bool { !playableRegions.isEmpty }
    var playableFilenames: [String] { playableRegions.map(\.filename) }
    var suppressedFilenames: [String] { suppressedEntries.map(\.filename) }
}
