//
//  SourceLibraryStore.swift
//  PortastudioPreview
//

import Foundation
import Observation
import SwiftData

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

    private var modelContext: ModelContext?
    let bookmarkService: any BookmarkServiceProtocol
    private let classifier: SourceFolderClassifier
    let fingerprintService: FingerprintService
    private let projectLoader: @Sendable (URL) async throws -> PortastudioProject

    init(
        modelContext: ModelContext? = nil,
        bookmarkService: any BookmarkServiceProtocol = SecurityScopedBookmarkService(),
        classifier: SourceFolderClassifier = SourceFolderClassifier(),
        fingerprintService: FingerprintService = FingerprintService(),
        projectLoader: @escaping @Sendable (URL) async throws -> PortastudioProject = { url in
            try await ProjectFolderLoader().loadProject(at: url)
        }
    ) {
        self.modelContext = modelContext
        self.bookmarkService = bookmarkService
        self.classifier = classifier
        self.fingerprintService = fingerprintService
        self.projectLoader = projectLoader
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Persistence Hydration

    func hydrateFromPersistence() async {
        guard let context = modelContext else { return }

        let sourceDescriptor = FetchDescriptor<LibrarySourceRecord>()
        let sourceRecords = (try? context.fetch(sourceDescriptor)) ?? []

        for record in sourceRecords {
            guard let kind = record.sourceKind else { continue }
            let resolvedURL = resolveStoredURL(
                bookmarkData: record.bookmarkData,
                fallbackPath: record.lastKnownPath
            ) { newData in record.bookmarkData = newData }

            if let url = resolvedURL {
                let secured = url.startAccessingSecurityScopedResource()
                let musicURL = url.appendingPathComponent("MUSIC", isDirectory: true)
                let songURLs = scanSongFolders(in: musicURL)
                var songs = persistAndBuildSongs(songURLs: songURLs, sourceRecord: record, context: context)

                // Compute fingerprints and set match state while security scope is open.
                let sourceFP = fingerprintService.buildSourceFingerprint(at: url, kind: kind)
                let sourceMatchState: FingerprintMatchState
                if let stored = record.aggregateFingerprintString {
                    sourceMatchState = sourceFP.aggregateString == stored ? .exact : .changedSinceLastSeen
                } else {
                    sourceMatchState = .unknown
                }
                record.matchStateRawValue = sourceMatchState.rawValue

                let songFPByName = Dictionary(uniqueKeysWithValues: sourceFP.songSummaries.map { ($0.folderName, $0) })
                songs = songs.map { song in
                    var s = song
                    guard let songFP = songFPByName[song.folderURL.lastPathComponent],
                          let songRec = record.songs.first(where: { $0.lastKnownPath == song.folderURL.path }) else {
                        s.matchState = .unknown
                        return s
                    }
                    let songMatchState: FingerprintMatchState
                    if let stored = songRec.aggregateFingerprintString {
                        songMatchState = songFP.aggregateString == stored ? .exact : .changedSinceLastSeen
                    } else {
                        songMatchState = .unknown
                    }
                    songRec.matchStateRawValue = songMatchState.rawValue
                    s.matchState = songMatchState
                    return s
                }

                if secured { url.stopAccessingSecurityScopedResource() }

                upsertSourceInMemory(
                    id: record.id,
                    folderURL: url,
                    kind: kind,
                    displayName: record.displayName,
                    songs: songs,
                    isMissing: false,
                    bookmarkData: record.bookmarkData
                )
                if let idx = sources.firstIndex(where: { $0.id == record.id }) {
                    sources[idx].matchState = sourceMatchState
                }
                record.isMissing = false
                record.lastSeenAt = Date()
            } else {
                upsertSourceInMemory(
                    id: record.id,
                    folderURL: URL(fileURLWithPath: record.lastKnownPath),
                    kind: kind,
                    displayName: record.displayName,
                    songs: [],
                    isMissing: true,
                    bookmarkData: record.bookmarkData
                )
                record.isMissing = true
            }
        }

        let songDescriptor = FetchDescriptor<LibrarySongRecord>(
            predicate: #Predicate { $0.isStandalone == true }
        )
        let songRecords = (try? context.fetch(songDescriptor)) ?? []

        for record in songRecords {
            let resolvedURL = resolveStoredURL(
                bookmarkData: record.bookmarkData,
                fallbackPath: record.lastKnownPath
            ) { newData in record.bookmarkData = newData }

            if let url = resolvedURL {
                let secured = url.startAccessingSecurityScopedResource()
                let songMatchState: FingerprintMatchState
                if let stored = record.aggregateFingerprintString {
                    let current = fingerprintService.buildSongFingerprint(at: url)
                    songMatchState = current.aggregateString == stored ? .exact : .changedSinceLastSeen
                } else {
                    songMatchState = .unknown
                }
                record.matchStateRawValue = songMatchState.rawValue
                if secured { url.stopAccessingSecurityScopedResource() }

                upsertIndividualSongInMemory(
                    id: record.id,
                    folderURL: url,
                    loadState: .loading,
                    isMissing: false,
                    bookmarkData: record.bookmarkData
                )
                if let idx = individualSongs.firstIndex(where: { $0.id == record.id }) {
                    individualSongs[idx].matchState = songMatchState
                }
                record.isMissing = false
                record.lastSeenAt = Date()
            } else {
                upsertIndividualSongInMemory(
                    id: record.id,
                    folderURL: URL(fileURLWithPath: record.lastKnownPath),
                    loadState: .failed(message: "Location not found."),
                    isMissing: true,
                    bookmarkData: nil
                )
                record.isMissing = true
            }
        }

        try? context.save()
    }

    // MARK: - Add / Open

    func addSourceRoot(at url: URL) async {
        isLoading = true
        loadError = nil

        let canonicalURL = canonicalFolderURL(for: url)
        let kind = classifier.classify(url: canonicalURL)

        switch kind {
        case .mediaRoot:
            await persistAndLoadSourceRoot(at: canonicalURL, kind: .mediaRoot)
        case .backupRoot:
            await persistAndLoadSourceRoot(at: canonicalURL, kind: .backupRoot)
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

        let bookmarkData = try? bookmarkService.createBookmark(for: canonicalURL)

        let songID: UUID
        if let context = modelContext {
            if let existing = fetchSongRecord(by: canonicalURL.path, context: context) {
                songID = existing.id
                existing.displayName = displayName(for: canonicalURL)
                existing.lastKnownPath = canonicalURL.path
                if let data = bookmarkData { existing.bookmarkData = data }
                existing.isMissing = false
                existing.lastSeenAt = Date()
            } else {
                let newID = UUID()
                songID = newID
                let record = LibrarySongRecord(
                    id: newID,
                    displayName: displayName(for: canonicalURL),
                    lastKnownPath: canonicalURL.path,
                    bookmarkData: bookmarkData,
                    isMissing: false,
                    isStandalone: true,
                    lastSeenAt: Date()
                )
                context.insert(record)
            }
            try? context.save()
        } else {
            songID = individualSongs.first(where: {
                canonicalFolderURL(for: $0.folderURL) == canonicalURL
            })?.id ?? UUID()
        }

        upsertIndividualSongInMemory(
            id: songID,
            folderURL: canonicalURL,
            loadState: .loading,
            isMissing: false,
            bookmarkData: bookmarkData
        )

        do {
            let project = try await projectLoader(canonicalURL)
            selectedProject = project
            if let index = individualSongs.firstIndex(where: { $0.id == songID }) {
                individualSongs[index].loadState = .loaded
            }
            let songFP = fingerprintService.buildSongFingerprint(at: canonicalURL)
            if let context = modelContext, let songRecord = fetchSongRecord(by: canonicalURL.path, context: context) {
                songRecord.aggregateFingerprintString = songFP.aggregateString
                songRecord.wavInventorySummaryString = songFP.wavInventory.summaryString
                songRecord.fingerprintGeneratedAt = songFP.generatedAt
                songRecord.matchStateRawValue = FingerprintMatchState.exact.rawValue
                try? context.save()
            }
            if let index = individualSongs.firstIndex(where: { $0.id == songID }) {
                individualSongs[index].matchState = .exact
            }
            selection = .individualSong(songID)
            isLoading = false
        } catch {
            selectedProject = nil
            loadError = error.localizedDescription
            if let index = individualSongs.firstIndex(where: { $0.id == songID }) {
                individualSongs[index].loadState = .failed(message: error.localizedDescription)
            }
            selection = .individualSong(songID)
            isLoading = false
        }
    }

    func loadIfSourceSong() async {
        guard case .individualSong(let id) = selection else { return }

        // Source-nested song
        if let (sourceIndex, songIndex) = findSourceSong(id: id) {
            let song = sources[sourceIndex].songs[songIndex]
            if case .loaded = song.loadState, selectedProject?.folderURL == song.folderURL { return }

            sources[sourceIndex].songs[songIndex].loadState = .loading
            isLoading = true
            loadError = nil

            var securedURL: URL? = nil
            if let data = sources[sourceIndex].bookmarkData,
               let (resolved, _) = try? bookmarkService.resolveBookmark(data),
               resolved.startAccessingSecurityScopedResource() {
                securedURL = resolved
            }

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

            if let url = securedURL { url.stopAccessingSecurityScopedResource() }
            return
        }

        // Standalone individual song hydrated from persistence
        if let songIndex = individualSongs.firstIndex(where: { $0.id == id }) {
            let song = individualSongs[songIndex]
            if song.isMissing { return }
            if case .loaded = song.loadState, selectedProject?.folderURL == song.folderURL { return }

            individualSongs[songIndex].loadState = .loading
            isLoading = true
            loadError = nil

            var securedURL: URL? = nil
            if let data = song.bookmarkData,
               let (resolved, _) = try? bookmarkService.resolveBookmark(data),
               resolved.startAccessingSecurityScopedResource() {
                securedURL = resolved
            }

            do {
                let project = try await projectLoader(song.folderURL)
                selectedProject = project
                individualSongs[songIndex].loadState = .loaded
                isLoading = false
            } catch {
                selectedProject = nil
                loadError = error.localizedDescription
                individualSongs[songIndex].loadState = .failed(message: error.localizedDescription)
                isLoading = false
            }

            if let url = securedURL { url.stopAccessingSecurityScopedResource() }
        }
    }

    // MARK: - Forget

    func forgetSource(id: UUID) {
        guard let sourceIndex = sources.firstIndex(where: { $0.id == id }) else { return }
        let source = sources[sourceIndex]
        let songIDs = Set(source.songs.map(\.id))

        clearSelectionForSource(id: id, songIDs: songIDs)
        sources.remove(at: sourceIndex)

        guard let context = modelContext else { return }
        let path = source.folderURL.path
        let descriptor = FetchDescriptor<LibrarySourceRecord>(
            predicate: #Predicate { $0.lastKnownPath == path }
        )
        if let record = try? context.fetch(descriptor).first {
            context.delete(record)
            try? context.save()
        }
    }

    func forgetSong(id: UUID) {
        guard let songIndex = individualSongs.firstIndex(where: { $0.id == id }) else { return }
        let song = individualSongs[songIndex]

        if case .individualSong(let selectedID) = selection, selectedID == id {
            selection = nil
            selectedProject = nil
        }
        individualSongs.remove(at: songIndex)

        guard let context = modelContext else { return }
        let path = song.folderURL.path
        let descriptor = FetchDescriptor<LibrarySongRecord>(
            predicate: #Predicate { $0.lastKnownPath == path }
        )
        if let record = try? context.fetch(descriptor).first {
            context.delete(record)
            try? context.save()
        }
    }

    // MARK: - Relocate

    func relocateSource(id: UUID, to newURL: URL) async {
        let canonicalURL = canonicalFolderURL(for: newURL)
        let kind = classifier.classify(url: canonicalURL)

        switch kind {
        case .mediaRoot, .backupRoot:
            break
        default:
            loadError = "Selected folder is not a recognized SD card or backup root."
            return
        }

        let newKind: SourceKind = (kind == .mediaRoot) ? .mediaRoot : .backupRoot
        let newBookmarkData = try? bookmarkService.createBookmark(for: canonicalURL)

        if let context = modelContext,
           let sourceIndex = sources.firstIndex(where: { $0.id == id }) {
            let oldPath = sources[sourceIndex].folderURL.path
            let descriptor = FetchDescriptor<LibrarySourceRecord>(
                predicate: #Predicate { $0.lastKnownPath == oldPath }
            )
            if let record = try? context.fetch(descriptor).first {
                record.lastKnownPath = canonicalURL.path
                record.displayName = displayName(for: canonicalURL)
                if let data = newBookmarkData { record.bookmarkData = data }
                record.kindRawValue = newKind == .mediaRoot ? "mediaRoot" : "backupRoot"
                record.isMissing = false
                record.lastSeenAt = Date()
                try? context.save()
            }
        }

        await persistAndLoadSourceRoot(at: canonicalURL, kind: newKind, existingID: id)
    }

    func relocateSong(id: UUID, to newURL: URL) async {
        let canonicalURL = canonicalFolderURL(for: newURL)
        let kind = classifier.classify(url: canonicalURL)

        guard case .songFolder = kind else {
            loadError = "Selected folder is not a recognized song folder."
            return
        }

        let newBookmarkData = try? bookmarkService.createBookmark(for: canonicalURL)

        if let context = modelContext,
           let songIndex = individualSongs.firstIndex(where: { $0.id == id }) {
            let oldPath = individualSongs[songIndex].folderURL.path
            let descriptor = FetchDescriptor<LibrarySongRecord>(
                predicate: #Predicate { $0.lastKnownPath == oldPath }
            )
            if let record = try? context.fetch(descriptor).first {
                record.lastKnownPath = canonicalURL.path
                record.displayName = displayName(for: canonicalURL)
                if let data = newBookmarkData { record.bookmarkData = data }
                record.isMissing = false
                record.lastSeenAt = Date()
                try? context.save()
            }
        }

        if let index = individualSongs.firstIndex(where: { $0.id == id }) {
            individualSongs[index].folderURL = canonicalURL
            individualSongs[index].displayName = displayName(for: canonicalURL)
            individualSongs[index].bookmarkData = newBookmarkData
            individualSongs[index].isMissing = false
            individualSongs[index].loadState = .loading
        }

        isLoading = true
        loadError = nil
        do {
            let project = try await projectLoader(canonicalURL)
            selectedProject = project
            if let index = individualSongs.firstIndex(where: { $0.id == id }) {
                individualSongs[index].loadState = .loaded
            }
            let songFP = fingerprintService.buildSongFingerprint(at: canonicalURL)
            if let context = modelContext, let songRecord = fetchSongRecord(by: canonicalURL.path, context: context) {
                songRecord.aggregateFingerprintString = songFP.aggregateString
                songRecord.wavInventorySummaryString = songFP.wavInventory.summaryString
                songRecord.fingerprintGeneratedAt = songFP.generatedAt
                songRecord.matchStateRawValue = FingerprintMatchState.exact.rawValue
                try? context.save()
            }
            if let index = individualSongs.firstIndex(where: { $0.id == id }) {
                individualSongs[index].matchState = .exact
            }
            selection = .individualSong(id)
            isLoading = false
        } catch {
            selectedProject = nil
            loadError = error.localizedDescription
            if let index = individualSongs.firstIndex(where: { $0.id == id }) {
                individualSongs[index].loadState = .failed(message: error.localizedDescription)
            }
            isLoading = false
        }
    }

    // MARK: - Private Persistence Helpers

    private func persistAndLoadSourceRoot(at url: URL, kind: SourceKind, existingID: UUID? = nil) async {
        let bookmarkData = try? bookmarkService.createBookmark(for: url)
        let sourceID: UUID

        if let context = modelContext {
            if let existing = fetchSourceRecord(by: url.path, context: context) {
                sourceID = existing.id
                existing.displayName = displayName(for: url)
                existing.kindRawValue = kindRawValue(for: kind)
                existing.lastKnownPath = url.path
                if let data = bookmarkData { existing.bookmarkData = data }
                existing.isMissing = false
                existing.lastSeenAt = Date()
            } else {
                let newID = existingID ?? UUID()
                sourceID = newID
                let record = LibrarySourceRecord(
                    id: newID,
                    displayName: displayName(for: url),
                    kindRawValue: kindRawValue(for: kind),
                    lastKnownPath: url.path,
                    bookmarkData: bookmarkData,
                    isMissing: false,
                    lastSeenAt: Date()
                )
                context.insert(record)
            }
        } else {
            sourceID = existingID
                ?? sources.first(where: { canonicalFolderURL(for: $0.folderURL) == url })?.id
                ?? UUID()
        }

        let musicURL = url.appendingPathComponent("MUSIC", isDirectory: true)
        let songURLs = scanSongFolders(in: musicURL)
        let songs: [SourceLibrarySong]

        if let context = modelContext, let sourceRecord = fetchSourceRecord(by: url.path, context: context) {
            songs = persistAndBuildSongs(songURLs: songURLs, sourceRecord: sourceRecord, context: context)
        } else {
            songs = buildSongsWithoutPersistence(songURLs: songURLs, sourceID: sourceID)
        }

        try? modelContext?.save()

        upsertSourceInMemory(
            id: sourceID,
            folderURL: url,
            kind: kind,
            displayName: displayName(for: url),
            songs: songs,
            isMissing: false,
            bookmarkData: bookmarkData
        )

        // Compute and persist fingerprints; newly added/re-scanned sources are .exact.
        if let context = modelContext, let sourceRecord = fetchSourceRecord(by: url.path, context: context) {
            let sourceFP = fingerprintService.buildSourceFingerprint(at: url, kind: kind)
            sourceRecord.aggregateFingerprintString = sourceFP.aggregateString
            sourceRecord.fingerprintGeneratedAt = sourceFP.generatedAt
            sourceRecord.matchStateRawValue = FingerprintMatchState.exact.rawValue
            let songFPByName = Dictionary(uniqueKeysWithValues: sourceFP.songSummaries.map { ($0.folderName, $0) })
            for songRecord in sourceRecord.songs {
                let name = URL(fileURLWithPath: songRecord.lastKnownPath).lastPathComponent
                if let songFP = songFPByName[name] {
                    songRecord.aggregateFingerprintString = songFP.aggregateString
                    songRecord.wavInventorySummaryString = songFP.wavInventory.summaryString
                    songRecord.fingerprintGeneratedAt = songFP.generatedAt
                    songRecord.matchStateRawValue = FingerprintMatchState.exact.rawValue
                }
            }
            try? context.save()
        }
        if let idx = sources.firstIndex(where: { $0.id == sourceID }) {
            sources[idx].matchState = .exact
            sources[idx].songs = sources[idx].songs.map { s in
                var updated = s
                updated.matchState = .exact
                return updated
            }
        }

        selection = .source(sourceID)
        isLoading = false
    }

    private func persistAndBuildSongs(
        songURLs: [URL],
        sourceRecord: LibrarySourceRecord,
        context: ModelContext
    ) -> [SourceLibrarySong] {
        songURLs.map { songURL in
            let songID: UUID
            if let existing = sourceRecord.songs.first(where: { $0.lastKnownPath == songURL.path }) {
                songID = existing.id
                existing.isMissing = false
                existing.lastSeenAt = Date()
                existing.displayName = displayName(for: songURL)
            } else {
                let newID = UUID()
                songID = newID
                let record = LibrarySongRecord(
                    id: newID,
                    displayName: displayName(for: songURL),
                    lastKnownPath: songURL.path,
                    bookmarkData: nil,
                    isMissing: false,
                    isStandalone: false,
                    lastSeenAt: Date()
                )
                context.insert(record)
                sourceRecord.songs.append(record)
            }
            return SourceLibrarySong(
                id: songID,
                folderURL: songURL,
                displayName: displayName(for: songURL),
                loadState: .loading,
                sourceID: sourceRecord.id
            )
        }
    }

    private func buildSongsWithoutPersistence(songURLs: [URL], sourceID: UUID) -> [SourceLibrarySong] {
        let existingSource = sources.first(where: { $0.id == sourceID })
        return songURLs.map { songURL in
            let existingID = existingSource?.songs.first(where: {
                canonicalFolderURL(for: $0.folderURL) == canonicalFolderURL(for: songURL)
            })?.id
            return SourceLibrarySong(
                id: existingID ?? UUID(),
                folderURL: songURL,
                displayName: displayName(for: songURL),
                loadState: .loading,
                sourceID: sourceID
            )
        }
    }

    // MARK: - Private In-Memory Helpers

    private func upsertSourceInMemory(
        id: UUID,
        folderURL: URL,
        kind: SourceKind,
        displayName: String,
        songs: [SourceLibrarySong],
        isMissing: Bool,
        bookmarkData: Data?
    ) {
        if let index = sources.firstIndex(where: { $0.id == id }) {
            sources[index].folderURL = folderURL
            sources[index].kind = kind
            sources[index].displayName = displayName
            sources[index].songs = songs
            sources[index].isMissing = isMissing
            sources[index].loadState = .loaded
            if let data = bookmarkData { sources[index].bookmarkData = data }
        } else if let index = sources.firstIndex(where: {
            canonicalFolderURL(for: $0.folderURL) == canonicalFolderURL(for: folderURL)
        }) {
            sources[index].folderURL = folderURL
            sources[index].kind = kind
            sources[index].displayName = displayName
            sources[index].songs = songs
            sources[index].isMissing = isMissing
            sources[index].loadState = .loaded
            if let data = bookmarkData { sources[index].bookmarkData = data }
        } else {
            sources.append(SourceLibrarySource(
                id: id,
                folderURL: folderURL,
                kind: kind,
                displayName: displayName,
                songs: songs,
                loadState: .loaded,
                isMissing: isMissing,
                bookmarkData: bookmarkData
            ))
        }
    }

    private func upsertIndividualSongInMemory(
        id: UUID,
        folderURL: URL,
        loadState: SourceLibrarySong.LoadState,
        isMissing: Bool,
        bookmarkData: Data?
    ) {
        let canonicalURL = canonicalFolderURL(for: folderURL)
        if let index = individualSongs.firstIndex(where: {
            $0.id == id || canonicalFolderURL(for: $0.folderURL) == canonicalURL
        }) {
            individualSongs[index].folderURL = canonicalURL
            individualSongs[index].displayName = displayName(for: canonicalURL)
            individualSongs[index].loadState = loadState
            individualSongs[index].isMissing = isMissing
            if let data = bookmarkData { individualSongs[index].bookmarkData = data }
        } else {
            individualSongs.append(SourceLibrarySong(
                id: id,
                folderURL: canonicalURL,
                displayName: displayName(for: canonicalURL),
                loadState: loadState,
                isMissing: isMissing,
                bookmarkData: bookmarkData
            ))
        }
    }

    private func resolveStoredURL(
        bookmarkData: Data?,
        fallbackPath: String,
        onRefresh: (Data) -> Void
    ) -> URL? {
        if let data = bookmarkData {
            do {
                let (url, isStale) = try bookmarkService.resolveBookmark(data)
                if isStale, let refreshed = try? bookmarkService.createBookmark(for: url) {
                    onRefresh(refreshed)
                }
                return url
            } catch {
                // Fall through to path fallback
            }
        }
        let fallbackURL = URL(fileURLWithPath: fallbackPath)
        return FileManager.default.fileExists(atPath: fallbackURL.path) ? fallbackURL : nil
    }

    private func fetchSourceRecord(by path: String, context: ModelContext) -> LibrarySourceRecord? {
        let descriptor = FetchDescriptor<LibrarySourceRecord>(
            predicate: #Predicate { $0.lastKnownPath == path }
        )
        return try? context.fetch(descriptor).first
    }

    private func fetchSongRecord(by path: String, context: ModelContext) -> LibrarySongRecord? {
        let descriptor = FetchDescriptor<LibrarySongRecord>(
            predicate: #Predicate { $0.lastKnownPath == path }
        )
        return try? context.fetch(descriptor).first
    }

    private func clearSelectionForSource(id: UUID, songIDs: Set<UUID>) {
        switch selection {
        case .source(let selectedID) where selectedID == id:
            selection = nil
            selectedProject = nil
        case .individualSong(let songID) where songIDs.contains(songID):
            selection = nil
            selectedProject = nil
        default:
            break
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

    private func displayName(for url: URL) -> String {
        let name = url.lastPathComponent
        return name.isEmpty ? url.path : name
    }

    private func canonicalFolderURL(for url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
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

    private func kindRawValue(for kind: SourceKind) -> String {
        switch kind {
        case .mediaRoot: return "mediaRoot"
        case .backupRoot: return "backupRoot"
        }
    }
}

