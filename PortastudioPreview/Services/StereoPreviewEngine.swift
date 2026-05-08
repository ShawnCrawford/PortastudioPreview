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

    static func playableRegionSourceFilenames(for project: PortastudioProject) -> [String] {
        playableRegions(for: project).map { $0.url.lastPathComponent }
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

    private static func playableRegions(for project: PortastudioProject) -> [PlayableRegion] {
        var result: [PlayableRegion] = []

        // Assigned tracks with known timelines use their mixer settings directly.
        // This path correctly applies mute, approximate volume, and pan without relying
        // on positional EDL-index inference.
        for track in project.tracks {
            guard let sourceURL = track.candidateWAV?.url,
                  track.timeline != nil,
                  let firstRegion = track.timeline?.regions.first,
                  !isMuted(track) else {
                continue
            }
            result.append(PlayableRegion(
                key: "track-\(track.trackNumber)",
                url: sourceURL,
                startSample: max(firstRegion.startSample, 0),
                volume: approximateVolume(for: track),
                pan: approximatePan(for: track)
            ))
        }

        // Unassigned regions go through the planner for virtual-take filtering and
        // any evidence-backed mute suppression that still applies.
        if !project.unassignedAudioRegions.isEmpty {
            let plan = PreviewPlaybackPlanner.plan(for: project)
            result.append(contentsOf: plan.playableRegions.map { scheduled in
                PlayableRegion(
                    key: scheduled.filename,
                    url: scheduled.url,
                    startSample: scheduled.startSample,
                    volume: scheduled.volume,
                    pan: scheduled.pan
                )
            })
        }

        return result
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
