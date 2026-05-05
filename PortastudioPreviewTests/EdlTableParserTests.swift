//
//  EdlTableParserTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct EdlTableParserTests {
    @Test func readsActiveTakeCandidateByte() throws {
        var data = Data(count: EdlTableParser.track1ActiveTakeCandidateOffset + 1)
        data[EdlTableParser.track1ActiveTakeCandidateOffset] = 0x03

        let summary = try EdlTableParser().parse(data)

        #expect(summary.activeTakeCandidateOffset == 0x00B01A38)
        #expect(summary.track1ActiveTakeCandidate == 0x03)
        #expect(summary.evidenceLevel == .correlated)
    }

    @Test func rejectsDataShorterThanActiveTakeCandidateOffset() {
        let data = Data(count: EdlTableParser.track1ActiveTakeCandidateOffset)

        #expect(throws: ByteReaderError.truncated(
            offset: EdlTableParser.track1ActiveTakeCandidateOffset,
            requiredLength: EdlTableParser.track1ActiveTakeCandidateOffset + 1,
            actualLength: EdlTableParser.track1ActiveTakeCandidateOffset
        )) {
            try EdlTableParser().parse(data)
        }
    }
}
