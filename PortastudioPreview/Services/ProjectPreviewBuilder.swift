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

        let unassignedAudioRegions = buildUnassignedAudioRegions(
            wavInventory: wavInventory,
            edlTableSummary: edlTableSummary
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

    private func buildUnassignedAudioRegions(
        wavInventory: [WAVInventoryItem],
        edlTableSummary: EdlTableSummary?
    ) -> [TimelineRegion] {
        let orderedWAVs = orderedUnassignedWAVs(wavInventory: wavInventory, edlTableSummary: edlTableSummary)
        let starts = edlTableSummary?.timelineAnchors.sorted() ?? []
        let canPairStarts = !starts.isEmpty && starts.count == orderedWAVs.count

        return orderedWAVs.enumerated().map { index, wav in
            let startSample = canPairStarts ? starts[index] : 0
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

    private func wavSampleLength(for url: URL) -> Int? {
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            return nil
        }

        return Int(audioFile.length)
    }
}
