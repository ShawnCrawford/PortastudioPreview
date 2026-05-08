//
//  SongSysParser.swift
//  PortastudioPreview
//

import Foundation

struct SongSysParser {
    func parse(_ data: Data) throws -> [TrackMixerSetting] {
        let reader = ByteReader(data: data)

        return try (0..<MixerMapOffsets.trackCount).map { trackIndex in
            let levelPrimaryOffset = MixerMapOffsets.levelOffset(trackIndex: trackIndex)
            let panPrimaryOffset = MixerMapOffsets.panOffset(trackIndex: trackIndex)
            let levelMirrorOffset = MixerMapOffsets.levelPanMirrorOffsetForPhysicalTrack(trackIndex: trackIndex)
            let panMirrorOffset = MixerMapOffsets.panMirrorOffsetForPhysicalTrack(trackIndex: trackIndex)

            let preferredLevelOffset = preferredPrimaryOffset(
                forTrackIndex: trackIndex,
                lowBankOffset: levelPrimaryOffset,
                mirrorOffset: levelMirrorOffset
            )
            let preferredPanOffset = preferredPrimaryOffset(
                forTrackIndex: trackIndex,
                lowBankOffset: panPrimaryOffset,
                mirrorOffset: panMirrorOffset
            )

            let level = try readMirroredSetting(
                name: "Level",
                reader: reader,
                primaryOffset: preferredLevelOffset,
                mirrorOffset: preferredLevelOffset == levelPrimaryOffset ? levelMirrorOffset : nil,
                evidenceLevel: levelMirrorOffset == nil ? .hypothesis : .confirmed
            )

            let pan = try readMirroredSetting(
                name: "Pan",
                reader: reader,
                primaryOffset: preferredPanOffset,
                mirrorOffset: preferredPanOffset == panPrimaryOffset ? panMirrorOffset : nil,
                evidenceLevel: panMirrorOffset == nil ? .hypothesis : .confirmed
            )

            let mute = try parseMuteSetting(trackIndex: trackIndex, reader: reader)

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
        mirrorOffset: Int?,
        evidenceLevel: EvidenceLevel
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
            evidenceLevel: evidenceLevel
        )
    }

    private func parseMuteSetting(trackIndex: Int, reader: ByteReader) throws -> MixerSetting? {
        let mirrorOffset = MixerMapOffsets.muteMirrorOffsetForPhysicalTrack(trackIndex: trackIndex)
        let lowBankOffset = MixerMapOffsets.hasConfirmedLowBankMute(trackIndex: trackIndex)
            ? MixerMapOffsets.muteOffset(trackIndex: trackIndex)
            : nil

        guard mirrorOffset != nil || lowBankOffset != nil else {
            return nil
        }

        let primaryOffset: Int
        let secondaryOffset: Int?
        if trackIndex >= MixerChannelLayout.monoTrackRange.count, let mirrorOffset {
            primaryOffset = mirrorOffset
            secondaryOffset = nil
        } else if let lowBankOffset {
            primaryOffset = lowBankOffset
            secondaryOffset = mirrorOffset
        } else if let mirrorOffset {
            primaryOffset = mirrorOffset
            secondaryOffset = nil
        } else {
            return nil
        }

        return try readMirroredSetting(
            name: "Mute",
            reader: reader,
            primaryOffset: primaryOffset,
            mirrorOffset: secondaryOffset,
            evidenceLevel: mirrorOffset == nil ? .observed : .confirmed
        )
    }

    private func preferredPrimaryOffset(forTrackIndex trackIndex: Int, lowBankOffset: Int, mirrorOffset: Int?) -> Int {
        guard trackIndex >= MixerChannelLayout.monoTrackRange.count, let mirrorOffset else {
            return lowBankOffset
        }

        return mirrorOffset
    }
}
