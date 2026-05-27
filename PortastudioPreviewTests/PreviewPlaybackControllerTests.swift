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

        #expect(!controller.isPlaying)
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
    var lastStartTrackVolumeOverrides: [Int: Double]?
    var lastStartTrackPanOverrides: [Int: Double]?
    var lastStartTrackMuteOverrides: [Int: Bool]?
    var lastStartSelectedVirtualTrackOptionIDs: [Int: VirtualTrackOption.ID]?
    var lastStartStartingAt: Double?
    var lastUpdatedPanTrackNumber: Int?
    var lastUpdatedPanPosition: Double?
    var lastUpdatedMuteTrackNumber: Int?
    var lastUpdatedMuteState: Bool?
    var outputLevelsToEmitOnStart: StereoMeterLevels?

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
        self.lastStartTrackVolumeOverrides = trackVolumeOverrides
        self.lastStartTrackPanOverrides = trackPanOverrides
        self.lastStartTrackMuteOverrides = trackMuteOverrides
        self.lastStartSelectedVirtualTrackOptionIDs = selectedVirtualTrackOptionIDs
        self.lastStartStartingAt = elapsedSeconds
        if let outputLevelsToEmitOnStart {
            onOutputLevelChanged(outputLevelsToEmitOnStart)
        }
    }

    func stop() {}

    func updateTrackVolume(trackNumber: Int, levelPosition: Double) {}

    func updateTrackPan(trackNumber: Int, panPosition: Double) {
        lastUpdatedPanTrackNumber = trackNumber
        lastUpdatedPanPosition = panPosition
    }

    func updateTrackMute(trackNumber: Int, isMuted: Bool) {
        lastUpdatedMuteTrackNumber = trackNumber
        lastUpdatedMuteState = isMuted
    }
}
