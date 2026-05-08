//
//  PreviewPlaybackController.swift
//  PortastudioPreview
//

import Foundation
import Observation

protocol PreviewPlaybackEngineProtocol {
    func startPreview(
        for project: PortastudioProject,
        trackVolumeOverrides: [Int: Double],
        trackPanOverrides: [Int: Double],
        trackMuteOverrides: [Int: Bool],
        selectedVirtualTrackOptionIDs: [Int: VirtualTrackOption.ID],
        onTrackLevelChanged: @escaping @Sendable (Int, Double) -> Void,
        onOutputLevelChanged: @escaping @Sendable (StereoMeterLevels) -> Void,
        onPlaybackCompleted: @escaping () -> Void
    ) throws
    func stop()
    func updateTrackVolume(trackNumber: Int, levelPosition: Double)
    func updateTrackPan(trackNumber: Int, panPosition: Double)
    func updateTrackMute(trackNumber: Int, isMuted: Bool)
}

struct StereoMeterLevels: Equatable, Sendable {
    var left: Double
    var right: Double

    static let silence = StereoMeterLevels(left: 0, right: 0)

    init(left: Double, right: Double) {
        self.left = min(max(left, 0), 1)
        self.right = min(max(right, 0), 1)
    }
}

/// Shared transport model for approximate stereo preview playback.
///
/// Owns `StereoPreviewEngine` and provides `isPlaying` and `elapsedSeconds`
/// for workspace transport display.
/// Create one instance per selected-song workspace lifetime.
@Observable
@MainActor
final class PreviewPlaybackController {

    private let engine: any PreviewPlaybackEngineProtocol
    private(set) var isPlaying = false
    private(set) var elapsedSeconds: Double = 0
    private(set) var playbackError: String?
    private(set) var trackMeterLevels: [Int: Double] = [:]
    private(set) var outputMeterLevels: StereoMeterLevels = .silence
    private var trackVolumeOverrides: [Int: Double] = [:]
    private var trackPanOverrides: [Int: Double] = [:]
    private var trackMuteOverrides: [Int: Bool] = [:]
    private var elapsedTask: Task<Void, Never>?

    init() {
        self.engine = StereoPreviewEngine()
    }

    init(engine: any PreviewPlaybackEngineProtocol) {
        self.engine = engine
    }

    func canPlay(
        _ project: PortastudioProject,
        selectedVirtualTrackOptionIDs: [Int: VirtualTrackOption.ID] = [:]
    ) -> Bool {
        StereoPreviewEngine.hasPlayableTracks(
            project,
            selectedVirtualTrackOptionIDs: selectedVirtualTrackOptionIDs
        )
    }

    func startPreview(
        for project: PortastudioProject,
        trackVolumeOverrides: [Int: Double] = [:],
        trackPanOverrides: [Int: Double] = [:],
        trackMuteOverrides: [Int: Bool] = [:],
        selectedVirtualTrackOptionIDs: [Int: VirtualTrackOption.ID] = [:]
    ) {
        stop()
        self.trackVolumeOverrides = trackVolumeOverrides
        self.trackPanOverrides = trackPanOverrides
        self.trackMuteOverrides = trackMuteOverrides
        do {
            try engine.startPreview(
                for: project,
                trackVolumeOverrides: trackVolumeOverrides,
                trackPanOverrides: trackPanOverrides,
                trackMuteOverrides: trackMuteOverrides,
                selectedVirtualTrackOptionIDs: selectedVirtualTrackOptionIDs,
                onTrackLevelChanged: { [weak self] trackNumber, level in
                    Task { @MainActor [weak self] in
                        let channelTrackNumber = MixerChannelLayout.leadingTrackNumber(for: trackNumber) ?? trackNumber
                        self?.trackMeterLevels[channelTrackNumber] = level
                    }
                },
                onOutputLevelChanged: { [weak self] levels in
                    Task { @MainActor [weak self] in
                        self?.outputMeterLevels = levels
                    }
                }
            ) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handlePlaybackCompleted()
                }
            }
            isPlaying = true
            playbackError = nil
            startElapsedTimer()
        } catch {
            isPlaying = false
            playbackError = error.localizedDescription
        }
    }

    func stop() {
        elapsedTask?.cancel()
        elapsedTask = nil
        engine.stop()
        isPlaying = false
        elapsedSeconds = 0
        playbackError = nil
        trackMeterLevels = [:]
        outputMeterLevels = .silence
        trackVolumeOverrides = [:]
        trackPanOverrides = [:]
        trackMuteOverrides = [:]
    }

    func setTrackVolume(_ levelPosition: Double, for trackNumber: Int) {
        let channelTrackNumber = MixerChannelLayout.leadingTrackNumber(for: trackNumber) ?? trackNumber
        trackVolumeOverrides[channelTrackNumber] = levelPosition

        guard isPlaying else {
            return
        }

        engine.updateTrackVolume(trackNumber: channelTrackNumber, levelPosition: levelPosition)
    }

    func setTrackPan(_ panPosition: Double, for trackNumber: Int) {
        let channelTrackNumber = MixerChannelLayout.leadingTrackNumber(for: trackNumber) ?? trackNumber
        trackPanOverrides[channelTrackNumber] = panPosition

        guard isPlaying else {
            return
        }

        engine.updateTrackPan(trackNumber: channelTrackNumber, panPosition: panPosition)
    }

    func setTrackMute(_ isMuted: Bool, for trackNumber: Int) {
        let channelTrackNumber = MixerChannelLayout.leadingTrackNumber(for: trackNumber) ?? trackNumber
        trackMuteOverrides[channelTrackNumber] = isMuted

        guard isPlaying else {
            return
        }

        engine.updateTrackMute(trackNumber: channelTrackNumber, isMuted: isMuted)
    }

    func trackMeterLevel(for trackNumber: Int) -> Double {
        let channelTrackNumber = MixerChannelLayout.leadingTrackNumber(for: trackNumber) ?? trackNumber
        return trackMeterLevels[channelTrackNumber] ?? 0
    }

    // MARK: - Private

    private func handlePlaybackCompleted() {
        elapsedTask?.cancel()
        elapsedTask = nil
        isPlaying = false
        elapsedSeconds = 0
        trackMeterLevels = [:]
        outputMeterLevels = .silence
    }

    private func startElapsedTimer() {
        elapsedTask?.cancel()
        let startTime = Date()
        elapsedTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { break }
                self.elapsedSeconds = Date().timeIntervalSince(startTime)
            }
        }
    }
}

extension StereoPreviewEngine: PreviewPlaybackEngineProtocol {}
