//
//  ProjectPreviewBuilder.swift
//  PortastudioPreview
//

import Foundation

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
            for warning in setting.warnings {
                validationIssues.append(
                    ProjectValidationIssue(
                        id: "song.track\(setting.trackNumber).\(warning.hashValue)",
                        severity: .warning,
                        message: warning
                    )
                )
            }
        }

        let tracks = (0..<MixerMapOffsets.trackCount).map { trackIndex in
            TrackPreview(
                trackNumber: trackIndex + 1,
                candidateWAV: wavInventory.indices.contains(trackIndex) ? wavInventory[trackIndex] : nil,
                mixerSetting: mixerSettings.indices.contains(trackIndex) ? mixerSettings[trackIndex] : nil,
                track1ActiveTakeCandidate: trackIndex == 0 ? edlTableSummary?.track1ActiveTakeCandidate : nil
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
}
