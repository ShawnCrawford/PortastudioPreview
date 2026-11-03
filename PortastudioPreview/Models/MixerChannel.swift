//
//  MixerChannel.swift
//  PortastudioPreview
//

import Foundation

/// Maps physical DP-32SD tracks to logical mixer channels used by the UI and preview controls.
enum MixerChannelLayout {
    static let monoTrackRange = 1...8
    static let pairedTrackRange = 9...32

    static let allLeadingTrackNumbers: [Int] =
        Array(monoTrackRange) + Array(stride(from: pairedTrackRange.lowerBound, through: 31, by: 2))

    static func leadingTrackNumber(for trackNumber: Int) -> Int? {
        if monoTrackRange.contains(trackNumber) {
            return trackNumber
        }

        guard pairedTrackRange.contains(trackNumber) else {
            return nil
        }

        return trackNumber.isMultiple(of: 2) ? trackNumber - 1 : trackNumber
    }

    static func memberTrackNumbers(forLeadingTrackNumber leadingTrackNumber: Int) -> [Int] {
        if monoTrackRange.contains(leadingTrackNumber) {
            return [leadingTrackNumber]
        }

        guard pairedTrackRange.contains(leadingTrackNumber), !leadingTrackNumber.isMultiple(of: 2) else {
            return []
        }

        return [leadingTrackNumber, leadingTrackNumber + 1]
    }

    static func trackNumberLabel(forLeadingTrackNumber leadingTrackNumber: Int) -> String {
        let members = memberTrackNumbers(forLeadingTrackNumber: leadingTrackNumber)
        guard members.count == 2 else {
            return "\(leadingTrackNumber)"
        }

        return "\(members[0])/\(members[1])"
    }

    static func trackNumberLabel(forTrackNumber trackNumber: Int) -> String {
        guard let leadingTrackNumber = leadingTrackNumber(for: trackNumber) else {
            return "\(trackNumber)"
        }

        return trackNumberLabel(forLeadingTrackNumber: leadingTrackNumber)
    }

    /// Mirror-bank logical index where T1-T8 map to 0-7 and T9/10...31/32 map to 8-19.
    static func mirrorBankLogicalIndex(forTrackNumber trackNumber: Int) -> Int? {
        guard let leadingTrackNumber = leadingTrackNumber(for: trackNumber) else {
            return nil
        }

        if monoTrackRange.contains(leadingTrackNumber) {
            return leadingTrackNumber - 1
        }

        return 8 + ((leadingTrackNumber - 9) / 2)
    }

    static func mirrorBankLogicalIndex(forTrackIndex trackIndex: Int) -> Int? {
        mirrorBankLogicalIndex(forTrackNumber: trackIndex + 1)
    }
}

struct MixerChannel: Identifiable, Hashable, Sendable {
    let id: Int
    let memberTracks: [TrackPreview]
    let hasUnassignedAudio: Bool

    init(leadingTrackNumber: Int, memberTracks: [TrackPreview], hasUnassignedAudio: Bool = false) {
        id = leadingTrackNumber
        self.memberTracks = memberTracks.sorted { $0.trackNumber < $1.trackNumber }
        self.hasUnassignedAudio = hasUnassignedAudio
    }

    var annotationTrackNumber: Int { id }

    var memberTrackNumbers: [Int] {
        memberTracks.map(\.trackNumber)
    }

    var trackNumberLabel: String {
        MixerChannelLayout.trackNumberLabel(forLeadingTrackNumber: id)
    }

    var isStereoPair: Bool {
        memberTrackNumbers.count == 2
    }

    var controlTrack: TrackPreview? {
        memberTracks.first(where: { $0.trackNumber == id }) ?? memberTracks.first
    }

    var isActiveTrackCandidate: Bool {
        memberTracks.contains(where: \.isActiveTrackCandidate)
    }
}
