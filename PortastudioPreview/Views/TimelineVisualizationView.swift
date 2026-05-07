//
//  TimelineVisualizationView.swift
//  PortastudioPreview
//

import SwiftUI

/// Polished read-only timeline surface with waveform lanes, time ruler, zoom controls,
/// horizontal scroll, selection wiring, and approximate playhead display.
///
/// Region track-to-WAV assignment is Hypothesis.
/// All timing positions are approximate; inferred start samples use 48 kHz domain.
struct TimelineVisualizationView: View {

    let project: PortastudioProject
    @Binding var selectedRegionID: TimelineRegion.ID?
    let playbackController: PreviewPlaybackController

    // MARK: - Constants

    private static let baseCanvasWidth: CGFloat = 900
    private static let laneHeight: CGFloat = 60
    private static let rulerHeight: CGFloat = 24
    private static let labelWidth: CGFloat = 144
    private static let minCanvasHeight: CGFloat = 32

    // MARK: - State

    @State private var zoomFactor: Double = 1.0
    /// Keyed by TimelineRegion.id → peak state for that region's WAV file.
    @State private var peakStates: [String: WaveformPeakState] = [:]
    @State private var peakTasks: [String: Task<Void, Never>] = [:]

    // MARK: - Derived

    private var canvasWidth: CGFloat {
        Self.baseCanvasWidth * zoomFactor
    }

    private var model: TimelineVisualizationModel {
        let plan = PreviewPlaybackPlanner.plan(for: project)
        return TimelineVisualizationBuilder.build(
            project: project,
            selectedRegionID: selectedRegionID,
            playbackPlan: plan
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            Divider()
            if model.isEmptyProject {
                emptyState
            } else {
                timelineBody
            }
        }
        .task(id: project.folderURL) {
            cancelAllPeakTasks()
            await generatePeaks(for: model.lanes)
        }
        .onChange(of: project.folderURL) { _, _ in
            zoomFactor = 1.0
            peakStates = [:]
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerBar: some View {
        HStack(spacing: 8) {
            // Evidence notice
            Label("Hypothesis", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .help("Track-to-WAV assignment is Hypothesis. Timing positions are approximate.")
                .accessibilityLabel("Track-to-WAV assignment is Hypothesis")

            Spacer()

            if model.hasAmbiguousTiming {
                Label("Timing unresolved", systemImage: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .help("Multiple regions all start at sample 0. Inferred timing is ambiguous.")
            }

            Divider().frame(height: 16)

            Button("Zoom Out", systemImage: "minus.magnifyingglass") {
                zoomFactor = TimelineVisualizationBuilder.clampedZoom(zoomFactor / 1.5)
            }
            .buttonStyle(.borderless)
            .disabled(zoomFactor <= TimelineVisualizationBuilder.minZoom)
            .help("Zoom Out")
            .accessibilityIdentifier("timeline-zoom-out")

            Button("Fit", systemImage: "arrow.up.left.and.arrow.down.right") {
                zoomFactor = TimelineVisualizationBuilder.minZoom
            }
            .buttonStyle(.borderless)
            .help("Fit all regions")
            .accessibilityIdentifier("timeline-zoom-fit")

            Button("Zoom In", systemImage: "plus.magnifyingglass") {
                zoomFactor = TimelineVisualizationBuilder.clampedZoom(zoomFactor * 1.5)
            }
            .buttonStyle(.borderless)
            .disabled(zoomFactor >= TimelineVisualizationBuilder.maxZoom)
            .help("Zoom In")
            .accessibilityIdentifier("timeline-zoom-in")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Text(model.emptyStateReason ?? "No unassigned regions to display.")
            .foregroundStyle(.secondary)
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
    }

    // MARK: - Timeline Body

    private var timelineBody: some View {
        HStack(alignment: .top, spacing: 0) {
            // Fixed left: lane labels
            labelsColumn
                .frame(width: Self.labelWidth)

            Divider()

            // Scrollable right: ruler + waveform lanes
            ScrollView(.horizontal, showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        rulerView
                        laneViews
                    }
                    playheadOverlay
                }
                .frame(width: canvasWidth)
            }
            .accessibilityLabel("Timeline canvas. Use horizontal scroll to pan.")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Label Column

    private var labelsColumn: some View {
        VStack(spacing: 0) {
            // Spacer aligned with ruler row height
            Color.clear
                .frame(height: Self.rulerHeight)
            Divider()
            ForEach(model.lanes) { lane in
                laneLabelRow(lane: lane)
                Divider()
            }
        }
    }

    @ViewBuilder
    private func laneLabelRow(lane: TimelineLane) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(lane.region.sourceFilename)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.primary)
            Text(lane.region.evidenceLevel.rawValue)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .frame(height: Self.laneHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Ruler

    private var rulerView: some View {
        Canvas { context, size in
            let ticks = TimelineVisualizationBuilder.rulerTicks(
                visibleStartSample: 0,
                visibleEndSample: model.totalSampleExtent,
                maxTicks: max(Int(size.width / 80), 5)
            )
            for tick in ticks {
                let x = TimelineVisualizationBuilder.sampleToX(
                    sample: tick.samplePosition,
                    totalExtent: model.totalSampleExtent,
                    width: size.width
                )
                let tickH: CGFloat = tick.isMajor ? size.height - 4 : (size.height - 4) * 0.6
                let tickPath = Path { p in
                    p.move(to: CGPoint(x: x, y: size.height - tickH))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }
                context.stroke(tickPath, with: .color(.secondary.opacity(0.6)), lineWidth: 0.5)

                if tick.isMajor && x > 2 {
                    let label = Text(tick.label)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    let resolved = context.resolve(label)
                    context.draw(resolved, at: CGPoint(x: x + 2, y: 2), anchor: .topLeading)
                }
            }
        }
        .frame(width: canvasWidth, height: Self.rulerHeight)
    }

    // MARK: - Waveform Lanes

    private var laneViews: some View {
        ForEach(model.lanes) { lane in
            VStack(spacing: 0) {
                laneRow(lane: lane)
                Divider()
            }
        }
    }

    @ViewBuilder
    private func laneRow(lane: TimelineLane) -> some View {
        Button {
            selectedRegionID = lane.region.id
        } label: {
            WaveformCanvasView(
                region: lane.region,
                peakState: peakStates[lane.region.id],
                totalSampleExtent: model.totalSampleExtent,
                canvasWidth: canvasWidth,
                laneHeight: Self.laneHeight
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Region \(lane.region.sourceFilename)")
        .accessibilityHint("Double-tap to select")
        .accessibilityAddTraits(lane.region.isSelected ? .isSelected : [])
        .background(lane.region.isSelected ? Color.accentColor.opacity(0.06) : Color.clear)
    }

    // MARK: - Playhead

    @ViewBuilder
    private var playheadOverlay: some View {
        if playbackController.isPlaying {
            let totalHeight = Self.rulerHeight + CGFloat(model.lanes.count) * Self.laneHeight
            let playheadX = playheadXPosition
            Canvas { context, _ in
                let path = Path { p in
                    p.move(to: CGPoint(x: playheadX, y: 0))
                    p.addLine(to: CGPoint(x: playheadX, y: totalHeight))
                }
                context.stroke(path, with: .color(.accentColor.opacity(0.9)), lineWidth: 1.5)
            }
            .frame(width: canvasWidth, height: totalHeight)
            .allowsHitTesting(false)
        }
    }

    private var playheadXPosition: CGFloat {
        let elapsedSamples = Int(playbackController.elapsedSeconds * SampleTimeFormatter.standardSampleRate)
        return TimelineVisualizationBuilder.sampleToX(
            sample: elapsedSamples,
            totalExtent: model.totalSampleExtent,
            width: canvasWidth
        )
    }

    // MARK: - Peak Generation

    private func generatePeaks(for lanes: [TimelineLane]) async {
        for lane in lanes {
            guard let url = project.unassignedAudioRegions
                .first(where: { $0.id == lane.id })?.sourceURL else {
                peakStates[lane.id] = .unavailable("No source URL")
                continue
            }

            peakStates[lane.id] = .generating

            let regionID = lane.id
            let task = Task {
                do {
                    let summary = try await WaveformPeakBuilder.buildPeaks(
                        url: url,
                        maxBuckets: 400
                    )
                    await MainActor.run {
                        peakStates[regionID] = .available(summary)
                    }
                } catch {
                    await MainActor.run {
                        peakStates[regionID] = .unavailable(error.localizedDescription)
                    }
                }
            }
            peakTasks[regionID] = task
        }
    }

    private func cancelAllPeakTasks() {
        for task in peakTasks.values { task.cancel() }
        peakTasks = [:]
        peakStates = [:]
    }
}
