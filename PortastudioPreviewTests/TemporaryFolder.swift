//
//  TemporaryFolder.swift
//  PortastudioPreviewTests
//

import Foundation

struct TemporaryFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PortastudioPreviewTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
