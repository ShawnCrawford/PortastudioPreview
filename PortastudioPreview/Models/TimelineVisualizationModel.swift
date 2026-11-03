//
//  TimelineVisualizationModel.swift
//  PortastudioPreview
//

import Foundation

struct TimelineRegionPresentation: Sendable, Equatable, Identifiable {
    let id: String
    let sourceFilename: String
    let startSample: Int?
    let lengthSample: Int?
    let evidenceLevel: EvidenceLevel
    let isSelected: Bool

    var endSample: Int? {
        guard let lengthSample else { return nil }
        guard let startSample else { return nil }
        return startSample + lengthSample
    }
}

struct TimelineLane: Sendable, Equatable, Identifiable {
    let id: String
    let label: String
    let trackNumber: Int?
    let colorIndex: Int
    let regions: [TimelineRegionPresentation]
}

struct TimelineTimeRulerTick: Sendable, Equatable, Identifiable {
    let id: Int
    let samplePosition: Int
    let label: String
    let isMajor: Bool
}

struct TimelineVisualizationModel: Sendable, Equatable {
    let lanes: [TimelineLane]
    let totalSampleExtent: Int
    let hasUnresolvedTiming: Bool

    var isEmpty: Bool {
        !lanes.contains { !$0.regions.isEmpty }
    }

    var hasResolvedTiming: Bool {
        lanes.contains { lane in lane.regions.contains { $0.startSample != nil } }
    }

    static let empty = TimelineVisualizationModel(
        lanes: [],
        totalSampleExtent: 0,
        hasUnresolvedTiming: false
    )
}
