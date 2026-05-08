//
//  MixerChannelLayoutTests.swift
//  PortastudioPreviewTests
//

import Testing
@testable import PortastudioPreview

struct MixerChannelLayoutTests {
    @Test func monoTracksMapToSingleChannels() {
        #expect(MixerChannelLayout.leadingTrackNumber(for: 1) == 1)
        #expect(MixerChannelLayout.leadingTrackNumber(for: 8) == 8)
        #expect(MixerChannelLayout.memberTrackNumbers(forLeadingTrackNumber: 1) == [1])
        #expect(MixerChannelLayout.memberTrackNumbers(forLeadingTrackNumber: 8) == [8])
    }

    @Test func stereoTracksGroupAsAdjacentPairs() {
        #expect(MixerChannelLayout.memberTrackNumbers(forLeadingTrackNumber: 9) == [9, 10])
        #expect(MixerChannelLayout.memberTrackNumbers(forLeadingTrackNumber: 11) == [11, 12])
        #expect(MixerChannelLayout.memberTrackNumbers(forLeadingTrackNumber: 31) == [31, 32])

        #expect(MixerChannelLayout.leadingTrackNumber(for: 10) == 9)
        #expect(MixerChannelLayout.leadingTrackNumber(for: 12) == 11)
        #expect(MixerChannelLayout.leadingTrackNumber(for: 32) == 31)
    }

    @Test func mirrorLogicalIndicesFollowConfirmedPairFormula() {
        #expect(MixerChannelLayout.mirrorBankLogicalIndex(forTrackNumber: 9) == 8)
        #expect(MixerChannelLayout.mirrorBankLogicalIndex(forTrackNumber: 10) == 8)
        #expect(MixerChannelLayout.mirrorBankLogicalIndex(forTrackNumber: 11) == 9)
        #expect(MixerChannelLayout.mirrorBankLogicalIndex(forTrackNumber: 31) == 19)
        #expect(MixerChannelLayout.mirrorBankLogicalIndex(forTrackNumber: 32) == 19)
    }
}
