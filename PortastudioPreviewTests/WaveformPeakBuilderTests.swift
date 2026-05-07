//
//  WaveformPeakBuilderTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
import AVFoundation
@testable import PortastudioPreview

struct WaveformPeakBuilderTests {

    // MARK: - Helpers

    /// Creates a PCM WAV file at `url` with a synthetic sine wave.
    private func makeSyntheticWAV(url: URL, frameCount: AVAudioFrameCount, silent: Bool) throws {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 1,
            interleaved: false
        )!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        if !silent, let floatData = buffer.floatChannelData {
            for i in 0..<Int(frameCount) {
                floatData[0][i] = sin(Float(i) * 0.01) * 0.5
            }
        }

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }

    // MARK: - Silence

    @Test func silentWAVYieldsZeroPeaks() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: url) }

        try makeSyntheticWAV(url: url, frameCount: 4800, silent: true)

        let summary = try await WaveformPeakBuilder.buildPeaks(url: url, maxBuckets: 10)
        #expect(summary.peaks.allSatisfy { $0.minAmplitude == 0 && $0.maxAmplitude == 0 })
        #expect(!summary.peaks.isEmpty)
    }

    // MARK: - Non-Silent

    @Test func nonSilentWAVYieldsNonZeroPeaks() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: url) }

        try makeSyntheticWAV(url: url, frameCount: 48000, silent: false)

        let summary = try await WaveformPeakBuilder.buildPeaks(url: url, maxBuckets: 20)
        #expect(summary.peaks.contains { $0.maxAmplitude > 0 })
    }

    // MARK: - Bucket Count

    @Test func bucketCountCappedAtMaxBuckets() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: url) }

        try makeSyntheticWAV(url: url, frameCount: 96000, silent: false)

        let summary = try await WaveformPeakBuilder.buildPeaks(url: url, maxBuckets: 50)
        // Peak count is at most maxBuckets + 1 (flush of final partial bucket).
        #expect(summary.peaks.count <= 51)
        #expect(summary.peaks.count >= 1)
    }

    @Test func singleFrameWAVProducesAtLeastOnePeak() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: url) }

        try makeSyntheticWAV(url: url, frameCount: 1, silent: false)

        let summary = try await WaveformPeakBuilder.buildPeaks(url: url, maxBuckets: 10)
        #expect(summary.peaks.count >= 1)
    }

    // MARK: - Unreadable File

    @Test func unreadableFileThrowsError() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".wav")
        // File does not exist.
        do {
            _ = try await WaveformPeakBuilder.buildPeaks(url: url, maxBuckets: 10)
            Issue.record("Expected error not thrown")
        } catch let error as WaveformPeakBuilderError {
            if case .fileUnreadable = error {
                // Expected
            } else {
                Issue.record("Unexpected error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - Read-Only

    @Test func peakGenerationDoesNotWriteToSourceFolder() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let wavURL = tmpDir.appendingPathComponent("test.wav")
        try makeSyntheticWAV(url: wavURL, frameCount: 4800, silent: false)

        let beforeContents = try FileManager.default.contentsOfDirectory(
            at: tmpDir, includingPropertiesForKeys: nil
        ).map { $0.lastPathComponent }.sorted()

        _ = try await WaveformPeakBuilder.buildPeaks(url: wavURL, maxBuckets: 10)

        let afterContents = try FileManager.default.contentsOfDirectory(
            at: tmpDir, includingPropertiesForKeys: nil
        ).map { $0.lastPathComponent }.sorted()

        #expect(beforeContents == afterContents, "Peak generation must not write into the source folder")
    }

    // MARK: - Metadata

    @Test func summaryCarriesCorrectMetadata() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: url) }

        try makeSyntheticWAV(url: url, frameCount: 4800, silent: false)

        let summary = try await WaveformPeakBuilder.buildPeaks(url: url, maxBuckets: 10)
        #expect(summary.sourceURL == url)
        #expect(summary.sampleCount == 4800)
        #expect(summary.channelCount == 1)
        #expect(summary.sampleRate == 48000)
    }
}
