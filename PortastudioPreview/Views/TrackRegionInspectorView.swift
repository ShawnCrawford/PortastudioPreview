//
//  TrackRegionInspectorView.swift
//  PortastudioPreview
//

import AppKit
import SwiftUI

struct TrackRegionInspectorView: View {
    let project: PortastudioProject
    let selectedTrack: TrackPreview?
    let selectedRegion: TimelineRegion?
    let annotationStore: TrackAnnotationStore

    private var summary: ProjectHeaderSummary {
        ProjectHeaderSummary(
            project: project,
            displayName: annotationStore.annotationContext?.effectiveDisplayName
        )
    }

    private var selectedAudioFileURL: URL? {
        if let url = selectedRegion?.sourceURL {
            return url
        }
        return selectedTrack?.candidateWAV?.url
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SongInspectorSection(summary: summary, project: project)
                SelectedTrackInspectorSection(track: selectedTrack, annotationStore: annotationStore)
                AudioFilesInspectorSection(project: project, selectedRegion: selectedRegion)
                InspectorActionsSection(project: project, selectedAudioFileURL: selectedAudioFileURL)
            }
            .padding(14)
        }
    }
}

private struct SongInspectorSection: View {
    let summary: ProjectHeaderSummary
    let project: PortastudioProject

    var body: some View {
        InspectorSectionCard(title: "Song", systemImage: "music.note.list") {
            InspectorInfoRow(label: "Title", value: summary.title)
            InspectorInfoRow(label: "Folder", value: summary.folderName)
            InspectorInfoRow(label: "Duration", value: summary.durationLabel)
            InspectorInfoRow(label: "Tracks", value: summary.trackCountLabel)
            InspectorInfoRow(label: "Audio Files", value: summary.wavCountLabel)

            if let issueLabel = summary.issueLabel {
                InspectorInfoRow(label: "Status", value: issueLabel, valueStyle: .orange)
            }
            if let unavailable = summary.previewUnavailableLabel {
                InspectorInfoRow(label: "Preview", value: unavailable, valueStyle: .secondary)
            }
        }
    }
}

private struct SelectedTrackInspectorSection: View {
    let track: TrackPreview?
    let annotationStore: TrackAnnotationStore

    var body: some View {
        InspectorSectionCard(title: "Selected Track", systemImage: "slider.horizontal.3") {
            if let track {
                let annotationTrackNumber = MixerChannelLayout.leadingTrackNumber(for: track.trackNumber) ?? track.trackNumber
                let trackLabel = MixerChannelLayout.trackNumberLabel(forTrackNumber: track.trackNumber)
                InspectorInfoRow(label: "Track", value: "Track \(trackLabel)")
                InspectorInfoRow(
                    label: "Name",
                    value: annotationStore.trackName(for: annotationTrackNumber) ?? "Track \(trackLabel)",
                    valueStyle: .primary
                )
                InspectorInfoRow(
                    label: "Audio File",
                    value: track.candidateWAV?.rawFilename ?? "No Audio File",
                    valueStyle: track.candidateWAV == nil ? .secondary : .primary
                )
                InspectorInfoRow(label: "Pan", value: panValue(for: track))
                InspectorInfoRow(label: "Level", value: levelValue(for: track))
                InspectorInfoRow(label: "Mute", value: isMuted(track) ? "On" : "Off")

                Divider()
                TrackLabelEditorView(trackNumber: annotationTrackNumber, annotationStore: annotationStore)
            } else {
                Text("Select a track in the mixer to view details.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func panValue(for track: TrackPreview) -> String {
        guard let pan = track.mixerSetting?.pan else { return "n/a" }
        return PanMapper.displayValue(for: pan.primaryByte)
    }

    private func levelValue(for track: TrackPreview) -> String {
        guard let level = track.mixerSetting?.level else { return "n/a" }
        return LevelMapper.displayValue(for: level.primaryByte)
    }

    private func isMuted(_ track: TrackPreview) -> Bool {
        (track.mixerSetting?.mute?.primaryByte ?? 0) != 0
    }
}

private struct AudioFilesInspectorSection: View {
    let project: PortastudioProject
    let selectedRegion: TimelineRegion?

    var body: some View {
        InspectorSectionCard(title: "Audio Files", systemImage: "waveform") {
            if let selectedRegion {
                Text("Selected Audio File")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                InspectorInfoRow(label: "Filename", value: selectedRegion.sourceFilename ?? "Unknown")
                InspectorInfoRow(label: "Start", value: SampleTimeFormatter.displayString(samples: selectedRegion.startSample))

                if let length = selectedRegion.resolvedLengthSample {
                    InspectorInfoRow(label: "Length", value: SampleTimeFormatter.displayString(samples: length))
                }
            }

            if !project.wavInventory.isEmpty {
                if selectedRegion != nil {
                    Divider()
                }

                Text("Song Files")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(project.wavInventory.prefix(8), id: \.url) { item in
                    Text(item.rawFilename)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if project.wavInventory.count > 8 {
                    Text("+ \(project.wavInventory.count - 8) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No audio files were found for this song.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct InspectorActionsSection: View {
    let project: PortastudioProject
    let selectedAudioFileURL: URL?

    var body: some View {
        InspectorSectionCard(title: "Actions", systemImage: "ellipsis.circle") {
            Button("Reveal Song in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([project.folderURL])
            }
            .buttonStyle(.bordered)

            Button("Reveal Audio File in Finder", systemImage: "waveform.path") {
                guard let selectedAudioFileURL else { return }
                NSWorkspace.shared.activateFileViewerSelecting([selectedAudioFileURL])
            }
            .buttonStyle(.bordered)
            .disabled(selectedAudioFileURL == nil)
        }
    }
}

private struct InspectorSectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 10))
    }
}

private struct InspectorInfoRow: View {
    let label: String
    let value: String
    var valueStyle: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundStyle(valueStyle)
                .lineLimit(2)
                .truncationMode(.middle)

            Spacer(minLength: 0)
        }
    }
}
