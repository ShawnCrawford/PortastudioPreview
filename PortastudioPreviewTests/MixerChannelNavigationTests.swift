//
//  MixerChannelNavigationTests.swift
//  PortastudioPreviewTests
//

import Testing
@testable import PortastudioPreview

struct MixerChannelNavigationTests {
    @Test func nextFromNilSelectionStartsAtFirstVisibleChannel() {
        let navigation = MixerChannelNavigation(channels: makeChannels([1, 3, 5]))

        #expect(navigation.selectNextChannel(from: nil) == 1)
        #expect(navigation.canSelectPreviousChannel(selectedTrackID: nil) == false)
        #expect(navigation.canSelectNextChannel(selectedTrackID: nil))
    }

    @Test func previousAndNextStepThroughOrderedVisibleChannels() {
        let navigation = MixerChannelNavigation(channels: makeChannels([1, 3, 5]))

        #expect(navigation.selectPreviousChannel(from: 3) == 1)
        #expect(navigation.selectNextChannel(from: 3) == 5)
    }

    @Test func firstAndLastDisableTheirBlockedDirections() {
        let navigation = MixerChannelNavigation(channels: makeChannels([1, 3, 5]))

        #expect(navigation.canSelectPreviousChannel(selectedTrackID: 1) == false)
        #expect(navigation.canSelectNextChannel(selectedTrackID: 1))
        #expect(navigation.canSelectPreviousChannel(selectedTrackID: 5))
        #expect(navigation.canSelectNextChannel(selectedTrackID: 5) == false)
    }

    @Test func emptyNavigationHasNoAvailableDirections() {
        let navigation = MixerChannelNavigation(channels: [])

        #expect(navigation.firstChannelID == nil)
        #expect(navigation.canSelectPreviousChannel(selectedTrackID: nil) == false)
        #expect(navigation.canSelectNextChannel(selectedTrackID: nil) == false)
        #expect(navigation.selectPreviousChannel(from: nil) == nil)
        #expect(navigation.selectNextChannel(from: nil) == nil)
    }

    private func makeChannels(_ trackNumbers: [Int]) -> [MixerChannel] {
        trackNumbers.map { trackNumber in
            MixerChannel(
                leadingTrackNumber: trackNumber,
                memberTracks: [
                    TrackPreview(
                        trackNumber: trackNumber,
                        candidateWAV: nil,
                        mixerSetting: nil,
                        track1ActiveTakeCandidate: nil,
                        timeline: nil,
                        virtualTrackOptions: [],
                        defaultVirtualTrackOptionID: nil
                    )
                ]
            )
        }
    }
}
