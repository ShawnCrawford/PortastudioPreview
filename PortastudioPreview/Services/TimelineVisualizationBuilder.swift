//
//  TimelineVisualizationBuilder.swift
//  PortastudioPreview
//

import Foundation
import CoreGraphics

enum TimelineVisualizationBuilder {
    static let minZoom: Double = 0.1
    static let maxZoom: Double = 10
    static let defaultMaxRulerTicks = 12

    static func build(
        project: PortastudioProject,
        selectedRegionID: TimelineRegion.ID?,
        selectedVirtualTrackIDs: [Int: VirtualTrackOption.ID]
    ) -> TimelineVisualizationModel {
        var lanes = project.tracks.sorted { $0.trackNumber < $1.trackNumber }.map { track in
            let selectedOption = track.selectedVirtualTrackOption(
                selectedOptionID: selectedVirtualTrackIDs[track.trackNumber]
            )
            let regions = selectedOption.map { [$0.timelineRegion] } ?? (track.timeline?.regions ?? [])
            let selectedTake = selectedOption.map { " · \($0.takeLabel)" } ?? ""

            return TimelineLane(
                id: "track-\(track.trackNumber)",
                label: "Track \(track.trackNumber)\(selectedTake)",
                trackNumber: track.trackNumber,
                colorIndex: track.trackNumber - 1,
                regions: regions.map {
                    presentation(for: $0, selectedRegionID: selectedRegionID)
                }
            )
        }

        // Keep files without an evidence-backed physical-track assignment visible
        // without implying that their file-list order identifies a track.
        lanes.append(contentsOf: project.unassignedAudioRegions.enumerated().map { index, region in
            let filename = region.sourceFilename ?? "Audio file \(index + 1)"
            return TimelineLane(
                id: "unassigned-\(region.id)",
                label: "Unassigned · \(filename)",
                trackNumber: nil,
                colorIndex: index,
                regions: [presentation(for: region, selectedRegionID: selectedRegionID)]
            )
        })

        let allRegions = lanes.flatMap(\.regions)
        guard !allRegions.isEmpty else { return .empty }

        let maxEnd = allRegions.compactMap(\.endSample).max() ?? 0
        let maxStart = allRegions.map(\.startSample).max() ?? 0
        let unassignedRegions = project.unassignedAudioRegions
        let hasUnresolvedTiming = unassignedRegions.count > 1
            && unassignedRegions.allSatisfy { $0.startSample == 0 }

        return TimelineVisualizationModel(
            lanes: lanes,
            totalSampleExtent: max(max(maxEnd, maxStart), 1),
            hasUnresolvedTiming: hasUnresolvedTiming
        )
    }

    static func rulerTicks(
        totalSampleExtent: Int,
        maxTicks: Int = defaultMaxRulerTicks,
        sampleRate: Double = SampleTimeFormatter.standardSampleRate
    ) -> [TimelineTimeRulerTick] {
        guard totalSampleExtent > 0, maxTicks > 0, sampleRate > 0 else { return [] }

        let durationSeconds = Double(totalSampleExtent) / sampleRate
        let roughInterval = durationSeconds / Double(maxTicks)
        let intervalSeconds = niceTimeInterval(roughInterval)
        let intervalSamples = max(Int(intervalSeconds * sampleRate), 1)
        var ticks: [TimelineTimeRulerTick] = []
        var sample = 0

        while sample <= totalSampleExtent && ticks.count <= maxTicks {
            ticks.append(TimelineTimeRulerTick(
                id: ticks.count,
                samplePosition: sample,
                label: SampleTimeFormatter.displayString(samples: sample),
                isMajor: ticks.count.isMultiple(of: 4)
            ))
            sample += intervalSamples
        }

        return ticks
    }

    static func sampleToX(sample: Int, totalExtent: Int, width: CGFloat) -> CGFloat {
        guard totalExtent > 0, width > 0 else { return 0 }
        return CGFloat(sample) / CGFloat(totalExtent) * width
    }

    static func clampedZoom(_ zoom: Double) -> Double {
        min(max(zoom, minZoom), maxZoom)
    }

    private static func presentation(
        for region: TimelineRegion,
        selectedRegionID: TimelineRegion.ID?
    ) -> TimelineRegionPresentation {
        TimelineRegionPresentation(
            id: region.id,
            sourceFilename: region.sourceFilename ?? "Audio file",
            startSample: max(region.startSample, 0),
            lengthSample: region.resolvedLengthSample,
            evidenceLevel: region.evidenceLevel,
            isSelected: region.id == selectedRegionID
        )
    }

    private static let niceIntervals: [Double] = [1, 2, 5, 10, 15, 30, 60, 120, 300, 600]

    private static func niceTimeInterval(_ rough: Double) -> Double {
        niceIntervals.first(where: { $0 >= rough }) ?? niceIntervals[niceIntervals.count - 1]
    }
}
