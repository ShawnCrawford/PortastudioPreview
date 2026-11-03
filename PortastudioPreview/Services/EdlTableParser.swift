//
//  EdlTableParser.swift
//  PortastudioPreview
//

import Foundation

struct EdlTableParser {
    static let track1ActiveTakeCandidateOffset = 0x00B01A38
    private static let fileListLabel = "File List"
    private static let fileListScanLength = 0x2000
    private static let timelineSampleRate = 44_100
    private static let timelineScanBegin = 0x41600
    private static let timelineScanEnd = 0x42D00
    private static let secondBoundaryTolerance = 800
    private static let duplicateTolerance = 800

    func parse(_ data: Data) throws -> EdlTableSummary {
        let reader = ByteReader(data: data)
        let activeTakeCandidate = try reader.readUInt8(at: Self.track1ActiveTakeCandidateOffset)
        let fileListEntries = Self.parseFileListEntries(from: data)
        let timelineCandidates = Self.extractTimelineCandidates(from: data)

        return EdlTableSummary(
            track1ActiveTakeCandidate: activeTakeCandidate,
            activeTakeCandidateOffset: Self.track1ActiveTakeCandidateOffset,
            evidenceLevel: .correlated,
            fileListEntries: fileListEntries,
            timelineAnchors: timelineCandidates.map(\.representativeSample),
            timelineCandidates: timelineCandidates
        )
    }

    private static func parseFileListEntries(from data: Data) -> [EdlFileListEntry] {
        guard let labelRange = data.range(of: Data(fileListLabel.utf8)) else {
            return []
        }

        // The file list payload is compact and close to the label in current captures,
        // but multi-take folders can exceed the earlier MVP-sized scan window.
        let start = labelRange.lowerBound
        let end = min(data.count, start + fileListScanLength)
        let payload = data[start..<end]

        guard !payload.isEmpty else {
            return []
        }

        guard let regex = try? NSRegularExpression(pattern: "ZZ\\d{4}_\\d\\.wav", options: [.caseInsensitive]) else {
            return []
        }

        let text = String(decoding: payload, as: UTF8.self)
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: nsRange)

        var entries: [EdlFileListEntry] = []
        var searchStart = labelRange.lowerBound

        for (index, match) in matches.enumerated() {
            guard let range = Range(match.range, in: text) else {
                continue
            }

            let filename = String(text[range])
            let rawFilenameRange = data.range(
                of: Data(filename.utf8),
                in: searchStart..<end
            )
            if let rawFilenameRange {
                searchStart = rawFilenameRange.upperBound
            }

            entries.append(
                EdlFileListEntry(
                    fileID: index,
                    byteOffset: rawFilenameRange.map { data.distance(from: data.startIndex, to: $0.lowerBound) },
                    filename: filename,
                    evidenceLevel: .confirmed
                )
            )
        }

        return entries
    }

    private static func extractTimelineCandidates(from data: Data) -> [EdlTimelineCandidate] {
        // Confirmed timeline starts: delayed captures use 44.1k sample-domain
        // values in this record window.
        let minSample = timelineSampleRate
        let maxSample = timelineSampleRate * 60 * 20
        let begin = timelineScanBegin
        let end = min(data.count, timelineScanEnd)

        guard end > begin + 4 else {
            return []
        }

        var rawSamples: [Int] = []

        for offset in stride(from: begin, to: end - 3, by: 4) {
            let value = readUInt32LE(data: data, offset: offset)

            guard value >= minSample,
                  value <= maxSample,
                  isNearSecondBoundary(value) else {
                continue
            }

            rawSamples.append(value)
        }

        return groupTimelineSamples(rawSamples)
    }

    private static func isNearSecondBoundary(_ value: Int) -> Bool {
        let remainder = value % timelineSampleRate
        return remainder <= secondBoundaryTolerance || (timelineSampleRate - remainder) <= secondBoundaryTolerance
    }

    private static func groupTimelineSamples(_ rawSamples: [Int]) -> [EdlTimelineCandidate] {
        let sortedSamples = rawSamples.sorted()

        guard !sortedSamples.isEmpty else {
            return []
        }

        var groups: [[Int]] = []

        for sample in sortedSamples {
            if let lastGroup = groups.last,
               let lastSample = lastGroup.last,
               abs(sample - lastSample) <= duplicateTolerance {
                groups[groups.count - 1].append(sample)
            } else {
                groups.append([sample])
            }
        }

        return groups.map { group in
            let nearestSecond = Int((Double(group[0]) / Double(timelineSampleRate)).rounded()) * timelineSampleRate

            return EdlTimelineCandidate(
                representativeSample: nearestSecond,
                rawSamples: Array(Set(group)).sorted(),
                evidenceLevel: .confirmed
            )
        }
    }

    private static func readUInt32LE(data: Data, offset: Int) -> Int {
        let b0 = Int(data[data.startIndex + offset])
        let b1 = Int(data[data.startIndex + offset + 1]) << 8
        let b2 = Int(data[data.startIndex + offset + 2]) << 16
        let b3 = Int(data[data.startIndex + offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }
}
