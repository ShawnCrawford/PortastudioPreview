//
//  FingerprintService.swift
//  PortastudioPreview
//

import CryptoKit
import Foundation

/// Computes read-only identity fingerprints for source roots and song folders.
///
/// Rules:
/// - Hashes only small key files: dp-24.sys, song.sys, edltable.sys.
/// - Never hashes WAV file contents; WAV identity uses relative path, byte count, and modification date.
/// - Ignores .DS_Store, .Spotlight-V100, .fseventsd, and AppleDouble ._* files.
/// - Treats missing key files as absent fingerprint components, not errors.
/// - All fingerprint strings are deterministic for identical on-disk state.
struct FingerprintService: Sendable {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Key File Hashing

    func hashKeyFile(at url: URL) -> FileFingerprint? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let attrs = try? fileManager.attributesOfItem(atPath: url.path)
        let modDate = attrs?[.modificationDate] as? Date
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return FileFingerprint(
            filename: url.lastPathComponent,
            byteCount: data.count,
            modificationDate: modDate,
            sha256Hex: hex
        )
    }

    // MARK: - WAV Inventory

    func buildWAVInventoryFingerprint(songURL: URL) -> WAVInventoryFingerprint {
        guard let enumerator = fileManager.enumerator(
            at: songURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return emptyInventory()
        }

        let base = songURL.standardizedFileURL.path
        var entries: [WAVInventoryFingerprint.Entry] = []

        for case let fileURL as URL in enumerator {
            let filename = fileURL.lastPathComponent
            guard !Self.isIgnoredEntry(filename) else { continue }
            guard fileURL.pathExtension.localizedCaseInsensitiveCompare("wav") == .orderedSame else { continue }
            guard let values = try? fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
            ), values.isRegularFile == true else { continue }

            let absolutePath = fileURL.standardizedFileURL.path
            let relativePath: String
            if absolutePath.hasPrefix(base) {
                relativePath = String(absolutePath.dropFirst(base.count).drop(while: { $0 == "/" }))
            } else {
                relativePath = filename
            }

            entries.append(WAVInventoryFingerprint.Entry(
                relativePath: relativePath.lowercased(),
                byteCount: values.fileSize ?? 0,
                modificationDate: values.contentModificationDate
            ))
        }

        entries.sort { $0.relativePath < $1.relativePath }

        let totalBytes = entries.reduce(0) { $0 + $1.byteCount }
        let entryParts = entries.map { "\($0.relativePath):\($0.byteCount)" }
        let summaryString = "wav:\(entries.count):\(totalBytes):\(entryParts.joined(separator: ","))"

        return WAVInventoryFingerprint(
            visibleWAVCount: entries.count,
            totalVisibleWAVBytes: totalBytes,
            entries: entries,
            summaryString: summaryString
        )
    }

    // MARK: - Song Fingerprint

    func buildSongFingerprint(at songURL: URL) -> SongFingerprint {
        let songSys = hashKeyFile(at: songURL.appendingPathComponent("song.sys"))
        let edlTable = hashKeyFile(at: songURL.appendingPathComponent("edltable.sys"))
        let wav = buildWAVInventoryFingerprint(songURL: songURL)

        var components: [String] = ["song:\(songURL.lastPathComponent)"]
        if let s = songSys { components.append("songsys:\(s.sha256Hex):\(s.byteCount)") }
        if let e = edlTable { components.append("edl:\(e.sha256Hex):\(e.byteCount)") }
        components.append(wav.summaryString)

        return SongFingerprint(
            folderName: songURL.lastPathComponent,
            songSysFingerprint: songSys,
            edlTableFingerprint: edlTable,
            wavInventory: wav,
            aggregateString: components.joined(separator: "|"),
            generatedAt: Date()
        )
    }

    // MARK: - Source Fingerprint

    func buildSourceFingerprint(at sourceURL: URL, kind: SourceKind) -> SourceFingerprint {
        let dp24Sys = hashKeyFile(at: sourceURL.appendingPathComponent("dp-24.sys"))
        let musicURL = sourceURL.appendingPathComponent("MUSIC", isDirectory: true)
        var isDir: ObjCBool = false
        let hasMusicFolder = fileManager.fileExists(atPath: musicURL.path, isDirectory: &isDir) && isDir.boolValue

        let songURLs = scanSongFolders(in: musicURL)
        let songSummaries = songURLs.map { buildSongFingerprint(at: $0) }

        var components: [String] = ["source:\(sourceURL.lastPathComponent)"]
        if let d = dp24Sys { components.append("dp24sys:\(d.sha256Hex):\(d.byteCount)") }
        components.append("songs:\(songSummaries.count)")
        for song in songSummaries { components.append(song.aggregateString) }

        let kindStr: String
        switch kind {
        case .mediaRoot: kindStr = "SD Card"
        case .backupRoot: kindStr = "Backup"
        }

        return SourceFingerprint(
            folderName: sourceURL.lastPathComponent,
            pathDisplayString: "\(kindStr) · \(sourceURL.path)",
            kind: kind,
            hasMusicFolder: hasMusicFolder,
            dp24SysFingerprint: dp24Sys,
            songCount: songSummaries.count,
            songSummaries: songSummaries,
            aggregateString: components.joined(separator: "|"),
            generatedAt: Date()
        )
    }

    // MARK: - Ignored Entry Filtering

    static func isIgnoredEntry(_ filename: String) -> Bool {
        ignoredFilenames.contains(filename) || filename.hasPrefix("._")
    }

    private static let ignoredFilenames: Set<String> = [".DS_Store", ".Spotlight-V100", ".fseventsd"]

    // MARK: - Private Helpers

    private func scanSongFolders(in musicURL: URL) -> [URL] {
        let options: FileManager.DirectoryEnumerationOptions = [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
        guard let children = try? fileManager.contentsOfDirectory(
            at: musicURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: options
        ) else { return [] }

        return children.filter { childURL in
            guard !Self.isIgnoredEntry(childURL.lastPathComponent) else { return false }
            guard (try? childURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return false }
            let contents = (try? fileManager.contentsOfDirectory(atPath: childURL.path)).map(Set.init) ?? []
            return contents.contains("song.sys") && contents.contains("edltable.sys")
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func emptyInventory() -> WAVInventoryFingerprint {
        WAVInventoryFingerprint(
            visibleWAVCount: 0,
            totalVisibleWAVBytes: 0,
            entries: [],
            summaryString: "wav:0:0:"
        )
    }
}
