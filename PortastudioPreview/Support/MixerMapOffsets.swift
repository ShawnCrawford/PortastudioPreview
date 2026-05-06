//
//  MixerMapOffsets.swift
//  PortastudioPreview
//

import Foundation

enum MixerMapOffsets {
    // MARK: - Track counts

    /// Physical channel count in the song.sys low bank (T1–T32). Confirmed: stride 0x14 from SONG_0092
    /// and full-range probe from SONG_0095.
    static let trackCount = 32

    /// Logical track count covered by the mirror bank level/pan table (T1–T8 mono + 12 stereo pairs).
    /// Confirmed: SONG_0092 for T1–T8; SONG_0095 for stereo pairs T9/T10–T31/T32.
    /// Mirror entries for stereo pairs are indexed by pair number (T9/T10 = logical-idx 8, ...,
    /// T31/T32 = logical-idx 19), not by physical channel.
    static let confirmedMirrorLevelPanCount = 20

    /// Convenience alias kept for parsers that only use the first eight tracks (mono channel range).
    /// Use confirmedMirrorLevelPanCount for the full logical mirror range.
    static let correlatedLevelPanTrackCount = 8

    // MARK: - Level / Pan offsets (stride 0x14, low bank and mirror bank)

    /// Low-bank level base. Confirmed for T1–T8 from SONG_0092; Confirmed for T9–T32 stride from SONG_0095.
    static let levelBase = 0x00C4
    /// Mirror-bank level base. Logical-track layout confirmed from SONG_0092 and SONG_0095.
    static let levelMirrorBase = 0x081C

    /// Low-bank pan base. Confirmed for T1–T8 from SONG_0092. Center = 0x40 (baseline value).
    static let panBase = 0x00C6
    /// Mirror-bank pan base. Confirmed for T1–T8 from SONG_0092.
    static let panMirrorBase = 0x081E

    static let trackStride = 0x14

    // MARK: - Mute offsets (stride 1, byte-packed tables)

    /// Low-bank mute table base. Stride 1 per physical channel.
    /// Confirmed for T1–T18 from SONG_0093. Bytes beyond index 17 (0x0279+) are a different field.
    static let muteBase = 0x0268

    /// Number of physical-channel entries confirmed in the low-bank mute table.
    /// Covers T1–T8 mono and T9–T18 stereo channels (5 active stereo pairs × 2 channels).
    /// Extends to more channels as stereo pairs are enabled; cap at 32 physical channels.
    static let confirmedLowBankMuteCount = 18

    /// Mirror-bank mute table base. Stride 1 per logical track (1 entry per stereo pair).
    /// Confirmed for T1–T20 (8 mono + 12 stereo pairs) from SONG_0093.
    static let muteMirrorBase = 0x0A2D

    /// Number of logical-track entries confirmed in the mirror-bank mute table.
    static let confirmedMirrorMuteCount = 20

    // Kept for backward compatibility with code that references individual track offsets.
    static let track1Mute = 0x0268        // muteBase + 0
    static let track1MuteMirror = 0x0A2D  // muteMirrorBase + 0
    static let track2Mute = 0x0269        // muteBase + 1
    static let track2MuteMirror = 0x0A2E  // muteMirrorBase + 1

    // MARK: - Track-type table (strong hypothesis)

    /// Repeating-byte table where each entry encodes the track type for a stereo pair.
    /// Strong hypothesis from SONG_0095: 0x02 = stereo, 0x01 = mono (observed when T27/T28
    /// was converted from stereo to mono, entry 9 of this table changed from 0x02 to 0x01).
    static let trackTypeTableBase = 0x09F0

    // MARK: - Minimum file length

    static var minimumSongSysLength: Int {
        max(
            panOffset(trackIndex: trackCount - 1),
            panMirrorOffset(trackIndex: confirmedMirrorLevelPanCount - 1),
            muteBase + confirmedLowBankMuteCount - 1,
            muteMirrorBase + confirmedMirrorMuteCount - 1
        ) + 1
    }

    // MARK: - Offset helpers

    static func levelOffset(trackIndex: Int) -> Int {
        levelBase + trackIndex * trackStride
    }

    static func levelMirrorOffset(trackIndex: Int) -> Int {
        levelMirrorBase + trackIndex * trackStride
    }

    static func panOffset(trackIndex: Int) -> Int {
        panBase + trackIndex * trackStride
    }

    static func panMirrorOffset(trackIndex: Int) -> Int {
        panMirrorBase + trackIndex * trackStride
    }

    static func muteOffset(trackIndex: Int) -> Int {
        muteBase + trackIndex
    }

    /// Mirror mute offset for mono tracks (T1–T8, trackIndex 0–7) where physical index equals
    /// logical index. For stereo-pair tracks (trackIndex ≥ 8) the mirror uses pair-based indexing
    /// and this helper should not be used without additional mapping.
    static func muteMirrorOffsetForMonoTrack(trackIndex: Int) -> Int {
        muteMirrorBase + trackIndex
    }

    static func hasCorrelatedLevelPanMirror(trackIndex: Int) -> Bool {
        (0..<correlatedLevelPanTrackCount).contains(trackIndex)
    }

    static func hasConfirmedLowBankMute(trackIndex: Int) -> Bool {
        (0..<confirmedLowBankMuteCount).contains(trackIndex)
    }

    static func hasConfirmedMirrorMuteForMonoTrack(trackIndex: Int) -> Bool {
        (0..<correlatedLevelPanTrackCount).contains(trackIndex)
    }
}
