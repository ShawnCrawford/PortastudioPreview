//
//  StereoPreviewEngine.swift
//  PortastudioPreview
//

import AVFoundation
import Foundation

final class StereoPreviewEngine {
    private let engine = AVAudioEngine()
    private var playerNodes: [AVAudioPlayerNode] = []
    private var playerNodesByTrackNumber: [Int: [AVAudioPlayerNode]] = [:]
    private var trackMixerNodes: [Int: AVAudioMixerNode] = [:]
    private let completionCoordinator = PlaybackCompletionCoordinator()
    private var activePlaybackID: UUID?
    private static let previewSampleRate: Double = 48_000

    private struct PlayableRegion {
        let trackNumber: Int?
        let url: URL
        let startSample: Int
        let volume: Float
        let pan: Float
    }

    var isRunning: Bool {
        engine.isRunning
    }

    func startPreview(
        for project: PortastudioProject,
        trackVolumeOverrides: [Int: Double] = [:],
        trackPanOverrides: [Int: Double] = [:],
        selectedVirtualTrackOptionIDs: [Int: VirtualTrackOption.ID] = [:],
        onTrackLevelChanged: @escaping @Sendable (Int, Double) -> Void,
        onPlaybackCompleted: @escaping () -> Void
    ) throws {
        stop()

        let playableRegions = Self.playableRegions(
            for: project,
            trackVolumeOverrides: trackVolumeOverrides,
            trackPanOverrides: trackPanOverrides,
            selectedVirtualTrackOptionIDs: selectedVirtualTrackOptionIDs
        )

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
            if let trackNumber = region.trackNumber {
                let trackMixerNode = trackMixerNode(
                    for: trackNumber,
                    format: file.processingFormat,
                    onTrackLevelChanged: onTrackLevelChanged
                )
                engine.connect(playerNode, to: trackMixerNode, format: file.processingFormat)
            } else {
                engine.connect(playerNode, to: engine.mainMixerNode, format: file.processingFormat)
            }

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
            if let trackNumber = region.trackNumber {
                playerNodesByTrackNumber[trackNumber, default: []].append(playerNode)
            }
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

        for (trackNumber, mixerNode) in trackMixerNodes {
            mixerNode.removeTap(onBus: 0)
            engine.detach(mixerNode)
            playerNodesByTrackNumber[trackNumber] = nil
        }

        playerNodes.removeAll()
        playerNodesByTrackNumber.removeAll()
        trackMixerNodes.removeAll()
        engine.stop()
    }

    func updateTrackVolume(trackNumber: Int, levelPosition: Double) {
        let gain = LevelMapper.gain(forNormalizedPosition: levelPosition)
        for playerNode in playerNodesByTrackNumber[trackNumber] ?? [] {
            playerNode.volume = gain
        }
    }

    func updateTrackPan(trackNumber: Int, panPosition: Double) {
        let pan = Float(min(max(panPosition, -1), 1))
        for playerNode in playerNodesByTrackNumber[trackNumber] ?? [] {
            playerNode.pan = pan
        }
    }

    static func hasPlayableTracks(
        _ project: PortastudioProject,
        selectedVirtualTrackOptionIDs: [Int: VirtualTrackOption.ID] = [:]
    ) -> Bool {
        !playableRegions(for: project, selectedVirtualTrackOptionIDs: selectedVirtualTrackOptionIDs).isEmpty
    }

    static func playableRegionSourceFilenames(
        for project: PortastudioProject,
        selectedVirtualTrackOptionIDs: [Int: VirtualTrackOption.ID] = [:]
    ) -> [String] {
        playableRegions(for: project, selectedVirtualTrackOptionIDs: selectedVirtualTrackOptionIDs).map { $0.url.lastPathComponent }
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

        return LevelMapper.gain(for: rawLevel)
    }

    static func approximateVolume(for track: TrackPreview, overrideLevelPosition: Double?) -> Float {
        if let overrideLevelPosition {
            return LevelMapper.gain(forNormalizedPosition: overrideLevelPosition)
        }

        return approximateVolume(for: track)
    }

    static func approximatePan(for track: TrackPreview) -> Float {
        approximatePan(for: track, overridePanPosition: nil)
    }

    static func approximatePan(for track: TrackPreview, overridePanPosition: Double?) -> Float {
        if let overridePanPosition {
            return Float(min(max(overridePanPosition, -1), 1))
        }

        guard let rawPan = track.mixerSetting?.pan.primaryByte else {
            return 0.0
        }

        return Float(PanMapper.normalizedPosition(for: rawPan))
    }

    static func timelineStartSamples(for tracks: [TrackPreview]) -> [Int: Int] {
        Dictionary(uniqueKeysWithValues: tracks.map { track in
            let startSample = max(track.timeline?.regions.first?.startSample ?? 0, 0)
            return (track.trackNumber, startSample)
        })
    }

    private static func playableRegions(
        for project: PortastudioProject,
        trackVolumeOverrides: [Int: Double] = [:],
        trackPanOverrides: [Int: Double] = [:],
        selectedVirtualTrackOptionIDs: [Int: VirtualTrackOption.ID] = [:]
    ) -> [PlayableRegion] {
        var result: [PlayableRegion] = []

        // Assigned tracks with known timelines use their mixer settings directly.
        // This path correctly applies mute, approximate volume, and pan without relying
        // on positional EDL-index inference.
        for track in project.tracks {
            let selectedOption = track.selectedVirtualTrackOption(
                selectedOptionID: selectedVirtualTrackOptionIDs[track.trackNumber]
            )
            let sourceURL = selectedOption?.wavItem.url ?? track.candidateWAV?.url
            let firstRegion = selectedOption?.timelineRegion ?? track.timeline?.regions.first
            guard let sourceURL,
                  let firstRegion,
                  !isMuted(track) else {
                continue
            }
            result.append(PlayableRegion(
                trackNumber: track.trackNumber,
                url: sourceURL,
                startSample: max(firstRegion.startSample, 0),
                volume: approximateVolume(
                    for: track,
                    overrideLevelPosition: trackVolumeOverrides[track.trackNumber]
                ),
                pan: approximatePan(
                    for: track,
                    overridePanPosition: trackPanOverrides[track.trackNumber]
                )
            ))
        }

        // Unassigned regions go through the planner for virtual-take filtering and
        // any evidence-backed mute suppression that still applies.
        if !project.unassignedAudioRegions.isEmpty {
            let plan = PreviewPlaybackPlanner.plan(for: project)
            result.append(contentsOf: plan.playableRegions.map { scheduled in
                PlayableRegion(
                    trackNumber: nil,
                    url: scheduled.url,
                    startSample: scheduled.startSample,
                    volume: scheduled.volume,
                    pan: scheduled.pan
                )
            })
        }

        return result
    }

    static func playableRegionPans(
        for project: PortastudioProject,
        trackPanOverrides: [Int: Double] = [:],
        selectedVirtualTrackOptionIDs: [Int: VirtualTrackOption.ID] = [:]
    ) -> [Float] {
        playableRegions(
            for: project,
            trackPanOverrides: trackPanOverrides,
            selectedVirtualTrackOptionIDs: selectedVirtualTrackOptionIDs
        ).map(\.pan)
    }

    private func handlePlaybackNodeCompleted(playbackID: UUID) {
        guard let completion = completionCoordinator.markCompletion(for: playbackID) else {
            return
        }

        if activePlaybackID == playbackID {
            activePlaybackID = nil
        }

        Task { @MainActor in
            completion()
        }
    }

    private func trackMixerNode(
        for trackNumber: Int,
        format: AVAudioFormat,
        onTrackLevelChanged: @escaping @Sendable (Int, Double) -> Void
    ) -> AVAudioMixerNode {
        if let existingNode = trackMixerNodes[trackNumber] {
            return existingNode
        }

        let mixerNode = AVAudioMixerNode()
        engine.attach(mixerNode)
        engine.connect(mixerNode, to: engine.mainMixerNode, format: format)
        installLevelTap(on: mixerNode, trackNumber: trackNumber, onTrackLevelChanged: onTrackLevelChanged)
        trackMixerNodes[trackNumber] = mixerNode
        return mixerNode
    }

    private func installLevelTap(
        on mixerNode: AVAudioMixerNode,
        trackNumber: Int,
        onTrackLevelChanged: @escaping @Sendable (Int, Double) -> Void
    ) {
        mixerNode.installTap(onBus: 0, bufferSize: 1_024, format: nil) { buffer, _ in
            onTrackLevelChanged(trackNumber, Self.normalizedPeakLevel(for: buffer))
        }
    }

    private static func normalizedPeakLevel(for buffer: AVAudioPCMBuffer) -> Double {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else {
            return 0
        }

        switch buffer.format.commonFormat {
        case .pcmFormatFloat32:
            guard let channels = buffer.floatChannelData else {
                return 0
            }
            return normalizedPeakLevel(
                frameLength: frameLength,
                channelCount: Int(buffer.format.channelCount),
                sampleAt: { channel, frame in
                    Double(abs(channels[channel][frame]))
                }
            )
        case .pcmFormatInt16:
            guard let channels = buffer.int16ChannelData else {
                return 0
            }
            return normalizedPeakLevel(
                frameLength: frameLength,
                channelCount: Int(buffer.format.channelCount),
                sampleAt: { channel, frame in
                    Double(abs(Int32(channels[channel][frame]))) / Double(Int16.max)
                }
            )
        case .pcmFormatInt32:
            guard let channels = buffer.int32ChannelData else {
                return 0
            }
            return normalizedPeakLevel(
                frameLength: frameLength,
                channelCount: Int(buffer.format.channelCount),
                sampleAt: { channel, frame in
                    Double(abs(channels[channel][frame])) / Double(Int32.max)
                }
            )
        default:
            return 0
        }
    }

    private static func normalizedPeakLevel(
        frameLength: Int,
        channelCount: Int,
        sampleAt: (_ channel: Int, _ frame: Int) -> Double
    ) -> Double {
        guard channelCount > 0 else {
            return 0
        }

        var peakLevel = 0.0
        for channel in 0..<channelCount {
            for frame in 0..<frameLength {
                peakLevel = max(peakLevel, sampleAt(channel, frame))
            }
        }

        return min(max(peakLevel, 0), 1)
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
