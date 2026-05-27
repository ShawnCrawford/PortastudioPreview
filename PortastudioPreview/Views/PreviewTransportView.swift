//
//  PreviewTransportView.swift
//  PortastudioPreview
//

import SwiftUI

struct PreviewTransportView: View {
    let project: PortastudioProject
    let playbackController: PreviewPlaybackController

    private var canPlay: Bool {
        playbackController.canPlay(project)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    if playbackController.isPlaying {
                        playbackController.pause()
                    } else {
                        playbackController.startPreview(for: project)
                    }
                } label: {
                    Label(
                        playbackController.isPlaying ? "Pause" : "Play",
                        systemImage: playbackController.isPlaying ? "pause.fill" : "play.fill"
                    )
                }
                .disabled(!canPlay)
                .accessibilityLabel(
                    playbackController.isPlaying ? "Pause approximate stereo preview" : "Play approximate stereo preview"
                )

                Button {
                    playbackController.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(!playbackController.canStop)
                .accessibilityLabel("Stop playback")
            }

            if !canPlay {
                Label("No playable WAV regions found for this song.", systemImage: "waveform.slash")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else if let playbackError = playbackController.playbackError {
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
            playbackController.stop()
        }
    }
}
