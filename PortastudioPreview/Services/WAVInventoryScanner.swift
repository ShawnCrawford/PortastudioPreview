//
//  WAVInventoryScanner.swift
//  PortastudioPreview
//

import Foundation

struct WAVInventoryScanner {
    func scan(_ folderURL: URL, fileManager: FileManager = .default) throws -> [WAVInventoryItem] {
        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var items: [WAVInventoryItem] = []

        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])

            guard values.isRegularFile == true,
                  fileURL.pathExtension.localizedCaseInsensitiveCompare("wav") == .orderedSame else {
                continue
            }

            items.append(
                WAVInventoryItem(
                    url: fileURL,
                    rawFilename: fileURL.lastPathComponent,
                    byteCount: values.fileSize
                )
            )
        }

        return items.sorted {
            let filenameComparison = $0.rawFilename.localizedStandardCompare($1.rawFilename)

            if filenameComparison == .orderedSame {
                return $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending
            }

            return filenameComparison == .orderedAscending
        }
    }
}
