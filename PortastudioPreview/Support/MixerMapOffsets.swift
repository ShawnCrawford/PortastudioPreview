//
//  MixerMapOffsets.swift
//  PortastudioPreview
//

import Foundation

enum MixerMapOffsets {
    static let trackCount = 32
    static let correlatedLevelPanTrackCount = 8

    static let levelBase = 0x00C4
    static let levelMirrorBase = 0x081C
    static let panBase = 0x00C6
    static let panMirrorBase = 0x081E
    static let trackStride = 0x14

    static let track1Mute = 0x0268
    static let track1MuteMirror = 0x0A2D
    static let track2Mute = 0x0269
    static let track2MuteMirror = 0x0A2E

    static var minimumSongSysLength: Int {
        max(
            panOffset(trackIndex: trackCount - 1),
            panMirrorOffset(trackIndex: correlatedLevelPanTrackCount - 1),
            track2MuteMirror
        ) + 1
    }

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

    static func hasCorrelatedLevelPanMirror(trackIndex: Int) -> Bool {
        (0..<correlatedLevelPanTrackCount).contains(trackIndex)
    }
}
