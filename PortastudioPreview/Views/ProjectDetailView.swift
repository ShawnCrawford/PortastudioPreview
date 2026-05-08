//
//  ProjectDetailView.swift
//  PortastudioPreview
//

import SwiftUI

struct ProjectDetailView: View {
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
            showInspector: showInspector
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
                selectedTrack: project.visibleTracks.first { $0.id == selectedTrackID },
                selectedRegion: project.unassignedAudioRegions.first { $0.id == selectedRegionID },
                annotationStore: annotationStore
            )
            .inspectorColumnWidth(min: 240, ideal: 300, max: 360)
        }
        .onChange(of: selectedTrackID) { _, newValue in
            if newValue != nil { selectedRegionID = nil }
        }
        .onChange(of: selectedRegionID) { _, newValue in
            if newValue != nil { selectedTrackID = nil }
        }
        .onChange(of: project.folderURL) { _, _ in
            selectedTrackID = nil
            selectedRegionID = nil
            mixState = PreviewMixState(project: project)
            selectedVirtualTrackIDs = [:]
            playbackController.stop()
        }
        .onChange(of: annotationStore.annotationContext?.songFingerprintString) { _, _ in
            selectedVirtualTrackIDs = [:]
        }
    }

    private func toggleInspector() {
        isInspectorPresented.toggle()
    }

    private func showInspector() {
        isInspectorPresented = true
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

    var body: some View {
        GroupBox {
            TrackTableView(
                tracks: tracks,
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

// MARK: - Regions / Timeline

private struct RegionsTimelineGroupBoxView: View {
    let project: PortastudioProject
    @Binding var selectedRegionID: TimelineRegion.ID?
    let playbackController: PreviewPlaybackController

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("Regions from edltable.sys not yet matched to a specific track. Track-to-WAV assignment is Hypothesis.")
                    .foregroundStyle(.secondary)
                    .font(.callout)

                if project.unassignedAudioRegions.isEmpty {
                    Text("No unassigned regions parsed.")
                        .foregroundStyle(.secondary)
                } else {
                    // Visual timeline above the data table.
                    TimelineVisualizationView(
                        project: project,
                        selectedRegionID: $selectedRegionID,
                        playbackController: playbackController
                    )
                    .background(.background.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .frame(minHeight: 80)

                    Divider()

                    UnassignedRegionsTableView(
                        regions: project.unassignedAudioRegions,
                        selectedRegionID: $selectedRegionID
                    )
                }

                if let edl = project.edlTableSummary {
                    Divider()
                    EDLSummaryView(edl: edl)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack {
                Label("Regions / Timeline", systemImage: "timeline.selection")
                    .font(.headline)
                Spacer()
                if !project.unassignedAudioRegions.isEmpty {
                    Text("\(project.unassignedAudioRegions.count) region\(project.unassignedAudioRegions.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityLabel("Regions and timeline data")
    }
}

private struct UnassignedRegionsTableView: View {
    let regions: [TimelineRegion]
    @Binding var selectedRegionID: TimelineRegion.ID?

    var body: some View {
        Table(regions, selection: $selectedRegionID) {
            TableColumn("Unassigned WAV") { region in
                Text(region.sourceFilename ?? "Unknown")
            }
            .width(min: 150, ideal: 220)

            TableColumn("Start") { region in
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(region.startSample)")
                        .font(.system(.caption, design: .monospaced))
                    Text("≈ \(SampleTimeFormatter.displayString(samples: region.startSample))")
                        .foregroundStyle(.secondary)
                        .font(.system(.caption2, design: .monospaced))
                }
            }
            .width(min: 110, ideal: 140)

            TableColumn("Length") { region in
                if let length = region.resolvedLengthSample {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(length)")
                            .font(.system(.caption, design: .monospaced))
                        Text("≈ \(SampleTimeFormatter.displayString(samples: length))")
                            .foregroundStyle(.secondary)
                            .font(.system(.caption2, design: .monospaced))
                    }
                } else {
                    Text("n/a")
                        .foregroundStyle(.secondary)
                        .font(.system(.caption, design: .monospaced))
                }
            }
            .width(min: 110, ideal: 140)

            TableColumn("Evidence") { region in
                Text(region.evidenceLevel.rawValue)
                    .foregroundStyle(.secondary)
            }
            .width(100)
        }
        .frame(minHeight: 96, idealHeight: 140)
    }
}

private struct EDLSummaryView: View {
    let edl: EdlTableSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EDL Summary")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !edl.fileListEntries.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("File list — \(edl.fileListEntries.count) entries · \(edl.evidenceLevel.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(edl.fileListEntries, id: \.self) { entry in
                        HStack(spacing: 8) {
                            Text("#\(entry.fileID)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .trailing)
                            Text(entry.filename)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
            }

            if !edl.timelineCandidates.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Timeline candidates — \(edl.timelineCandidates.count) · Hypothesis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(edl.timelineCandidates.indices, id: \.self) { index in
                        let candidate = edl.timelineCandidates[index]
                        HStack(spacing: 8) {
                            Text("\(candidate.representativeSample)")
                                .font(.system(.caption, design: .monospaced))
                                .frame(width: 80, alignment: .trailing)
                            Text("≈ \(SampleTimeFormatter.displayString(samples: candidate.representativeSample))")
                                .foregroundStyle(.secondary)
                                .font(.system(.caption2, design: .monospaced))
                        }
                    }
                }
            }

            if edl.fileListEntries.isEmpty && edl.timelineCandidates.isEmpty {
                Text("No file list entries or timeline candidates parsed.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
        }
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
