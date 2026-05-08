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
            selectedVirtualTrackOptionIDs: [1: "track1#zz0000_2.wav"]
        )

        #expect(engine.lastStartTrackVolumeOverrides?[1] == 0.75)
        #expect(engine.lastStartTrackPanOverrides?[1] == -0.25)
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

    @Test func setTrackPanDoesNotTouchEngineWhenPlaybackIsIdle() {
        let engine = SpyPreviewEngine()
        let controller = PreviewPlaybackController(engine: engine)

        controller.setTrackPan(-0.4, for: 2)

        #expect(engine.lastUpdatedPanTrackNumber == nil)
        #expect(engine.lastUpdatedPanPosition == nil)
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
    var lastStartSelectedVirtualTrackOptionIDs: [Int: VirtualTrackOption.ID]?
    var lastUpdatedPanTrackNumber: Int?
    var lastUpdatedPanPosition: Double?

    func startPreview(
        for project: PortastudioProject,
        trackVolumeOverrides: [Int: Double],
        trackPanOverrides: [Int: Double],
        selectedVirtualTrackOptionIDs: [Int: VirtualTrackOption.ID],
        onTrackLevelChanged: @escaping @Sendable (Int, Double) -> Void,
        onPlaybackCompleted: @escaping () -> Void
    ) throws {
        self.lastStartTrackVolumeOverrides = trackVolumeOverrides
        self.lastStartTrackPanOverrides = trackPanOverrides
        self.lastStartSelectedVirtualTrackOptionIDs = selectedVirtualTrackOptionIDs
    }

    func stop() {}

    func updateTrackVolume(trackNumber: Int, levelPosition: Double) {}

    func updateTrackPan(trackNumber: Int, panPosition: Double) {
        lastUpdatedPanTrackNumber = trackNumber
        lastUpdatedPanPosition = panPosition
    }
}
