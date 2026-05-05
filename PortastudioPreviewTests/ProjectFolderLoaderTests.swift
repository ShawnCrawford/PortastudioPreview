//
//  ProjectFolderLoaderTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct ProjectFolderLoaderTests {
    @Test func missingSongSysProducesExplicitValidationIssue() async throws {
        let folder = try TemporaryFolder()
        try writeMinimumEdlTable(to: folder.url.appendingPathComponent("edltable.sys"))
        try Data().write(to: folder.url.appendingPathComponent("ZZ0000_1.wav"))

        let project = try await ProjectFolderLoader().loadProject(at: folder.url)

        #expect(project.validationIssues.contains(ProjectValidationIssue(id: "song.missing", severity: .error, message: "Missing song.sys.")))
    }

    @Test func missingEdlTableProducesExplicitValidationIssue() async throws {
        let folder = try TemporaryFolder()
        try writeMinimumSongSys(to: folder.url.appendingPathComponent("song.sys"))
        try Data().write(to: folder.url.appendingPathComponent("ZZ0000_1.wav"))

        let project = try await ProjectFolderLoader().loadProject(at: folder.url)

        #expect(project.validationIssues.contains(ProjectValidationIssue(id: "edltable.missing", severity: .error, message: "Missing edltable.sys.")))
    }

    @Test func emptyWAVInventoryProducesWarning() async throws {
        let folder = try TemporaryFolder()
        try writeMinimumSongSys(to: folder.url.appendingPathComponent("song.sys"))
        try writeMinimumEdlTable(to: folder.url.appendingPathComponent("edltable.sys"))

        let project = try await ProjectFolderLoader().loadProject(at: folder.url)

        #expect(project.validationIssues.contains(ProjectValidationIssue(id: "wav.empty", severity: .warning, message: "No WAV inventory found.")))
    }

    @Test func loadingFolderDoesNotWriteCreateRenameOrDeleteFiles() async throws {
        let folder = try TemporaryFolder()
        try writeMinimumSongSys(to: folder.url.appendingPathComponent("song.sys"))
        try writeMinimumEdlTable(to: folder.url.appendingPathComponent("edltable.sys"))
        try Data([0x01, 0x02, 0x03]).write(to: folder.url.appendingPathComponent("ZZ0000_1.wav"))

        let before = try FileReadOnlyGuard.snapshot(of: folder.url)
        _ = try await ProjectFolderLoader().loadProject(at: folder.url)
        let after = try FileReadOnlyGuard.snapshot(of: folder.url)

        #expect(after == before)
    }

    private func writeMinimumSongSys(to url: URL) throws {
        try Data(count: MixerMapOffsets.minimumSongSysLength).write(to: url)
    }

    private func writeMinimumEdlTable(to url: URL) throws {
        try Data(count: EdlTableParser.track1ActiveTakeCandidateOffset + 1).write(to: url)
    }
}
