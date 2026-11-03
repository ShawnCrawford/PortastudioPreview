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
    let mixState: PreviewMixState
    let selectedVirtualTrackIDs: [Int: VirtualTrackOption.ID]
    let resetSelectedAction: () -> Void
    @State private var isTechnicalDetailsExpanded = false

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
        if let selectedTrack,
           let selectedVirtualTrack = selectedVirtualTrack(for: selectedTrack) {
            return selectedVirtualTrack.wavItem.url
        }
        return selectedTrack?.candidateWAV?.url
    }

    private func selectedVirtualTrack(for track: TrackPreview) -> VirtualTrackOption? {
        let channelTrackNumber = MixerChannelLayout.leadingTrackNumber(for: track.trackNumber) ?? track.trackNumber
        return track.selectedVirtualTrackOption(selectedOptionID: selectedVirtualTrackIDs[channelTrackNumber])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SongInspectorSection(summary: summary, project: project)
                SelectedTrackInspectorSection(
                    track: selectedTrack,
                    annotationStore: annotationStore,
                    mixState: mixState,
                    selectedVirtualTrackIDs: selectedVirtualTrackIDs,
                    hasUnassignedAudio: !project.unassignedAudioRegions.isEmpty,
                    isTechnicalDetailsExpanded: $isTechnicalDetailsExpanded
                )
                AudioFilesInspectorSection(project: project, selectedRegion: selectedRegion)
                InspectorActionsSection(
                    project: project,
                    selectedAudioFileURL: selectedAudioFileURL,
                    canResetSelected: selectedTrack != nil,
                    resetSelectedAction: resetSelectedAction
                )
            }
            .padding(12)
        }
        .background(.thinMaterial)
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
    let mixState: PreviewMixState
    let selectedVirtualTrackIDs: [Int: VirtualTrackOption.ID]
    let hasUnassignedAudio: Bool
    @Binding var isTechnicalDetailsExpanded: Bool

    var body: some View {
        InspectorSectionCard(title: "Selected Track", systemImage: "slider.horizontal.3") {
            if let track {
                let annotationTrackNumber = MixerChannelLayout.leadingTrackNumber(for: track.trackNumber) ?? track.trackNumber
                let trackLabel = MixerChannelLayout.trackNumberLabel(forTrackNumber: track.trackNumber)
                let selectedVirtualTrack = selectedVirtualTrack(for: track)
                let selectedWAV = selectedVirtualTrack?.wavItem ?? track.candidateWAV
                let trackName = annotationStore.trackName(for: annotationTrackNumber) ?? "Track \(trackLabel)"

                InspectorSubheading("Identity")
                InspectorInfoRow(label: "Track", value: "Track \(trackLabel)")
                InspectorInfoRow(label: "Name", value: trackName, valueStyle: .primary)
                InspectorInfoRow(label: "Status", value: audioStatus(for: track, selectedWAV: selectedWAV), valueStyle: selectedWAV == nil ? .secondary : .primary)

                Divider()

                InspectorSubheading("Audio Source")
                InspectorInfoRow(
                    label: "Filename",
                    value: selectedWAV?.rawFilename ?? (hasUnassignedAudio ? "Unassigned audio" : "No audio file"),
                    valueStyle: selectedWAV == nil ? .secondary : .primary
                )
                InspectorInfoRow(label: "Take", value: selectedVirtualTrack?.takeLabel ?? track.defaultVirtualTrackOption?.takeLabel ?? "Default")
                InspectorInfoRow(label: "Evidence", value: selectedVirtualTrack?.evidenceLevel.rawValue ?? track.candidateWAVEvidence.rawValue)

                Divider()

                InspectorSubheading("Mix")
                InspectorInfoRow(label: "Level", value: LevelMapper.previewDisplayValue(forNormalizedPosition: mixState.levelPosition(for: annotationTrackNumber)), valueStyle: .primary)
                InspectorInfoRow(label: "Pan", value: PanMapper.previewDisplayValue(forNormalizedPosition: mixState.panPosition(for: annotationTrackNumber)), valueStyle: .primary)
                InspectorInfoRow(label: "Mute", value: mixState.isMuted(for: annotationTrackNumber) ? "On" : "Off")
                InspectorInfoRow(label: "Solo", value: mixState.isSoloed(for: annotationTrackNumber) ? "On" : "Off")
                InspectorInfoRow(label: "Status", value: mixState.isEffectivelyMuted(for: annotationTrackNumber) ? "Muted" : "Audible")

                Divider()

                DisclosureGroup("Technical Details", isExpanded: $isTechnicalDetailsExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        InspectorInfoRow(label: "Parsed Level", value: levelValue(for: track), valueStyle: .secondary)
                        InspectorInfoRow(label: "Parsed Pan", value: panValue(for: track), valueStyle: .secondary)
                        InspectorInfoRow(label: "Parsed Mute", value: parsedMuteValue(track), valueStyle: .secondary)
                        InspectorInfoRow(label: "Raw Bytes", value: rawBytes(for: track), valueStyle: .secondary)
                        if let activeTakeByte = track.track1ActiveTakeCandidate {
                            InspectorInfoRow(
                                label: "Track 1 Selector",
                                value: "\(HexFormatter.offset(EdlTableParser.track1ActiveTakeCandidateOffset))=\(HexFormatter.byte(activeTakeByte))",
                                valueStyle: .secondary
                            )
                        }
                        InspectorInfoRow(label: "Evidence", value: selectedVirtualTrack?.evidenceLevel.rawValue ?? track.candidateWAVEvidence.rawValue, valueStyle: .secondary)
                        if hasMirrorMismatch(track) {
                            InspectorInfoRow(label: "Mirror", value: "Mismatch detected", valueStyle: .orange)
                        }
                    }
                    .padding(.top, 6)
                }
                .font(.caption)
                .tint(.secondary)

                Divider()
                InspectorSubheading("Label")
                TrackLabelEditorView(trackNumber: annotationTrackNumber, annotationStore: annotationStore)
            } else {
                Text("Select a track in the mixer to view details.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func audioStatus(for track: TrackPreview, selectedWAV: WAVInventoryItem?) -> String {
        if selectedWAV != nil {
            return "Audio assigned"
        }
        if hasUnassignedAudio {
            return "Project audio is present; track mapping is unresolved"
        }
        return track.isActiveTrackCandidate ? "Missing audio" : "No audio"
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

    private func parsedMuteValue(_ track: TrackPreview) -> String {
        guard let mute = track.mixerSetting?.mute else { return "Unknown" }
        return mute.primaryByte == 0 ? "Off" : "On"
    }

    private func selectedVirtualTrack(for track: TrackPreview) -> VirtualTrackOption? {
        let channelTrackNumber = MixerChannelLayout.leadingTrackNumber(for: track.trackNumber) ?? track.trackNumber
        return track.selectedVirtualTrackOption(selectedOptionID: selectedVirtualTrackIDs[channelTrackNumber])
    }

    private func rawBytes(for track: TrackPreview) -> String {
        if let mixerSetting = track.mixerSetting {
            return mixerSetting.rawBytesDescription
        }

        return "n/a"
    }

    private func hasMirrorMismatch(_ track: TrackPreview) -> Bool {
        guard let mixerSetting = track.mixerSetting else {
            return false
        }

        return mixerSetting.level.hasMirrorMismatch
            || mixerSetting.pan.hasMirrorMismatch
            || (mixerSetting.mute?.hasMirrorMismatch ?? false)
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
                if let filename = selectedRegion.sourceFilename,
                   let entry = project.edlTableSummary?.fileListEntries.first(where: {
                       $0.filename.localizedCaseInsensitiveCompare(filename) == .orderedSame
                   }) {
                    InspectorInfoRow(
                        label: "EDL Entry",
                        value: "#\(entry.fileID) · \(entry.byteOffset.map(HexFormatter.offset) ?? "offset unavailable")",
                        valueStyle: .secondary
                    )
                }
                InspectorInfoRow(
                    label: "Start",
                    value: selectedRegion.startSample.map { SampleTimeFormatter.displayString(samples: $0) } ?? "Unresolved"
                )
                InspectorInfoRow(label: "Placement Evidence", value: selectedRegion.evidenceLevel.rawValue, valueStyle: .secondary)

                if let length = selectedRegion.resolvedLengthSample {
                    InspectorInfoRow(label: "File Length", value: SampleTimeFormatter.displayString(samples: length))
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
                        .foregroundStyle(.secondary)
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
    let canResetSelected: Bool
    let resetSelectedAction: () -> Void

    var body: some View {
        InspectorSectionCard(title: "Actions", systemImage: "ellipsis.circle") {
            Button("Reset Selected Channel", systemImage: "arrow.counterclockwise") {
                resetSelectedAction()
            }
            .buttonStyle(.bordered)
            .disabled(!canResetSelected)

            Divider()

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

private struct InspectorSubheading: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

private struct InspectorSectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            content
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 0.5)
        }
    }
}

private struct InspectorInfoRow: View {
    let label: String
    let value: String
    var valueStyle: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.caption2)
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

#if DEBUG
#Preview("Inspector - No Selection") {
    let fixture = PreviewFixtures.mixerWorkspace()

    TrackRegionInspectorView(
        project: fixture.project,
        selectedTrack: nil,
        selectedRegion: nil,
        annotationStore: fixture.annotationStore,
        mixState: fixture.mixState,
        selectedVirtualTrackIDs: fixture.selectedVirtualTrackIDs,
        resetSelectedAction: {}
    )
    .frame(width: 320, height: 680)
}

#Preview("Inspector - Selected Track") {
    let fixture = PreviewFixtures.mixerWorkspace()

    TrackRegionInspectorView(
        project: fixture.project,
        selectedTrack: fixture.project.visibleMixerChannels
            .first { $0.id == 4 }?
            .controlTrack,
        selectedRegion: nil,
        annotationStore: fixture.annotationStore,
        mixState: fixture.mixState,
        selectedVirtualTrackIDs: fixture.selectedVirtualTrackIDs,
        resetSelectedAction: {}
    )
    .frame(width: 320, height: 760)
}

#Preview("Inspector - Missing Audio") {
    let fixture = PreviewFixtures.mixerWorkspace()

    TrackRegionInspectorView(
        project: fixture.project,
        selectedTrack: fixture.project.tracks.first { $0.trackNumber == 7 },
        selectedRegion: nil,
        annotationStore: fixture.annotationStore,
        mixState: fixture.mixState,
        selectedVirtualTrackIDs: fixture.selectedVirtualTrackIDs,
        resetSelectedAction: {}
    )
    .frame(width: 320, height: 720)
}

#Preview("Inspector - Selected Region") {
    let fixture = PreviewFixtures.mixerWorkspace()
    let selectedTrack = fixture.project.tracks.first { $0.trackNumber == 1 }

    TrackRegionInspectorView(
        project: fixture.project,
        selectedTrack: selectedTrack,
        selectedRegion: selectedTrack?.timeline?.regions.first,
        annotationStore: fixture.annotationStore,
        mixState: fixture.mixState,
        selectedVirtualTrackIDs: fixture.selectedVirtualTrackIDs,
        resetSelectedAction: {}
    )
    .frame(width: 320, height: 760)
}
#endif
