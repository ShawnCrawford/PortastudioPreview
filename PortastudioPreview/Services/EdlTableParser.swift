//
//  EdlTableParser.swift
//  PortastudioPreview
//

import Foundation

struct EdlTableParser {
    static let track1ActiveTakeCandidateOffset = 0x00B01A38

    func parse(_ data: Data) throws -> EdlTableSummary {
        let reader = ByteReader(data: data)
        let activeTakeCandidate = try reader.readUInt8(at: Self.track1ActiveTakeCandidateOffset)

        return EdlTableSummary(
            track1ActiveTakeCandidate: activeTakeCandidate,
            activeTakeCandidateOffset: Self.track1ActiveTakeCandidateOffset,
            evidenceLevel: .correlated
        )
    }
}
