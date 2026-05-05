//
//  StereoPreviewEngine.swift
//  PortastudioPreview
//

import AVFoundation
import Foundation

final class StereoPreviewEngine {
    private let engine = AVAudioEngine()
    private var playerNodes: [AVAudioPlayerNode] = []

    var isRunning: Bool {
        engine.isRunning
    }

    func startPreview(for project: PortastudioProject) throws {
        stop()

        let playableTracks = project.tracks.filter { track in
            track.candidateWAV != nil && !Self.isMuted(track)
        }

        guard !playableTracks.isEmpty else {
            throw StereoPreviewEngineError.noPlayableTracks
        }

        for track in playableTracks {
            guard let wavURL = track.candidateWAV?.url else {
                continue
            }

            let file = try AVAudioFile(forReading: wavURL)
            let playerNode = AVAudioPlayerNode()
            playerNode.volume = Self.approximateVolume(for: track)
            playerNode.pan = Self.approximatePan(for: track)

            engine.attach(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: file.processingFormat)
            playerNode.scheduleFile(file, at: nil)
            playerNodes.append(playerNode)
        }

        try engine.start()
        playerNodes.forEach { $0.play() }
    }

    func stop() {
        for playerNode in playerNodes {
            playerNode.stop()
            engine.detach(playerNode)
        }

        playerNodes.removeAll()
        engine.stop()
    }

    static func hasPlayableTracks(_ project: PortastudioProject) -> Bool {
        project.tracks.contains { $0.candidateWAV != nil && !isMuted($0) }
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

        let centered = (Float(rawPan) - Float(0x40)) / Float(0x40)
        return min(max(centered, -1.0), 1.0)
    }
}

enum StereoPreviewEngineError: Error, LocalizedError {
    case noPlayableTracks

    var errorDescription: String? {
        switch self {
        case .noPlayableTracks:
            return "No playable candidate WAV tracks are available."
        }
    }
}
