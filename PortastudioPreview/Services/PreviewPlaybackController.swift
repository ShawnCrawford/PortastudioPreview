//
//  PreviewPlaybackController.swift
//  PortastudioPreview
//

import Foundation
import Observation

/// Shared transport model for approximate stereo preview playback.
///
/// Owns `StereoPreviewEngine` and provides `isPlaying` and `elapsedSeconds`
/// for playhead display in `TimelineVisualizationView`.
/// Create one instance per selected-song workspace lifetime.
@Observable
@MainActor
final class PreviewPlaybackController {

    private let engine = StereoPreviewEngine()
    private(set) var isPlaying = false
    private(set) var elapsedSeconds: Double = 0
    private(set) var playbackError: String?
    private var elapsedTask: Task<Void, Never>?

    func canPlay(_ project: PortastudioProject) -> Bool {
        StereoPreviewEngine.hasPlayableTracks(project)
    }

    func startPreview(for project: PortastudioProject) {
        stop()
        do {
            try engine.startPreview(for: project) { [weak self] in
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
    }

    // MARK: - Private

    private func handlePlaybackCompleted() {
        elapsedTask?.cancel()
        elapsedTask = nil
        isPlaying = false
        elapsedSeconds = 0
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
