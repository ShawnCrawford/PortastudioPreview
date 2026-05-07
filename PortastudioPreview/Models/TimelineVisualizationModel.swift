//
//  TimelineVisualizationModel.swift
//  PortastudioPreview
//

import Foundation

/// Playability state of a region as reflected in the visual timeline.
enum TimelineRegionPlayState: Sendable, Equatable {
    /// Region will be played by the preview engine.
    case playable
    /// Region was suppressed by active-take or mute filtering.
    case suppressed(String)
    /// Source WAV file URL is unavailable or nil.
    case missingSource
    /// Multiple regions all start at sample 0; timing is ambiguous.
    case ambiguousTiming
}

/// A presentation-ready region for one visual lane in the timeline.
struct TimelineRegionPresentation: Sendable, Equatable, Identifiable {
    /// Matches `TimelineRegion.id` so table and canvas selection stay in sync.
    let id: String
    let sourceFilename: String
    let startSample: Int
    /// 0 when the region length is unknown.
    let lengthSample: Int
    let evidenceLevel: EvidenceLevel
    let playState: TimelineRegionPlayState
    let isSelected: Bool
    let startTimeDisplay: String
    let lengthDisplay: String
    /// Stable index into the lane color palette.
    let colorIndex: Int
}

/// A single horizontal lane in the visual timeline, corresponding to one region.
struct TimelineLane: Sendable, Equatable, Identifiable {
    let id: String
    let label: String
    let colorIndex: Int
    let region: TimelineRegionPresentation
}

/// A tick mark on the time ruler.
struct TimelineTimeRulerTick: Sendable, Equatable, Identifiable {
    /// Unique within a ruler tick set; used for `ForEach` identity.
    let id: Int
    let samplePosition: Int
    let label: String
    let isMajor: Bool
}

/// The complete presentation model for the timeline surface.
///
/// Built by `TimelineVisualizationBuilder` from a `PortastudioProject` and a `PlaybackPlan`.
struct TimelineVisualizationModel: Sendable, Equatable {
    let lanes: [TimelineLane]
    /// Largest inferred end-sample across all regions; used for ruler and pixel mapping.
    let totalSampleExtent: Int
    /// `true` when two or more regions all start at sample 0 and timing is unresolved.
    let hasAmbiguousTiming: Bool
    let isEmptyProject: Bool
    let emptyStateReason: String?
}

extension TimelineVisualizationModel {
    static let empty = TimelineVisualizationModel(
        lanes: [],
        totalSampleExtent: 0,
        hasAmbiguousTiming: false,
        isEmptyProject: true,
        emptyStateReason: "No unassigned regions parsed."
    )
}
