//
//  ProjectWorkspaceView.swift
//  PortastudioPreview
//

import SwiftUI

struct ProjectWorkspaceView: View {
    let project: PortastudioProject
    let annotationStore: TrackAnnotationStore
    @Binding var selectedTrackID: TrackPreview.ID?
    @Binding var selectedRegionID: TimelineRegion.ID?
    @Binding var workspaceMode: ProjectWorkspaceMode
    let playbackController: PreviewPlaybackController
    let showInspector: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ProjectHeaderView(
                project: project,
                annotationStore: annotationStore,
                playbackController: playbackController
            )

            Divider()

            ProjectModeBarView(
                selection: $workspaceMode,
                showInspector: showInspector
            )

            Divider()

            ProjectEditorSurface(
                project: project,
                selectedTrackID: $selectedTrackID,
                selectedRegionID: $selectedRegionID,
                workspaceMode: workspaceMode,
                annotationStore: annotationStore,
                playbackController: playbackController
            )
        }
        .frame(minWidth: 760, minHeight: 620)
        .background(.background)
        .accessibilityIdentifier("project-workspace")
    }
}

// MARK: - Header

private struct ProjectHeaderView: View {
    let project: PortastudioProject
    let annotationStore: TrackAnnotationStore
    let playbackController: PreviewPlaybackController

    private var summary: ProjectHeaderSummary {
        ProjectHeaderSummary(
            project: project,
            displayName: annotationStore.annotationContext?.effectiveDisplayName
        )
    }

    private var canPlay: Bool {
        playbackController.canPlay(project)
    }

    var body: some View {
        HStack(spacing: 18) {
            ProjectGlyphView()

            VStack(alignment: .leading, spacing: 4) {
                Text(summary.title)
                    .font(.title3)
                    .bold()
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(summary.deviceContext)
                    Text(summary.formatLabel)
                    Text(summary.trackCountLabel)
                    ReadOnlyBadge(text: summary.readOnlyLabel)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)

            HeaderTransportControls(
                project: project,
                playbackController: playbackController,
                canPlay: canPlay
            )

            if let error = playbackController.playbackError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(minWidth: 80, maxWidth: 160)
                    .accessibilityLabel("Playback error: \(error)")
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(elapsedLabel)
                    .font(.system(.title3, design: .monospaced))
                    .contentTransition(.numericText())
                Text(summary.durationLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 120, alignment: .trailing)

            PreviewActivityMeter(playbackController: playbackController)
                .frame(width: 150)

            VStack(alignment: .leading, spacing: 4) {
                Label(summary.validationLabel, systemImage: summary.validationSystemImage)
                    .foregroundStyle(validationStyle)
                Label(summary.previewLabel, systemImage: summary.previewSystemImage)
                    .foregroundStyle(canPlay ? .secondary : .tertiary)
            }
            .font(.caption)
            .frame(width: 118, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .accessibilityElement(children: .contain)
    }

    private var elapsedLabel: String {
        SampleTimeFormatter.displayString(
            samples: Int(playbackController.elapsedSeconds * SampleTimeFormatter.standardSampleRate)
        )
    }

    private var validationStyle: Color {
        if project.validationIssues.contains(where: { $0.severity == .error }) {
            return .red
        } else if project.validationIssues.isEmpty {
            return .green
        } else {
            return .orange
        }
    }
}

private struct ProjectGlyphView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
            Image(systemName: "slider.horizontal.below.rectangle")
                .font(.title2)
                .foregroundStyle(.teal)
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)
    }
}

private struct ReadOnlyBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.green.opacity(0.14), in: .capsule)
            .foregroundStyle(.green)
    }
}

private struct HeaderTransportControls: View {
    let project: PortastudioProject
    let playbackController: PreviewPlaybackController
    let canPlay: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button("Play Preview", systemImage: "play.fill") {
                playbackController.startPreview(for: project)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderedProminent)
            .disabled(playbackController.isPlaying || !canPlay)
            .help("Play approximate stereo preview")
            .accessibilityLabel("Play approximate stereo preview")

            Button("Stop Preview", systemImage: "stop.fill") {
                playbackController.stop()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .disabled(!playbackController.isPlaying)
            .help("Stop playback")
            .accessibilityLabel("Stop playback")
        }
        .controlSize(.large)
    }
}

private struct PreviewActivityMeter: View {
    let playbackController: PreviewPlaybackController

    private var leftLevel: Double {
        guard playbackController.isPlaying else { return 0 }
        return 0.35 + 0.45 * abs(sin(playbackController.elapsedSeconds * 4.2))
    }

    private var rightLevel: Double {
        guard playbackController.isPlaying else { return 0 }
        return 0.30 + 0.42 * abs(sin(playbackController.elapsedSeconds * 3.4 + 0.6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MeterRow(label: "L", value: leftLevel)
            MeterRow(label: "R", value: rightLevel)
        }
        .help("Preview activity meter. This is not a calibrated hardware level meter.")
        .accessibilityLabel("Preview activity meter, not calibrated")
    }
}

private struct MeterRow: View {
    let label: String
    let value: Double

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 10, alignment: .trailing)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(meterStyle)
                        .frame(width: max(proxy.size.width * value, 2))
                }
            }
            .frame(height: 6)
        }
    }

    private var meterStyle: LinearGradient {
        LinearGradient(
            colors: [.green, .green, .yellow, .orange],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Mode Bar

private struct ProjectModeBarView: View {
    @Binding var selection: ProjectWorkspaceMode
    let showInspector: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ProjectWorkspaceMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    VStack(spacing: 7) {
                        Label(mode.title, systemImage: mode.systemImage)
                            .labelStyle(.titleAndIcon)
                            .font(.callout)
                        Rectangle()
                            .fill(selection == mode ? Color.teal : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(minWidth: 112)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == mode ? .primary : .secondary)
                .accessibilityIdentifier("project-mode-\(mode.rawValue)")
            }

            Spacer()

            Label("Track-to-WAV assignment: Hypothesis", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .help("The app keeps inferred track-to-WAV behavior labeled as Hypothesis.")
        }
        .padding(.horizontal, 18)
        .padding(.top, 9)
    }
}

// MARK: - Editor

private struct ProjectEditorSurface: View {
    let project: PortastudioProject
    @Binding var selectedTrackID: TrackPreview.ID?
    @Binding var selectedRegionID: TimelineRegion.ID?
    let workspaceMode: ProjectWorkspaceMode
    let annotationStore: TrackAnnotationStore
    let playbackController: PreviewPlaybackController

    var body: some View {
        switch workspaceMode {
        case .tracks:
            TrackMixerDeckView(
                tracks: project.tracks,
                selectedTrackID: $selectedTrackID,
                annotationStore: annotationStore
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityIdentifier("editor-surface-tracks")

        case .timeline:
            TimelineSurface(
                project: project,
                selectedRegionID: $selectedRegionID,
                playbackController: playbackController
            )
            .accessibilityIdentifier("editor-surface-timeline")
        }
    }
}

private struct TimelineSurface: View {
    let project: PortastudioProject
    @Binding var selectedRegionID: TimelineRegion.ID?
    let playbackController: PreviewPlaybackController

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Timeline", systemImage: "timeline.selection")
                    .font(.headline)
                Spacer()
                Text("\(project.unassignedAudioRegions.count) region\(project.unassignedAudioRegions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if project.unassignedAudioRegions.isEmpty {
                ContentUnavailableView(
                    "No Timeline Regions",
                    systemImage: "waveform.slash",
                    description: Text("No unassigned WAV regions were parsed for this song.")
                )
                .frame(maxWidth: .infinity, minHeight: 300)
            } else {
                TimelineVisualizationView(
                    project: project,
                    selectedRegionID: $selectedRegionID,
                    playbackController: playbackController
                )
                .background(.background.secondary)
                .clipShape(.rect(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                }
                .frame(minHeight: 360)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background.secondary.opacity(0.35))
    }
}

// MARK: - Mixer Deck

struct TrackMixerDeckView: View {
    let tracks: [TrackPreview]
    @Binding var selectedTrackID: TrackPreview.ID?
    let annotationStore: TrackAnnotationStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Tracks", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
                Text("\(tracks.count) read-only mixer strips")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)

            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(tracks) { track in
                        let presentation = TrackMixerStripPresentation(
                            track: track,
                            displayName: annotationStore.trackName(for: track.trackNumber),
                            isSelected: selectedTrackID == track.id
                        )
                        TrackMixerStripButton(presentation: presentation) {
                            selectedTrackID = track.id
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
            .scrollIndicators(.hidden)
        }
        .frame(height: 248)
        .background(.regularMaterial)
        .accessibilityIdentifier("track-mixer-deck")
    }
}

private struct TrackMixerStripButton: View {
    let presentation: TrackMixerStripPresentation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TrackMixerStripView(presentation: presentation)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Track \(presentation.trackNumber), \(presentation.displayName)")
        .accessibilityValue("\(presentation.levelLabel), pan \(presentation.panLabel), \(presentation.muteLabel)")
    }
}

private struct TrackMixerStripView: View {
    let presentation: TrackMixerStripPresentation

    private static let colors: [Color] = [.red, .orange, .yellow, .green, .teal, .blue, .purple, .pink]

    private var trackColor: Color {
        Self.colors[presentation.colorIndex % Self.colors.count]
    }

    var body: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(trackColor)
                .frame(height: 3)

            VStack(spacing: 2) {
                Text("\(presentation.trackNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(presentation.displayName)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(height: 34)

            Text(presentation.candidateWAVLabel)
                .font(.caption2)
                .foregroundStyle(presentation.candidateWAVLabel == "Unassigned" ? .tertiary : .secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(height: 16)

            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("PAN")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(presentation.panLabel)
                        .font(.caption)
                        .monospacedDigit()
                }

                VStack(spacing: 2) {
                    Text("M")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Image(systemName: presentation.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundStyle(presentation.isMuted ? .orange : .secondary)
                }
            }

            HStack(alignment: .bottom, spacing: 7) {
                LevelScaleView()
                FaderTrackView(value: presentation.levelPosition, color: trackColor)
                OutputLevelView(value: presentation.isMuted ? 0 : max(presentation.levelPosition, 0.08))
            }
            .frame(height: 86)

            Text(presentation.levelLabel)
                .font(.caption)
                .monospacedDigit()
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.primary.opacity(0.08), in: .rect(cornerRadius: 4))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 96, height: 206)
        .background(presentation.isSelected ? trackColor.opacity(0.13) : Color.clear)
        .overlay {
            Rectangle()
                .stroke(
                    presentation.isSelected ? trackColor.opacity(0.8) : Color.secondary.opacity(0.16),
                    lineWidth: 1
                )
        }
        .contentShape(.rect)
    }
}

private struct LevelScaleView: View {
    var body: some View {
        VStack {
            ForEach(["10", "0", "-10", "-30", "-60"], id: \.self) { label in
                Text(label)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(width: 19)
    }
}

private struct FaderTrackView: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(value, 0), 1)
            let handleY = proxy.size.height * (1 - clamped)

            ZStack(alignment: .top) {
                Capsule()
                    .fill(.quaternary)
                    .frame(width: 5)
                    .frame(maxHeight: .infinity)
                Capsule()
                    .fill(color.opacity(0.45))
                    .frame(width: 5, height: max(proxy.size.height * clamped, 3))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                RoundedRectangle(cornerRadius: 3)
                    .fill(.background)
                    .shadow(radius: 1, y: 1)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    }
                    .frame(width: 22, height: 12)
                    .offset(y: handleY - 6)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 28)
    }
}

private struct OutputLevelView: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(value, 0), 1)
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(.quaternary)
                Rectangle()
                    .fill(.linearGradient(colors: [.green, .yellow], startPoint: .bottom, endPoint: .top))
                    .frame(height: max(proxy.size.height * clamped, 2))
            }
        }
        .frame(width: 10)
        .clipShape(.rect(cornerRadius: 2))
    }
}
