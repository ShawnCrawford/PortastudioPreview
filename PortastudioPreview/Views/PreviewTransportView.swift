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

    var body: some View {
        HStack {
            Button(action: startPreview) {
                Label(isPlaying ? "Playing" : "Play", systemImage: "play.fill")
            }
            .disabled(isPlaying || !StereoPreviewEngine.hasPlayableTracks(project))

            Button(action: stopPreview) {
                Label("Stop", systemImage: "stop.fill")
            }
            .disabled(!isPlaying)

            VStack(alignment: .leading, spacing: 2) {
                Text("Approximate stereo preview")
                    .foregroundStyle(.secondary)

                if let playbackError {
                    Text(playbackError)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                } else {
                    Text("WAV regions are unassigned until track mapping is correlated.")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
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
