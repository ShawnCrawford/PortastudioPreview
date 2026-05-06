//
//  ProjectPreviewBuilder.swift
//  PortastudioPreview
//

import Foundation
import AVFoundation

struct ProjectPreviewBuilder {
    func build(folderURL: URL, fileManager: FileManager = .default) throws -> PortastudioProject {
        var validationIssues: [ProjectValidationIssue] = []
        let songURL = folderURL.appendingPathComponent("song.sys")
        let edlTableURL = folderURL.appendingPathComponent("edltable.sys")

        let wavInventory = try WAVInventoryScanner().scan(folderURL, fileManager: fileManager)

        if wavInventory.isEmpty {
            validationIssues.append(
                ProjectValidationIssue(
                    id: "wav.empty",
                    severity: .warning,
                    message: "No WAV inventory found."
                )
            )
        }

        let mixerSettings = parseSongSys(at: songURL, fileManager: fileManager, validationIssues: &validationIssues)
        let edlTableData = fileManager.fileExists(atPath: edlTableURL.path)
            ? (try? Data(contentsOf: edlTableURL, options: .mappedIfSafe))
            : nil
        let edlTableSummary = parseEdlTable(
            data: edlTableData,
            url: edlTableURL,
            fileManager: fileManager,
            validationIssues: &validationIssues
        )

        for setting in mixerSettings {
            for warning in setting.warningIssues {
                validationIssues.append(
                    ProjectValidationIssue(
                        id: "song.track\(setting.trackNumber).\(warning.idComponent)",
                        severity: .warning,
                        message: warning.message
                    )
                )
            }
        }

        let unassignedAudioRegions = buildUnassignedAudioRegions(
            wavInventory: wavInventory,
            edlTableSummary: edlTableSummary,
            edlTableData: edlTableData
        )

        let tracks = (0..<MixerMapOffsets.trackCount).map { trackIndex in
            return TrackPreview(
                trackNumber: trackIndex + 1,
                candidateWAV: nil,
                mixerSetting: mixerSettings.indices.contains(trackIndex) ? mixerSettings[trackIndex] : nil,
                track1ActiveTakeCandidate: trackIndex == 0 ? edlTableSummary?.track1ActiveTakeCandidate : nil,
                timeline: nil
            )
        }

        return PortastudioProject(
            folderURL: folderURL,
            validationIssues: validationIssues,
            wavInventory: wavInventory,
            unassignedAudioRegions: unassignedAudioRegions,
            tracks: tracks,
            edlTableSummary: edlTableSummary
        )
    }

    private func parseSongSys(
        at url: URL,
        fileManager: FileManager,
        validationIssues: inout [ProjectValidationIssue]
    ) -> [TrackMixerSetting] {
        guard fileManager.fileExists(atPath: url.path) else {
            validationIssues.append(
                ProjectValidationIssue(
                    id: "song.missing",
                    severity: .error,
                    message: "Missing song.sys."
                )
            )
            return []
        }

        do {
            return try SongSysParser().parse(Data(contentsOf: url, options: .mappedIfSafe))
        } catch {
            validationIssues.append(
                ProjectValidationIssue(
                    id: "song.unreadable",
                    severity: .error,
                    message: "Could not parse song.sys: \(error.localizedDescription)"
                )
            )
            return []
        }
    }

    private func parseEdlTable(
        data: Data?,
        url: URL,
        fileManager: FileManager,
        validationIssues: inout [ProjectValidationIssue]
    ) -> EdlTableSummary? {
        guard fileManager.fileExists(atPath: url.path) else {
            validationIssues.append(
                ProjectValidationIssue(
                    id: "edltable.missing",
                    severity: .error,
                    message: "Missing edltable.sys."
                )
            )
            return nil
        }

        guard let data else {
            validationIssues.append(
                ProjectValidationIssue(
                    id: "edltable.unreadable",
                    severity: .error,
                    message: "Could not read edltable.sys."
                )
            )
            return nil
        }

        do {
            return try EdlTableParser().parse(data)
        } catch {
            validationIssues.append(
                ProjectValidationIssue(
                    id: "edltable.unreadable",
                    severity: .error,
                    message: "Could not parse edltable.sys: \(error.localizedDescription)"
                )
            )
            return nil
        }
    }

    private func buildUnassignedAudioRegions(
        wavInventory: [WAVInventoryItem],
        edlTableSummary: EdlTableSummary?,
        edlTableData: Data?
    ) -> [TimelineRegion] {
        let orderedWAVs = orderedUnassignedWAVs(wavInventory: wavInventory, edlTableSummary: edlTableSummary)
        var startSamples = Self.inferredStartSamples(
            wavCount: orderedWAVs.count,
            timelineAnchors: edlTableSummary?.timelineAnchors ?? []
        )

        // Fallback: when no timeline anchors resolve positions and multiple WAVs are present,
        // attempt a sequential layout (each clip placed immediately after the previous one).
        // Each clip's length is the WAV sample count minus the device's 441-sample trim.
        // Stereo pairs (ZZxxxx_2.wav alongside ZZxxxx_1.wav) share the same start position.
        // Evidence: Hypothesis — staircase values matching trimmed WAV lengths are correlated
        // in edltable.sys for PONG_0096 captures; confirmed absent from SONG_0077/0078 which
        // use explicit Type A position records instead.
        if startSamples.allSatisfy({ $0 == 0 }), orderedWAVs.count > 1,
           let sequential = Self.sequentialStartSamplesIfConfirmed(
               orderedWAVs: orderedWAVs,
               edlData: edlTableData
           ) {
            startSamples = sequential
        }

        return orderedWAVs.enumerated().map { index, wav in
            let startSample = startSamples[index]
            let lengthSample = wavSampleLength(for: wav.url)

            return TimelineRegion(
                startSample: startSample,
                endSample: lengthSample.map { startSample + $0 },
                lengthSample: lengthSample,
                sourceFilename: wav.rawFilename,
                sourceURL: wav.url,
                evidenceLevel: .hypothesis
            )
        }
    }

    private func orderedUnassignedWAVs(
        wavInventory: [WAVInventoryItem],
        edlTableSummary: EdlTableSummary?
    ) -> [WAVInventoryItem] {
        guard let edlEntries = edlTableSummary?.fileListEntries,
              !edlEntries.isEmpty else {
            return wavInventory
        }

        var remainingWAVs = wavInventory
        var orderedWAVs: [WAVInventoryItem] = []

        for entry in edlEntries {
            guard let matchIndex = remainingWAVs.firstIndex(where: {
                $0.rawFilename.localizedCaseInsensitiveCompare(entry.filename) == .orderedSame
            }) else {
                continue
            }

            orderedWAVs.append(remainingWAVs.remove(at: matchIndex))
        }

        return orderedWAVs + remainingWAVs
    }

    static func inferredStartSamples(wavCount: Int, timelineAnchors: [Int]) -> [Int] {
        guard wavCount > 0 else {
            return []
        }

        let starts = timelineAnchors.map { max($0, 0) }.sorted()

        if starts.count == wavCount {
            return starts
        }

        if wavCount > 1, starts.count == wavCount - 1 {
            return [0] + starts
        }

        return Array(repeating: 0, count: wavCount)
    }

    // MARK: - Sequential start-time fallback

    /// Computes sequential start positions from WAV file lengths when the edltable.sys
    /// does not yield usable timeline anchors (e.g., clips not near second boundaries).
    ///
    /// Cross-validates against the binary data: if the first expected boundary value
    /// (trimmed length of the first WAV) is not found in the edltable scan region,
    /// returns `nil` to keep the all-zero fallback.
    ///
    /// Stereo pairs are detected by filename: `ZZxxxx_N.wav` with N > 1 when a
    /// matching `ZZxxxx_1.wav` is present. Pairs receive the same start position as
    /// their primary take and do NOT advance the staircase pointer.
    ///
    /// Evidence: Hypothesis — correlated with PONG_0096 captures where staircase
    /// values matching trimmed WAV lengths appear in the edltable scan region.
    static func sequentialStartSamplesIfConfirmed(
        orderedWAVs: [WAVInventoryItem],
        edlData: Data?
    ) -> [Int]? {
        guard orderedWAVs.count > 1 else { return nil }

        // Build (stem → trimmed length) map from the primary (_1) take for each stem.
        let deviceTrim = 441
        var stemPrimaryLength: [String: Int] = [:]
        for wav in orderedWAVs {
            guard let stem = Self.wavStemAndSuffix(wav.rawFilename),
                  stem.suffix == 1 else { continue }
            if let file = try? AVAudioFile(forReading: wav.url) {
                let trimmed = max(Int(file.length) - deviceTrim, 0)
                stemPrimaryLength[stem.stem] = trimmed
            }
        }

        guard !stemPrimaryLength.isEmpty else { return nil }

        // Compute the staircase in EDL file-list order.
        // Only _1.wav files advance the pointer; _N.wav (N > 1) share their stem's position.
        var staircase: [Int] = []
        var pointer = 0
        for wav in orderedWAVs {
            guard let parsed = Self.wavStemAndSuffix(wav.rawFilename) else {
                staircase.append(pointer)
                continue
            }
            if parsed.suffix == 1 {
                staircase.append(pointer)
                if let length = stemPrimaryLength[parsed.stem] {
                    pointer += length
                }
            } else {
                // Stereo pair or alternate take: share the start position of the primary (_1) file
                // for this stem. If no primary has been seen yet, default to the current pointer.
                let pairedPosition: Int = staircase.indices.last(where: { idx in
                    guard let p = Self.wavStemAndSuffix(orderedWAVs[idx].rawFilename) else { return false }
                    return p.stem == parsed.stem && p.suffix == 1
                }).map { staircase[$0] } ?? pointer
                staircase.append(pairedPosition)
            }
        }

        guard staircase.count == orderedWAVs.count else { return nil }

        // Cross-validate: at least one expected non-zero boundary must be present in the
        // edltable scan region (0x41600 – 0x50000, 4-byte LE, tolerance ±5 samples).
        // This guards against false application of sequential layout to songs where clips
        // genuinely start simultaneously at position 0.
        let boundaries = Set(staircase.filter { $0 > 0 })
        guard !boundaries.isEmpty else { return nil }

        guard let edlData,
              Self.anyBoundaryFoundInEdl(boundaries, data: edlData) else {
            return nil
        }

        return staircase
    }

    /// Returns true if any value in `boundaries` appears in the edltable scan region
    /// (0x41600 – 0x50000) at 4-byte stride with ±5 sample tolerance.
    static func anyBoundaryFoundInEdl(_ boundaries: Set<Int>, data: Data) -> Bool {
        let scanBegin = 0x41600
        let scanEnd = min(data.count - 3, 0x50000)
        guard scanEnd > scanBegin else { return false }
        var offset = scanBegin
        while offset < scanEnd {
            let lo = Int(data[data.startIndex + offset])
            let b1 = Int(data[data.startIndex + offset + 1]) << 8
            let b2 = Int(data[data.startIndex + offset + 2]) << 16
            let b3 = Int(data[data.startIndex + offset + 3]) << 24
            let value = lo | b1 | b2 | b3
            for boundary in boundaries {
                if abs(value - boundary) <= 5 { return true }
            }
            offset += 4
        }
        return false
    }

    /// Parses a `ZZxxxx_N.wav` filename into `(stem: "ZZxxxx", suffix: N)`.
    /// Returns `nil` for filenames that do not match the pattern.
    static func wavStemAndSuffix(_ filename: String) -> (stem: String, suffix: Int)? {
        let name = (filename as NSString).deletingPathExtension
        guard let underscoreRange = name.range(of: "_", options: .backwards) else { return nil }
        let stemPart = String(name[name.startIndex ..< underscoreRange.lowerBound])
        let suffixPart = String(name[underscoreRange.upperBound...])
        guard let suffix = Int(suffixPart), suffix >= 1 else { return nil }
        return (stem: stemPart, suffix: suffix)
    }

    private func wavSampleLength(for url: URL) -> Int? {
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            return nil
        }

        return Int(audioFile.length)
    }
}
