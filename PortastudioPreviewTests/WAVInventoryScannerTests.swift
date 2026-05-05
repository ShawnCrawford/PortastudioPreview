//
//  WAVInventoryScannerTests.swift
//  PortastudioPreviewTests
//

import Foundation
import Testing
@testable import PortastudioPreview

struct WAVInventoryScannerTests {
    @Test func findsWAVFilesCaseInsensitively() throws {
        let folder = try TemporaryFolder()
        try Data().write(to: folder.url.appendingPathComponent("ZZ0001_1.WAV"))
        try Data().write(to: folder.url.appendingPathComponent("notes.txt"))

        let inventory = try WAVInventoryScanner().scan(folder.url)

        #expect(inventory.map(\.rawFilename) == ["ZZ0001_1.WAV"])
    }

    @Test func sortsDeterministicallyByFilename() throws {
        let folder = try TemporaryFolder()
        try Data().write(to: folder.url.appendingPathComponent("ZZ0002_1.wav"))
        try Data().write(to: folder.url.appendingPathComponent("ZZ0000_1.wav"))
        try Data().write(to: folder.url.appendingPathComponent("ZZ0001_1.wav"))

        let inventory = try WAVInventoryScanner().scan(folder.url)

        #expect(inventory.map(\.rawFilename) == ["ZZ0000_1.wav", "ZZ0001_1.wav", "ZZ0002_1.wav"])
    }

    @Test func preservesRawFilenamesForHypothesisDisplay() throws {
        let folder = try TemporaryFolder()
        try Data().write(to: folder.url.appendingPathComponent("ZZ0003_2.Wav"))

        let inventory = try WAVInventoryScanner().scan(folder.url)

        #expect(inventory.first?.rawFilename == "ZZ0003_2.Wav")
    }
}
