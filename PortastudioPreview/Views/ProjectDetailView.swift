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
    @State private var selectedRegionID: TimelineRegion.ID?
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
            selectedRegionID: $selectedRegionID,
            playbackController: playbackController,
            mixState: mixState,
            selectedVirtualTrackIDs: $selectedVirtualTrackIDs,
            canSelectPreviousChannel: channelNavigation.canSelectPreviousChannel(selectedTrackID: selectedTrackID),
            canSelectNextChannel: channelNavigation.canSelectNextChannel(selectedTrackID: selectedTrackID),
            selectPreviousChannelAction: selectPreviousChannel,
            selectNextChannelAction: selectNextChannel,
            playAction: playPausePreview,
            stopAction: stopPreview,
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
                selectedTrack: project.tracks.first { $0.trackNumber == selectedTrackID },
                selectedRegion: selectedRegion,
                annotationStore: annotationStore,
                mixState: mixState,
                selectedVirtualTrackIDs: selectedVirtualTrackIDs,
                resetSelectedAction: resetSelectedChannel
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
            selectedRegionID = nil
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

    private var selectedRegion: TimelineRegion? {
        guard let selectedRegionID else { return nil }
        if let region = project.tracks
            .flatMap({ $0.virtualTrackOptions.map(\.timelineRegion) + ($0.timeline?.regions ?? []) })
            .first(where: { $0.id == selectedRegionID }) {
            return region
        }
        return project.unassignedAudioRegions.first { $0.id == selectedRegionID }
    }

    private var canPlay: Bool {
        playbackController.canPlay(project, selectedVirtualTrackOptionIDs: selectedVirtualTrackIDs)
    }

    private var channelNavigation: MixerChannelNavigation {
        MixerChannelNavigation(channels: project.visibleMixerChannels)
    }

    private var mixerCommandActions: MixerCommandActions {
        MixerCommandActions(
            canPlay: canPlay && !playbackController.isPlaying,
            canStop: playbackController.canStop,
            hasSelectedChannel: selectedTrackID != nil,
            canSelectPreviousChannel: channelNavigation.canSelectPreviousChannel(selectedTrackID: selectedTrackID),
            canSelectNextChannel: channelNavigation.canSelectNextChannel(selectedTrackID: selectedTrackID),
            play: playPreview,
            stop: stopPreview,
            selectPreviousChannel: selectPreviousChannel,
            selectNextChannel: selectNextChannel,
            toggleMuteSelected: toggleMuteSelected,
            toggleSoloSelected: toggleSoloSelected,
            resetSelected: resetSelectedChannel,
            resetAll: resetAllMix
        )
    }

    private func playPausePreview() {
        if playbackController.isPlaying {
            playbackController.pause()
        } else {
            playPreview()
        }
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

    private func selectPreviousChannel() {
        guard let previousChannelID = channelNavigation.selectPreviousChannel(from: selectedTrackID) else {
            return
        }

        selectedTrackID = previousChannelID
    }

    private func selectNextChannel() {
        guard let nextChannelID = channelNavigation.selectNextChannel(from: selectedTrackID) else {
            return
        }

        selectedTrackID = nextChannelID
    }

    private func applyCurrentMixToPlayback() {
        playbackController.applyTrackMutes(mixState.effectiveTrackMuteOverrides)
        for setting in mixState.trackSettings {
            playbackController.setTrackVolume(setting.levelPosition, for: setting.channelTrackNumber)
            playbackController.setTrackPan(setting.panPosition, for: setting.channelTrackNumber)
        }
    }

}
