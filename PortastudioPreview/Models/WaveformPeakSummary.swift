//
//  WaveformPeakSummary.swift
//  PortastudioPreview
//

import Foundation

/// A single amplitude bucket in a waveform peak summary.
///
/// Both values are normalised to [-1.0, 1.0].
/// `minAmplitude` ≤ 0 and `maxAmplitude` ≥ 0.
struct WaveformPeak: Sendable, Equatable {
    let minAmplitude: Float
    let maxAmplitude: Float

    static let silent = WaveformPeak(minAmplitude: 0, maxAmplitude: 0)
}

/// Bucketed peak amplitude data derived read-only from a WAV file.
///
/// Peak data is purely derived app state. No sidecar files are written
/// into source Portastudio song folders.
struct WaveformPeakSummary: Sendable, Equatable {
    let sourceURL: URL
    let sampleCount: Int
    let channelCount: Int
    let sampleRate: Double
    let peaks: [WaveformPeak]
}

/// The loading state for a waveform peak summary.
enum WaveformPeakState: Sendable, Equatable {
    case generating
    case available(WaveformPeakSummary)
    case unavailable(String)
}
