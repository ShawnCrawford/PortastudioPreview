//
//  TimelineVisualizationView.swift
//  PortastudioPreview
//

import SwiftUI

struct TimelineVisualizationView: View {
    let project: PortastudioProject
    @Binding var selectedTrackID: TrackPreview.ID?
    @Binding var selectedRegionID: TimelineRegion.ID?
    let selectedVirtualTrackIDs: [Int: VirtualTrackOption.ID]

    @State private var zoom = 1.0

    private let labelColumnWidth: CGFloat = 190
    private let rulerHeight: CGFloat = 32
    private let laneHeight: CGFloat = 34

    private var model: TimelineVisualizationModel {
        TimelineVisualizationBuilder.build(
            project: project,
            selectedRegionID: selectedRegionID,
            selectedVirtualTrackIDs: selectedVirtualTrackIDs
        )
    }

    private var chartWidth: CGFloat {
        let duration = Double(max(model.totalSampleExtent, 1)) / SampleTimeFormatter.standardSampleRate
        return max(900, CGFloat(duration * 28 * zoom))
    }

    private var ticks: [TimelineTimeRulerTick] {
        guard model.hasResolvedTiming else { return [] }
        return TimelineVisualizationBuilder.rulerTicks(totalSampleExtent: model.totalSampleExtent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if model.isEmpty {
                ContentUnavailableView(
                    "No Track Timing Available",
                    systemImage: "timeline.selection",
                    description: Text("This song has no audio regions with usable timing data.")
                )
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                if model.hasUnresolvedTiming {
                    Label(
                        "Available EDL candidates are not yet linked to individual files. Unresolved files are labeled Unplaced.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                timeline
            }
        }
        .padding(14)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
        .accessibilityIdentifier("track-timeline")
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Track Timeline")
                    .font(.headline)
                Text("Audio regions by track and song time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Zoom Out", systemImage: "minus.magnifyingglass") {
                zoom = TimelineVisualizationBuilder.clampedZoom(zoom / 1.5)
            }
            .help("Zoom out in the timeline")
            .accessibilityIdentifier("timeline-zoom-out")

            Button("Zoom In", systemImage: "plus.magnifyingglass") {
                zoom = TimelineVisualizationBuilder.clampedZoom(zoom * 1.5)
            }
            .help("Zoom in on the timeline")
            .accessibilityIdentifier("timeline-zoom-in")

            Button("Fit", systemImage: "arrow.left.and.right") {
                let duration = Double(max(model.totalSampleExtent, 1)) / SampleTimeFormatter.standardSampleRate
                zoom = TimelineVisualizationBuilder.clampedZoom(1_000 / max(duration * 28, 1))
            }
            .help("Fit the song duration in the timeline")
            .accessibilityIdentifier("timeline-fit")
        }
        .buttonStyle(.borderless)
    }

    private var timeline: some View {
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    Text("TRACK")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: labelColumnWidth, height: rulerHeight, alignment: .leading)
                        .padding(.leading, 8)

                    ForEach(model.lanes) { lane in
                        Button {
                            selectedTrackID = lane.trackNumber
                            selectedRegionID = lane.regions.first?.id
                        } label: {
                            HStack(spacing: 7) {
                                if lane.trackNumber != nil {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(laneColor(lane.colorIndex))
                                        .frame(width: 4, height: 17)
                                }
                                Text(lane.label)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 0)
                            }
                            .font(.caption)
                            .frame(width: labelColumnWidth, height: laneHeight, alignment: .leading)
                            .padding(.leading, 8)
                            .contentShape(.rect)
                            .background(lane.trackNumber.map { selectedTrackID == $0 } == true ? Color.accentColor.opacity(0.1) : .clear)
                        }
                        .buttonStyle(.plain)
                        .help(lane.label)
                    }
                }
                .frame(width: labelColumnWidth)

                ScrollView(.horizontal) {
                    VStack(spacing: 0) {
                        ruler
                        ForEach(model.lanes) { lane in
                            laneContent(lane)
                        }
                    }
                    .frame(width: chartWidth, alignment: .leading)
                }
                .scrollIndicators(.visible)
            }
        }
        .scrollIndicators(.visible)
        .frame(minHeight: 250, maxHeight: .infinity)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(.separator)
                .frame(width: 1)
                .padding(.leading, labelColumnWidth)
        }
    }

    private var ruler: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(.background.secondary)
            ForEach(ticks) { tick in
                let x = TimelineVisualizationBuilder.sampleToX(
                    sample: tick.samplePosition,
                    totalExtent: model.totalSampleExtent,
                    width: chartWidth
                )
                Rectangle()
                    .fill(.secondary.opacity(tick.isMajor ? 0.55 : 0.25))
                    .frame(width: 1, height: rulerHeight)
                    .offset(x: x)
                Text(tick.label)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                    .offset(x: x + 4, y: 5)
            }
        }
        .frame(width: chartWidth, height: rulerHeight)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.separator).frame(height: 1)
        }
        .accessibilityLabel("Timeline ruler")
    }

    private func laneContent(_ lane: TimelineLane) -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(lane.trackNumber.map { selectedTrackID == $0 ? Color.accentColor.opacity(0.07) : Color.clear } ?? Color.clear)

            ForEach(ticks) { tick in
                let x = TimelineVisualizationBuilder.sampleToX(
                    sample: tick.samplePosition,
                    totalExtent: model.totalSampleExtent,
                    width: chartWidth
                )
                Rectangle()
                    .fill(.secondary.opacity(tick.isMajor ? 0.14 : 0.07))
                    .frame(width: 1)
                    .offset(x: x)
            }

            ForEach(lane.regions) { region in
                let x = TimelineVisualizationBuilder.sampleToX(
                    sample: region.startSample ?? 0,
                    totalExtent: model.totalSampleExtent,
                    width: chartWidth
                )
                let resolvedWidth = region.lengthSample.map { length in
                    max(TimelineVisualizationBuilder.sampleToX(
                        sample: length,
                        totalExtent: model.totalSampleExtent,
                        width: chartWidth
                    ), 8)
                } ?? 10

                Button {
                    selectedTrackID = lane.trackNumber
                    selectedRegionID = region.id
                } label: {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(laneColor(lane.colorIndex).opacity(region.isSelected ? 0.95 : 0.72))
                        .overlay {
                            if region.isSelected {
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(.primary.opacity(0.8), lineWidth: 1.5)
                            }
                        }
                        .overlay(alignment: .leading) {
                            Text(region.startSample == nil ? "Unplaced · \(region.sourceFilename)" : region.sourceFilename)
                                .font(.caption2)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .padding(.horizontal, 5)
                        }
                        .frame(width: resolvedWidth, height: 23)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .offset(x: x, y: 5)
                .help(regionAccessibilityDescription(region))
                .accessibilityLabel(regionAccessibilityDescription(region))
                .accessibilityIdentifier("timeline-region-\(region.id)")
            }
        }
        .frame(width: chartWidth, height: laneHeight)
        .overlay(alignment: .bottom) {
            Rectangle().fill(.separator.opacity(0.45)).frame(height: 0.5)
        }
    }

    private func laneColor(_ index: Int) -> Color {
        let palette: [Color] = [.blue, .green, .orange, .purple, .teal, .pink, .indigo, .cyan]
        return palette[index % palette.count]
    }

    private func regionAccessibilityDescription(_ region: TimelineRegionPresentation) -> String {
        let start = region.startSample.map { SampleTimeFormatter.displayString(samples: $0) } ?? "placement unresolved"
        let length = region.lengthSample.map { SampleTimeFormatter.displayString(samples: $0) } ?? "unknown length"
        return "\(region.sourceFilename), start \(start), length \(length), timing evidence \(region.evidenceLevel.rawValue)"
    }
}
