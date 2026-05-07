//
//  PreviewTransportView.swift
//  PortastudioPreview
//

import SwiftUI

struct PreviewTransportView: View {
    let project: PortastudioProject

    @State private var engine = StereoPreviewEngine()
    @State private var isPlaying = false
    @State private var playbackError: String?

    private var canPlay: Bool {
        StereoPreviewEngine.hasPlayableTracks(project)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button(action: startPreview) {
                    Label(isPlaying ? "Playing…" : "Play", systemImage: "play.fill")
                }
                .disabled(isPlaying || !canPlay)
                .accessibilityLabel(isPlaying ? "Playback in progress" : "Play approximate stereo preview")

                Button(action: stopPreview) {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(!isPlaying)
                .accessibilityLabel("Stop playback")
            }

            if !canPlay {
                Label("No playable WAV regions found for this song.", systemImage: "waveform.slash")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else if let playbackError {
                Label(playbackError, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .lineLimit(2)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Approximate stereo preview — track-to-WAV assignment is Hypothesis.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                    Text("WAV regions may not reflect the final device mix.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
        .onDisappear {
            stopPreview()
        }
    }

    private func startPreview() {
        do {
            try engine.startPreview(for: project) {
                Task { @MainActor in
                    isPlaying = false
                }
            }
            isPlaying = true
            playbackError = nil
        } catch {
            isPlaying = false
            playbackError = error.localizedDescription
        }
    }

    private func stopPreview() {
        engine.stop()
        isPlaying = false
    }
}
