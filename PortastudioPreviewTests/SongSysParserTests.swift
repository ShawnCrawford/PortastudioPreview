//
//  SongSysParserTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct SongSysParserTests {
    @Test func track1LevelReadsPrimaryAndMirrorOffsets() throws {
        var data = makeMinimumSongSysData()
        data[0x00C4] = 0x22
        data[0x081C] = 0x22

        let tracks = try SongSysParser().parse(data)

        #expect(tracks[0].level.primaryOffset == 0x00C4)
        #expect(tracks[0].level.primaryByte == 0x22)
        #expect(tracks[0].level.mirrorOffset == 0x081C)
        #expect(tracks[0].level.mirrorByte == 0x22)
    }

    @Test func track1PanReadsPrimaryAndMirrorOffsets() throws {
        var data = makeMinimumSongSysData()
        data[0x00C6] = 0x40
        data[0x081E] = 0x40

        let tracks = try SongSysParser().parse(data)

        #expect(tracks[0].pan.primaryOffset == 0x00C6)
        #expect(tracks[0].pan.primaryByte == 0x40)
        #expect(tracks[0].pan.mirrorOffset == 0x081E)
        #expect(tracks[0].pan.mirrorByte == 0x40)
    }

    @Test func muteParsedForAllConfirmedLowBankTracks() throws {
        var data = makeMinimumSongSysData()
        // Set every confirmed low-bank mute byte (T1–T18, indices 0–17)
        for i in 0..<MixerMapOffsets.confirmedLowBankMuteCount {
            data[MixerMapOffsets.muteBase + i] = 0x01
        }
        // Set mirror bytes for all logical channels (T1–T8 + T9/10–T31/32).
        for i in 0..<MixerMapOffsets.confirmedMirrorMuteCount {
            data[MixerMapOffsets.muteMirrorBase + i] = 0x01
        }

        let tracks = try SongSysParser().parse(data)

        // T1 and T2 retain their confirmed offsets
        #expect(tracks[0].mute?.primaryOffset == 0x0268)
        #expect(tracks[0].mute?.primaryByte == 0x01)
        #expect(tracks[0].mute?.mirrorOffset == 0x0A2D)
        #expect(tracks[0].mute?.mirrorByte == 0x01)
        #expect(tracks[1].mute?.primaryOffset == 0x0269)
        #expect(tracks[1].mute?.primaryByte == 0x01)
        #expect(tracks[1].mute?.mirrorOffset == 0x0A2E)
        #expect(tracks[1].mute?.mirrorByte == 0x01)

        // T3–T8: confirmed low-bank + confirmed mirror (1:1 stride-1)
        #expect(tracks[2].mute?.primaryOffset == 0x026A)
        #expect(tracks[2].mute?.primaryByte == 0x01)
        #expect(tracks[2].mute?.mirrorOffset == 0x0A2F)
        #expect(tracks[7].mute?.primaryOffset == 0x026F)
        #expect(tracks[7].mute?.mirrorOffset == 0x0A34)

        // T9–T18: effective mute prefers mirror logical pair entries.
        #expect(tracks[8].mute?.primaryOffset == 0x0A35)
        #expect(tracks[8].mute?.primaryByte == 0x01)
        #expect(tracks[8].mute?.mirrorOffset == nil)
        #expect(tracks[9].mute?.primaryOffset == 0x0A35)
        #expect(tracks[17].mute?.primaryOffset == 0x0A41)

        // T19+ still reads confirmed mirror mute entries.
        #expect(tracks[18].mute?.primaryOffset == 0x0A42)
        #expect(tracks[31].mute?.primaryOffset == 0x0A40)
    }

    @Test func trackIndexOffsetCalculationUsesCorrelatedStride() throws {
        let tracks = try SongSysParser().parse(makeMinimumSongSysData())

        #expect(tracks[4].level.primaryOffset == 0x00C4 + 4 * 0x14)
        #expect(tracks[4].pan.primaryOffset == 0x00C6 + 4 * 0x14)
        #expect(tracks[7].level.mirrorOffset == 0x081C + 7 * 0x14)
        #expect(tracks[7].pan.mirrorOffset == 0x081E + 7 * 0x14)
        #expect(tracks[31].level.primaryOffset == 0x081C + 19 * 0x14)
        #expect(tracks[31].pan.primaryOffset == 0x081E + 19 * 0x14)
        #expect(tracks[31].level.mirrorOffset == nil)
        #expect(tracks[31].pan.mirrorOffset == nil)
    }

    @Test func stereoPairUsesSharedMirrorLevelAndPan() throws {
        var data = makeMinimumSongSysData()
        let logicalOffset = 8 * MixerMapOffsets.trackStride
        data[MixerMapOffsets.levelMirrorBase + logicalOffset] = 0x4C
        data[MixerMapOffsets.panMirrorBase + logicalOffset] = 0x55

        // Different low-bank values should not affect effective paired controls.
        data[MixerMapOffsets.levelOffset(trackIndex: 8)] = 0x10
        data[MixerMapOffsets.levelOffset(trackIndex: 9)] = 0x20
        data[MixerMapOffsets.panOffset(trackIndex: 8)] = 0x01
        data[MixerMapOffsets.panOffset(trackIndex: 9)] = 0x7F

        let tracks = try SongSysParser().parse(data)

        #expect(tracks[8].level.primaryByte == 0x4C)
        #expect(tracks[9].level.primaryByte == 0x4C)
        #expect(tracks[8].pan.primaryByte == 0x55)
        #expect(tracks[9].pan.primaryByte == 0x55)
    }

    @Test func mirrorMismatchReturnsWarningWithoutPromotion() throws {
        var data = makeMinimumSongSysData()
        data[0x00C4] = 0x11
        data[0x081C] = 0x12

        let tracks = try SongSysParser().parse(data)

        #expect(tracks[0].level.hasMirrorMismatch)
        #expect(tracks[0].level.evidenceLevel == .correlated)
        #expect(tracks[0].warnings.contains { $0.contains("mirror mismatch") })
    }

    @Test func unsupportedMirrorRowsDoNotReturnWarnings() throws {
        var data = makeMinimumSongSysData()
        data[0x022E] = 0x00
        data[0x081E + 13 * 0x14] = 0x40

        let tracks = try SongSysParser().parse(data)

        #expect(tracks[18].pan.primaryOffset == 0x081E + 13 * 0x14)
        #expect(tracks[18].pan.mirrorOffset == nil)
        #expect(tracks[18].pan.evidenceLevel == .confirmed)
        #expect(tracks[18].warnings.isEmpty)
    }

    private func makeMinimumSongSysData() -> Data {
        Data(count: MixerMapOffsets.minimumSongSysLength)
    }
}
