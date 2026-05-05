//
//  FileReadOnlyGuard.swift
//  PortastudioPreview
//

import Foundation

struct FileReadOnlyGuard {
    struct Snapshot: Equatable {
        let entries: [String: Int]
    }

    static func snapshot(of folderURL: URL, fileManager: FileManager = .default) throws -> Snapshot {
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return Snapshot(entries: [:])
        }

        var entries: [String: Int] = [:]

        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])

            guard values.isRegularFile == true else {
                continue
            }

            let relativePath = String(fileURL.path.dropFirst(folderURL.path.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            entries[relativePath] = values.fileSize ?? 0
        }

        return Snapshot(entries: entries)
    }
}
