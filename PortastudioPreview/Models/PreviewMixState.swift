//
//  PreviewMixState.swift
//  PortastudioPreview
//

import Foundation
import Observation

struct PreviewTrackMixSetting: Identifiable, Hashable, Sendable {
    let trackNumber: Int
    var levelPosition: Double
    var panPosition: Double

    var id: Int { trackNumber }
}

@MainActor
@Observable
final class PreviewMixState {
    var trackSettings: [PreviewTrackMixSetting]

    init(project: PortastudioProject) {
        trackSettings = project.tracks.map { track in
            let levelPosition: Double
            if let rawLevel = track.mixerSetting?.level.primaryByte {
                levelPosition = LevelMapper.normalizedPosition(for: rawLevel)
            } else {
                levelPosition = LevelMapper.normalizedPosition(for: LevelMapper.rawUnity)
            }

            let panPosition: Double
            if let rawPan = track.mixerSetting?.pan.primaryByte {
                panPosition = PanMapper.normalizedPosition(for: rawPan)
            } else {
                panPosition = 0
            }

            return PreviewTrackMixSetting(
                trackNumber: track.trackNumber,
                levelPosition: levelPosition,
                panPosition: panPosition
            )
        }
    }

    var trackVolumeOverrides: [Int: Double] {
        Dictionary(uniqueKeysWithValues: trackSettings.map { ($0.trackNumber, $0.levelPosition) })
    }

    var trackPanOverrides: [Int: Double] {
        Dictionary(uniqueKeysWithValues: trackSettings.map { ($0.trackNumber, $0.panPosition) })
    }

    func levelPosition(for trackNumber: Int) -> Double {
        trackSettings.first(where: { $0.trackNumber == trackNumber })?.levelPosition
            ?? LevelMapper.normalizedPosition(for: LevelMapper.rawUnity)
    }

    func setLevelPosition(_ levelPosition: Double, for trackNumber: Int) {
        guard let index = trackSettings.firstIndex(where: { $0.trackNumber == trackNumber }) else {
            return
        }

        trackSettings[index].levelPosition = min(max(levelPosition, 0), 1)
    }

    func panPosition(for trackNumber: Int) -> Double {
        trackSettings.first(where: { $0.trackNumber == trackNumber })?.panPosition ?? 0
    }

    func setPanPosition(_ panPosition: Double, for trackNumber: Int) {
        guard let index = trackSettings.firstIndex(where: { $0.trackNumber == trackNumber }) else {
            return
        }

        trackSettings[index].panPosition = min(max(panPosition, -1), 1)
    }
}
