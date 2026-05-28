//
//  TimelineVisualizationBuilder.swift
//  PortastudioPreview
//

import Foundation

/// Converts a `PortastudioProject` and a `PlaybackPlan` into a `TimelineVisualizationModel`.
///
/// All logic is pure and testable. No UI dependencies.
enum TimelineVisualizationBuilder {

    static let minZoom: Double = 1.0
    static let maxZoom: Double = 10.0
    static let defaultMaxRulerTicks = 10

    /// Builds a `TimelineVisualizationModel` from a project and its current playback plan.
    ///
    /// - Parameters:
    ///   - project: The currently selected Portastudio project.
    ///   - selectedRegionID: The currently selected region, if any.
    ///   - playbackPlan: The plan produced by `PreviewPlaybackPlanner.plan(for:)`.
    static func build(
        project: PortastudioProject,
        selectedRegionID: TimelineRegion.ID?,
        playbackPlan: PlaybackPlan
    ) -> TimelineVisualizationModel {
        let regions = project.unassignedAudioRegions

        guard !regions.isEmpty else {
            return .empty
        }

        let suppressedFilenames = Set(playbackPlan.suppressedEntries.map { $0.filename })
        let suppressedReasons = Dictionary(
            uniqueKeysWithValues: playbackPlan.suppressedEntries.compactMap { entry -> (String, PlaybackSuppressionReason)? in
                (entry.filename, entry.reason)
            }
        )

        // Compute total sample extent from all regions.
        let totalExtent = computeTotalExtent(regions: regions)

        // Ambiguous timing: multiple regions all starting at sample 0.
        let hasAmbiguousTiming = regions.count > 1 && regions.allSatisfy { $0.startSample == 0 }

        let lanes = regions.enumerated().map { (index, region) -> TimelineLane in
            let filename = region.sourceFilename ?? "Region \(index + 1)"
            let isSelected = region.id == selectedRegionID

            let playState = resolvePlayState(
                region: region,
                filename: filename,
                suppressedFilenames: suppressedFilenames,
                suppressedReasons: suppressedReasons,
                hasAmbiguousTiming: hasAmbiguousTiming
            )

            let lengthSample = region.resolvedLengthSample ?? 0

            let presentation = TimelineRegionPresentation(
                id: region.id,
                sourceFilename: filename,
                startSample: region.startSample,
                lengthSample: lengthSample,
                evidenceLevel: region.evidenceLevel,
                playState: playState,
                isSelected: isSelected,
                startTimeDisplay: SampleTimeFormatter.displayString(samples: region.startSample),
                lengthDisplay: lengthSample > 0
                    ? SampleTimeFormatter.displayString(samples: lengthSample)
                    : "Unknown",
                colorIndex: index
            )

            return TimelineLane(
                id: region.id,
                label: filename,
                colorIndex: index,
                region: presentation
            )
        }

        return TimelineVisualizationModel(
            lanes: lanes,
            totalSampleExtent: totalExtent,
            hasAmbiguousTiming: hasAmbiguousTiming,
            isEmptyProject: false,
            emptyStateReason: nil
        )
    }

    /// Generates ruler tick marks for a visible sample range.
    ///
    /// Ticks are spaced at rounded intervals that are human-readable at the current zoom level.
    /// Every fourth tick is marked major.
    ///
    /// - Parameters:
    ///   - visibleStartSample: The first visible sample position.
    ///   - visibleEndSample: The last visible sample position.
    ///   - maxTicks: Upper bound on the number of ticks to generate.
    ///   - sampleRate: The assumed sample rate for display formatting.
    static func rulerTicks(
        visibleStartSample: Int,
        visibleEndSample: Int,
        maxTicks: Int = defaultMaxRulerTicks,
        sampleRate: Double = SampleTimeFormatter.standardSampleRate
    ) -> [TimelineTimeRulerTick] {
        guard visibleEndSample > visibleStartSample,
              maxTicks > 0,
              sampleRate > 0 else {
            return []
        }

        let durationSeconds = Double(visibleEndSample - visibleStartSample) / sampleRate
        let roughInterval = durationSeconds / Double(maxTicks)
        let tickIntervalSeconds = niceTimeInterval(roughInterval)
        let tickIntervalSamples = Int(tickIntervalSeconds * sampleRate)

        guard tickIntervalSamples > 0 else { return [] }

        // Align first tick to a multiple of the tick interval.
        let firstTickSample: Int
        if visibleStartSample == 0 {
            firstTickSample = 0
        } else {
            firstTickSample = ((visibleStartSample + tickIntervalSamples - 1)
                / tickIntervalSamples) * tickIntervalSamples
        }

        var ticks: [TimelineTimeRulerTick] = []
        var sample = firstTickSample
        var idx = 0

        while sample <= visibleEndSample && ticks.count < maxTicks * 2 {
            let isMajor = tickIntervalSamples > 0 && (sample % (tickIntervalSamples * 4) == 0)
            ticks.append(TimelineTimeRulerTick(
                id: idx,
                samplePosition: sample,
                label: SampleTimeFormatter.displayString(samples: sample),
                isMajor: isMajor
            ))
            sample += tickIntervalSamples
            idx += 1
        }

        return ticks
    }

    /// Converts a sample position to an x-coordinate within a canvas of the given pixel width.
    static func sampleToX(sample: Int, totalExtent: Int, width: CGFloat) -> CGFloat {
        guard totalExtent > 0, width > 0 else { return 0 }
        return CGFloat(sample) / CGFloat(totalExtent) * width
    }

    /// Clamps a zoom factor to `[minZoom, maxZoom]`.
    static func clampedZoom(_ zoom: Double) -> Double {
        min(max(zoom, minZoom), maxZoom)
    }

    // MARK: - Private

    private static func computeTotalExtent(regions: [TimelineRegion]) -> Int {
        let maxEnd = regions.compactMap { region -> Int? in
            if let length = region.resolvedLengthSample {
                return region.startSample + length
            }
            return region.startSample > 0 ? region.startSample : nil
        }.max() ?? 0
        return max(maxEnd, 1)
    }

    private static func resolvePlayState(
        region: TimelineRegion,
        filename: String,
        suppressedFilenames: Set<String>,
        suppressedReasons: [String: PlaybackSuppressionReason],
        hasAmbiguousTiming: Bool
    ) -> TimelineRegionPlayState {
        if region.sourceURL == nil {
            return .missingSource
        }
        if suppressedFilenames.contains(filename) {
            let reason = suppressedReasons[filename]?.displayDescription ?? "Suppressed"
            return .suppressed(reason)
        }
        if hasAmbiguousTiming {
            return .ambiguousTiming
        }
        return .playable
    }

    private static let niceIntervals: [Double] = [
        0.1, 0.25, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600
    ]

    private static func niceTimeInterval(_ rough: Double) -> Double {
        for interval in niceIntervals {
            if interval >= rough { return interval }
        }
        return niceIntervals.last ?? 1
    }
}

// MARK: - CoreGraphics import

import CoreGraphics

// MARK: - PlaybackSuppressionReason display

private extension PlaybackSuppressionReason {
    var displayDescription: String {
        switch self {
        case .track1ActiveVirtualTake: return "Inactive virtual take"
        case .track1Mute: return "Track muted (Confirmed)"
        case .track2Mute: return "Track muted (Confirmed)"
        case .trackMute: return "Track muted (Confirmed)"
        }
    }
}
