//
//  PreviewMixState.swift
//  PortastudioPreview
//

import Foundation
import Observation

struct PreviewTrackMixSetting: Identifiable, Hashable, Sendable {
    let channelTrackNumber: Int
    var levelPosition: Double
    var panPosition: Double
    var isMuted: Bool

    var id: Int { channelTrackNumber }
}

@MainActor
@Observable
final class PreviewMixState {
    var trackSettings: [PreviewTrackMixSetting]

    init(project: PortastudioProject) {
        trackSettings = project.visibleMixerChannels.compactMap { channel in
            guard let controlTrack = channel.controlTrack else {
                return nil
            }

            let levelPosition: Double
            if let rawLevel = controlTrack.mixerSetting?.level.primaryByte {
                levelPosition = LevelMapper.normalizedPosition(for: rawLevel)
            } else {
                levelPosition = LevelMapper.normalizedPosition(for: LevelMapper.rawUnity)
            }

            let panPosition: Double
            if let rawPan = controlTrack.mixerSetting?.pan.primaryByte {
                panPosition = PanMapper.normalizedPosition(for: rawPan)
            } else {
                panPosition = 0
            }

            return PreviewTrackMixSetting(
                channelTrackNumber: channel.id,
                levelPosition: levelPosition,
                panPosition: panPosition,
                isMuted: StereoPreviewEngine.isMuted(controlTrack)
            )
        }
    }

    var trackVolumeOverrides: [Int: Double] {
        Dictionary(uniqueKeysWithValues: trackSettings.map { ($0.channelTrackNumber, $0.levelPosition) })
    }

    var trackPanOverrides: [Int: Double] {
        Dictionary(uniqueKeysWithValues: trackSettings.map { ($0.channelTrackNumber, $0.panPosition) })
    }

    var trackMuteOverrides: [Int: Bool] {
        Dictionary(uniqueKeysWithValues: trackSettings.map { ($0.channelTrackNumber, $0.isMuted) })
    }

    func levelPosition(for trackNumber: Int) -> Double {
        trackSettings.first(where: { $0.channelTrackNumber == logicalChannelTrackNumber(for: trackNumber) })?.levelPosition
            ?? LevelMapper.normalizedPosition(for: LevelMapper.rawUnity)
    }

    func setLevelPosition(_ levelPosition: Double, for trackNumber: Int) {
        let channelTrackNumber = logicalChannelTrackNumber(for: trackNumber)
        guard let index = trackSettings.firstIndex(where: { $0.channelTrackNumber == channelTrackNumber }) else {
            return
        }

        trackSettings[index].levelPosition = min(max(levelPosition, 0), 1)
    }

    func panPosition(for trackNumber: Int) -> Double {
        trackSettings.first(where: { $0.channelTrackNumber == logicalChannelTrackNumber(for: trackNumber) })?.panPosition ?? 0
    }

    func setPanPosition(_ panPosition: Double, for trackNumber: Int) {
        let channelTrackNumber = logicalChannelTrackNumber(for: trackNumber)
        guard let index = trackSettings.firstIndex(where: { $0.channelTrackNumber == channelTrackNumber }) else {
            return
        }

        trackSettings[index].panPosition = min(max(panPosition, -1), 1)
    }

    func isMuted(for trackNumber: Int) -> Bool {
        trackSettings.first(where: { $0.channelTrackNumber == logicalChannelTrackNumber(for: trackNumber) })?.isMuted ?? false
    }

    func setMuted(_ isMuted: Bool, for trackNumber: Int) {
        let channelTrackNumber = logicalChannelTrackNumber(for: trackNumber)
        guard let index = trackSettings.firstIndex(where: { $0.channelTrackNumber == channelTrackNumber }) else {
            return
        }

        trackSettings[index].isMuted = isMuted
    }

    private func logicalChannelTrackNumber(for trackNumber: Int) -> Int {
        MixerChannelLayout.leadingTrackNumber(for: trackNumber) ?? trackNumber
    }
}
