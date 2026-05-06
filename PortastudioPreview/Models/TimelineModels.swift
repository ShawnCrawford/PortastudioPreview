//
//  TimelineModels.swift
//  PortastudioPreview
//

import Foundation

struct EdlFileListEntry: Equatable, Hashable {
    let fileID: Int
    let filename: String
    let evidenceLevel: EvidenceLevel
}

struct TimelineRegion: Equatable, Hashable, Identifiable {
    let startSample: Int
    let endSample: Int?
    let lengthSample: Int?
    let sourceFilename: String?
    let sourceURL: URL?
    let evidenceLevel: EvidenceLevel

    var id: String {
        let source = sourceFilename ?? "unknown"
        return "\(startSample)-\(endSample ?? -1)-\(source)"
    }

    var resolvedLengthSample: Int? {
        if let lengthSample {
            return lengthSample
        }

        guard let endSample else {
            return nil
        }

        return max(endSample - startSample, 0)
    }
}

struct TrackTimeline: Equatable, Hashable {
    let trackNumber: Int
    let regions: [TimelineRegion]
    let evidenceLevel: EvidenceLevel
}