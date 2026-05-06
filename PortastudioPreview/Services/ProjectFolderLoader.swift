//
//  ProjectFolderLoader.swift
//  PortastudioPreview
//

import Foundation

struct ProjectFolderLoader {
    func loadProject(at url: URL) async throws -> PortastudioProject {
        try await Task.detached(priority: .userInitiated) {
            try ProjectPreviewBuilder().build(folderURL: url)
        }.value
    }
}
