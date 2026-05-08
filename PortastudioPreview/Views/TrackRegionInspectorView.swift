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

    var body: some View {
        if let track = selectedTrack {
            TrackInspectorContent(project: project, track: track, annotationStore: annotationStore)
        } else if let region = selectedRegion {
            RegionInspectorContent(project: project, region: region)
        } else {
            SongInspectorContent(project: project, annotationStore: annotationStore)
        }
    }
}

// MARK: - Song Inspector

private struct SongInspectorContent: View {
    let project: PortastudioProject
    let annotationStore: TrackAnnotationStore

    @State private var nameDraft = ""
    @FocusState private var nameFieldFocused: Bool

    private var summary: ProjectHeaderSummary {
        ProjectHeaderSummary(
            project: project,
            displayName: annotationStore.annotationContext?.effectiveDisplayName
        )
    }

    private var context: SongAnnotationContext? {
        annotationStore.annotationContext
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                InspectorSectionHeader(title: "Song Information", systemImage: "music.note.list")
                InspectorGrid {
                    InspectorRow(label: "Title", value: summary.title)
                    InspectorRow(label: "Folder", value: summary.folderName)
                    InspectorRow(
                        label: "Path",
                        value: summary.folderPath,
                        valueStyle: .secondary,
                        truncationMode: .middle
                    )
                    InspectorRow(label: "Format", value: summary.formatLabel)
                    InspectorRow(label: "Duration", value: summary.durationLabel)
                    InspectorRow(label: "Tracks", value: summary.trackCountLabel)
                    InspectorRow(label: "WAVs", value: summary.wavCountLabel)
                }

                Divider()
                InspectorSectionHeader(title: "Identity", systemImage: "checkmark.seal")
                InspectorGrid {
                    InspectorRow(label: "Access", value: summary.readOnlyLabel, valueStyle: .green)
                    InspectorRow(label: "Preview", value: summary.previewLabel)
                    InspectorRow(label: "Validation", value: summary.validationLabel)
                    if let matchState = context?.matchState {
                        InspectorRow(label: "Match", value: fingerprintMatchStateLabel(matchState) ?? "Unknown")
                    } else {
                        InspectorRow(label: "Match", value: "Unknown", valueStyle: .secondary)
                    }
                }

                if !project.validationIssues.isEmpty {
                    Divider()
                    InspectorSectionHeader(title: "Validation", systemImage: "exclamationmark.triangle")
                    ValidationIssuesView(issues: project.validationIssues)
                }

                Divider()
                InspectorSectionHeader(title: "Labels", systemImage: "tag")
                if context?.isEditable == true {
                    HStack(spacing: 6) {
                        TextField("Song name", text: $nameDraft)
                            .focused($nameFieldFocused)
                            .onSubmit { commitName() }
                            .onChange(of: nameFieldFocused) { _, focused in
                                if !focused { commitName() }
                            }
                            .accessibilityIdentifier("inspector-song-name")

                        if !nameDraft.isEmpty {
                            Button("Clear Song Name", systemImage: "xmark.circle.fill") {
                                nameDraft = ""
                                annotationStore.setSongDisplayNameOverride(nil)
                            }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.plain)
                            .help("Clear song name override")
                        }
                    }
                } else {
                    Text("Labels are read-only until the remembered song identity is an exact match.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Divider()
                InspectorSectionHeader(title: "Actions", systemImage: "ellipsis.circle")
                Button("Reveal in Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([project.folderURL])
                }
                .buttonStyle(.bordered)

                if let edl = project.edlTableSummary,
                   !edl.fileListEntries.isEmpty {
                    Divider()
                    InspectorSectionHeader(title: "EDL File List", systemImage: "list.bullet.rectangle")
                    EDLFileListInspector(edl: edl)
                }
            }
            .padding(14)
        }
        .task(id: context?.songFingerprintString) {
            nameDraft = context?.displayNameOverride ?? ""
        }
    }

    private func commitName() {
        annotationStore.setSongDisplayNameOverride(nameDraft.isEmpty ? nil : nameDraft)
        nameDraft = annotationStore.annotationContext?.displayNameOverride ?? ""
    }
}

// MARK: - Track Inspector

private struct TrackInspectorContent: View {
    let project: PortastudioProject
    let track: TrackPreview
    let annotationStore: TrackAnnotationStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                InspectorSectionHeader(title: "Track", systemImage: "slider.horizontal.3")

                InspectorGrid {
                    InspectorRow(label: "Track #", value: "\(track.trackNumber)")
                    InspectorRow(
                        label: "Candidate WAV",
                        value: track.candidateWAV?.rawFilename ?? "Unassigned",
                        secondary: track.candidateWAV != nil ? "Evidence: Hypothesis" : nil,
                        valueStyle: track.candidateWAV == nil ? .secondary : .primary
                    )
                }

                if let mixer = track.mixerSetting {
                    Divider()
                    MixerInspectorSection(mixer: mixer)
                }

                if track.trackNumber == 1, let activeTake = track.track1ActiveTakeCandidate {
                    Divider()
                    InspectorSectionHeader(title: "Active Take", systemImage: "film.stack")
                    InspectorGrid {
                        InspectorRow(
                            label: "Byte",
                            value: HexFormatter.byte(activeTake),
                            secondary: "\(HexFormatter.offset(EdlTableParser.track1ActiveTakeCandidateOffset))"
                        )
                        InspectorRow(label: "Evidence", value: "Correlated")
                    }
                }

                Divider()
                InspectorSectionHeader(title: "Label", systemImage: "tag")
                TrackLabelEditorView(trackNumber: track.trackNumber, annotationStore: annotationStore)
            }
            .padding(14)
        }
    }
}

private struct MixerInspectorSection: View {
    let mixer: TrackMixerSetting

    var body: some View {
        Group {
            InspectorSectionHeader(title: "Level", systemImage: "waveform")
            InspectorGrid {
                InspectorRow(label: "Value", value: LevelMapper.displayValue(for: mixer.level.primaryByte))
                InspectorRow(
                    label: "Raw byte",
                    value: "\(HexFormatter.byte(mixer.level.primaryByte)) @ \(HexFormatter.offset(mixer.level.primaryOffset))"
                )
                if let mirrorOffset = mixer.level.mirrorOffset, let mirrorByte = mixer.level.mirrorByte {
                    InspectorRow(
                        label: "Mirror",
                        value: "\(HexFormatter.byte(mirrorByte)) @ \(HexFormatter.offset(mirrorOffset))",
                        secondary: mixer.level.hasMirrorMismatch ? "⚠ Mismatch" : nil,
                        secondaryStyle: mixer.level.hasMirrorMismatch ? .orange : .secondary
                    )
                }
                InspectorRow(label: "Evidence", value: mixer.level.evidenceLevel.rawValue)
            }

            Divider()
            InspectorSectionHeader(title: "Pan", systemImage: "dial.low")
            InspectorGrid {
                InspectorRow(label: "Value", value: PanMapper.displayValue(for: mixer.pan.primaryByte))
                InspectorRow(
                    label: "Raw byte",
                    value: "\(HexFormatter.byte(mixer.pan.primaryByte)) @ \(HexFormatter.offset(mixer.pan.primaryOffset))"
                )
                if let mirrorOffset = mixer.pan.mirrorOffset, let mirrorByte = mixer.pan.mirrorByte {
                    InspectorRow(
                        label: "Mirror",
                        value: "\(HexFormatter.byte(mirrorByte)) @ \(HexFormatter.offset(mirrorOffset))",
                        secondary: mixer.pan.hasMirrorMismatch ? "⚠ Mismatch" : nil,
                        secondaryStyle: mixer.pan.hasMirrorMismatch ? .orange : .secondary
                    )
                }
                InspectorRow(label: "Evidence", value: mixer.pan.evidenceLevel.rawValue)
            }

            if let mute = mixer.mute {
                Divider()
                InspectorSectionHeader(title: "Mute", systemImage: "speaker.slash")
                InspectorGrid {
                    InspectorRow(
                        label: "Raw byte",
                        value: "\(HexFormatter.byte(mute.primaryByte)) @ \(HexFormatter.offset(mute.primaryOffset))"
                    )
                    if let mirrorOffset = mute.mirrorOffset, let mirrorByte = mute.mirrorByte {
                        InspectorRow(
                            label: "Mirror",
                            value: "\(HexFormatter.byte(mirrorByte)) @ \(HexFormatter.offset(mirrorOffset))",
                            secondary: mute.hasMirrorMismatch ? "⚠ Mismatch" : nil,
                            secondaryStyle: mute.hasMirrorMismatch ? .orange : .secondary
                        )
                    }
                    InspectorRow(label: "Evidence", value: mute.evidenceLevel.rawValue)
                }
            }
        }
    }
}

// MARK: - Region Inspector

private struct RegionInspectorContent: View {
    let project: PortastudioProject
    let region: TimelineRegion

    private var edlFileListMatch: EdlFileListEntry? {
        guard let filename = region.sourceFilename else { return nil }
        return project.edlTableSummary?.fileListEntries.first {
            $0.filename.caseInsensitiveCompare(filename) == .orderedSame
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                InspectorSectionHeader(title: "Region", systemImage: "waveform.badge.magnifyingglass")

                InspectorGrid {
                    InspectorRow(
                        label: "Source",
                        value: region.sourceFilename ?? "Unknown"
                    )
                    if let url = region.sourceURL {
                        InspectorRow(
                            label: "Path",
                            value: url.path(percentEncoded: false),
                            truncationMode: .middle
                        )
                    }
                }

                Divider()
                InspectorSectionHeader(title: "Timing", systemImage: "timer")
                InspectorGrid {
                    InspectorRow(
                        label: "Start",
                        value: "\(region.startSample)",
                        secondary: "≈ \(SampleTimeFormatter.displayString(samples: region.startSample))"
                    )
                    if let length = region.resolvedLengthSample {
                        InspectorRow(
                            label: "Length",
                            value: "\(length)",
                            secondary: "≈ \(SampleTimeFormatter.displayString(samples: length))"
                        )
                    }
                    if let end = region.endSample {
                        InspectorRow(
                            label: "End",
                            value: "\(end)",
                            secondary: "≈ \(SampleTimeFormatter.displayString(samples: end))"
                        )
                    }
                    InspectorRow(label: "Evidence", value: region.evidenceLevel.rawValue)
                }

                if let match = edlFileListMatch {
                    Divider()
                    InspectorSectionHeader(title: "EDL File List", systemImage: "list.bullet.rectangle")
                    InspectorGrid {
                        InspectorRow(label: "File ID", value: "#\(match.fileID)")
                        InspectorRow(label: "Filename", value: match.filename)
                        InspectorRow(label: "Evidence", value: match.evidenceLevel.rawValue)
                    }
                }

                Divider()
                InspectorSectionHeader(title: "Assignment", systemImage: "questionmark.circle")
                InspectorGrid {
                    InspectorRow(
                        label: "Status",
                        value: "Unassigned",
                        secondary: "Track-to-WAV assignment remains Hypothesis"
                    )
                }
            }
            .padding(14)
        }
    }
}

private struct EDLFileListInspector: View {
    let edl: EdlTableSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(edl.fileListEntries, id: \.self) { entry in
                HStack(spacing: 8) {
                    Text("#\(entry.fileID)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .trailing)
                    Text(entry.filename)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Text(entry.evidenceLevel.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Shared Layout Helpers

private struct InspectorSectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

private struct InspectorGrid<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 5) {
            content
        }
    }
}

private struct InspectorRow: View {
    let label: String
    let value: String
    var secondary: String? = nil
    var valueStyle: Color = .primary
    var secondaryStyle: Color = .secondary
    var truncationMode: Text.TruncationMode = .tail

    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(.tertiary)
                .font(.caption)
                .frame(minWidth: 68, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .foregroundStyle(valueStyle)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(2)
                    .truncationMode(truncationMode)

                if let secondary {
                    Text(secondary)
                        .foregroundStyle(secondaryStyle)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
        }
    }
}

private func fingerprintMatchStateLabel(_ state: FingerprintMatchState?) -> String? {
    switch state {
    case .exact: return "Exact match"
    case .changedSinceLastSeen: return "Changed since last seen"
    case .ambiguous: return "Ambiguous"
    case .unknown, nil: return nil
    }
}
