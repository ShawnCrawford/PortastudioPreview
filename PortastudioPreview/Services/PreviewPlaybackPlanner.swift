//
//  PreviewPlaybackPlanner.swift
//  PortastudioPreview
//

import Foundation

/// Pure playback-planning layer that converts a `PortastudioProject` into a `PlaybackPlan`
/// without touching AVFoundation.
///
/// **V1 scope — evidence-backed rules only:**
/// - Active virtual-take selection from the EDL active-take byte (Correlated, SONG_0083–0085)
/// - Track 1 mute suppression via EDL position 0 (Confirmed, SONG_0075)
/// - Track mute suppression via confirmed EDL position-to-track mapping
/// - Regions without assigned track mixer settings play at unity gain, center pan
struct PreviewPlaybackPlanner {

    static func plan(for project: PortastudioProject) -> PlaybackPlan {
        let allRegions = project.unassignedAudioRegions

        guard !allRegions.isEmpty else {
            return PlaybackPlan(playableRegions: [], suppressedEntries: [])
        }

        // Step 1: Apply virtual-take filtering.
        let (virtualTakeFiltered, virtualTakeSuppressed) = applyVirtualTakeFiltering(
            regions: allRegions,
            project: project
        )

        // Step 2: Apply mute suppression from confirmed EDL position-to-track mapping.
        let (muteFiltered, muteSuppressed) = applyMuteSuppression(
            regions: virtualTakeFiltered,
            project: project
        )

        // Step 3: Map remaining unassigned regions. Assigned tracks are handled by
        // StereoPreviewEngine's direct track path with mixer pan/level/mute applied.
        let scheduled = muteFiltered.compactMap { region -> ScheduledPlaybackRegion? in
            guard let url = region.sourceURL, let filename = region.sourceFilename else {
                return nil
            }
            return ScheduledPlaybackRegion(
                filename: filename,
                url: url,
                startSample: max(region.startSample, 0),
                volume: 1.0,
                pan: 0.0
            )
        }

        return PlaybackPlan(
            playableRegions: scheduled,
            suppressedEntries: virtualTakeSuppressed + muteSuppressed
        )
    }

    // MARK: - Virtual-take filtering

    /// Filters regions to the active virtual take.
    ///
    /// Two supported cases:
    /// 1. Same-stem multi-take: exactly one stem with multiple take-number alternatives.
    ///    Evidence: Correlated (SONG_0083–0085 same-stem pairs).
    /// 2. EDL file-list selector: active-take byte indexes directly into the EDL file list.
    ///    Evidence: Correlated (SONG_0084, `0x00B01A38 == 0x01` → ZZ0002_1.wav at list index 2).
    private static func applyVirtualTakeFiltering(
        regions: [TimelineRegion],
        project: PortastudioProject
    ) -> ([TimelineRegion], [SuppressedPlaybackEntry]) {
        // Build a map of stems that have more than one take number present.
        let multiTakeStems = Dictionary(grouping: regions) { region -> String? in
            guard let filename = region.sourceFilename,
                  let parsed = VirtualTakeFilename(filename) else { return nil }
            return parsed.stem
        }
        .compactMapValues { group -> Set<Int>? in
            let takeNumbers = Set(group.compactMap { region -> Int? in
                guard let filename = region.sourceFilename else { return nil }
                return VirtualTakeFilename(filename)?.takeNumber
            })
            return takeNumbers.count > 1 ? takeNumbers : nil
        }

        guard multiTakeStems.count == 1,
              let activeTakeByte = project.edlTableSummary?.track1ActiveTakeCandidate else {
            return applyCapturedTrack1ActiveTakeFilter(regions: regions, project: project)
        }

        let activeTakeNumber = Int(activeTakeByte) + 1
        guard multiTakeStems.values.contains(where: { $0.contains(activeTakeNumber) }) else {
            return applyCapturedTrack1ActiveTakeFilter(regions: regions, project: project)
        }

        var suppressed: [SuppressedPlaybackEntry] = []
        let filtered = regions.filter { region in
            guard let filename = region.sourceFilename,
                  let parsed = VirtualTakeFilename(filename),
                  multiTakeStems.keys.contains(parsed.stem) else {
                return true
            }

            if parsed.takeNumber == activeTakeNumber {
                return true
            } else {
                suppressed.append(SuppressedPlaybackEntry(filename: filename, reason: .track1ActiveVirtualTake))
                return false
            }
        }
        return (filtered, suppressed)
    }

    /// EDL file-list-selector pattern: active-take byte indexes into the EDL file list
    /// when the same-stem pattern does not apply.
    /// Evidence: Correlated (SONG_0084).
    private static func applyCapturedTrack1ActiveTakeFilter(
        regions: [TimelineRegion],
        project: PortastudioProject
    ) -> ([TimelineRegion], [SuppressedPlaybackEntry]) {
        guard let summary = project.edlTableSummary,
              summary.track1ActiveTakeCandidate > 0 else {
            return (regions, [])
        }

        let activeTakeIndex = Int(summary.track1ActiveTakeCandidate) + 1
        let fileListEntries = summary.fileListEntries
        guard fileListEntries.indices.contains(activeTakeIndex) else {
            return (regions, [])
        }

        let activeFilename = fileListEntries[activeTakeIndex].filename
        let selected = regions.filter {
            $0.sourceFilename?.localizedCaseInsensitiveCompare(activeFilename) == .orderedSame
        }

        guard !selected.isEmpty else {
            return (regions, [])
        }

        let suppressed = regions
            .filter { $0.sourceFilename?.localizedCaseInsensitiveCompare(activeFilename) != .orderedSame }
            .compactMap { region -> SuppressedPlaybackEntry? in
                guard let filename = region.sourceFilename else { return nil }
                return SuppressedPlaybackEntry(filename: filename, reason: .track1ActiveVirtualTake)
            }
        return (selected, suppressed)
    }

    // MARK: - Mute suppression

    /// Suppresses regions whose EDL position index maps to a muted track.
    ///
    /// Evidence for EDL-position-to-track mapping: Confirmed.
    private static func applyMuteSuppression(
        regions: [TimelineRegion],
        project: PortastudioProject
    ) -> ([TimelineRegion], [SuppressedPlaybackEntry]) {
        var suppressed: [SuppressedPlaybackEntry] = []
        var filtered: [TimelineRegion] = []

        for (index, region) in regions.enumerated() {
            if let reason = muteReasonForEDLPosition(index, project: project) {
                if let filename = region.sourceFilename {
                    suppressed.append(SuppressedPlaybackEntry(filename: filename, reason: reason))
                }
            } else {
                filtered.append(region)
            }
        }

        return (filtered, suppressed)
    }

    private static func muteReasonForEDLPosition(
        _ position: Int,
        project: PortastudioProject
    ) -> PlaybackSuppressionReason? {
        guard project.tracks.indices.contains(position) else { return nil }

        let track = project.tracks[position]

        // If this track has an assigned candidateWAV its region is no longer in
        // unassignedAudioRegions; the engine handles mute via the direct assignment path.
        // Applying positional mute suppression here would incorrectly silence a different
        // unassigned WAV that happens to land at this index after the assigned ones are removed.
        guard track.candidateWAV == nil else { return nil }

        guard let mute = track.mixerSetting?.mute, mute.primaryByte != 0 else { return nil }

        if position == 0 { return .track1Mute }
        if position == 1 { return .track2Mute }
        return .trackMute
    }

    // MARK: - Virtual take filename helper

    private struct VirtualTakeFilename {
        let stem: String
        let takeNumber: Int

        init?(_ filename: String) {
            let pattern = #"^(ZZ\d{4})_(\d)\.wav$"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return nil
            }

            let nsRange = NSRange(filename.startIndex..<filename.endIndex, in: filename)
            guard let match = regex.firstMatch(in: filename, range: nsRange),
                  match.numberOfRanges == 3,
                  let stemRange = Range(match.range(at: 1), in: filename),
                  let takeRange = Range(match.range(at: 2), in: filename),
                  let takeNumber = Int(filename[takeRange]) else {
                return nil
            }

            stem = String(filename[stemRange]).uppercased()
            self.takeNumber = takeNumber
        }
    }
}
