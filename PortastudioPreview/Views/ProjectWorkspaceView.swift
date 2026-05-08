//
//  ProjectWorkspaceView.swift
//  PortastudioPreview
//

import SwiftUI

struct ProjectWorkspaceView: View {
    let project: PortastudioProject
    let annotationStore: TrackAnnotationStore
    @Binding var selectedTrackID: TrackPreview.ID?
    let playbackController: PreviewPlaybackController
    let mixState: PreviewMixState
    @Binding var selectedVirtualTrackIDs: [Int: VirtualTrackOption.ID]

    var body: some View {
        VStack(spacing: 0) {
            ProjectHeaderView(
                project: project,
                annotationStore: annotationStore,
                playbackController: playbackController,
                mixState: mixState,
                selectedVirtualTrackIDs: selectedVirtualTrackIDs
            )

            Divider()

            TrackMixerDeckView(
                tracks: project.visibleTracks,
                selectedTrackID: $selectedTrackID,
                annotationStore: annotationStore,
                playbackController: playbackController,
                mixState: mixState
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("editor-surface-mixer")
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
    let mixState: PreviewMixState
    let selectedVirtualTrackIDs: [Int: VirtualTrackOption.ID]

    private var summary: ProjectHeaderSummary {
        ProjectHeaderSummary(
            project: project,
            displayName: annotationStore.annotationContext?.effectiveDisplayName
        )
    }

    private var canPlay: Bool {
        playbackController.canPlay(project, selectedVirtualTrackOptionIDs: selectedVirtualTrackIDs)
    }

    var body: some View {
        HStack(spacing: 20) {
            ProjectGlyphView()

            VStack(alignment: .leading, spacing: 6) {
                Text(summary.title)
                    .font(.title2)
                    .bold()
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.metadataLine)
                    Text("\(summary.deviceContext) · \(summary.formatLabel)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)

            HeaderTransportControls(
                project: project,
                playbackController: playbackController,
                mixState: mixState,
                selectedVirtualTrackIDs: selectedVirtualTrackIDs,
                canPlay: canPlay
            )

            VStack(alignment: .trailing, spacing: 2) {
                Text(elapsedLabel)
                    .font(.system(.title3, design: .monospaced))
                    .contentTransition(.numericText())
                Text(summary.durationLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 132, alignment: .trailing)

            PreviewActivityMeter(playbackController: playbackController)
                .frame(width: 180)

            VStack(alignment: .leading, spacing: 4) {
                if let error = playbackController.playbackError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .accessibilityLabel("Playback error: \(error)")
                } else {
                    if let issueLabel = summary.issueLabel {
                        Label(issueLabel, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    if let unavailable = summary.previewUnavailableLabel {
                        Label(unavailable, systemImage: "waveform.slash")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.caption)
            .frame(width: 190, alignment: .leading)
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

private struct HeaderTransportControls: View {
    let project: PortastudioProject
    let playbackController: PreviewPlaybackController
    let mixState: PreviewMixState
    let selectedVirtualTrackIDs: [Int: VirtualTrackOption.ID]
    let canPlay: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button("Play Preview", systemImage: "play.fill") {
                playbackController.startPreview(
                    for: project,
                    trackVolumeOverrides: mixState.trackVolumeOverrides,
                    trackPanOverrides: mixState.trackPanOverrides,
                    trackMuteOverrides: mixState.trackMuteOverrides,
                    selectedVirtualTrackOptionIDs: selectedVirtualTrackIDs
                )
            }
            .buttonStyle(.borderedProminent)
            .disabled(playbackController.isPlaying || !canPlay)
            .help("Play song preview")
            .accessibilityLabel("Play song preview")

            Button("Stop Preview", systemImage: "stop.fill") {
                playbackController.stop()
            }
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
        playbackController.outputMeterLevels.left
    }

    private var rightLevel: Double {
        playbackController.outputMeterLevels.right
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MeterRow(label: "L", value: leftLevel)
            MeterRow(label: "R", value: rightLevel)
        }
        .help("Realtime preview output meter")
        .accessibilityLabel("Realtime preview output meter")
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
                        .frame(width: value == 0 ? 0 : max(proxy.size.width * value, 2))
                }
            }
            .frame(height: 8)
        }
    }

    private var meterStyle: LinearGradient {
        LinearGradient(
            colors: [.mint.opacity(0.75), .teal.opacity(0.75), .blue.opacity(0.75)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Mixer Deck

struct TrackMixerDeckView: View {
    let tracks: [TrackPreview]
    @Binding var selectedTrackID: TrackPreview.ID?
    let annotationStore: TrackAnnotationStore
    let playbackController: PreviewPlaybackController
    let mixState: PreviewMixState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Mixer", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
                Text("\(tracks.count) track\(tracks.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, MixerDeckMetrics.edgePadding)
            .padding(.top, 18)
            .padding(.bottom, 12)

            GeometryReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .center, spacing: MixerDeckMetrics.stripSpacing) {
                        ForEach(tracks) { track in
                            let presentation = TrackMixerStripPresentation(
                                track: track,
                                displayName: annotationStore.trackName(for: track.trackNumber),
                                isSelected: selectedTrackID == track.id,
                                panPositionOverride: mixState.panPosition(for: track.trackNumber),
                                levelPositionOverride: mixState.levelPosition(for: track.trackNumber),
                                muteOverride: mixState.isMuted(for: track.trackNumber),
                                meterLevel: playbackController.trackMeterLevel(for: track.trackNumber)
                            )
                            TrackMixerStripView(
                                presentation: presentation,
                                selectAction: {
                                    selectedTrackID = track.id
                                },
                                setLevelPosition: { newValue in
                                    selectedTrackID = track.id
                                    mixState.setLevelPosition(newValue, for: track.trackNumber)
                                    playbackController.setTrackVolume(newValue, for: track.trackNumber)
                                },
                                setPanPosition: { newValue in
                                    selectedTrackID = track.id
                                    mixState.setPanPosition(newValue, for: track.trackNumber)
                                    playbackController.setTrackPan(newValue, for: track.trackNumber)
                                },
                                setMuted: { isMuted in
                                    selectedTrackID = track.id
                                    mixState.setMuted(isMuted, for: track.trackNumber)
                                    playbackController.setTrackMute(isMuted, for: track.trackNumber)
                                }
                            )
                            .frame(
                                width: MixerDeckMetrics.stripWidth,
                                height: stripHeight(availableHeight: proxy.size.height)
                            )
                        }
                    }
                    .padding(.horizontal, MixerDeckMetrics.edgePadding)
                    .padding(.vertical, MixerDeckMetrics.channelVerticalPadding)
                    .frame(
                        minWidth: proxy.size.width,
                        minHeight: proxy.size.height,
                        alignment: .center
                    )
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial, in: .rect(cornerRadius: 8))
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .accessibilityIdentifier("track-mixer-deck")
    }

    private func stripHeight(availableHeight: CGFloat) -> CGFloat {
        max(
            MixerDeckMetrics.minimumStripHeight,
            availableHeight - (MixerDeckMetrics.channelVerticalPadding * 2)
        )
    }
}

private enum MixerDeckMetrics {
    static let edgePadding: CGFloat = 28
    static let channelVerticalPadding: CGFloat = 18
    static let stripSpacing: CGFloat = 18
    static let stripWidth: CGFloat = 148
    static let minimumStripHeight: CGFloat = 390
}

private struct TrackMixerStripView: View {
    let presentation: TrackMixerStripPresentation
    let selectAction: () -> Void
    let setLevelPosition: (Double) -> Void
    let setPanPosition: (Double) -> Void
    let setMuted: (Bool) -> Void

    private static let colors: [Color] = [
        .blue.opacity(0.75),
        .mint.opacity(0.75),
        .teal.opacity(0.75),
        .indigo.opacity(0.75),
        .cyan.opacity(0.75),
        .gray.opacity(0.75),
        .brown.opacity(0.75),
        .purple.opacity(0.75)
    ]

    private var trackColor: Color {
        Self.colors[presentation.colorIndex % Self.colors.count]
    }

    var body: some View {
        VStack(spacing: 12) {
            Button(action: selectAction) {
                VStack(spacing: 4) {
                    Text("Track \(presentation.trackNumber)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(presentation.displayName)
                        .font(.callout)
                        .bold()
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(height: 42)
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text("Audio File")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(presentation.candidateWAVLabel)
                    .font(.caption)
                    .foregroundStyle(presentation.candidateWAVLabel == "No Audio File" ? .tertiary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(height: 30)

            HStack(spacing: 10) {
                VStack(spacing: 4) {
                    Text(presentation.panDisplayLabel)
                        .font(.caption)
                        .monospacedDigit()
                    PanControlView(
                        value: presentation.panPosition,
                        color: trackColor,
                        onSelect: selectAction,
                        onValueChanged: setPanPosition
                    )
                }

                VStack(spacing: 4) {
                    Toggle(
                        isOn: Binding(
                            get: { presentation.isMuted },
                            set: { newValue in
                                selectAction()
                                setMuted(newValue)
                            }
                        )
                    ) {
                        Label(
                            "Mute",
                            systemImage: presentation.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
                        )
                    }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .tint(.orange)
                    .help(presentation.isMuted ? "Unmute track" : "Mute track")
                    .accessibilityValue(presentation.isMuted ? "On" : "Off")
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                LevelScaleView()
                FaderTrackView(
                    value: presentation.levelPosition,
                    color: trackColor,
                    onSelect: selectAction,
                    onValueChanged: setLevelPosition
                )
                OutputLevelView(value: presentation.isMuted ? 0 : presentation.meterLevel)
            }
            .frame(minHeight: 220, maxHeight: .infinity)

            Text(presentation.levelLabel)
                .font(.caption)
                .monospacedDigit()
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.primary.opacity(0.08), in: .rect(cornerRadius: 4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxHeight: .infinity)
        .background(presentation.isSelected ? trackColor.opacity(0.13) : Color.clear)
        .clipShape(.rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    presentation.isSelected ? trackColor.opacity(0.35) : Color.secondary.opacity(0.12),
                    lineWidth: 1
                )
        }
        .contentShape(.rect)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Track \(presentation.trackNumber), \(presentation.displayName)")
        .accessibilityValue("\(presentation.levelLabel), pan \(presentation.panDisplayLabel), \(presentation.muteLabel)")
    }
}

private struct PanControlView: View {
    let value: Double
    let color: Color
    let onSelect: () -> Void
    let onValueChanged: (Double) -> Void

    private let centerDetent: Double = 0.04

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(value, -1), 1)
            let centerX = proxy.size.width / 2
            let knobX = ((clamped + 1) / 2) * proxy.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                    .frame(height: 4)
                    .frame(maxHeight: .infinity, alignment: .center)

                Rectangle()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 1, height: 10)
                    .position(x: centerX, y: proxy.size.height / 2)

                RoundedRectangle(cornerRadius: 4)
                    .fill(.background)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(color.opacity(0.75), lineWidth: 1)
                    }
                    .frame(width: 12, height: 12)
                    .position(x: knobX, y: proxy.size.height / 2)
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { dragValue in
                        onSelect()
                        let mapped = ((dragValue.location.x / proxy.size.width) * 2) - 1
                        onValueChanged(snapToCenter(mapped))
                    }
            )
        }
        .frame(width: 72, height: 16)
        .accessibilityLabel("Pan")
        .accessibilityAdjustableAction { direction in
            onSelect()
            switch direction {
            case .increment:
                onValueChanged(snapToCenter(value + 0.05))
            case .decrement:
                onValueChanged(snapToCenter(value - 0.05))
            @unknown default:
                break
            }
        }
    }

    private func snapToCenter(_ proposedValue: Double) -> Double {
        let clamped = min(max(proposedValue, -1), 1)
        return abs(clamped) <= centerDetent ? 0 : clamped
    }
}

private struct LevelScaleView: View {
    var body: some View {
        VStack {
            ForEach(["10", "0", "-10", "-30", "-60"], id: \.self) { label in
                Text(label)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(width: 24)
    }
}

private struct FaderTrackView: View {
    let value: Double
    let color: Color
    let onSelect: () -> Void
    let onValueChanged: (Double) -> Void

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(value, 0), 1)
            let handleY = proxy.size.height * (1 - clamped)

            ZStack(alignment: .top) {
                Capsule()
                    .fill(.quaternary)
                    .frame(width: 6)
                    .frame(maxHeight: .infinity)
                Capsule()
                    .fill(color.opacity(0.45))
                    .frame(width: 6, height: max(proxy.size.height * clamped, 3))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                RoundedRectangle(cornerRadius: 3)
                    .fill(.background)
                    .shadow(radius: 1, y: 1)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    }
                    .frame(width: 24, height: 14)
                    .offset(y: handleY - 6)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { dragValue in
                        onSelect()
                        let levelPosition = 1 - (dragValue.location.y / proxy.size.height)
                        onValueChanged(levelPosition)
                    }
            )
        }
        .frame(width: 34)
        .accessibilityAdjustableAction { direction in
            onSelect()
            switch direction {
            case .increment:
                onValueChanged(value + 0.05)
            case .decrement:
                onValueChanged(value - 0.05)
            @unknown default:
                break
            }
        }
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
                    .fill(.linearGradient(colors: [.mint.opacity(0.85), .teal.opacity(0.85)], startPoint: .bottom, endPoint: .top))
                    .frame(height: clamped == 0 ? 0 : max(proxy.size.height * clamped, 2))
            }
        }
        .frame(width: 12)
        .clipShape(.rect(cornerRadius: 3))
    }
}
