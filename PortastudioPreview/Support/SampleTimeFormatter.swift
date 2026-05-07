//
//  SampleTimeFormatter.swift
//  PortastudioPreview
//

import Foundation

/// Converts a raw PCM sample count to a human-readable time string.
///
/// Uses the standard project sample rate of 48,000 Hz.
/// All results are approximate; callers should prefix display text with "≈"
/// when the sample position itself is Hypothesis-level evidence.
enum SampleTimeFormatter {
    static let standardSampleRate: Double = 48_000

    /// Returns a display string for a sample count at `sampleRate`.
    ///
    /// - Returns `"0s"` for zero or negative samples.
    /// - Returns `"N.Ns"` for durations under one minute.
    /// - Returns `"Nm N.Ns"` for durations of one minute or more.
    static func displayString(samples: Int, sampleRate: Double = standardSampleRate) -> String {
        guard sampleRate > 0, samples > 0 else { return "0s" }

        let totalSeconds = Double(samples) / sampleRate
        let minutes = Int(totalSeconds) / 60
        let remainingSeconds = totalSeconds - Double(minutes * 60)

        if minutes > 0 {
            return String(format: "%dm %.1fs", minutes, remainingSeconds)
        } else {
            return String(format: "%.1fs", totalSeconds)
        }
    }

    /// Returns `"Unknown"` for `nil`; otherwise delegates to `displayString(samples:sampleRate:)`.
    static func displayString(optionalSamples: Int?, sampleRate: Double = standardSampleRate) -> String {
        guard let samples = optionalSamples else { return "Unknown" }
        return displayString(samples: samples, sampleRate: sampleRate)
    }
}
