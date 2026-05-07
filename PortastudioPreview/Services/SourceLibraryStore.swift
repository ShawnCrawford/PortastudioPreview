//
//  SourceLibraryStore.swift
//  PortastudioPreview
//

import Foundation
import Observation

@MainActor
@Observable
final class SourceLibraryStore {
    var sources: [SourceLibrarySource] = []
    var individualSongs: [SourceLibrarySong] = []
    var missingItems: [SourceLibraryMissingItem] = []
    var selection: SourceLibrarySelection?
    var selectedProject: PortastudioProject?
    var isLoading = false
    var loadError: String?

    private let projectLoader: @Sendable (URL) async throws -> PortastudioProject

    init(projectLoader: @escaping @Sendable (URL) async throws -> PortastudioProject = { url in
        try await ProjectFolderLoader().loadProject(at: url)
    }) {
        self.projectLoader = projectLoader
    }

    func openIndividualSongFolder(at url: URL) async {
        isLoading = true
        loadError = nil

        let canonicalURL = canonicalFolderURL(for: url)
        upsertSong(folderURL: canonicalURL, loadState: .loading)

        do {
            let project = try await projectLoader(canonicalURL)
            selectedProject = project
            upsertSong(folderURL: canonicalURL, loadState: .loaded)
            selectSong(at: canonicalURL)
            isLoading = false
        } catch {
            selectedProject = nil
            loadError = error.localizedDescription
            upsertSong(folderURL: canonicalURL, loadState: .failed(message: error.localizedDescription))
            selectSong(at: canonicalURL)
            isLoading = false
        }
    }

    private func upsertSong(folderURL: URL, loadState: SourceLibrarySong.LoadState) {
        if let index = individualSongs.firstIndex(where: { canonicalFolderURL(for: $0.folderURL) == folderURL }) {
            individualSongs[index].displayName = displayName(for: folderURL)
            individualSongs[index].loadState = loadState
            return
        }

        individualSongs.append(
            SourceLibrarySong(
                folderURL: folderURL,
                displayName: displayName(for: folderURL),
                loadState: loadState
            )
        )
    }

    private func selectSong(at folderURL: URL) {
        guard let song = individualSongs.first(where: { canonicalFolderURL(for: $0.folderURL) == folderURL }) else {
            return
        }

        selection = .individualSong(song.id)
    }

    private func displayName(for url: URL) -> String {
        let name = url.lastPathComponent
        return name.isEmpty ? url.path : name
    }

    private func canonicalFolderURL(for url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}
