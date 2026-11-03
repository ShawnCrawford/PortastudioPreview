//
//  TimelineModels.swift
//  PortastudioPreview
//

import Foundation

struct EdlFileListEntry: Equatable, Hashable, Sendable {
    let fileID: Int
    let byteOffset: Int?
    let filename: String
    let evidenceLevel: EvidenceLevel

    init(fileID: Int, byteOffset: Int? = nil, filename: String, evidenceLevel: EvidenceLevel) {
        self.fileID = fileID
        self.byteOffset = byteOffset
        self.filename = filename
        self.evidenceLevel = evidenceLevel
    }
}

struct EdlTimelineCandidate: Equatable, Hashable, Sendable {
    let representativeSample: Int
    let rawSamples: [Int]
    let evidenceLevel: EvidenceLevel
}

struct TimelineRegion: Equatable, Hashable, Identifiable, Sendable {
    let startSample: Int?
    let endSample: Int?
    let lengthSample: Int?
    let sourceFilename: String?
    let sourceURL: URL?
    let evidenceLevel: EvidenceLevel

    var id: String {
        let source = sourceFilename ?? "unknown"
        return "\(startSample.map { String($0) } ?? "unresolved")-\(endSample ?? -1)-\(source)"
    }

    var resolvedLengthSample: Int? {
        if let lengthSample {
            return lengthSample
        }

        guard let endSample else {
            return nil
        }

        guard let startSample else { return nil }
        return max(endSample - startSample, 0)
    }
}

struct TrackTimeline: Equatable, Hashable, Sendable {
    let trackNumber: Int
    let regions: [TimelineRegion]
    let evidenceLevel: EvidenceLevel
}
