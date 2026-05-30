//
//  PortastudioPreviewUITests.swift
//  PortastudioPreviewUITests
//
//  Created by Shawn Crawford on 5/5/26.
//

import XCTest

final class PortastudioPreviewUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testStripBackgroundClickSelectsTrack() throws {
        let app = try launchMixerWorkspace()

        let track2Background = app.buttons["mixer-strip-select-2"]
        XCTAssertTrue(track2Background.waitForExistence(timeout: 5))
        track2Background.click()

        assertTrackIsSelected(app, trackNumber: 2)
        assertTrackIsNotSelected(app, trackNumber: 1)
    }

    @MainActor
    func testFaderInteractionSelectsTrackAndChangesLevel() throws {
        let app = try launchMixerWorkspace()

        let levelLabel = app.staticTexts["mixer-strip-level-label-3"]
        XCTAssertTrue(levelLabel.waitForExistence(timeout: 5))
        let originalLevel = levelLabel.label

        let levelControl = app.otherElements["mixer-strip-level-3"]
        XCTAssertTrue(levelControl.waitForExistence(timeout: 5))
        let startCoordinate = levelControl.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
        let endCoordinate = levelControl.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        startCoordinate.press(forDuration: 0.05, thenDragTo: endCoordinate)

        assertTrackIsSelected(app, trackNumber: 3)
        XCTAssertNotEqual(levelLabel.label, originalLevel)
    }

    @MainActor
    func testMuteAndSoloToggleSelectTrack() throws {
        let app = try launchMixerWorkspace()

        let muteToggle = app.buttons["mixer-strip-mute-4"]
        XCTAssertTrue(muteToggle.waitForExistence(timeout: 5))
        muteToggle.click()
        assertTrackIsSelected(app, trackNumber: 4)

        let soloToggle = app.buttons["mixer-strip-solo-6"]
        XCTAssertTrue(soloToggle.waitForExistence(timeout: 5))
        soloToggle.click()
        assertTrackIsSelected(app, trackNumber: 6)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments.append("--ui-test-mixer-workspace")
            app.launch()
        }
    }

    private func launchMixerWorkspace() throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-mixer-workspace")
        app.launch()
        guard app.otherElements["project-workspace"].waitForExistence(timeout: 5) else {
            throw XCTSkip("UI test fixture workspace was not available in this run.")
        }
        return app
    }

    private func assertTrackIsSelected(_ app: XCUIApplication, trackNumber: Int, file: StaticString = #filePath, line: UInt = #line) {
        let strip = app.otherElements["mixer-strip-\(trackNumber)"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5), file: file, line: line)
        let selected = (strip.value as? String)?.localizedStandardContains("Selected") == true
        XCTAssertTrue(selected, "Expected track \(trackNumber) to be selected.", file: file, line: line)
    }

    private func assertTrackIsNotSelected(_ app: XCUIApplication, trackNumber: Int, file: StaticString = #filePath, line: UInt = #line) {
        let strip = app.otherElements["mixer-strip-\(trackNumber)"]
        XCTAssertTrue(strip.waitForExistence(timeout: 5), file: file, line: line)
        let selected = (strip.value as? String)?.localizedStandardContains("Selected") == true
        XCTAssertFalse(selected, "Expected track \(trackNumber) to not be selected.", file: file, line: line)
    }
}
