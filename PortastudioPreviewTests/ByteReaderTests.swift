//
//  ByteReaderTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct ByteReaderTests {
    @Test func readsUInt8AtHexOffsets() throws {
        var data = Data(count: 0x00C5)
        data[0x00C4] = 0x7F

        let reader = ByteReader(data: data)

        #expect(try reader.readUInt8(at: 0x00C4) == 0x7F)
    }

    @Test func throwsDeterministicTruncationError() {
        let reader = ByteReader(data: Data(count: 3))

        #expect(throws: ByteReaderError.truncated(offset: 0x0003, requiredLength: 4, actualLength: 3)) {
            try reader.readUInt8(at: 0x0003)
        }
    }
}
