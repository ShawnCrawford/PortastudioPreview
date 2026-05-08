//
//  ProjectWorkspacePresentation.swift
//  PortastudioPreview
//

import Foundation

enum ProjectWorkspaceMode: String, CaseIterable, Identifiable {
    case tracks
    case timeline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tracks: return "Tracks"
        case .timeline: return "Timeline"
        }
    }

    var systemImage: String {
        switch self {
        case .tracks: return "slider.horizontal.3"
        case .timeline: return "timeline.selection"
        }
    }
}

struct ProjectHeaderSummary: Equatable {
    let title: String
    let folderName: String
    let folderPath: String
    let deviceContext: String
    let formatLabel: String
    let readOnlyLabel: String
    let trackCountLabel: String
    let wavCountLabel: String
    let durationLabel: String
    let validationLabel: String
    let validationSystemImage: String
    let previewLabel: String
    let previewSystemImage: String

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
        deviceContext = "Portastudio project"
        formatLabel = "\(Int(SampleTimeFormatter.standardSampleRate / 1_000)) kHz preview domain"
        readOnlyLabel = "Read Only"
        trackCountLabel = "\(summary.trackCount) tracks"
        wavCountLabel = "\(summary.wavCount) WAV\(summary.wavCount == 1 ? "" : "s")"
        durationLabel = Self.durationLabel(for: project)

        if summary.validationIssueCount == 0 {
            validationLabel = "Validated"
            validationSystemImage = "checkmark.seal.fill"
        } else if summary.hasErrors {
            validationLabel = "\(summary.validationIssueCount) issue\(summary.validationIssueCount == 1 ? "" : "s")"
            validationSystemImage = "xmark.octagon.fill"
        } else {
            validationLabel = "\(summary.validationIssueCount) warning\(summary.validationIssueCount == 1 ? "" : "s")"
            validationSystemImage = "exclamationmark.triangle.fill"
        }

        previewLabel = summary.previewAvailable ? "Preview Available" : "No Preview"
        previewSystemImage = summary.previewAvailable ? "waveform" : "waveform.slash"
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
    let displayName: String
    let candidateWAVLabel: String
    let candidateEvidenceLabel: String
    let panLabel: String
    let levelLabel: String
    let levelPosition: Double
    let isMuted: Bool
    let muteLabel: String
    let isSelected: Bool
    let colorIndex: Int

    init(track: TrackPreview, displayName: String?, isSelected: Bool, levelPositionOverride: Double? = nil) {
        id = track.trackNumber
        trackNumber = track.trackNumber
        if let displayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayName.isEmpty {
            self.displayName = displayName
        } else {
            self.displayName = "Track \(track.trackNumber)"
        }
        candidateWAVLabel = track.candidateWAV?.rawFilename ?? "Unassigned"
        candidateEvidenceLabel = track.candidateWAV == nil ? "No WAV" : "WAV: \(track.candidateWAVEvidence.rawValue)"

        if let pan = track.mixerSetting?.pan {
            panLabel = PanMapper.displayValue(for: pan.primaryByte)
        } else {
            panLabel = "n/a"
        }

        if let levelPositionOverride {
            levelLabel = LevelMapper.previewDisplayValue(forNormalizedPosition: levelPositionOverride)
            levelPosition = levelPositionOverride
        } else if let level = track.mixerSetting?.level {
            levelLabel = LevelMapper.displayValue(for: level.primaryByte)
            levelPosition = Self.levelPosition(rawByte: level.primaryByte)
        } else {
            levelLabel = "n/a"
            levelPosition = 0
        }

        isMuted = (track.mixerSetting?.mute?.primaryByte ?? 0) != 0
        muteLabel = isMuted ? "Muted" : "Live"
        self.isSelected = isSelected
        colorIndex = (track.trackNumber - 1) % Self.paletteCount
    }

    private static let paletteCount = 8

    private static func levelPosition(rawByte: UInt8) -> Double {
        Double(rawByte) / Double(LevelMapper.rawMax)
    }
}
