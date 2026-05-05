//
//  TrackMixerSetting.swift
//  PortastudioPreview
//

import Foundation

struct TrackMixerSetting: Identifiable, Hashable {
    let trackNumber: Int
    let level: MixerSetting
    let pan: MixerSetting
    let mute: MixerSetting?

    var id: Int { trackNumber }

    var warnings: [String] {
        [level, pan, mute].compactMap { setting in
            guard let setting, setting.hasMirrorMismatch else {
                return nil
            }

            return "Track \(trackNumber) \(setting.name) mirror mismatch: \(setting.rawBytesDescription)"
        }
    }

    var rawBytesDescription: String {
        [level, pan, mute]
            .compactMap { $0?.rawBytesDescription }
            .joined(separator: " | ")
    }
}
