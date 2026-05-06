//
//  StereoPreviewEngine.swift
//  PortastudioPreview
//

import AVFoundation
import Foundation

final class StereoPreviewEngine {
    private let engine = AVAudioEngine()
    private var playerNodes: [AVAudioPlayerNode] = []
    private let completionCoordinator = PlaybackCompletionCoordinator()
    private var activePlaybackID: UUID?
    private static let previewSampleRate: Double = 48_000

    private struct PlayableRegion {
        let key: String
        let url: URL
        let startSample: Int
        let volume: Float
        let pan: Float
    }

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

    var isRunning: Bool {
        engine.isRunning
    }

    func startPreview(for project: PortastudioProject, onPlaybackCompleted: @escaping () -> Void) throws {
        stop()

        let playableRegions = Self.playableRegions(for: project)

        guard !playableRegions.isEmpty else {
            throw StereoPreviewEngineError.noPlayableTracks
        }

        let playbackID = UUID()
        activePlaybackID = playbackID
        completionCoordinator.configure(
            playbackID: playbackID,
            expectedCompletions: playableRegions.count,
            onPlaybackCompleted: onPlaybackCompleted
        )

        for region in playableRegions {
            let file = try AVAudioFile(forReading: region.url)
            let playerNode = AVAudioPlayerNode()
            playerNode.volume = region.volume
            playerNode.pan = region.pan

            engine.attach(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: file.processingFormat)

            if let startTime = Self.absoluteStartTime(startSample: region.startSample, sampleRate: file.processingFormat.sampleRate) {
                playerNode.scheduleFile(file, at: startTime) { [weak self] in
                    self?.handlePlaybackNodeCompleted(playbackID: playbackID)
                }
            } else {
                playerNode.scheduleFile(file, at: nil) { [weak self] in
                    self?.handlePlaybackNodeCompleted(playbackID: playbackID)
                }
            }

            playerNodes.append(playerNode)
        }

        do {
            try engine.start()
        } catch {
            activePlaybackID = nil
            completionCoordinator.invalidate(playbackID: playbackID)
            throw error
        }

        playerNodes.forEach { $0.play() }
    }

    func stop() {
        if let activePlaybackID {
            completionCoordinator.invalidate(playbackID: activePlaybackID)
            self.activePlaybackID = nil
        }

        for playerNode in playerNodes {
            playerNode.stop()
            engine.detach(playerNode)
        }

        playerNodes.removeAll()
        engine.stop()
    }

    static func hasPlayableTracks(_ project: PortastudioProject) -> Bool {
        !playableRegions(for: project).isEmpty
    }

    static func isMuted(_ track: TrackPreview) -> Bool {
        guard let muteByte = track.mixerSetting?.mute?.primaryByte else {
            return false
        }

        return muteByte != 0
    }

    static func approximateVolume(for track: TrackPreview) -> Float {
        guard let rawLevel = track.mixerSetting?.level.primaryByte else {
            return 1.0
        }

        guard rawLevel != 0 else {
            return 1.0
        }

        return min(max(Float(rawLevel) / Float(0x7F), 0.0), 1.5)
    }

    static func approximatePan(for track: TrackPreview) -> Float {
        guard let rawPan = track.mixerSetting?.pan.primaryByte else {
            return 0.0
        }

        let centered = (Float(rawPan) - Float(0x40)) / Float(0x3F)
        return min(max(centered, -1.0), 1.0)
    }

    static func timelineStartSamples(for tracks: [TrackPreview]) -> [Int: Int] {
        Dictionary(uniqueKeysWithValues: tracks.map { track in
            let startSample = max(track.timeline?.regions.first?.startSample ?? 0, 0)
            return (track.trackNumber, startSample)
        })
    }

    static func playableRegionSourceFilenames(for project: PortastudioProject) -> [String] {
        playableRegions(for: project).map { region in
            region.url.lastPathComponent
        }
    }

    private static func playableRegions(for project: PortastudioProject) -> [PlayableRegion] {
        let selectedUnassignedRegions = activeVirtualTakeFilteredRegions(for: project)
        let unassignedRegions = selectedUnassignedRegions.compactMap { region -> PlayableRegion? in
            guard let sourceURL = region.sourceURL else {
                return nil
            }

            return PlayableRegion(
                key: region.id,
                url: sourceURL,
                startSample: max(region.startSample, 0),
                volume: 1.0,
                pan: 0.0
            )
        }

        if !unassignedRegions.isEmpty {
            return unassignedRegions
        }

        return project.tracks.compactMap { track in
            guard let sourceURL = track.candidateWAV?.url,
                  !Self.isMuted(track) else {
                return nil
            }

            return PlayableRegion(
                key: "track-\(track.trackNumber)",
                url: sourceURL,
                startSample: max(track.timeline?.regions.first?.startSample ?? 0, 0),
                volume: Self.approximateVolume(for: track),
                pan: Self.approximatePan(for: track)
            )
        }
    }

    private static func activeVirtualTakeFilteredRegions(for project: PortastudioProject) -> [TimelineRegion] {
        let regions = project.unassignedAudioRegions
        let multiTakeStems = Dictionary(grouping: regions) { region -> String? in
            guard let sourceFilename = region.sourceFilename,
                  let parsedFilename = VirtualTakeFilename(sourceFilename) else {
                return nil
            }

            return parsedFilename.stem
        }
        .compactMapValues { groupedRegions in
            let takeNumbers = Set(groupedRegions.compactMap { region -> Int? in
                guard let sourceFilename = region.sourceFilename else {
                    return nil
                }

                return VirtualTakeFilename(sourceFilename)?.takeNumber
            })

            return takeNumbers.count > 1 ? takeNumbers : nil
        }

        guard multiTakeStems.count == 1,
              let activeTakeByte = project.edlTableSummary?.track1ActiveTakeCandidate else {
            return capturedTrack1ActiveTakeFilteredRegions(for: project, regions: regions)
        }

        let activeTakeNumber = Int(activeTakeByte) + 1
        guard multiTakeStems.values.contains(where: { $0.contains(activeTakeNumber) }) else {
            return capturedTrack1ActiveTakeFilteredRegions(for: project, regions: regions)
        }

        return regions.filter { region in
            guard let sourceFilename = region.sourceFilename,
                  let parsedFilename = VirtualTakeFilename(sourceFilename),
                  multiTakeStems.keys.contains(parsedFilename.stem) else {
                return true
            }

            return parsedFilename.takeNumber == activeTakeNumber
        }
    }

    private static func capturedTrack1ActiveTakeFilteredRegions(
        for project: PortastudioProject,
        regions: [TimelineRegion]
    ) -> [TimelineRegion] {
        guard let edlTableSummary = project.edlTableSummary,
              edlTableSummary.track1ActiveTakeCandidate > 0 else {
            return regions
        }

        let activeTakeIndex = Int(edlTableSummary.track1ActiveTakeCandidate) + 1
        let fileListEntries = edlTableSummary.fileListEntries
        guard fileListEntries.indices.contains(activeTakeIndex) else {
            return regions
        }

        let activeFilename = fileListEntries[activeTakeIndex].filename
        let selectedRegions = regions.filter { region in
            region.sourceFilename?.localizedCaseInsensitiveCompare(activeFilename) == .orderedSame
        }

        return selectedRegions.isEmpty ? regions : selectedRegions
    }

    private func handlePlaybackNodeCompleted(playbackID: UUID) {
        guard let completion = completionCoordinator.markCompletion(for: playbackID) else {
            return
        }

        if activePlaybackID == playbackID {
            activePlaybackID = nil
        }

        DispatchQueue.main.async {
            completion()
        }
    }

    private static func absoluteStartTime(startSample: Int, sampleRate: Double) -> AVAudioTime? {
        guard startSample > 0 else {
            return nil
        }

        let clampedSampleRate = sampleRate > 0 ? sampleRate : previewSampleRate
        let seconds = Double(startSample) / clampedSampleRate
        let hostDelta = AVAudioTime.hostTime(forSeconds: seconds)
        let hostNow = mach_absolute_time()

        return AVAudioTime(hostTime: hostNow + hostDelta)
    }
}

final class PlaybackCompletionCoordinator {
    private let lock = NSLock()
    private var currentPlaybackID: UUID?
    private var remainingCompletions = 0
    private var completionFired = false
    private var onPlaybackCompleted: (() -> Void)?

    func configure(playbackID: UUID, expectedCompletions: Int, onPlaybackCompleted: @escaping () -> Void) {
        lock.lock()
        defer { lock.unlock() }

        currentPlaybackID = playbackID
        remainingCompletions = max(expectedCompletions, 0)
        completionFired = false
        self.onPlaybackCompleted = onPlaybackCompleted
    }

    func invalidate(playbackID: UUID) {
        lock.lock()
        defer { lock.unlock() }

        guard currentPlaybackID == playbackID else {
            return
        }

        currentPlaybackID = nil
        remainingCompletions = 0
        completionFired = false
        onPlaybackCompleted = nil
    }

    func markCompletion(for playbackID: UUID) -> (() -> Void)? {
        lock.lock()
        defer { lock.unlock() }

        guard currentPlaybackID == playbackID,
              !completionFired,
              remainingCompletions > 0 else {
            return nil
        }

        remainingCompletions -= 1

        guard remainingCompletions == 0 else {
            return nil
        }

        completionFired = true
        let completion = onPlaybackCompleted
        onPlaybackCompleted = nil
        return completion
    }
}

enum StereoPreviewEngineError: Error, LocalizedError {
    case noPlayableTracks

    var errorDescription: String? {
        switch self {
        case .noPlayableTracks:
            return "No playable WAV regions are available."
        }
    }
}
