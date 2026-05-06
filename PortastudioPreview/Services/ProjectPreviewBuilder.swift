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
        let edlTableSummary = parseEdlTable(at: edlTableURL, fileManager: fileManager, validationIssues: &validationIssues)

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

        let tracks = (0..<MixerMapOffsets.trackCount).map { trackIndex in
            let candidateWAV = wavInventory.indices.contains(trackIndex) ? wavInventory[trackIndex] : nil
            let timeline = inferTimeline(
                for: trackIndex + 1,
                candidateWAV: candidateWAV,
                edlTableSummary: edlTableSummary
            )

            return TrackPreview(
                trackNumber: trackIndex + 1,
                candidateWAV: candidateWAV,
                mixerSetting: mixerSettings.indices.contains(trackIndex) ? mixerSettings[trackIndex] : nil,
                track1ActiveTakeCandidate: trackIndex == 0 ? edlTableSummary?.track1ActiveTakeCandidate : nil,
                timeline: timeline
            )
        }

        return PortastudioProject(
            folderURL: folderURL,
            validationIssues: validationIssues,
            wavInventory: wavInventory,
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
        at url: URL,
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

        do {
            return try EdlTableParser().parse(Data(contentsOf: url, options: .mappedIfSafe))
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

    private func inferTimeline(
        for trackNumber: Int,
        candidateWAV: WAVInventoryItem?,
        edlTableSummary: EdlTableSummary?
    ) -> TrackTimeline? {
        guard let candidateWAV,
              let summary = edlTableSummary else {
            return nil
        }

        let wavLengthSample = wavSampleLength(for: candidateWAV.url)
        let anchors = summary.timelineAnchors.sorted()

        guard let startSample = preferredStartSample(for: trackNumber, anchors: anchors, wavLengthSample: wavLengthSample) else {
            return nil
        }

        let lengthSample = max((wavLengthSample ?? 0) - 480, 0)
        let region = TimelineRegion(
            startSample: startSample,
            endSample: lengthSample > 0 ? (startSample + lengthSample) : nil,
            lengthSample: lengthSample > 0 ? lengthSample : nil,
            sourceFilename: candidateWAV.rawFilename,
            sourceURL: candidateWAV.url,
            evidenceLevel: .hypothesis
        )

        return TrackTimeline(
            trackNumber: trackNumber,
            regions: [region],
            evidenceLevel: .hypothesis
        )
    }

    private func preferredStartSample(for trackNumber: Int, anchors: [Int], wavLengthSample: Int?) -> Int? {
        guard !anchors.isEmpty else {
            return nil
        }

        // Keep current behavior conservative: use delayed anchors when clearly present,
        // otherwise fall back to timeline start.
        if trackNumber > 4, let delayed = anchors.first(where: { $0 >= 48_000 * 5 }) {
            return delayed
        }

        if let wavLengthSample,
           let matched = anchors.first(where: { $0 >= wavLengthSample && $0 <= (wavLengthSample * 2) }) {
            return matched
        }

        return anchors.first
    }

    private func wavSampleLength(for url: URL) -> Int? {
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            return nil
        }

        return Int(audioFile.length)
    }
}
