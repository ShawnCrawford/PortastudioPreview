# PortastudioPreview

PortastudioPreview is a macOS SwiftUI prototype for read-only preview of TASCAM DP-32SD song folders, with an app-owned source library that remembers opened SD card roots, backup roots, and individual songs across relaunches.

This is an independent project and is not affiliated with or endorsed by TASCAM or TEAC Corporation. TASCAM and DP-32SD are trademarks of their respective owner.

The app is designed for safe inspection, annotation, and stereo preview playback of validated DP-32SD project mappings. It does not write to project folders.

## Goals

- Add an SD card root or backup folder and browse all its songs.
- Open an individual DP-32SD song folder.
- Classify selected folders conservatively as media roots, backup roots, or song folders.
- Parse `song.sys` and `edltable.sys` with evidence-scoped behavior.
- Show the full 20-channel mixer layout, distinguishing assigned audio from songs whose files remain unassigned, with musician-facing track info first and parser diagnostics in expandable technical details.
- Provide read-only stereo preview only when file identity, region placement, and the applicable saved mute state are resolved. Withhold playback for ambiguous multi-file projects rather than playing inactive takes or invented placements.
- Adjust preview-only mix settings with app-owned level, pan, mute, solo, and virtual-take overrides.
- Remember opened sources and songs using SwiftData and security-scoped bookmarks.
- Show missing remembered locations as muted rows with Relocate and Forget affordances.
- Annotate tracks with app-owned names keyed by song fingerprint; never write to source folders.

## Non-Goals

- No project mutation, export, or normalization.
- No destructive operations on sample folders.
- No claims above documented evidence levels.
- No automatic removable-media detection (Phase 12).
- No whole-WAV content hashing during routine scans (WAV identity uses metadata only).

## Repository Layout

- `PortastudioPreview/` app source
- `PortastudioPreviewTests/` Swift Testing unit/integration tests
- `PortastudioPreviewUITests/` UI test target
- `Docs/` local documentation index into the research repo
- `Plans/` implementation handoff plans for major phases

## Current Architecture Snapshot

The app is organized around a source library and a selected-song workspace whose first view is a scrollable track timeline. The timeline places audio regions against song time so users can see gaps and later starts across tracks.

- `ContentView` owns the source-library shell and routes selection to either `ProjectOpenView`, `SourceSelectedView`, or `ProjectDetailView`.
- `SourceLibraryStore` handles remembered source/song hydration, add/open flows, relocate/forget, fingerprints, and missing-location state.
- `ProjectPreviewBuilder` assembles the read-only `PortastudioProject` by scanning WAV inventory and parsing `song.sys` and `edltable.sys`. It retains a correlated single-file assignment only for the one-entry/one-WAV case; multi-file order does not establish track, take, or region identity.
- `PortastudioProject.tracks` keeps full parser scope (physical tracks), and `visibleMixerChannels` exposes the full 20-channel mixer layout (mono tracks 1–8 plus stereo pairs 9/10–31/32). Channels without a supported WAV assignment remain visible and report no assigned audio.
- `ProjectDetailView` owns selected-track and selected-region state, inspector visibility, `PreviewPlaybackController`, `PreviewMixState`, and selected virtual-take IDs for the loaded song.
- `ProjectWorkspaceView` presents a time-aligned track map first, with zoom and horizontal/vertical scrolling. The mixer deck remains below the timeline for preview adjustments.
- `TrackRegionInspectorView` is the native right-side inspector for song summary, selected-track identity/audio/mix values, app-owned track labels, audio file list, Reveal in Finder, and reset selected channel, with parser-level data under a collapsed Technical Details disclosure.
- `PreviewMixState` persists app-owned preview overrides in SwiftData through `MixOverrideRecord`; source folders remain read-only.
- `PreviewPlaybackController` and `StereoPreviewEngine` own playback lifecycle, live mixer updates, selected virtual-take playback, elapsed time, per-track/output meters, and error state.
- `TimelineVisualizationBuilder` keeps files with unresolved assignment or placement in explicitly unplaced rows. EDL scan candidates are not paired to WAVs by count, and no sequential WAV-length fallback is used. Unresolved starts are not plotted as song-time positions; no waveform is drawn and no timeline seeking/editing is provided. `WaveformPeakBuilder` remains unused by the visible UI. Keep all analysis read-only and never write caches beside Portastudio files.

### Playback and timeline evidence update (November 3, 2026)

Review findings are recorded in `Research/Review-2026-11-03/output/DP32SD_Playback_Timeline_Findings.md`. The app no longer applies the Track 1 selector to unrelated file groups, treats multi-file EDL ordering as physical channel assignment, or schedules unassigned files at unity/center. Starts from the EDL scan and WAV lengths are not enough to identify region placement, so those starts remain unresolved. Automatic playback is withheld until file assignment, region start, and mute state have supported evidence. Missing mute data displays as Unknown; app-owned mute overrides remain distinct from parsed device state.

The capture review found no independent AudioDepot/per-track exports to validate a full mix or exact region placement. Several mute-byte comparisons support the parser within their documented capture scope, but they do not resolve general multi-clip or active-take mapping.

## Build and Test

Requires macOS 26.4 or later and Xcode with the macOS 26.4 SDK.

```bash
xcodebuild -list -project PortastudioPreview.xcodeproj
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' build
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' test
```

### First-Round Polish and Validation (Phase 8)

- **Sidebar search/filter**: `SourceLibrarySidebarView` now owns `@State private var searchText` and computes `FilterResult` via `SourceLibrarySearch.filter(sources:individualSongs:missingItems:searchText:)`. Source name/kind/path and nested song name/path matching is case-insensitive. A source match shows all its children; a song-only match narrows the children shown. A `noResultsSection` appears when search is active and all sections are empty.
- **Toolbar/command polish**: Toolbar "Add SD Card or Backup…" and "Open Individual Song…" buttons now have `.help(…)` tooltips and `.accessibilityIdentifier` labels. Keyboard shortcuts were already present from earlier phases.
- **Open-state action polish**: `ProjectOpenView` builds both first-run actions with SwiftUI's text + `systemImage` button API, keeping the add-source and open-song controls consistent with the rest of the macOS command surface.
- **SourceSelectedView**: Selecting a source row in the sidebar (without loading a specific song) now shows a polished intermediate detail view with source name, kind, path, song count, and match state. Previously this showed a blank detail area.
- **Empty and missing states**: "No sources added", "No songs opened", and "No missing items" rows are suppressed during active search to avoid conflating empty-section feedback with no-results feedback. The unified "No results for…" row handles the active-search case.
- **Accessibility**: Added `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityIdentifier`, and `.accessibilityHidden(true)` to decorative icons and interactive elements across `ProjectOpenView`, `ProjectDetailView`, `TrackLabelEditorView`, and sidebar rows.
- **Tests added** (all passing):
  - `SourceLibrarySearchTests` (20 tests): empty/whitespace passthrough, source/song/missing matching logic, source-match shows all children, song-only match narrows children, no-results state, `hasAnyResults`, mutation safety, case insensitivity.
  - `SourceFolderClassifierTests` additions: AppleDouble files inside MUSIC/ don't create fake songs; valid songs alongside hidden metadata classify correctly.
  - `SourceLibraryStoreTests` additions: hydration keeps missing record visible, wrong-kind relocate leaves source missing with error, forget source/song clears selection, selecting nested source song loads project, source folders unchanged after forget/relocate-failure.
  - `TrackAnnotationStoreTests` additions: nil context disables all writes, ambiguous match state disables writes, clearing labels is app-owned only.

### App-Owned Track Labels (Phase 7)

- `TrackAnnotationRecord` is a SwiftData `@Model` keyed by song fingerprint string + track number. Records are app-owned; no source folders are ever modified.
- `TrackAnnotationStore` is a `@MainActor @Observable` service. It exposes `annotationContext` (a `SongAnnotationContext` value) and write methods: `setTrackName`, `clearTrackName`, `setSongDisplayNameOverride`. It is owned by `ContentView` and passed down through `ProjectDetailView`, `TrackTableView`, and `TrackRegionInspectorView`.
- `SongAnnotationContext` carries the song fingerprint, match state, folder URL, and folder name. `isEditable` returns `true` only when `matchState == .exact` and fingerprint is non-empty.
- `SourceLibraryStore.selectedSongAnnotationContext()` builds and returns context for the selected song. `ContentView` calls this via `.task(id: store.selectedProject?.folderURL)` so context reloads on selection change.
- `TrackTableView` shows a "Name" column populated from `annotationStore` when available.
- `TrackRegionInspectorView` replaces the Phase 6 placeholder rows with a grouped selected-track inspector and `TrackLabelEditorView` in a "Label" section. The editor saves on Return and on focus loss; when `isEditable` is false, the field is read-only with an orange warning when the fingerprint has changed.
- Song display-name override is stored in `LibrarySongRecord.displayNameOverride`. The nav title and song header show the override name when set.
- The app schema includes `TrackAnnotationRecord.self` in the `ModelContainer` schema alongside `LibrarySourceRecord` and `LibrarySongRecord`.

### Track Selection and Inspector (Phase 6)

- `ProjectDetailView` owns `selectedTrackID` as view-local `@State`; selecting a mixer strip drives the native inspector.
- `TrackTableView` remains a reusable raw/evidence table component with `@Binding` selection support, but the current primary UI is the mixer deck in `ProjectWorkspaceView`.
- `TrackRegionInspectorView` is a native right-side inspector attached with `.inspector(isPresented:)`. It displays:
  - **Empty state**: neutral prompt when nothing is selected.
  - **Track inspector**: track number, assigned/selected WAV, selected take, saved mix state (level/pan/mute/solo), effective status, and the current app-owned track-label editor. Technical parser diagnostics (raw bytes, parsed values, active-take byte/offset, mirror mismatch) are available in the collapsed Technical Details disclosure.
  - **Audio-file section**: selected or song-level WAV inventory, with Reveal in Finder routed to the selected audio file when present.
- Inspector width is 240–360 pt. A toolbar button toggles it with `sidebar.right` icon.
- Evidence labels follow research-repo conventions exactly: `Observed`, `Correlated`, `Confirmed`, `Hypothesis`, `Rejected`. No evidence is promoted beyond levels already encoded in current models.
- The inspector remains read-only toward Portastudio files. Phase 7 annotation edits are app-owned SwiftData writes only; no sidecar files or source-folder mutations are created.

### Track Timeline (Phase 15; waveform deferred)

- `TimelineVisualizationView` is the first section in the selected-song workspace. It shows one row per physical track, with bars positioned by region start and length, plus zoom, fit, and horizontal/vertical scrolling.
- The visible bar follows the track's selected virtual take. Files without a supported track association appear in separate `Unassigned` rows; file-list order is never presented as track identity.
- Bars represent parsed WAV regions and their inferred start/length. The app does not analyze silence inside a WAV, so a long WAV containing quiet gaps appears as one continuous region.
- Current parsing provides one selected WAV region per physical track; virtual-take alternatives are choices rather than simultaneous clips. Multiple non-contiguous regions on the same track need additional evidence-backed parser work.
- Selecting a bar selects its track and region for the inspector. Bars include the filename, approximate timing, and evidence label for accessibility.
- Timing remains evidence-scoped. If all regions overlap at zero because start timing is unresolved, the timeline says so instead of implying distinct positions.
- Waveform peak analysis exists as a read-only service, but waveform drawing is deferred. There is no timeline seeking or editing.
- Detailed scope: `Plans/Phase15WaveformAndTimelineVisualization.md`.

### Song Detail Workspace (Current)

- `ProjectDetailView` presents the selected-song workspace: song header, read-only playback controls, scrollable track timeline, mixer deck, and native inspector.
- The mixer uses one clear channel identity, concise audio status, grouped controls, and fader-dominant layout hierarchy, with virtual-take picker when multiple takes are available and reset-all mix access.
- Empty/unresolved channels are hidden from the main mixer surface. For stereo pairs (`9/10` through `31/32`), a single pair row appears when either side has resolved audio, and includes only active member tracks.
- Mix overrides are app-owned SwiftData records (`MixOverrideRecord`) keyed by exact song fingerprint context. They include level, pan, mute, solo, and selected virtual take.
- Raw filenames, evidence levels, take metadata, parsed bytes, saved-vs-parsed mix values, selected-channel reset, and Reveal in Finder actions live in `TrackRegionInspectorView`.
- Critical blockers remain visible in the primary workspace: playback errors, preview unavailable status, missing audio, and no-audio channel states.
- Preview playback remains read-only: live mix changes affect the preview engine and persisted app-owned overrides, never Portastudio source files.

### Source and Song Fingerprints (Phase 4)

- `FingerprintService` computes deterministic fingerprints for source roots and individual songs without writing to source folders.
- Key files hashed with SHA-256: `dp-24.sys` (source root), `song.sys`, `edltable.sys` (song folders). WAV files are never content-hashed; only relative path (lowercased), byte count, and modification date are used.
- Hidden Apple metadata is excluded from all fingerprint inputs: `.DS_Store`, `.Spotlight-V100`, `.fseventsd`, and AppleDouble `._*` files.
- `FingerprintMatchState`: `.exact` (stored aggregate matches current), `.changedSinceLastSeen` (stored aggregate exists but differs), `.unknown` (no stored aggregate or location missing), `.ambiguous` (reserved; not actively resolved in Phase 4).
- `LibrarySourceRecord` and `LibrarySongRecord` carry `aggregateFingerprintString`, `wavInventorySummaryString`, `fingerprintGeneratedAt`, and `matchStateRawValue` fields (all optional; SwiftData lightweight migration).
- Fingerprints are computed on add/open/relocate and stored as `.exact`. On hydration, the stored aggregate is compared against a freshly computed aggregate; only `matchStateRawValue` is updated during hydration (stored fingerprint is preserved as the "last seen" baseline).
- Sidebar source rows and song rows append `· Exact match` or `· Changed since last seen` to secondary labels when match state is non-nil and non-unknown.
- No writes, renames, sidecar files, or backup manifests are created in source folders. SwiftData updates are app-owned.

### Persistence and Remembered Locations

- Opened sources and songs are persisted using **SwiftData** (`LibrarySourceRecord`, `LibrarySongRecord`) injected into `SourceLibraryStore` via `ModelContainer` from `PortastudioPreviewApp`.
- Security-scoped bookmarks are created and resolved by `SecurityScopedBookmarkService` (production) / `PassthroughBookmarkService` (test seam); source-root scans and fingerprint passes run while the selected root's security scope is active.
- On launch, `hydrateFromPersistence()` reloads all remembered sources and songs; records whose bookmark and fallback path both fail resolve as muted missing rows rather than being deleted.
- Source records cascade-delete their nested song records when forgotten.
- Standalone individual songs use `isStandalone = true` in the SwiftData model to distinguish them from source-nested songs.

### Sidebar Affordances

- **Available source rows**: context menu with **Reveal in Finder** and **Forget**.
- **Available individual song rows**: context menu with **Reveal in Finder** and **Forget**.
- **Missing source rows**: appear in the `Missing` section as muted rows; context menu with **Relocate...** and **Forget**.
- **Missing individual song rows**: same muted treatment and context menu as missing sources.
- `Relocate...` opens `NSOpenPanel`, classifies the chosen folder, validates kind-compatibility, updates bookmark/path/display data, and moves the row out of `Missing` if valid; wrong-kind selections leave the missing record intact and surface a load error.
- `Forget` removes only the SwiftData record; source files are never modified.

### Source Library (carried forward from Phase 2)

- `NavigationSplitView` uses a source-library sidebar with native `List(selection:)`, `Section`, and `DisclosureGroup` structure.
- **Add SD Card or Backup...** (`Command-Shift-O`) and toolbar button classify the chosen folder, persist a `LibrarySourceRecord`, scan `MUSIC/` for song folders, persist a `LibrarySongRecord` per song, and insert a nested source row.
- **Open Individual Song...** (`Command-O`) routes through `SourceFolderClassifier`, persists a standalone `LibrarySongRecord`, and loads the project via `ProjectFolderLoader`.
- Sources upsert by canonical URL so reopening the same root updates the existing row and bookmark without duplicating records.
- Selecting a nested source song loads the project on demand via `loadIfSourceSong()`, which now also covers hydrated standalone songs.
- `SourceFolderClassifier` ignores hidden Apple metadata (`.DS_Store`, `._*`, `.Spotlight-V100`, `.fseventsd`) and classifies by folder contents, not folder names.
- Classification: `.mediaRoot` requires `dp-24.sys` + `MUSIC/` + at least one valid song; `.backupRoot` requires `MUSIC/` + valid songs; `.songFolder` requires `song.sys` + `edltable.sys` directly inside.
- Source rows show a kind-specific icon and a secondary `SD Card · /path` or `Backup · /path` label.
- Automatic removable-media detection is not implemented (Phase 12).

Run focused suites:

```bash
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' test \
  -only-testing:PortastudioPreviewTests/EdlTableParserTests \
  -only-testing:PortastudioPreviewTests/StereoPreviewEngineTests
```

## Playback Behavior

Playback is read-only and deliberately limited to mappings supported by current evidence. Audio is withheld when file identity, region placement, or saved mute state is unresolved. EDL order, WAV length, and the Track 1 selector do not independently establish physical track, active take, or region placement. Unknown mute remains distinct from unmuted. Preview level, pan, mute, solo, and take selections are app-owned overrides; they are never written into Portastudio project files.

## Evidence and Research

Build and run the app without any sibling repository or device-capture files. The evidence summaries included here are indexed in [Docs/PortastudioResearchReferences.md](Docs/PortastudioResearchReferences.md). Raw device captures and the separate research corpus are intentionally not distributed with this app repository.

## Evidence Discipline

Use the evidence labels recorded in the research summaries:

- `Observed`
- `Correlated`
- `Confirmed`
- `Hypothesis`
- `Rejected`

Do not promote parser or playback behavior above the evidence level supported by tests and the documented research summaries.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
