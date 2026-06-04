//
//  MixerChannelNavigation.swift
//  PortastudioPreview
//

import Foundation

struct MixerChannelNavigation: Sendable {
    let channels: [MixerChannel]

    var firstChannelID: Int? {
        channels.first?.id
    }

    func canSelectPreviousChannel(selectedTrackID: Int?) -> Bool {
        guard let selectedIndex = index(of: selectedTrackID) else {
            return false
        }

        return selectedIndex > channels.startIndex
    }

    func canSelectNextChannel(selectedTrackID: Int?) -> Bool {
        guard let selectedIndex = index(of: selectedTrackID) else {
            return !channels.isEmpty
        }

        return selectedIndex < channels.index(before: channels.endIndex)
    }

    func selectPreviousChannel(from selectedTrackID: Int?) -> Int? {
        guard let selectedIndex = index(of: selectedTrackID),
              selectedIndex > channels.startIndex else {
            return nil
        }

        return channels[channels.index(before: selectedIndex)].id
    }

    func selectNextChannel(from selectedTrackID: Int?) -> Int? {
        guard let selectedIndex = index(of: selectedTrackID) else {
            return firstChannelID
        }

        let nextIndex = channels.index(after: selectedIndex)
        guard nextIndex < channels.endIndex else {
            return nil
        }

        return channels[nextIndex].id
    }

    private func index(of selectedTrackID: Int?) -> Int? {
        guard let selectedTrackID else {
            return nil
        }

        return channels.firstIndex { $0.id == selectedTrackID }
    }
}
