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

    @Test func track1AndTrack2MuteReadPrimaryAndMirrorOffsetsOnly() throws {
        var data = makeMinimumSongSysData()
        data[0x0268] = 0x01
        data[0x0A2D] = 0x01
        data[0x0269] = 0x01
        data[0x0A2E] = 0x01

        let tracks = try SongSysParser().parse(data)

        #expect(tracks[0].mute?.primaryOffset == 0x0268)
        #expect(tracks[0].mute?.primaryByte == 0x01)
        #expect(tracks[0].mute?.mirrorOffset == 0x0A2D)
        #expect(tracks[0].mute?.mirrorByte == 0x01)
        #expect(tracks[1].mute?.primaryOffset == 0x0269)
        #expect(tracks[1].mute?.primaryByte == 0x01)
        #expect(tracks[1].mute?.mirrorOffset == 0x0A2E)
        #expect(tracks[1].mute?.mirrorByte == 0x01)
        #expect(tracks[2].mute == nil)
    }

    @Test func trackIndexOffsetCalculationUsesCorrelatedStride() throws {
        let tracks = try SongSysParser().parse(makeMinimumSongSysData())

        #expect(tracks[4].level.primaryOffset == 0x00C4 + 4 * 0x14)
        #expect(tracks[4].pan.primaryOffset == 0x00C6 + 4 * 0x14)
        #expect(tracks[7].level.mirrorOffset == 0x081C + 7 * 0x14)
        #expect(tracks[7].pan.mirrorOffset == 0x081E + 7 * 0x14)
        #expect(tracks[31].level.primaryOffset == 0x00C4 + 31 * 0x14)
        #expect(tracks[31].pan.primaryOffset == 0x00C6 + 31 * 0x14)
        #expect(tracks[31].level.mirrorOffset == nil)
        #expect(tracks[31].pan.mirrorOffset == nil)
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
        data[0x0986] = 0x40

        let tracks = try SongSysParser().parse(data)

        #expect(tracks[18].pan.primaryOffset == 0x022E)
        #expect(tracks[18].pan.mirrorOffset == nil)
        #expect(tracks[18].pan.evidenceLevel == .hypothesis)
        #expect(tracks[18].warnings.isEmpty)
    }

    private func makeMinimumSongSysData() -> Data {
        Data(count: MixerMapOffsets.minimumSongSysLength)
    }
}
