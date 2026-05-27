//
//  ProjectWorkspacePresentation.swift
//  PortastudioPreview
//

import Foundation

struct ProjectHeaderSummary: Equatable {
    let title: String
    let folderName: String
    let folderPath: String
    let deviceContext: String
    let formatLabel: String
    let trackCountLabel: String
    let wavCountLabel: String
    let durationLabel: String
    let metadataLine: String
    let issueLabel: String?
    let previewUnavailableLabel: String?

    init(project: PortastudioProject, displayName: String?) {
        let summary = SongDetailSummary(project: project)
        let resolvedTitle = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let resolvedTitle, !resolvedTitle.isEmpty {
            title = resolvedTitle
        } else {
            title = project.folderName
        }
        folderName = summary.folderName
        folderPath = summary.folderPath
        deviceContext = "Song"
        formatLabel = "\(Int(SampleTimeFormatter.standardSampleRate / 1_000)) kHz"
        trackCountLabel = "\(summary.trackCount) Track\(summary.trackCount == 1 ? "" : "s")"
        wavCountLabel = "\(summary.wavCount) Audio File\(summary.wavCount == 1 ? "" : "s")"
        durationLabel = Self.durationLabel(for: project)
        metadataLine = "\(trackCountLabel) · \(wavCountLabel) · \(durationLabel)"

        if summary.validationIssueCount == 0 {
            issueLabel = nil
        } else if summary.hasErrors {
            issueLabel = "\(summary.validationIssueCount) issue\(summary.validationIssueCount == 1 ? "" : "s") need attention"
        } else {
            issueLabel = "\(summary.validationIssueCount) warning\(summary.validationIssueCount == 1 ? "" : "s")"
        }

        previewUnavailableLabel = summary.previewAvailable ? nil : "Preview unavailable"
    }

    private static func durationLabel(for project: PortastudioProject) -> String {
        // Include both assigned-track timelines and unassigned regions so that moving
        // regions into tracks doesn't silently shorten the reported duration.
        let allRegions: [TimelineRegion] =
            project.tracks.compactMap { $0.timeline?.regions.first } +
            project.unassignedAudioRegions

        let maxEnd = allRegions.compactMap { region -> Int? in
            if let endSample = region.endSample {
                return endSample
            }
            guard let length = region.resolvedLengthSample else {
                return nil
            }
            return region.startSample + length
        }
        .max()

        guard let maxEnd, maxEnd > 0 else {
            return "Duration unknown"
        }

        return SampleTimeFormatter.displayString(samples: maxEnd)
    }
}

struct TrackMixerStripPresentation: Identifiable, Equatable {
    let id: Int
    let trackNumber: Int
    let trackNumberLabel: String
    let displayName: String
    let candidateWAVLabel: String
    let candidateDetailLabel: String
    let panPosition: Double
    let panDisplayLabel: String
    let levelLabel: String
    let levelPosition: Double
    let meterLevel: Double
    let isMuted: Bool
    let isSoloed: Bool
    let isEffectivelyMuted: Bool
    let muteLabel: String
    let soloLabel: String
    let isSelected: Bool
    let colorIndex: Int
    let virtualTrackOptions: [VirtualTrackOption]
    let selectedVirtualTrackOptionID: VirtualTrackOption.ID?
    let virtualTakeLabel: String
    let evidenceLabel: String
    let hasResolvedAudio: Bool

    init(
        channel: MixerChannel,
        displayName: String?,
        isSelected: Bool,
        panPositionOverride: Double? = nil,
        levelPositionOverride: Double? = nil,
        muteOverride: Bool? = nil,
        soloOverride: Bool? = nil,
        isEffectivelyMuted: Bool? = nil,
        selectedVirtualTrackOptionID: VirtualTrackOption.ID? = nil,
        meterLevel: Double = 0
    ) {
        let track = channel.controlTrack
        let selectedVirtualTrack = track?.selectedVirtualTrackOption(selectedOptionID: selectedVirtualTrackOptionID)
        id = channel.id
        trackNumber = channel.id
        trackNumberLabel = channel.trackNumberLabel
        if let displayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            self.displayName = displayName
        } else {
            self.displayName = "Track \(channel.trackNumberLabel)"
        }
        candidateWAVLabel = selectedVirtualTrack?.wavItem.rawFilename ?? track?.candidateWAV?.rawFilename ?? "No Audio File"
        candidateDetailLabel = (selectedVirtualTrack?.wavItem ?? track?.candidateWAV) == nil ? "Unassigned" : "Audio file"
        hasResolvedAudio = (selectedVirtualTrack?.wavItem ?? track?.candidateWAV) != nil

        if let panPositionOverride {
            panPosition = min(max(panPositionOverride, -1), 1)
            panDisplayLabel = PanMapper.previewDisplayValue(forNormalizedPosition: panPosition)
        } else if let pan = track?.mixerSetting?.pan {
            panPosition = PanMapper.normalizedPosition(for: pan.primaryByte)
            panDisplayLabel = PanMapper.previewDisplayValue(forNormalizedPosition: panPosition)
        } else {
            panPosition = 0
            panDisplayLabel = "C"
        }

        if let levelPositionOverride {
            levelLabel = LevelMapper.previewDisplayValue(forNormalizedPosition: levelPositionOverride)
            levelPosition = levelPositionOverride
        } else if let level = track?.mixerSetting?.level {
            levelLabel = LevelMapper.displayValue(for: level.primaryByte)
            levelPosition = Self.levelPosition(rawByte: level.primaryByte)
        } else {
            levelLabel = "n/a"
            levelPosition = 0
        }
        self.meterLevel = min(max(meterLevel, 0), 1)

        isMuted = muteOverride ?? ((track?.mixerSetting?.mute?.primaryByte ?? 0) != 0)
        isSoloed = soloOverride ?? false
        self.isEffectivelyMuted = isEffectivelyMuted ?? isMuted
        muteLabel = isMuted ? "Muted" : "Live"
        soloLabel = isSoloed ? "Solo" : "Not soloed"
        self.isSelected = isSelected
        colorIndex = (channel.id - 1) % Self.paletteCount
        virtualTrackOptions = track?.virtualTrackOptions ?? []
        self.selectedVirtualTrackOptionID = selectedVirtualTrack?.id ?? track?.defaultVirtualTrackOptionID
        virtualTakeLabel = selectedVirtualTrack?.takeLabel ?? track?.defaultVirtualTrackOption?.takeLabel ?? "Default"
        evidenceLabel = selectedVirtualTrack?.evidenceLevel.rawValue
            ?? track?.candidateWAVEvidence.rawValue
            ?? EvidenceLevel.observed.rawValue
    }

    private static let paletteCount = 8

    private static func levelPosition(rawByte: UInt8) -> Double {
        Double(rawByte) / Double(LevelMapper.rawMax)
    }
}
