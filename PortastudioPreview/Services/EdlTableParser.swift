//
//  EdlTableParser.swift
//  PortastudioPreview
//

import Foundation

struct EdlTableParser {
    static let track1ActiveTakeCandidateOffset = 0x00B01A38
    private static let fileListLabel = "File List"
    private static let timelineSampleRate = 48_000
    private static let likelyClipLengthTrim = 480

    func parse(_ data: Data) throws -> EdlTableSummary {
        let reader = ByteReader(data: data)
        let activeTakeCandidate = try reader.readUInt8(at: Self.track1ActiveTakeCandidateOffset)
        let fileListEntries = Self.parseFileListEntries(from: data)
        let timelineAnchors = Self.extractTimelineAnchors(from: data)

        return EdlTableSummary(
            track1ActiveTakeCandidate: activeTakeCandidate,
            activeTakeCandidateOffset: Self.track1ActiveTakeCandidateOffset,
            evidenceLevel: .correlated,
            fileListEntries: fileListEntries,
            timelineAnchors: timelineAnchors
        )
    }

    private static func parseFileListEntries(from data: Data) -> [EdlFileListEntry] {
        guard let labelRange = data.range(of: Data(fileListLabel.utf8)) else {
            return []
        }

        // The file list payload is compact and close to the label in current captures.
        let start = labelRange.lowerBound
        let end = min(data.count, start + 0x400)
        let payload = data[start..<end]

        guard !payload.isEmpty else {
            return []
        }

        guard let regex = try? NSRegularExpression(pattern: "ZZ\\d{4}_\\d\\.wav") else {
            return []
        }

        let text = String(decoding: payload, as: UTF8.self)
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)

        var entries: [EdlFileListEntry] = []

        for (index, match) in matches.enumerated() {
            guard let range = Range(match.range, in: text) else {
                continue
            }

            entries.append(
                EdlFileListEntry(
                    fileID: index,
                    filename: String(text[range]),
                    evidenceLevel: .hypothesis
                )
            )
        }

        return entries
    }

    private static func extractTimelineAnchors(from data: Data) -> [Int] {
        // Candidate timeline anchors: values that appear in structured record blocks
        // and align with the observed 48k sample-domain timing behavior.
        let minSample = timelineSampleRate
        let maxSample = timelineSampleRate * 60 * 20
        let begin = 0x43000
        let end = min(data.count, 0x46000)

        guard end > begin + 4 else {
            return []
        }

        var frequency: [Int: Int] = [:]

        for offset in stride(from: begin, to: end - 3, by: 4) {
            let value = readUInt32LE(data: data, offset: offset)

            guard value >= minSample,
                  value <= maxSample else {
                continue
            }

            frequency[value, default: 0] += 1
        }

        var anchors = frequency
            .filter { _, count in count >= 2 }
            .map(\ .key)
            .sorted()

        // Include known clipped-length style anchors if present nearby.
        let trimmedLengths = anchors.filter { ($0 % likelyClipLengthTrim) == 0 }

        if !trimmedLengths.isEmpty {
            anchors = Array(Set(anchors + trimmedLengths)).sorted()
        }

        return anchors
    }

    private static func readUInt32LE(data: Data, offset: Int) -> Int {
        let b0 = Int(data[data.startIndex + offset])
        let b1 = Int(data[data.startIndex + offset + 1]) << 8
        let b2 = Int(data[data.startIndex + offset + 2]) << 16
        let b3 = Int(data[data.startIndex + offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }
}
