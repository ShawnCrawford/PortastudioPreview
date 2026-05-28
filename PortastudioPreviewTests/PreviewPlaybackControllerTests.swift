//
//  PreviewPlaybackControllerTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

@MainActor
struct PreviewPlaybackControllerTests {

    // MARK: - Initial state

    @Test func initialStateIsIdle() {
        let controller = PreviewPlaybackController()

        #expect(controller.playbackState == .idle)
        #expect(!controller.isPlaying)
        #expect(!controller.isPaused)
        #expect(!controller.canStop)
        #expect(controller.elapsedSeconds == 0)
        #expect(controller.playbackError == nil)
        #expect(controller.trackMeterLevel(for: 1) == 0)
        #expect(controller.outputMeterLevels == .silence)
    }

    // MARK: - Error visibility on failure

    @Test func startPreviewSetsPlaybackErrorWhenNoPlayableTracks() async {
        let controller = PreviewPlaybackController()
        let emptyProject = PortastudioProject(
            folderURL: URL(fileURLWithPath: "/tmp/SONG_test"),
            validationIssues: [],
            wavInventory: [],
            unassignedAudioRegions: [],
            tracks: [],
            edlTableSummary: nil
        )

        controller.startPreview(for: emptyProject)

        #expect(!controller.isPlaying)
        #expect(controller.playbackError != nil)
    }

    @Test func startPreviewClearsStaleErrorOnAttempt() async {
        let controller = PreviewPlaybackController()
        let emptyProject = PortastudioProject(
            folderURL: URL(fileURLWithPath: "/tmp/SONG_test"),
            validationIssues: [],
            wavInventory: [],
            unassignedAudioRegions: [],
            tracks: [],
            edlTableSummary: nil
        )

        // First attempt fails — sets error.
        controller.startPreview(for: emptyProject)
        #expect(controller.playbackError != nil)

        // Second attempt on the same project calls stop() first, then tries again.
        // Error from the second failure replaces the first; it should still be non-nil.
        controller.startPreview(for: emptyProject)
        #expect(controller.playbackError != nil)
    }

    // MARK: - Stop clears error

    @Test func stopClearsPlaybackError() {
        let controller = PreviewPlaybackController()
        let emptyProject = PortastudioProject(
            folderURL: URL(fileURLWithPath: "/tmp/SONG_test"),
            validationIssues: [],
            wavInventory: [],
            unassignedAudioRegions: [],
            tracks: [],
            edlTableSummary: nil
        )

        controller.startPreview(for: emptyProject)
        #expect(controller.playbackError != nil)

        controller.stop()

        #expect(controller.playbackError == nil)
        #expect(!controller.isPlaying)
        #expect(controller.elapsedSeconds == 0)
        #expect(controller.trackMeterLevels.isEmpty)
    }

    @Test func stopOnIdleControllerKeepsErrorNil() {
        let controller = PreviewPlaybackController()

        controller.stop()

        #expect(controller.playbackError == nil)
    }

    // MARK: - canPlay

    @Test func canPlayReturnsFalseForEmptyProject() {
        let controller = PreviewPlaybackController()
        let emptyProject = PortastudioProject(
            folderURL: URL(fileURLWithPath: "/tmp/SONG_test"),
            validationIssues: [],
            wavInventory: [],
            unassignedAudioRegions: [],
            tracks: [],
            edlTableSummary: nil
        )

        #expect(!controller.canPlay(emptyProject))
    }

    @Test func startPreviewForwardsTrackPanOverrides() {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.startPreview(
            for: sampleProject,
            trackVolumeOverrides: [1: 0.75],
            trackPanOverrides: [1: -0.25],
            trackMuteOverrides: [1: true],
            selectedVirtualTrackOptionIDs: [1: "track1#zz0000_2.wav"]
        )

        #expect(engine.lastStartTrackVolumeOverrides?[1] == 0.75)
        #expect(engine.lastStartTrackPanOverrides?[1] == -0.25)
        #expect(engine.lastStartTrackMuteOverrides?[1] == true)
        #expect(engine.lastStartSelectedVirtualTrackOptionIDs?[1] == "track1#zz0000_2.wav")
        #expect(engine.lastStartStartingAt == 0)
        #expect(controller.playbackState == .playing)
    }

    @Test func reloadPreviewPreservingPositionForwardsCurrentElapsedTime() async throws {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.startPreview(for: sampleProject)
        for _ in 0..<10 where controller.elapsedSeconds == 0 {
            try await Task.sleep(for: .milliseconds(50))
        }
        let elapsedBeforeReload = controller.elapsedSeconds

        controller.reloadPreviewPreservingPosition(
            for: sampleProject,
            trackVolumeOverrides: [1: 0.5],
            trackPanOverrides: [1: 0.25],
            trackMuteOverrides: [1: false],
            selectedVirtualTrackOptionIDs: [1: "track1#zz0000_2.wav"]
        )

        #expect(elapsedBeforeReload > 0)
        #expect(engine.lastStartStartingAt ?? 0 >= elapsedBeforeReload)
        #expect(controller.elapsedSeconds >= elapsedBeforeReload)
        #expect(engine.lastStartTrackVolumeOverrides?[1] == 0.5)
        #expect(engine.lastStartTrackPanOverrides?[1] == 0.25)
        #expect(engine.lastStartTrackMuteOverrides?[1] == false)
        #expect(engine.lastStartSelectedVirtualTrackOptionIDs?[1] == "track1#zz0000_2.wav")
        controller.stop()
    }

    @Test func pausePreservesElapsedTimeAndUpdatesState() async throws {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.startPreview(for: sampleProject)
        for _ in 0..<10 where controller.elapsedSeconds == 0 {
            try await Task.sleep(for: .milliseconds(50))
        }

        controller.pause()
        let pausedElapsedSeconds = controller.elapsedSeconds
        try await Task.sleep(for: .milliseconds(100))

        #expect(engine.pauseCallCount == 1)
        #expect(controller.playbackState == .paused)
        #expect(controller.isPaused)
        #expect(!controller.isPlaying)
        #expect(controller.canStop)
        #expect(controller.elapsedSeconds == pausedElapsedSeconds)
    }

    @Test func startPreviewWhilePausedResumesWithoutResettingElapsedTime() async throws {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.startPreview(for: sampleProject)
        for _ in 0..<10 where controller.elapsedSeconds == 0 {
            try await Task.sleep(for: .milliseconds(50))
        }
        controller.pause()
        let pausedElapsedSeconds = controller.elapsedSeconds

        controller.startPreview(for: sampleProject)

        #expect(engine.resumeCallCount == 1)
        #expect(engine.startCallCount == 1)
        #expect(controller.playbackState == .playing)
        #expect(controller.elapsedSeconds >= pausedElapsedSeconds)
        controller.stop()
    }

    @Test func stopAfterPauseResetsElapsedTimeToZero() async throws {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.startPreview(for: sampleProject)
        for _ in 0..<10 where controller.elapsedSeconds == 0 {
            try await Task.sleep(for: .milliseconds(50))
        }
        controller.pause()

        controller.stop()

        #expect(engine.stopCallCount == 1)
        #expect(controller.playbackState == .idle)
        #expect(controller.elapsedSeconds == 0)
        #expect(!controller.canStop)
    }

    @Test func playbackCompletionResetsToIdleAndZeroElapsed() async throws {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.startPreview(for: sampleProject)
        for _ in 0..<10 where controller.elapsedSeconds == 0 {
            try await Task.sleep(for: .milliseconds(50))
        }

        engine.completePlayback()
        await Task.yield()

        #expect(controller.playbackState == .idle)
        #expect(controller.elapsedSeconds == 0)
        #expect(!controller.canStop)
        #expect(controller.outputMeterLevels == .silence)
    }

    @Test func reloadPreviewWhilePausedPreservesPositionAndPausedState() async throws {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.startPreview(for: sampleProject)
        for _ in 0..<10 where controller.elapsedSeconds == 0 {
            try await Task.sleep(for: .milliseconds(50))
        }
        controller.pause()
        let pausedElapsedSeconds = controller.elapsedSeconds

        controller.reloadPreviewPreservingPosition(
            for: sampleProject,
            trackVolumeOverrides: [1: 0.5],
            trackPanOverrides: [1: 0.25],
            trackMuteOverrides: [1: false],
            selectedVirtualTrackOptionIDs: [1: "track1#zz0000_2.wav"]
        )

        #expect(controller.playbackState == .paused)
        #expect(controller.elapsedSeconds == pausedElapsedSeconds)
        #expect(engine.stopCallCount == 1)
        #expect(engine.pauseCallCount == 2)
        #expect(engine.lastStartStartingAt == pausedElapsedSeconds)
        #expect(engine.lastStartTrackVolumeOverrides?[1] == 0.5)
        #expect(engine.lastStartTrackPanOverrides?[1] == 0.25)
        #expect(engine.lastStartTrackMuteOverrides?[1] == false)
        #expect(engine.lastStartSelectedVirtualTrackOptionIDs?[1] == "track1#zz0000_2.wav")
    }

    @Test func setTrackPanUpdatesEngineDuringActivePlayback() {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.startPreview(for: sampleProject)
        #expect(controller.isPlaying)

        controller.setTrackPan(0.6, for: 3)

        #expect(engine.lastUpdatedPanTrackNumber == 3)
        #expect(engine.lastUpdatedPanPosition == 0.6)
    }

    @Test func setTrackPanMapsEvenPairTrackToLeadingChannel() {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.startPreview(for: sampleProject)
        controller.setTrackPan(0.3, for: 10)

        #expect(engine.lastUpdatedPanTrackNumber == 9)
        #expect(engine.lastUpdatedPanPosition == 0.3)
    }

    @Test func setTrackPanDoesNotTouchEngineWhenPlaybackIsIdle() {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.setTrackPan(-0.4, for: 2)

        #expect(engine.lastUpdatedPanTrackNumber == nil)
        #expect(engine.lastUpdatedPanPosition == nil)
    }

    @Test func setTrackVolumeUpdatesEngineWhilePausedBeforeResume() {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.startPreview(for: sampleProject)
        controller.pause()

        controller.setTrackVolume(0.35, for: 2)

        #expect(engine.lastUpdatedVolumeTrackNumber == 2)
        #expect(engine.lastUpdatedVolumePosition == 0.35)
    }

    @Test func setTrackPanUpdatesEngineWhilePausedBeforeResume() {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.startPreview(for: sampleProject)
        controller.pause()

        controller.setTrackPan(-0.4, for: 3)

        #expect(engine.lastUpdatedPanTrackNumber == 3)
        #expect(engine.lastUpdatedPanPosition == -0.4)
    }

    @Test func setTrackMuteUpdatesEngineDuringActivePlayback() {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.startPreview(for: sampleProject)
        #expect(controller.isPlaying)

        controller.setTrackMute(true, for: 4)

        #expect(engine.lastUpdatedMuteTrackNumber == 4)
        #expect(engine.lastUpdatedMuteState == true)
    }

    @Test func setTrackMuteMapsEvenPairTrackToLeadingChannel() {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.startPreview(for: sampleProject)
        controller.setTrackMute(true, for: 10)

        #expect(engine.lastUpdatedMuteTrackNumber == 9)
        #expect(engine.lastUpdatedMuteState == true)
    }

    @Test func setTrackMuteDoesNotTouchEngineWhenPlaybackIsIdle() {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.setTrackMute(true, for: 4)

        #expect(engine.lastUpdatedMuteTrackNumber == nil)
        #expect(engine.lastUpdatedMuteState == nil)
    }

    @Test func setTrackMuteUpdatesEngineWhilePausedBeforeResume() {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.startPreview(for: sampleProject)
        controller.pause()

        controller.setTrackMute(true, for: 4)

        #expect(engine.lastUpdatedMuteTrackNumber == 4)
        #expect(engine.lastUpdatedMuteState == true)
    }

    @Test func applyTrackMutesUpdatesEngineWhilePausedBeforeResume() {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.startPreview(for: sampleProject)
        controller.pause()

        controller.applyTrackMutes([1: true, 2: false])

        #expect(engine.updatedMuteStates[1] == true)
        #expect(engine.updatedMuteStates[2] == false)
    }

    @Test func startPreviewPublishesOutputMeterLevelsFromEngine() async {
        let engine = SpyPreviewEngine()
        engine.outputLevelsToEmitOnStart = StereoMeterLevels(left: 0.25, right: 0.75)
        let controller = PreviewPlaybackController(engine: engine)

        controller.startPreview(for: sampleProject)
        await Task.yield()

        #expect(controller.outputMeterLevels == StereoMeterLevels(left: 0.25, right: 0.75))
    }

    private var sampleProject: PortastudioProject {
        PortastudioProject(
            folderURL: URL(fileURLWithPath: "/tmp/SONG_sample"),
            validationIssues: [],
            wavInventory: [],
            unassignedAudioRegions: [],
            tracks: [],
            edlTableSummary: nil
        )
    }
}

private final class SpyPreviewEngine: PreviewPlaybackEngineProtocol {
    var startCallCount = 0
    var pauseCallCount = 0
    var resumeCallCount = 0
    var stopCallCount = 0
    var lastStartTrackVolumeOverrides: [Int: Double]?
    var lastStartTrackPanOverrides: [Int: Double]?
    var lastStartTrackMuteOverrides: [Int: Bool]?
    var lastStartSelectedVirtualTrackOptionIDs: [Int: VirtualTrackOption.ID]?
    var lastStartStartingAt: Double?
    var lastUpdatedVolumeTrackNumber: Int?
    var lastUpdatedVolumePosition: Double?
    var lastUpdatedPanTrackNumber: Int?
    var lastUpdatedPanPosition: Double?
    var lastUpdatedMuteTrackNumber: Int?
    var lastUpdatedMuteState: Bool?
    var updatedMuteStates: [Int: Bool] = [:]
    var outputLevelsToEmitOnStart: StereoMeterLevels?
    private var onPlaybackCompleted: (() -> Void)?

    func startPreview(
        for project: PortastudioProject,
        trackVolumeOverrides: [Int: Double],
        trackPanOverrides: [Int: Double],
        trackMuteOverrides: [Int: Bool],
        selectedVirtualTrackOptionIDs: [Int: VirtualTrackOption.ID],
        startingAt elapsedSeconds: Double,
        onTrackLevelChanged: @escaping @Sendable (Int, Double) -> Void,
        onOutputLevelChanged: @escaping @Sendable (StereoMeterLevels) -> Void,
        onPlaybackCompleted: @escaping () -> Void
    ) throws {
        startCallCount += 1
        self.lastStartTrackVolumeOverrides = trackVolumeOverrides
        self.lastStartTrackPanOverrides = trackPanOverrides
        self.lastStartTrackMuteOverrides = trackMuteOverrides
        self.lastStartSelectedVirtualTrackOptionIDs = selectedVirtualTrackOptionIDs
        self.lastStartStartingAt = elapsedSeconds
        self.onPlaybackCompleted = onPlaybackCompleted
        if let outputLevelsToEmitOnStart {
            onOutputLevelChanged(outputLevelsToEmitOnStart)
        }
    }

    func pause() {
        pauseCallCount += 1
    }

    func resume() {
        resumeCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }

    func updateTrackVolume(trackNumber: Int, levelPosition: Double) {
        lastUpdatedVolumeTrackNumber = trackNumber
        lastUpdatedVolumePosition = levelPosition
    }

    func updateTrackPan(trackNumber: Int, panPosition: Double) {
        lastUpdatedPanTrackNumber = trackNumber
        lastUpdatedPanPosition = panPosition
    }

    func updateTrackMute(trackNumber: Int, isMuted: Bool) {
        lastUpdatedMuteTrackNumber = trackNumber
        lastUpdatedMuteState = isMuted
        updatedMuteStates[trackNumber] = isMuted
    }

    func completePlayback() {
        onPlaybackCompleted?()
    }
}
