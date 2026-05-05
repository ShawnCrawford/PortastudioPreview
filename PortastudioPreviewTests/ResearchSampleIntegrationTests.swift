//
//  ResearchSampleIntegrationTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct ResearchSampleIntegrationTests {
    @Test func mvpPan001DoesNotReportUnsupportedMirrorWarnings() async throws {
        let sampleURL = URL(fileURLWithPath: "/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/TestProjects/DP-32SD/MVP-PAN-001")

        guard FileManager.default.fileExists(atPath: sampleURL.path) else {
            return
        }

        let before = try FileReadOnlyGuard.snapshot(of: sampleURL)
        let project = try await ProjectFolderLoader().loadProject(at: sampleURL)
        let after = try FileReadOnlyGuard.snapshot(of: sampleURL)

        #expect(after == before)
        #expect(!project.validationIssues.contains { $0.message.contains("Track 19 Pan mirror mismatch") })
        #expect(project.validationIssues.isEmpty)
    }
}
