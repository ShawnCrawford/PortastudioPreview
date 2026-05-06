//
//  SongSysParser.swift
//  PortastudioPreview
//

import Foundation

struct SongSysParser {
    func parse(_ data: Data) throws -> [TrackMixerSetting] {
        let reader = ByteReader(data: data)

        return try (0..<MixerMapOffsets.trackCount).map { trackIndex in
            let level = try readMirroredSetting(
                name: "Level",
                reader: reader,
                primaryOffset: MixerMapOffsets.levelOffset(trackIndex: trackIndex),
                mirrorOffset: MixerMapOffsets.hasCorrelatedLevelPanMirror(trackIndex: trackIndex)
                    ? MixerMapOffsets.levelMirrorOffset(trackIndex: trackIndex)
                    : nil
            )

            let pan = try readMirroredSetting(
                name: "Pan",
                reader: reader,
                primaryOffset: MixerMapOffsets.panOffset(trackIndex: trackIndex),
                mirrorOffset: MixerMapOffsets.hasCorrelatedLevelPanMirror(trackIndex: trackIndex)
                    ? MixerMapOffsets.panMirrorOffset(trackIndex: trackIndex)
                    : nil
            )

            let mute: MixerSetting?
            if trackIndex == 0 {
                mute = try readMirroredSetting(
                    name: "Mute",
                    reader: reader,
                    primaryOffset: MixerMapOffsets.track1Mute,
                    mirrorOffset: MixerMapOffsets.track1MuteMirror
                )
            } else if trackIndex == 1 {
                mute = try readMirroredSetting(
                    name: "Mute",
                    reader: reader,
                    primaryOffset: MixerMapOffsets.track2Mute,
                    mirrorOffset: MixerMapOffsets.track2MuteMirror
                )
            } else {
                mute = nil
            }

            return TrackMixerSetting(
                trackNumber: trackIndex + 1,
                level: level,
                pan: pan,
                mute: mute
            )
        }
    }

    private func readMirroredSetting(
        name: String,
        reader: ByteReader,
        primaryOffset: Int,
        mirrorOffset: Int?
    ) throws -> MixerSetting {
        let primaryByte = try reader.readUInt8(at: primaryOffset)
        let mirrorByte: UInt8?

        if let mirrorOffset {
            mirrorByte = try reader.readUInt8(at: mirrorOffset)
        } else {
            mirrorByte = nil
        }

        return MixerSetting(
            name: name,
            primaryOffset: primaryOffset,
            primaryByte: primaryByte,
            mirrorOffset: mirrorOffset,
            mirrorByte: mirrorByte,
            evidenceLevel: mirrorOffset == nil ? .hypothesis : .correlated
        )
    }
}
