//
//  SourceFolderClassifier.swift
//  PortastudioPreview
//

import Foundation

enum SourceFolderKind: Equatable, Sendable {
    case songFolder
    case mediaRoot
    case backupRoot
    case unsupported(reason: String)
}

struct SourceFolderClassifier: Sendable {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func classify(url: URL) -> SourceFolderKind {
        let contents = visibleContents(of: url)

        if contents.contains("song.sys") && contents.contains("edltable.sys") {
            return .songFolder
        }

        let musicURL = url.appendingPathComponent("MUSIC", isDirectory: true)
        guard isDirectory(musicURL) else {
            return .unsupported(reason: "Folder does not contain a recognized Portastudio song or card structure.")
        }

        let hasValidSongs = visibleContents(of: musicURL).contains { child in
            let childURL = musicURL.appendingPathComponent(child, isDirectory: true)
            return isDirectory(childURL) && isSongFolder(childURL)
        }

        guard hasValidSongs else {
            return .unsupported(reason: "MUSIC folder contains no recognized song folders.")
        }

        if contents.contains("dp-24.sys") {
            return .mediaRoot
        }

        return .backupRoot
    }

    private func isSongFolder(_ url: URL) -> Bool {
        let contents = visibleContents(of: url)
        return contents.contains("song.sys") && contents.contains("edltable.sys")
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private func visibleContents(of url: URL) -> Set<String> {
        let options: FileManager.DirectoryEnumerationOptions = [
            .skipsSubdirectoryDescendants,
            .skipsHiddenFiles
        ]
        guard let items = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: options
        ) else {
            return []
        }
        return Set(items.map(\.lastPathComponent).filter { !$0.hasPrefix("._") })
    }
}
