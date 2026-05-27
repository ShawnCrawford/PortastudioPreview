//
//  ProjectDetailView.swift
//  PortastudioPreview
//

import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let project: PortastudioProject
    let annotationStore: TrackAnnotationStore

    @State private var selectedTrackID: TrackPreview.ID?
    @State private var isInspectorPresented = true
    @State private var playbackController = PreviewPlaybackController()
    @State private var mixState: PreviewMixState
    @State private var selectedVirtualTrackIDs: [Int: VirtualTrackOption.ID] = [:]

    init(project: PortastudioProject, annotationStore: TrackAnnotationStore) {
        self.project = project
        self.annotationStore = annotationStore
        _mixState = State(wrappedValue: PreviewMixState(project: project))
    }

    var body: some View {
        ProjectWorkspaceView(
            project: project,
            annotationStore: annotationStore,
            selectedTrackID: $selectedTrackID,
            playbackController: playbackController,
            mixState: mixState,
            selectedVirtualTrackIDs: $selectedVirtualTrackIDs,
            playAction: playPreview,
            stopAction: stopPreview,
            resetSelectedAction: resetSelectedChannel,
            resetAllAction: resetAllMix,
            reloadPlaybackPreservingPositionAction: reloadPreviewPreservingPosition
        )
        .navigationTitle(annotationStore.annotationContext?.effectiveDisplayName ?? project.folderName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    toggleInspector()
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
                .help(isInspectorPresented ? "Hide Inspector" : "Show Inspector")
                .accessibilityIdentifier("toolbar-inspector-toggle")
                .accessibilityLabel(isInspectorPresented ? "Hide Inspector" : "Show Inspector")
            }
        }
        .inspector(isPresented: $isInspectorPresented) {
            TrackRegionInspectorView(
                project: project,
                selectedTrack: project.visibleMixerChannels
                    .first { $0.id == selectedTrackID }?
                    .controlTrack,
                selectedRegion: nil,
                annotationStore: annotationStore,
                mixState: mixState,
                selectedVirtualTrackIDs: selectedVirtualTrackIDs,
                resetSelectedAction: resetSelectedChannel,
                resetAllAction: resetAllMix
            )
            .inspectorColumnWidth(min: 240, ideal: 300, max: 360)
        }
        .task {
            mixState.configure(modelContext: modelContext)
            mixState.loadOverrides(context: annotationStore.annotationContext)
            selectedVirtualTrackIDs = mixState.selectedVirtualTrackOptionIDs
        }
        .onChange(of: project.folderURL) { _, _ in
            selectedTrackID = nil
            mixState = PreviewMixState(project: project)
            mixState.configure(modelContext: modelContext)
            mixState.loadOverrides(context: annotationStore.annotationContext)
            selectedVirtualTrackIDs = mixState.selectedVirtualTrackOptionIDs
            playbackController.stop()
        }
        .onChange(of: annotationStore.annotationContext?.songFingerprintString) { _, _ in
            mixState.loadOverrides(context: annotationStore.annotationContext)
            selectedVirtualTrackIDs = mixState.selectedVirtualTrackOptionIDs
            playbackController.applyTrackMutes(mixState.effectiveTrackMuteOverrides)
        }
        .focusedValue(\.mixerCommandActions, mixerCommandActions)
    }

    private func toggleInspector() {
        isInspectorPresented.toggle()
    }

    private var canPlay: Bool {
        playbackController.canPlay(project, selectedVirtualTrackOptionIDs: selectedVirtualTrackIDs)
    }

    private var mixerCommandActions: MixerCommandActions {
        MixerCommandActions(
            canPlay: canPlay && !playbackController.isPlaying,
            canStop: playbackController.isPlaying,
            hasSelectedChannel: selectedTrackID != nil,
            play: playPreview,
            stop: stopPreview,
            toggleMuteSelected: toggleMuteSelected,
            toggleSoloSelected: toggleSoloSelected,
            resetSelected: resetSelectedChannel,
            resetAll: resetAllMix
        )
    }

    private func playPreview() {
        playbackController.startPreview(
            for: project,
            trackVolumeOverrides: mixState.trackVolumeOverrides,
            trackPanOverrides: mixState.trackPanOverrides,
            trackMuteOverrides: mixState.effectiveTrackMuteOverrides,
            selectedVirtualTrackOptionIDs: selectedVirtualTrackIDs
        )
    }

    private func stopPreview() {
        playbackController.stop()
    }

    private func reloadPreviewPreservingPosition() {
        playbackController.reloadPreviewPreservingPosition(
            for: project,
            trackVolumeOverrides: mixState.trackVolumeOverrides,
            trackPanOverrides: mixState.trackPanOverrides,
            trackMuteOverrides: mixState.effectiveTrackMuteOverrides,
            selectedVirtualTrackOptionIDs: selectedVirtualTrackIDs
        )
    }

    private func toggleMuteSelected() {
        guard let selectedTrackID else { return }
        mixState.setMuted(!mixState.isMuted(for: selectedTrackID), for: selectedTrackID)
        playbackController.applyTrackMutes(mixState.effectiveTrackMuteOverrides)
    }

    private func toggleSoloSelected() {
        guard let selectedTrackID else { return }
        mixState.setSoloed(!mixState.isSoloed(for: selectedTrackID), for: selectedTrackID)
        playbackController.applyTrackMutes(mixState.effectiveTrackMuteOverrides)
    }

    private func resetSelectedChannel() {
        guard let selectedTrackID else { return }
        mixState.resetChannel(trackNumber: selectedTrackID)
        selectedVirtualTrackIDs = mixState.selectedVirtualTrackOptionIDs
        applyCurrentMixToPlayback()
    }

    private func resetAllMix() {
        mixState.resetAll()
        selectedVirtualTrackIDs = mixState.selectedVirtualTrackOptionIDs
        applyCurrentMixToPlayback()
    }

    private func applyCurrentMixToPlayback() {
        playbackController.applyTrackMutes(mixState.effectiveTrackMuteOverrides)
        for setting in mixState.trackSettings {
            playbackController.setTrackVolume(setting.levelPosition, for: setting.channelTrackNumber)
            playbackController.setTrackPan(setting.panPosition, for: setting.channelTrackNumber)
        }
    }

}

// MARK: - Overview

private struct OverviewGroupBoxView: View {
    let project: PortastudioProject
    let annotationStore: TrackAnnotationStore

    @State private var nameDraft: String = ""
    @FocusState private var nameFieldFocused: Bool

    private var summary: SongDetailSummary { SongDetailSummary(project: project) }
    private var context: SongAnnotationContext? { annotationStore.annotationContext }

    var body: some View {
        GroupBox {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                if context != nil {
                    songNameRow
                    Divider().gridCellUnsizedAxes(.horizontal)
                }
                GridRow {
                    Text("Folder").foregroundStyle(.secondary)
                    Text(summary.folderName).fontWeight(.medium)
                }
                GridRow {
                    Text("Path").foregroundStyle(.secondary)
                    Text(summary.folderPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow {
                    Text("Tracks").foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text("\(summary.trackCount)")
                        if summary.assignedTrackCount > 0 {
                            Text("· \(summary.assignedTrackCount) with candidate WAV (Hypothesis)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                GridRow {
                    Text("WAV files").foregroundStyle(.secondary)
                    Text(summary.wavCount == 0 ? "None" : "\(summary.wavCount)")
                        .foregroundStyle(summary.wavCount == 0 ? .secondary : .primary)
                }
                GridRow {
                    Text("Unassigned regions").foregroundStyle(.secondary)
                    Text(summary.unassignedRegionCount == 0 ? "None" : "\(summary.unassignedRegionCount)")
                        .foregroundStyle(summary.unassignedRegionCount > 0 ? .primary : .secondary)
                }
                GridRow {
                    Text("EDL file list").foregroundStyle(.secondary)
                    Text(summary.edlFileListCount == 0 ? "None" : "\(summary.edlFileListCount) entries")
                        .foregroundStyle(summary.edlFileListCount > 0 ? .primary : .secondary)
                }
                GridRow {
                    Text("Timeline candidates").foregroundStyle(.secondary)
                    Text(summary.timelineCandidateCount == 0 ? "None" : "\(summary.timelineCandidateCount)")
                        .foregroundStyle(summary.timelineCandidateCount > 0 ? .primary : .secondary)
                }
                GridRow {
                    Text("Preview").foregroundStyle(.secondary)
                    Label(
                        summary.previewAvailable ? "Available" : "Not available",
                        systemImage: summary.previewAvailable ? "waveform" : "waveform.slash"
                    )
                    .foregroundStyle(summary.previewAvailable ? .primary : .secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Overview", systemImage: "info.circle")
                .font(.headline)
        }
        .accessibilityLabel("Song overview")
        .task(id: context?.songFingerprintString) {
            nameDraft = context?.displayNameOverride ?? ""
        }
    }

    @ViewBuilder
    private var songNameRow: some View {
        GridRow {
            Text("Name").foregroundStyle(.secondary)
            if context?.isEditable == true {
                HStack(spacing: 4) {
                    TextField("Song name", text: $nameDraft)
                        .focused($nameFieldFocused)
                        .onSubmit { commitName() }
                        .onChange(of: nameFieldFocused) { _, focused in
                            if !focused { commitName() }
                        }
                    if !nameDraft.isEmpty {
                        Button {
                            nameDraft = ""
                            annotationStore.setSongDisplayNameOverride(nil)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear name override")
                        .accessibilityLabel("Clear song name override")
                    }
                }
            } else {
                Text(context?.effectiveDisplayName ?? project.folderName)
                    .fontWeight(.medium)
            }
        }
    }

    private func commitName() {
        annotationStore.setSongDisplayNameOverride(nameDraft.isEmpty ? nil : nameDraft)
        nameDraft = annotationStore.annotationContext?.displayNameOverride ?? ""
    }
}

// MARK: - Validation

private struct ValidationGroupBoxView: View {
    let issues: [ProjectValidationIssue]

    private var hasErrors: Bool {
        issues.contains { $0.severity == .error }
    }

    private var labelIcon: String {
        if issues.isEmpty { return "checkmark.shield" }
        return hasErrors ? "xmark.shield" : "exclamationmark.shield"
    }

    private var labelColor: Color {
        if issues.isEmpty { return .green }
        return hasErrors ? .red : .orange
    }

    var body: some View {
        GroupBox {
            ValidationIssuesView(issues: issues)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack {
                Label("Validation", systemImage: labelIcon)
                    .font(.headline)
                    .foregroundStyle(labelColor)
                Spacer()
                Text(issues.isEmpty ? "No issues" : "\(issues.count) issue\(issues.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel("Validation issues")
    }
}

// MARK: - Tracks

private struct TracksGroupBoxView: View {
    let tracks: [TrackPreview]
    @Binding var selectedTrackID: TrackPreview.ID?
    @Binding var selectedVirtualTrackIDs: [Int: VirtualTrackOption.ID]
    let annotationStore: TrackAnnotationStore

    private var channels: [MixerChannel] {
        let tracksByNumber = Dictionary(uniqueKeysWithValues: tracks.map { ($0.trackNumber, $0) })
        return MixerChannelLayout.allLeadingTrackNumbers.compactMap { leadingTrackNumber in
            let members = MixerChannelLayout.memberTrackNumbers(forLeadingTrackNumber: leadingTrackNumber)
                .compactMap { tracksByNumber[$0] }
            guard !members.isEmpty else {
                return nil
            }
            return MixerChannel(leadingTrackNumber: leadingTrackNumber, memberTracks: members)
        }
    }

    var body: some View {
        GroupBox {
            TrackTableView(
                channels: channels,
                selectedTrackID: $selectedTrackID,
                selectedVirtualTrackIDs: $selectedVirtualTrackIDs,
                annotationStore: annotationStore
            )
                .frame(minHeight: 200, idealHeight: 300)
        } label: {
            Label("Tracks", systemImage: "slider.horizontal.3")
                .font(.headline)
        }
        .accessibilityLabel("Track and mixer data")
    }
}

// MARK: - Preview

private struct PreviewGroupBoxView: View {
    let project: PortastudioProject
    let playbackController: PreviewPlaybackController

    var body: some View {
        GroupBox {
            PreviewTransportView(project: project, playbackController: playbackController)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("Preview", systemImage: "waveform")
                .font(.headline)
        }
        .accessibilityLabel("Audio preview")
    }
}
