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
}
