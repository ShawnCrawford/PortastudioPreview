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
        #expect(summary.fileListEntries.isEmpty)
        #expect(summary.timelineAnchors.isEmpty)
    }

    @Test func parsesFileListAndTimelineAnchorsWhenPresent() throws {
        let fileListOffset = 0x00B02580
        let fileListText = "File List\0ZZ0002_1.wav\0ZZ0003_1.wav\0"
        let dataSize = max(
            EdlTableParser.track1ActiveTakeCandidateOffset + 1,
            max(0x46000, fileListOffset + fileListText.utf8.count)
        )

        var data = Data(count: dataSize)
        data[EdlTableParser.track1ActiveTakeCandidateOffset] = 0x01
        data.replaceSubrange(fileListOffset..<(fileListOffset + fileListText.utf8.count), with: fileListText.utf8)

        writeUInt32LE(820_800, to: &data, at: 0x44C58)
        writeUInt32LE(820_800, to: &data, at: 0x44C5C)
        writeUInt32LE(2_457_600, to: &data, at: 0x44C90)
        writeUInt32LE(2_457_600, to: &data, at: 0x44C94)
        writeUInt32LE(2_911_520, to: &data, at: 0x44EA0)
        writeUInt32LE(2_911_520, to: &data, at: 0x44EA4)

        let summary = try EdlTableParser().parse(data)

        #expect(summary.fileListEntries.count == 2)
        #expect(summary.fileListEntries[0].filename == "ZZ0002_1.wav")
        #expect(summary.fileListEntries[1].filename == "ZZ0003_1.wav")
        #expect(summary.timelineAnchors.contains(820_800))
        #expect(summary.timelineAnchors.contains(2_457_600))
        #expect(summary.timelineAnchors.contains(2_911_520))
    }

    @Test func parsesFileListEntriesBeyondInitialMVPWindow() throws {
        let fileListOffset = 0x100
        let fileListText = "File List\0ZZ0000_1.wav\0"
        let delayedFilename = "ZZ0098_8.WAV"
        let delayedFilenameOffset = fileListOffset + 0x500
        let dataSize = max(
            EdlTableParser.track1ActiveTakeCandidateOffset + 1,
            delayedFilenameOffset + delayedFilename.utf8.count
        )

        var data = Data(count: dataSize)
        data.replaceSubrange(fileListOffset..<(fileListOffset + fileListText.utf8.count), with: fileListText.utf8)
        data.replaceSubrange(delayedFilenameOffset..<(delayedFilenameOffset + delayedFilename.utf8.count), with: delayedFilename.utf8)

        let summary = try EdlTableParser().parse(data)

        #expect(summary.fileListEntries.map(\.filename) == ["ZZ0000_1.wav", "ZZ0098_8.WAV"])
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

    private func writeUInt32LE(_ value: UInt32, to data: inout Data, at offset: Int) {
        data[offset] = UInt8(value & 0xFF)
        data[offset + 1] = UInt8((value >> 8) & 0xFF)
        data[offset + 2] = UInt8((value >> 16) & 0xFF)
        data[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}
