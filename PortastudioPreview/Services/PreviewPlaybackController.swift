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
        selectedVirtualTrackOptionIDs: [Int: VirtualTrackOption.ID],
        onTrackLevelChanged: @escaping @Sendable (Int, Double) -> Void,
        onPlaybackCompleted: @escaping () -> Void
    ) throws
    func stop()
    func updateTrackVolume(trackNumber: Int, levelPosition: Double)
    func updateTrackPan(trackNumber: Int, panPosition: Double)
}

/// Shared transport model for approximate stereo preview playback.
///
/// Owns `StereoPreviewEngine` and provides `isPlaying` and `elapsedSeconds`
/// for playhead display in `TimelineVisualizationView`.
/// Create one instance per selected-song workspace lifetime.
@Observable
@MainActor
final class PreviewPlaybackController {

    private let engine: any PreviewPlaybackEngineProtocol
    private(set) var isPlaying = false
    private(set) var elapsedSeconds: Double = 0
    private(set) var playbackError: String?
    private(set) var trackMeterLevels: [Int: Double] = [:]
    private var trackVolumeOverrides: [Int: Double] = [:]
    private var trackPanOverrides: [Int: Double] = [:]
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
        selectedVirtualTrackOptionIDs: [Int: VirtualTrackOption.ID] = [:]
    ) {
        stop()
        self.trackVolumeOverrides = trackVolumeOverrides
        self.trackPanOverrides = trackPanOverrides
        do {
            try engine.startPreview(
                for: project,
                trackVolumeOverrides: trackVolumeOverrides,
                trackPanOverrides: trackPanOverrides,
                selectedVirtualTrackOptionIDs: selectedVirtualTrackOptionIDs,
                onTrackLevelChanged: { [weak self] trackNumber, level in
                    Task { @MainActor [weak self] in
                        self?.trackMeterLevels[trackNumber] = level
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
        trackVolumeOverrides = [:]
        trackPanOverrides = [:]
    }

    func setTrackVolume(_ levelPosition: Double, for trackNumber: Int) {
        trackVolumeOverrides[trackNumber] = levelPosition

        guard isPlaying else {
            return
        }

        engine.updateTrackVolume(trackNumber: trackNumber, levelPosition: levelPosition)
    }

    func setTrackPan(_ panPosition: Double, for trackNumber: Int) {
        trackPanOverrides[trackNumber] = panPosition

        guard isPlaying else {
            return
        }

        engine.updateTrackPan(trackNumber: trackNumber, panPosition: panPosition)
    }

    func trackMeterLevel(for trackNumber: Int) -> Double {
        trackMeterLevels[trackNumber] ?? 0
    }

    // MARK: - Private

    private func handlePlaybackCompleted() {
        elapsedTask?.cancel()
        elapsedTask = nil
        isPlaying = false
        elapsedSeconds = 0
        trackMeterLevels = [:]
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
