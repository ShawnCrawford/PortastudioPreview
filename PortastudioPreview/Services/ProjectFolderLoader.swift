//
//  ProjectFolderLoader.swift
//  PortastudioPreview
//

import Foundation

struct ProjectFolderLoader {
    func loadProject(at url: URL) async throws -> PortastudioProject {
        try ProjectPreviewBuilder().build(folderURL: url)
    }
}
