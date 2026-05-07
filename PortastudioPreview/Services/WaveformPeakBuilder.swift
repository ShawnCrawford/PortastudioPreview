//
//  WaveformPeakBuilder.swift
//  PortastudioPreview
//

import AVFoundation
import Foundation

/// Read-only waveform peak generation from WAV files.
///
/// Reads audio data using AVFoundation in memory-bounded chunks.
/// No sidecar files are created; peak data is purely derived app state.
enum WaveformPeakBuilder {

    private static let chunkFrameCount: AVAudioFrameCount = 8_192

    /// Generates a `WaveformPeakSummary` from the WAV at `url`.
    ///
    /// - Parameters:
    ///   - url: The WAV file to read. Only read access is used.
    ///   - maxBuckets: Maximum number of peak buckets in the output.
    ///     Actual count may be less for very short files.
    /// - Returns: A `WaveformPeakSummary` with bucketed amplitude values.
    /// - Throws: `WaveformPeakBuilderError` if the file cannot be opened or decoded.
    static func buildPeaks(url: URL, maxBuckets: Int) async throws -> WaveformPeakSummary {
        let clampedMax = max(maxBuckets, 1)

        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            throw WaveformPeakBuilderError.fileUnreadable(error.localizedDescription)
        }

        let format = audioFile.processingFormat
        let totalFrames = audioFile.length
        let channelCount = Int(format.channelCount)
        let sampleRate = format.sampleRate

        guard totalFrames > 0, channelCount > 0 else {
            return WaveformPeakSummary(
                sourceURL: url,
                sampleCount: 0,
                channelCount: channelCount,
                sampleRate: sampleRate,
                peaks: []
            )
        }

        let framesPerBucket = max(Int(totalFrames) / clampedMax, 1)

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: min(chunkFrameCount, AVAudioFrameCount(totalFrames))
        ) else {
            throw WaveformPeakBuilderError.bufferAllocationFailed
        }

        var peaks: [WaveformPeak] = []
        var framesRead = 0
        var bucketMin: Float = 0
        var bucketMax: Float = 0
        var bucketFrameCount = 0

        while framesRead < Int(totalFrames) {
            let framesToRead = min(Int(chunkFrameCount), Int(totalFrames) - framesRead)
            buffer.frameLength = 0

            do {
                try audioFile.read(into: buffer, frameCount: AVAudioFrameCount(framesToRead))
            } catch {
                break
            }

            let actualFrames = Int(buffer.frameLength)
            guard actualFrames > 0 else { break }

            if let floatData = buffer.floatChannelData {
                for frame in 0..<actualFrames {
                    // Average all channels for mono peak extraction.
                    var sample: Float = 0
                    for ch in 0..<channelCount {
                        sample += floatData[ch][frame]
                    }
                    sample /= Float(channelCount)

                    bucketMin = min(bucketMin, sample)
                    bucketMax = max(bucketMax, sample)
                    bucketFrameCount += 1

                    if bucketFrameCount >= framesPerBucket {
                        peaks.append(WaveformPeak(minAmplitude: bucketMin, maxAmplitude: bucketMax))
                        bucketMin = 0
                        bucketMax = 0
                        bucketFrameCount = 0
                    }
                }
            }

            framesRead += actualFrames
        }

        // Flush any remaining frames in the last bucket.
        if bucketFrameCount > 0 {
            peaks.append(WaveformPeak(minAmplitude: bucketMin, maxAmplitude: bucketMax))
        }

        return WaveformPeakSummary(
            sourceURL: url,
            sampleCount: Int(totalFrames),
            channelCount: channelCount,
            sampleRate: sampleRate,
            peaks: peaks
        )
    }
}

enum WaveformPeakBuilderError: Error, LocalizedError {
    case fileUnreadable(String)
    case bufferAllocationFailed

    var errorDescription: String? {
        switch self {
        case .fileUnreadable(let message):
            return "Cannot read audio file: \(message)"
        case .bufferAllocationFailed:
            return "Failed to allocate audio buffer."
        }
    }
}
