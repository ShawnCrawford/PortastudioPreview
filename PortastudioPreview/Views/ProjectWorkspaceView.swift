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
    let playAction: () -> Void
    let stopAction: () -> Void
    let resetAllAction: () -> Void
    let reloadPlaybackPreservingPositionAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ProjectHeaderView(
                project: project,
                annotationStore: annotationStore,
                playbackController: playbackController,
                mixState: mixState,
                selectedVirtualTrackIDs: selectedVirtualTrackIDs,
                playAction: playAction,
                stopAction: stopAction
            )

            Divider()

            TrackMixerDeckView(
                channels: project.visibleMixerChannels,
                selectedTrackID: $selectedTrackID,
                annotationStore: annotationStore,
                playbackController: playbackController,
                mixState: mixState,
                selectedVirtualTrackIDs: $selectedVirtualTrackIDs,
                resetAllAction: resetAllAction,
                reloadPlaybackPreservingPositionAction: reloadPlaybackPreservingPositionAction
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
    let playAction: () -> Void
    let stopAction: () -> Void

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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) {
                HeaderIdentityView(summary: summary)
                    .frame(minWidth: 260, maxWidth: .infinity, alignment: .leading)

                HeaderTransportControls(
                    playbackController: playbackController,
                    canPlay: canPlay,
                    playAction: playAction,
                    stopAction: stopAction
                )

                HeaderTimeView(elapsedLabel: elapsedLabel, durationLabel: summary.durationLabel)
                    .frame(width: 132, alignment: .trailing)

                PreviewActivityMeter(playbackController: playbackController)
                    .frame(width: 180)

                HeaderIssueStatusView(summary: summary, playbackError: playbackController.playbackError)
                    .frame(width: 190, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    HeaderIdentityView(summary: summary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HeaderIssueStatusView(summary: summary, playbackError: playbackController.playbackError)
                        .frame(minWidth: 150, alignment: .leading)
                }

                HStack(spacing: 18) {
                    HeaderTransportControls(
                        playbackController: playbackController,
                        canPlay: canPlay,
                        playAction: playAction,
                        stopAction: stopAction
                    )

                    Spacer(minLength: 12)

                    HeaderTimeView(elapsedLabel: elapsedLabel, durationLabel: summary.durationLabel)
                        .frame(width: 96, alignment: .trailing)

                    PreviewActivityMeter(playbackController: playbackController)
                        .frame(width: 180)
                }
            }
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

private struct HeaderIdentityView: View {
    let summary: ProjectHeaderSummary

    var body: some View {
        HStack(spacing: 14) {
            ProjectGlyphView()

            VStack(alignment: .leading, spacing: 6) {
                Text(summary.title)
                    .font(.title2)
                    .bold()
                    .lineLimit(1)
                    .truncationMode(.tail)

                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.metadataLine)
                    Text("\(summary.deviceContext) · \(summary.formatLabel)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HeaderTimeView: View {
    let elapsedLabel: String
    let durationLabel: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(elapsedLabel)
                .font(.system(.title3, design: .monospaced))
                .contentTransition(.numericText())
            Text(durationLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct HeaderIssueStatusView: View {
    let summary: ProjectHeaderSummary
    let playbackError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let playbackError {
                Label(playbackError, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .accessibilityLabel("Playback error: \(playbackError)")
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
        .lineLimit(1)
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
    let playbackController: PreviewPlaybackController
    let canPlay: Bool
    let playAction: () -> Void
    let stopAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(
                playbackController.isPlaying ? "Pause Preview" : "Play Preview",
                systemImage: playbackController.isPlaying ? "pause.fill" : "play.fill"
            ) {
                playAction()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canPlay)
            .help(playbackController.isPlaying ? "Pause song preview" : "Play song preview")
            .accessibilityLabel(playbackController.isPlaying ? "Pause song preview" : "Play song preview")

            Button("Stop Preview", systemImage: "stop.fill") {
                stopAction()
            }
            .buttonStyle(.bordered)
            .disabled(!playbackController.canStop)
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
    let channels: [MixerChannel]
    @Binding var selectedTrackID: TrackPreview.ID?
    let annotationStore: TrackAnnotationStore
    let playbackController: PreviewPlaybackController
    let mixState: PreviewMixState
    @Binding var selectedVirtualTrackIDs: [Int: VirtualTrackOption.ID]
    let resetAllAction: () -> Void
    let reloadPlaybackPreservingPositionAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Mixer", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
                Text("\(channels.count) track\(channels.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("Reset All Mix", systemImage: "arrow.counterclockwise.circle") {
                    resetAllAction()
                }
                .help("Reset all mix settings")
            }
            .padding(.horizontal, MixerDeckMetrics.edgePadding)
            .padding(.top, 18)
            .padding(.bottom, 12)

            GeometryReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .center, spacing: MixerDeckMetrics.stripSpacing) {
                        ForEach(channels) { channel in
                            let trackNumber = channel.id
                            let presentation = TrackMixerStripPresentation(
                                channel: channel,
                                displayName: annotationStore.trackName(for: trackNumber),
                                isSelected: selectedTrackID == trackNumber,
                                panPositionOverride: mixState.panPosition(for: trackNumber),
                                levelPositionOverride: mixState.levelPosition(for: trackNumber),
                                muteOverride: mixState.isMuted(for: trackNumber),
                                soloOverride: mixState.isSoloed(for: trackNumber),
                                isEffectivelyMuted: mixState.isEffectivelyMuted(for: trackNumber),
                                selectedVirtualTrackOptionID: mixState.selectedVirtualTrackOptionID(for: trackNumber),
                                meterLevel: playbackController.trackMeterLevel(for: trackNumber)
                            )
                            TrackMixerStripView(
                                presentation: presentation,
                                selectAction: {
                                    selectedTrackID = trackNumber
                                },
                                setLevelPosition: { newValue in
                                    selectedTrackID = trackNumber
                                    mixState.setLevelPosition(newValue, for: trackNumber)
                                    playbackController.setTrackVolume(newValue, for: trackNumber)
                                },
                                setPanPosition: { newValue in
                                    selectedTrackID = trackNumber
                                    mixState.setPanPosition(newValue, for: trackNumber)
                                    playbackController.setTrackPan(newValue, for: trackNumber)
                                },
                                setMuted: { isMuted in
                                    selectedTrackID = trackNumber
                                    mixState.setMuted(isMuted, for: trackNumber)
                                    playbackController.applyTrackMutes(mixState.effectiveTrackMuteOverrides)
                                },
                                setSoloed: { isSoloed in
                                    selectedTrackID = trackNumber
                                    mixState.setSoloed(isSoloed, for: trackNumber)
                                    playbackController.applyTrackMutes(mixState.effectiveTrackMuteOverrides)
                                },
                                setSelectedVirtualTrackOption: { selectedID in
                                    selectedTrackID = trackNumber
                                    selectedVirtualTrackIDs[trackNumber] = selectedID
                                    mixState.setSelectedVirtualTrackOptionID(selectedID, for: trackNumber)
                                    if playbackController.isPlaying {
                                        reloadPlaybackPreservingPositionAction()
                                    }
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
        let fittedHeight = max(0, availableHeight - (MixerDeckMetrics.channelVerticalPadding * 2))
        guard fittedHeight >= MixerDeckMetrics.minimumStripHeight else {
            return max(MixerDeckMetrics.compactMinimumStripHeight, fittedHeight)
        }

        return fittedHeight
    }
}

private enum MixerDeckMetrics {
    static let edgePadding: CGFloat = 28
    static let channelVerticalPadding: CGFloat = 18
    static let stripSpacing: CGFloat = 18
    static let stripWidth: CGFloat = 148
    static let minimumStripHeight: CGFloat = 390
    static let compactMinimumStripHeight: CGFloat = 300
}

private struct TrackMixerStripView: View {
    let presentation: TrackMixerStripPresentation
    let selectAction: () -> Void
    let setLevelPosition: (Double) -> Void
    let setPanPosition: (Double) -> Void
    let setMuted: (Bool) -> Void
    let setSoloed: (Bool) -> Void
    let setSelectedVirtualTrackOption: (VirtualTrackOption.ID) -> Void

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
                VStack(spacing: 3) {
                    Text(presentation.channelTitle)
                        .font(.callout)
                        .bold()
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let channelSubtitle = presentation.channelSubtitle {
                        Text(channelSubtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(height: 42)
            }
            .buttonStyle(.plain)

            Text(presentation.audioStatusLabel)
                .font(.caption)
                .foregroundStyle(presentation.hasResolvedAudio ? .secondary : .tertiary)
                .lineLimit(1)
                .frame(height: 18)
                .help(presentation.hasResolvedAudio ? presentation.candidateWAVLabel : presentation.audioStatusLabel)

            VStack(spacing: 0) {
                if presentation.virtualTrackOptions.count > 1 {
                    Picker("Virtual Take", selection: Binding(
                        get: { presentation.selectedVirtualTrackOptionID ?? presentation.virtualTrackOptions[0].id },
                        set: { selectedID in
                            selectAction()
                            setSelectedVirtualTrackOption(selectedID)
                        }
                    )) {
                        ForEach(presentation.virtualTrackOptions) { option in
                            Text(option.takeLabel).tag(option.id)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .accessibilityLabel("Virtual take")
                }
            }
            .frame(height: 22)

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

                VStack(spacing: 4) {
                    Toggle(
                        isOn: Binding(
                            get: { presentation.isSoloed },
                            set: { newValue in
                                selectAction()
                                setSoloed(newValue)
                            }
                        )
                    ) {
                        Label(
                            "Solo",
                            systemImage: presentation.isSoloed ? "headphones.circle.fill" : "headphones"
                        )
                    }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .tint(.yellow)
                    .help(presentation.isSoloed ? "Clear solo" : "Solo track")
                    .accessibilityValue(presentation.isSoloed ? "On" : "Off")
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
                OutputLevelView(value: presentation.isEffectivelyMuted ? 0 : presentation.meterLevel)
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
        .accessibilityLabel("Track \(presentation.trackNumberLabel), \(presentation.channelTitle)")
        .accessibilityValue("\(presentation.audioStatusLabel), \(presentation.levelLabel), pan \(presentation.panDisplayLabel), \(presentation.muteLabel), \(presentation.soloLabel)")
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
        .accessibilityValue(PanMapper.previewDisplayValue(forNormalizedPosition: value))
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
        .accessibilityLabel("Level")
        .accessibilityValue(LevelMapper.previewDisplayValue(forNormalizedPosition: value))
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

#if DEBUG
#Preview("Mixer Workspace") {
    @Previewable @State var selectedTrackID: TrackPreview.ID? = 4
    @Previewable @State var selectedVirtualTrackIDs: [Int: VirtualTrackOption.ID] = [:]
    let fixture = PreviewFixtures.mixerWorkspace()

    ProjectWorkspaceView(
        project: fixture.project,
        annotationStore: fixture.annotationStore,
        selectedTrackID: $selectedTrackID,
        playbackController: fixture.playbackController,
        mixState: fixture.mixState,
        selectedVirtualTrackIDs: $selectedVirtualTrackIDs,
        playAction: {},
        stopAction: {},
        resetAllAction: {},
        reloadPlaybackPreservingPositionAction: {}
    )
    .frame(width: 1180, height: 760)
    .task {
        selectedVirtualTrackIDs = fixture.selectedVirtualTrackIDs
    }
}

#Preview("Mixer Workspace - Compact") {
    @Previewable @State var selectedTrackID: TrackPreview.ID?
    @Previewable @State var selectedVirtualTrackIDs: [Int: VirtualTrackOption.ID] = [:]
    let fixture = PreviewFixtures.compactWorkspace()

    ProjectWorkspaceView(
        project: fixture.project,
        annotationStore: fixture.annotationStore,
        selectedTrackID: $selectedTrackID,
        playbackController: fixture.playbackController,
        mixState: fixture.mixState,
        selectedVirtualTrackIDs: $selectedVirtualTrackIDs,
        playAction: {},
        stopAction: {},
        resetAllAction: {},
        reloadPlaybackPreservingPositionAction: {}
    )
    .frame(width: 860, height: 640)
}

#Preview("Mixer Workspace - Edited") {
    @Previewable @State var selectedTrackID: TrackPreview.ID? = 3
    @Previewable @State var selectedVirtualTrackIDs: [Int: VirtualTrackOption.ID] = [:]
    let fixture = PreviewFixtures.editedWorkspace()

    ProjectWorkspaceView(
        project: fixture.project,
        annotationStore: fixture.annotationStore,
        selectedTrackID: $selectedTrackID,
        playbackController: fixture.playbackController,
        mixState: fixture.mixState,
        selectedVirtualTrackIDs: $selectedVirtualTrackIDs,
        playAction: {},
        stopAction: {},
        resetAllAction: {},
        reloadPlaybackPreservingPositionAction: {}
    )
    .frame(width: 1180, height: 760)
    .task {
        selectedVirtualTrackIDs = fixture.selectedVirtualTrackIDs
    }
}

#Preview("Mixer Deck") {
    @Previewable @State var selectedTrackID: TrackPreview.ID? = 9
    @Previewable @State var selectedVirtualTrackIDs: [Int: VirtualTrackOption.ID] = [:]
    let fixture = PreviewFixtures.mixerWorkspace()

    TrackMixerDeckView(
        channels: fixture.project.visibleMixerChannels,
        selectedTrackID: $selectedTrackID,
        annotationStore: fixture.annotationStore,
        playbackController: fixture.playbackController,
        mixState: fixture.mixState,
        selectedVirtualTrackIDs: $selectedVirtualTrackIDs,
        resetAllAction: {},
        reloadPlaybackPreservingPositionAction: {}
    )
    .frame(width: 1040, height: 560)
    .padding()
}

#Preview("Mixer Strip - States") {
    HStack(spacing: 18) {
        TrackMixerStripView(
            presentation: PreviewFixtures.stripPresentation(
                trackNumber: 1,
                isSelected: true,
                panPosition: -1,
                levelPosition: 0.92,
                meterLevel: 0.88
            ),
            selectAction: {},
            setLevelPosition: { _ in },
            setPanPosition: { _ in },
            setMuted: { _ in },
            setSoloed: { _ in },
            setSelectedVirtualTrackOption: { _ in }
        )
        .frame(width: MixerDeckMetrics.stripWidth, height: 460)

        TrackMixerStripView(
            presentation: PreviewFixtures.stripPresentation(
                trackNumber: 4,
                isSelected: false,
                panPosition: 0,
                levelPosition: 0.56,
                isMuted: true,
                isEffectivelyMuted: true,
                meterLevel: 0.15
            ),
            selectAction: {},
            setLevelPosition: { _ in },
            setPanPosition: { _ in },
            setMuted: { _ in },
            setSoloed: { _ in },
            setSelectedVirtualTrackOption: { _ in }
        )
        .frame(width: MixerDeckMetrics.stripWidth, height: 460)

        TrackMixerStripView(
            presentation: PreviewFixtures.stripPresentation(
                trackNumber: 8,
                isSelected: true,
                panPosition: 1,
                levelPosition: 0.28,
                isSoloed: true,
                meterLevel: 0.42
            ),
            selectAction: {},
            setLevelPosition: { _ in },
            setPanPosition: { _ in },
            setMuted: { _ in },
            setSoloed: { _ in },
            setSelectedVirtualTrackOption: { _ in }
        )
        .frame(width: MixerDeckMetrics.stripWidth, height: 460)
    }
    .padding()
}

#Preview("Pan Control") {
    @Previewable @State var hardLeft = -1.0
    @Previewable @State var center = 0.0
    @Previewable @State var hardRight = 1.0

    VStack(alignment: .leading, spacing: 16) {
        LabeledContent("Hard left") {
            PanControlView(value: hardLeft, color: .blue, onSelect: {}, onValueChanged: { hardLeft = $0 })
        }
        LabeledContent("Center") {
            PanControlView(value: center, color: .teal, onSelect: {}, onValueChanged: { center = $0 })
        }
        LabeledContent("Hard right") {
            PanControlView(value: hardRight, color: .orange, onSelect: {}, onValueChanged: { hardRight = $0 })
        }
    }
    .padding()
    .frame(width: 300)
}

#Preview("Fader And Meter") {
    @Previewable @State var quiet = 0.22
    @Previewable @State var unity = LevelMapper.normalizedPosition(for: LevelMapper.rawUnity)
    @Previewable @State var loud = 0.96

    HStack(alignment: .bottom, spacing: 28) {
        VStack {
            FaderTrackView(value: quiet, color: .blue, onSelect: {}, onValueChanged: { quiet = $0 })
            Text(LevelMapper.previewDisplayValue(forNormalizedPosition: quiet))
                .font(.caption)
        }
        VStack {
            FaderTrackView(value: unity, color: .teal, onSelect: {}, onValueChanged: { unity = $0 })
            Text(LevelMapper.previewDisplayValue(forNormalizedPosition: unity))
                .font(.caption)
        }
        VStack {
            FaderTrackView(value: loud, color: .orange, onSelect: {}, onValueChanged: { loud = $0 })
            Text(LevelMapper.previewDisplayValue(forNormalizedPosition: loud))
                .font(.caption)
        }
        VStack {
            OutputLevelView(value: 0.15)
            OutputLevelView(value: 0.58)
            OutputLevelView(value: 0.93)
        }
        .frame(height: 220)
    }
    .frame(height: 280)
    .padding()
}
#endif
