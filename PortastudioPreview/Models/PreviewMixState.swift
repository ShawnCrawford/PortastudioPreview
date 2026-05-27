//
//  PreviewMixState.swift
//  PortastudioPreview
//

import Foundation
import Observation
import SwiftData

struct PreviewTrackMixSetting: Identifiable, Hashable, Sendable {
    let channelTrackNumber: Int
    var levelPosition: Double
    var panPosition: Double
    var isMuted: Bool
    var isSoloed: Bool
    var selectedVirtualTrackOptionID: VirtualTrackOption.ID?

    var id: Int { channelTrackNumber }
}

@MainActor
@Observable
final class PreviewMixState {
    var trackSettings: [PreviewTrackMixSetting]
    private let defaultSettings: [Int: PreviewTrackMixSetting]
    private var records: [Int: MixOverrideRecord] = [:]
    private var modelContext: ModelContext?
    private var annotationContext: SongAnnotationContext?

    init(project: PortastudioProject) {
        var defaults: [Int: PreviewTrackMixSetting] = [:]
        trackSettings = project.visibleMixerChannels.map { channel in
            let controlTrack = channel.controlTrack
            let levelPosition: Double
            if let rawLevel = controlTrack?.mixerSetting?.level.primaryByte {
                levelPosition = LevelMapper.normalizedPosition(for: rawLevel)
            } else {
                levelPosition = LevelMapper.normalizedPosition(for: LevelMapper.rawUnity)
            }

            let panPosition: Double
            if let rawPan = controlTrack?.mixerSetting?.pan.primaryByte {
                panPosition = PanMapper.normalizedPosition(for: rawPan)
            } else {
                panPosition = 0
            }

            let setting = PreviewTrackMixSetting(
                channelTrackNumber: channel.id,
                levelPosition: levelPosition,
                panPosition: panPosition,
                isMuted: controlTrack.map(StereoPreviewEngine.isMuted) ?? false,
                isSoloed: false,
                selectedVirtualTrackOptionID: controlTrack?.defaultVirtualTrackOptionID
            )
            defaults[channel.id] = setting
            return setting
        }
        defaultSettings = defaults
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

    var effectiveTrackMuteOverrides: [Int: Bool] {
        let hasSolo = trackSettings.contains(where: \.isSoloed)
        return Dictionary(uniqueKeysWithValues: trackSettings.map { setting in
            let isEffectivelyMuted = hasSolo ? !setting.isSoloed || setting.isMuted : setting.isMuted
            return (setting.channelTrackNumber, isEffectivelyMuted)
        })
    }

    var selectedVirtualTrackOptionIDs: [Int: VirtualTrackOption.ID] {
        Dictionary(uniqueKeysWithValues: trackSettings.compactMap { setting in
            guard let selectedVirtualTrackOptionID = setting.selectedVirtualTrackOptionID else {
                return nil
            }
            return (setting.channelTrackNumber, selectedVirtualTrackOptionID)
        })
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadOverrides(context: SongAnnotationContext?) {
        annotationContext = context
        records = [:]
        resetToDeviceDefaultsInMemory()

        guard let context, !context.songFingerprintString.isEmpty, let modelContext else {
            return
        }

        let fp = context.songFingerprintString
        let descriptor = FetchDescriptor<MixOverrideRecord>(
            predicate: #Predicate { $0.songFingerprintString == fp }
        )
        let fetched = (try? modelContext.fetch(descriptor)) ?? []
        records = Dictionary(uniqueKeysWithValues: fetched.map { ($0.logicalChannelTrackNumber, $0) })

        for record in fetched {
            guard let index = index(for: record.logicalChannelTrackNumber) else {
                continue
            }
            trackSettings[index].levelPosition = min(max(record.levelPosition, 0), 1)
            trackSettings[index].panPosition = min(max(record.panPosition, -1), 1)
            trackSettings[index].isMuted = record.isMuted
            trackSettings[index].isSoloed = record.isSoloed
            trackSettings[index].selectedVirtualTrackOptionID = record.selectedVirtualTrackOptionID
        }
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
        persistSetting(at: index)
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
        persistSetting(at: index)
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
        persistSetting(at: index)
    }

    func isSoloed(for trackNumber: Int) -> Bool {
        trackSettings.first(where: { $0.channelTrackNumber == logicalChannelTrackNumber(for: trackNumber) })?.isSoloed ?? false
    }

    func setSoloed(_ isSoloed: Bool, for trackNumber: Int) {
        let channelTrackNumber = logicalChannelTrackNumber(for: trackNumber)
        guard let index = trackSettings.firstIndex(where: { $0.channelTrackNumber == channelTrackNumber }) else {
            return
        }

        trackSettings[index].isSoloed = isSoloed
        persistSetting(at: index)
    }

    func isEffectivelyMuted(for trackNumber: Int) -> Bool {
        effectiveTrackMuteOverrides[logicalChannelTrackNumber(for: trackNumber)] ?? false
    }

    func selectedVirtualTrackOptionID(for trackNumber: Int) -> VirtualTrackOption.ID? {
        trackSettings.first(where: { $0.channelTrackNumber == logicalChannelTrackNumber(for: trackNumber) })?.selectedVirtualTrackOptionID
    }

    func setSelectedVirtualTrackOptionID(_ selectedID: VirtualTrackOption.ID?, for trackNumber: Int) {
        let channelTrackNumber = logicalChannelTrackNumber(for: trackNumber)
        guard let index = trackSettings.firstIndex(where: { $0.channelTrackNumber == channelTrackNumber }) else {
            return
        }

        trackSettings[index].selectedVirtualTrackOptionID = selectedID
        persistSetting(at: index)
    }

    func resetChannel(trackNumber: Int) {
        let channelTrackNumber = logicalChannelTrackNumber(for: trackNumber)
        guard let index = index(for: channelTrackNumber),
              let defaultSetting = defaultSettings[channelTrackNumber] else {
            return
        }

        trackSettings[index] = defaultSetting
        if let modelContext, let record = records[channelTrackNumber] {
            modelContext.delete(record)
            records[channelTrackNumber] = nil
            try? modelContext.save()
        }
    }

    func resetAll() {
        resetToDeviceDefaultsInMemory()
        guard let modelContext else {
            records = [:]
            return
        }

        for record in records.values {
            modelContext.delete(record)
        }
        records = [:]
        try? modelContext.save()
    }

    private func logicalChannelTrackNumber(for trackNumber: Int) -> Int {
        MixerChannelLayout.leadingTrackNumber(for: trackNumber) ?? trackNumber
    }

    private func index(for channelTrackNumber: Int) -> Int? {
        trackSettings.firstIndex { $0.channelTrackNumber == channelTrackNumber }
    }

    private func resetToDeviceDefaultsInMemory() {
        trackSettings = trackSettings.map { setting in
            defaultSettings[setting.channelTrackNumber] ?? setting
        }
    }

    private func persistSetting(at index: Int) {
        guard let modelContext,
              let annotationContext,
              !annotationContext.songFingerprintString.isEmpty,
              annotationContext.isEditable else {
            return
        }

        let setting = trackSettings[index]
        if setting == defaultSettings[setting.channelTrackNumber] {
            if let record = records[setting.channelTrackNumber] {
                modelContext.delete(record)
                records[setting.channelTrackNumber] = nil
                try? modelContext.save()
            }
            return
        }

        if let existing = records[setting.channelTrackNumber] {
            existing.levelPosition = setting.levelPosition
            existing.panPosition = setting.panPosition
            existing.isMuted = setting.isMuted
            existing.isSoloed = setting.isSoloed
            existing.selectedVirtualTrackOptionID = setting.selectedVirtualTrackOptionID
            existing.updatedAt = Date()
            existing.lastKnownSongDisplayName = annotationContext.folderDerivedDisplayName
            existing.lastKnownSongPath = annotationContext.folderURL.path
            existing.songRecordID = annotationContext.songRecordID
        } else {
            let record = MixOverrideRecord(
                songFingerprintString: annotationContext.songFingerprintString,
                logicalChannelTrackNumber: setting.channelTrackNumber,
                levelPosition: setting.levelPosition,
                panPosition: setting.panPosition,
                isMuted: setting.isMuted,
                isSoloed: setting.isSoloed,
                selectedVirtualTrackOptionID: setting.selectedVirtualTrackOptionID,
                lastKnownSongDisplayName: annotationContext.folderDerivedDisplayName,
                lastKnownSongPath: annotationContext.folderURL.path,
                songRecordID: annotationContext.songRecordID
            )
            modelContext.insert(record)
            records[setting.channelTrackNumber] = record
        }

        try? modelContext.save()
    }
}
