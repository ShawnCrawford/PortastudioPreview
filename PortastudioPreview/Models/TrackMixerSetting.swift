//
//  TrackMixerSetting.swift
//  PortastudioPreview
//

import Foundation

struct TrackMixerSetting: Identifiable, Hashable, Sendable {
    struct WarningIssue: Hashable, Sendable {
        let idComponent: String
        let message: String
    }

    let trackNumber: Int
    let level: MixerSetting
    let pan: MixerSetting
    let mute: MixerSetting?

    var id: Int { trackNumber }

    var warningIssues: [WarningIssue] {
        var issues: [WarningIssue] = []

        if level.hasMirrorMismatch {
            issues.append(
                WarningIssue(
                    idComponent: "level.mirrorMismatch",
                    message: "Track \(trackNumber) \(level.name) mirror mismatch: \(level.rawBytesDescription)"
                )
            )
        }

        if pan.hasMirrorMismatch {
            issues.append(
                WarningIssue(
                    idComponent: "pan.mirrorMismatch",
                    message: "Track \(trackNumber) \(pan.name) mirror mismatch: \(pan.rawBytesDescription)"
                )
            )
        }

        if let mute, mute.hasMirrorMismatch {
            issues.append(
                WarningIssue(
                    idComponent: "mute.mirrorMismatch",
                    message: "Track \(trackNumber) \(mute.name) mirror mismatch: \(mute.rawBytesDescription)"
                )
            )
        }

        return issues
    }

    var warnings: [String] {
        warningIssues.map(\ .message)
    }

    var rawBytesDescription: String {
        [level, pan, mute]
            .compactMap { $0?.rawBytesDescription }
            .joined(separator: " | ")
    }
}
