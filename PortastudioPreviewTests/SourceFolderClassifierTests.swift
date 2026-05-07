//
//  SourceFolderClassifierTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct SourceFolderClassifierTests {
    private let classifier = SourceFolderClassifier()

    @Test func validSongFolderIsClassifiedAsSongFolder() throws {
        let folder = try TemporaryFolder()
        try Data().write(to: folder.url.appendingPathComponent("song.sys"))
        try Data().write(to: folder.url.appendingPathComponent("edltable.sys"))

        #expect(classifier.classify(url: folder.url) == .songFolder)
    }

    @Test func mediaRootWithDp24SysIsClassifiedAsMediaRoot() throws {
        let folder = try TemporaryFolder()
        try Data().write(to: folder.url.appendingPathComponent("dp-24.sys"))
        let songURL = try makeSongFolder(in: folder.url.appendingPathComponent("MUSIC", isDirectory: true), name: "SONG_0001")
        _ = songURL

        #expect(classifier.classify(url: folder.url) == .mediaRoot)
    }

    @Test func backupRootWithoutDp24SysIsClassifiedAsBackupRoot() throws {
        let folder = try TemporaryFolder()
        try makeSongFolder(in: folder.url.appendingPathComponent("MUSIC", isDirectory: true), name: "SONG_0001")

        #expect(classifier.classify(url: folder.url) == .backupRoot)
    }

    @Test func rootWithAudioDepotAndUtilityButNoSongsIsUnsupported() throws {
        let folder = try TemporaryFolder()
        try FileManager.default.createDirectory(
            at: folder.url.appendingPathComponent("AudioDepot", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: folder.url.appendingPathComponent("UTILITY", isDirectory: true),
            withIntermediateDirectories: true
        )
        let musicURL = folder.url.appendingPathComponent("MUSIC", isDirectory: true)
        try FileManager.default.createDirectory(at: musicURL, withIntermediateDirectories: true)

        guard case .unsupported = classifier.classify(url: folder.url) else {
            Issue.record("Expected .unsupported for root with AudioDepot/UTILITY but no valid songs.")
            return
        }
    }

    @Test func songFolderWithSpacesInNameIsAccepted() throws {
        let folder = try TemporaryFolder()
        try makeSongFolder(in: folder.url.appendingPathComponent("MUSIC", isDirectory: true), name: "My Cool Song")

        #expect(classifier.classify(url: folder.url) == .backupRoot)
    }

    @Test func songFolderWithNonStandardNumericNameIsAccepted() throws {
        let folder = try TemporaryFolder()
        try makeSongFolder(in: folder.url.appendingPathComponent("MUSIC", isDirectory: true), name: "042")

        #expect(classifier.classify(url: folder.url) == .backupRoot)
    }

    @Test func hiddenSystemMetadataIsIgnoredDuringClassification() throws {
        let folder = try TemporaryFolder()
        // Write only hidden/system files — no song.sys or edltable.sys
        try Data().write(to: folder.url.appendingPathComponent(".DS_Store"))
        try FileManager.default.createDirectory(
            at: folder.url.appendingPathComponent(".Spotlight-V100", isDirectory: true),
            withIntermediateDirectories: true
        )

        guard case .unsupported = classifier.classify(url: folder.url) else {
            Issue.record("Expected .unsupported when only hidden metadata is present.")
            return
        }
    }

    @Test func appleDoubleFilesDoNotTriggerSongFolderClassification() throws {
        let folder = try TemporaryFolder()
        // Write AppleDouble-prefixed versions only, not the real files
        try Data().write(to: folder.url.appendingPathComponent("._song.sys"))
        try Data().write(to: folder.url.appendingPathComponent("._edltable.sys"))

        guard case .unsupported = classifier.classify(url: folder.url) else {
            Issue.record("Expected .unsupported for folder with only AppleDouble files.")
            return
        }
    }

    // MARK: - Helpers

    @discardableResult
    private func makeSongFolder(in musicURL: URL, name: String) throws -> URL {
        let songURL = musicURL.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: songURL, withIntermediateDirectories: true)
        try Data().write(to: songURL.appendingPathComponent("song.sys"))
        try Data().write(to: songURL.appendingPathComponent("edltable.sys"))
        return songURL
    }
}
