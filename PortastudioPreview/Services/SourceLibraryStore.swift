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

    private let classifier: SourceFolderClassifier
    private let projectLoader: @Sendable (URL) async throws -> PortastudioProject

    init(
        classifier: SourceFolderClassifier = SourceFolderClassifier(),
        projectLoader: @escaping @Sendable (URL) async throws -> PortastudioProject = { url in
            try await ProjectFolderLoader().loadProject(at: url)
        }
    ) {
        self.classifier = classifier
        self.projectLoader = projectLoader
    }

    func addSourceRoot(at url: URL) async {
        isLoading = true
        loadError = nil

        let canonicalURL = canonicalFolderURL(for: url)
        let kind = classifier.classify(url: canonicalURL)

        switch kind {
        case .mediaRoot:
            loadSourceRoot(at: canonicalURL, kind: .mediaRoot)
        case .backupRoot:
            loadSourceRoot(at: canonicalURL, kind: .backupRoot)
        case .songFolder:
            loadError = "Selected folder is a single song folder. Use \"Open Individual Song...\" to open it."
            isLoading = false
        case .unsupported(let reason):
            loadError = reason
            isLoading = false
        }
    }

    func openIndividualSongFolder(at url: URL) async {
        isLoading = true
        loadError = nil

        let canonicalURL = canonicalFolderURL(for: url)
        let kind = classifier.classify(url: canonicalURL)

        guard case .songFolder = kind else {
            loadError = unsupportedOpenReason(for: kind)
            isLoading = false
            return
        }

        upsertSong(folderURL: canonicalURL, loadState: .loading)

        do {
            let project = try await projectLoader(canonicalURL)
            selectedProject = project
            upsertSong(folderURL: canonicalURL, loadState: .loaded)
            selectIndividualSong(at: canonicalURL)
            isLoading = false
        } catch {
            selectedProject = nil
            loadError = error.localizedDescription
            upsertSong(folderURL: canonicalURL, loadState: .failed(message: error.localizedDescription))
            selectIndividualSong(at: canonicalURL)
            isLoading = false
        }
    }

    func loadIfSourceSong() async {
        guard case .individualSong(let id) = selection else { return }
        guard let (sourceIndex, songIndex) = findSourceSong(id: id) else { return }

        let song = sources[sourceIndex].songs[songIndex]
        if case .loaded = song.loadState, selectedProject?.folderURL == song.folderURL { return }

        sources[sourceIndex].songs[songIndex].loadState = .loading
        isLoading = true
        loadError = nil

        do {
            let project = try await projectLoader(song.folderURL)
            selectedProject = project
            sources[sourceIndex].songs[songIndex].loadState = .loaded
            isLoading = false
        } catch {
            selectedProject = nil
            loadError = error.localizedDescription
            sources[sourceIndex].songs[songIndex].loadState = .failed(message: error.localizedDescription)
            isLoading = false
        }
    }

    private func loadSourceRoot(at url: URL, kind: SourceKind) {
        let musicURL = url.appendingPathComponent("MUSIC", isDirectory: true)
        let songURLs = scanSongFolders(in: musicURL)
        let songs = songURLs.map { songURL in
            SourceLibrarySong(
                folderURL: songURL,
                displayName: displayName(for: songURL),
                loadState: .loading
            )
        }

        if let index = sources.firstIndex(where: { canonicalFolderURL(for: $0.folderURL) == url }) {
            sources[index].kind = kind
            sources[index].songs = songs
            sources[index].displayName = displayName(for: url)
            sources[index].loadState = .loaded
            selection = .source(sources[index].id)
        } else {
            let source = SourceLibrarySource(
                folderURL: url,
                kind: kind,
                displayName: displayName(for: url),
                songs: songs,
                loadState: .loaded
            )
            sources.append(source)
            selection = .source(source.id)
        }

        isLoading = false
    }

    private func scanSongFolders(in musicURL: URL) -> [URL] {
        let options: FileManager.DirectoryEnumerationOptions = [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: musicURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: options
        ) else {
            return []
        }
        return children.filter { childURL in
            guard (try? childURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return false }
            guard !childURL.lastPathComponent.hasPrefix("._") else { return false }
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: childURL.path)).map(Set.init) ?? []
            return contents.contains("song.sys") && contents.contains("edltable.sys")
        }
    }

    private func findSourceSong(id: UUID) -> (sourceIndex: Int, songIndex: Int)? {
        for (si, source) in sources.enumerated() {
            if let songIndex = source.songs.firstIndex(where: { $0.id == id }) {
                return (si, songIndex)
            }
        }
        return nil
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

    private func selectIndividualSong(at folderURL: URL) {
        guard let song = individualSongs.first(where: { canonicalFolderURL(for: $0.folderURL) == folderURL }) else {
            return
        }
        selection = .individualSong(song.id)
    }

    private func unsupportedOpenReason(for kind: SourceFolderKind) -> String {
        switch kind {
        case .unsupported(let reason):
            return reason
        case .mediaRoot, .backupRoot:
            return "Selected folder looks like an SD card or backup root. Use \"Add SD Card or Backup...\" instead."
        case .songFolder:
            return ""
        }
    }

    private func displayName(for url: URL) -> String {
        let name = url.lastPathComponent
        return name.isEmpty ? url.path : name
    }

    private func canonicalFolderURL(for url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }
}
