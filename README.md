# PortastudioPreview

PortastudioPreview is a macOS SwiftUI prototype for read-only preview of TASCAM DP-32SD song folders, with an app-owned source library that remembers opened SD card roots, backup roots, and individual songs across relaunches.

The app is designed for safe inspection and stereo preview playback of validated DP-32SD project mappings. It does not write to project folders.

## Goals

- Add an SD card root or backup folder and browse all its songs.
- Open an individual DP-32SD song folder.
- Classify selected folders conservatively as media roots, backup roots, or song folders.
- Parse `song.sys` and `edltable.sys` with evidence-scoped behavior.
- Show track-level mixer bytes and confirmed WAV assignments.
- Provide read-only stereo preview playback using confirmed track-to-WAV, timeline, mute, pan, and level mapping.
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

## Build and Test

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
- `TrackRegionInspectorView` replaces the Phase 6 placeholder rows with a `TrackLabelEditorView` in a "Label" section. The editor saves on Return and on focus loss; when `isEditable` is false, the field is read-only with an orange warning when the fingerprint has changed.
- Song display-name override is stored in `LibrarySongRecord.displayNameOverride`. The nav title and overview section show the override name when set.
- The app schema includes `TrackAnnotationRecord.self` in the `ModelContainer` schema alongside `LibrarySourceRecord` and `LibrarySongRecord`.

### Track Selection and Inspector (Phase 6)

- `ProjectDetailView` owns `selectedTrackID` and `selectedRegionID` as view-local `@State`. Selecting a track clears any active region selection, and selecting a region clears track selection.
- `TrackTableView` is now selection-aware via a `@Binding var selectedTrackID` passed from `ProjectDetailView`. The `Table(tracks, selection:)` initializer enables single-row click selection while preserving all existing track/mixer columns.
- The unassigned-region table inside `RegionsTimelineGroupBoxView` is similarly selection-aware via `@Binding var selectedRegionID`.
- `TrackRegionInspectorView` is a native right-side inspector attached with `.inspector(isPresented:)`. It displays:
  - **Empty state**: neutral prompt when nothing is selected.
  - **Track inspector**: track number, assigned WAV (filename or "Unassigned" with evidence), level/pan/mute mapped values, raw byte offsets, mirror raw bytes and mismatch warnings, active-take byte and offset (track 1 only, Correlated evidence), identity context for the Phase 7 annotation key (song fingerprint + track number), and the current Phase 7 app-owned track-label editor.
  - **Region inspector**: source filename and path, start/length/end samples with time strings, evidence level, EDL file-list ID and evidence when the source filename matches a `fileListEntries` entry, and assignment status.
- Inspector width is 240–360 pt. A toolbar button toggles it with `sidebar.right` icon.
- Evidence labels follow research-repo conventions exactly: `Observed`, `Correlated`, `Confirmed`, `Hypothesis`, `Rejected`. No evidence is promoted beyond levels already encoded in current models.
- The inspector remains read-only toward Portastudio files. Phase 7 annotation edits are app-owned SwiftData writes only; no sidecar files or source-folder mutations are created.

### Waveform and Timeline Visualization (Phase 15)

- Detailed handoff plan: `Plans/Phase15WaveformAndTimelineVisualization.md`.
- Phase 15 has been promoted into the first-release visual polish path so the selected-song workspace shows a credible waveform/timeline view before shipping.
- **`TimelineVisualizationView`**: Inserted above the existing region table in `RegionsTimelineGroupBoxView`. Shows colored waveform lanes per region, a time ruler, zoom controls (Fit / Zoom In / Zoom Out), and a playhead overlay while audio is playing.
- **Waveform rendering**: `WaveformCanvasView` uses SwiftUI `Canvas` to render per-region peak summaries. Peak data is derived in-memory from the source WAV via `WaveformPeakBuilder` (AVAudioFile, 8192-frame chunk reads). Playable regions show colored waveforms; suppressed regions show a muted dashed-border lane with reason badge; missing-source and ambiguous-timing lanes are styled distinctly.
- **Playback controller refactor**: `PreviewPlaybackController` (`@Observable @MainActor`) now owns the `StereoPreviewEngine` instance and exposes `isPlaying`, `elapsedSeconds`, and `playbackError`. It is held as `@State` in `ProjectDetailView` and shared to both the transport view and the timeline view.
- **Paused mix edits**: Level, pan, mute, and solo-derived mute changes are pushed to the live preview engine while playback is paused, so resuming playback uses the current mixer state instead of stale values.
- **Playhead**: Drawn as a ZStack overlay in `TimelineVisualizationView` only when `isPlaying`. Position derived from `elapsedSeconds × sampleRate` mapped through `sampleToX(...)`.
- **Selection wiring**: Lane rows are tappable; selecting a lane sets `selectedRegionID` and clears `selectedTrackID` via the existing binding. The inspector shows the selected region.
- **Zoom range**: `[1.0, 10.0]×`; base canvas width 900 pt. Zoom state is local to `TimelineVisualizationView`.
- **Evidence guardrails**: Timeline builder uses `.ambiguousTiming` when all regions share `startSample == 0`. Track-to-WAV assignment and timeline offsets are confirmed for V1. No waveform caches or sidecar files are ever written to source folders.
- **Tests added** (all passing):
  - `WaveformPeakBuilderTests` (7 tests): silent WAV → zero peaks, non-silent → non-zero, bucket count capped, single frame, unreadable file throws, metadata correctness, read-only safety.
  - `TimelineVisualizationBuilderTests` (24 tests): empty project, zero/delayed/multi-region extent, missing length, ambiguous/suppressed/missing-source states, selection marking and lane order, zoom clamp, ruler ticks, `sampleToX` at boundary/midpoint values.

### Song Detail Workspace (Phase 5)

- `ProjectDetailView` is now a scrollable selected-song workspace with native `GroupBox` sections for **Overview**, **Validation**, **Tracks**, **Regions / Timeline**, and **Preview**.
- Overview adds view-only summary metrics (folder/path, track count, WAV count, validation issue count, unassigned region count, EDL file-list count, timeline candidate count, preview availability) derived from existing models.
- Track and region research/debug visibility remains intact: `TrackTableView` is still the canonical raw track/mixer table, and unassigned region rows remain visible with evidence labels.
- Regions/timeline summary includes sample positions plus readable time text.
- Preview transport remains read-only with unchanged Play/Stop semantics and clearer disabled/empty-state copy when no playable WAV regions are available.

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
- Security-scoped bookmarks are created and resolved by `SecurityScopedBookmarkService` (production) / `PassthroughBookmarkService` (test seam).
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

## Playback Behavior (Current)

Preview playback is read-only and evidence-scoped.

- Track-to-WAV mapping is confirmed from EDL file-list position to physical track.
- Track rows show mixer evidence, assigned WAVs, and active virtual-take options where available.
- Remaining unassigned regions use EDL file-list order when available, neutral center pan, and unity gain.
- Track 1 active virtual-take playback is applied where current captures support it. `edltable.sys` byte `0x00B01A38` is correlated with Track 1 active take; `SONG_0084` uses `0x01` and previews only `ZZ0002_1.wav`, even though all three WAV filenames end in `_1.wav`.
- Filename suffixes such as `_1` and `_2` are not sufficient active-take evidence. Current playback first handles same-stem take alternatives, then falls back to the `SONG_0084` EDL file-list pattern for Track 1 VT2.
- Mute, pan, and level playback uses the confirmed mixer byte mappings currently implemented by the app. Raw fader `0x00` is not treated as unity; it maps to minimum gain.
- Mix changes made while playback is paused are applied to the live engine before resume; idle changes remain stored only as pending overrides until playback starts.
- Timeline offsets parsed from `edltable.sys` are confirmed 44.1k sample-domain positions.
- Playback start normalization is applied so the earliest scheduled region starts at preview time zero while preserving relative offsets between tracks.

This avoids long initial silence when inferred anchors are far from zero (for example delayed clips around the 50-second region).

## Research Dependency

Canonical reverse-engineering evidence lives in the sibling repo:

- `/Users/shawn/Projects/SwiftUI/PortastudioResearch`

Use `Docs/PortastudioResearchReferences.md` in this repo as the local index.

For a read-only manual audit of current fader bytes, EDL file-list order, and WAV inventory/lengths, run:

```bash
/Users/shawn/Projects/SwiftUI/PortastudioResearch/Scripts/Prototypes/preview_sample_audit.py --generated-date 2026-05-06
```

## Evidence Discipline

Use the evidence labels exactly as defined in the research repo:

- `Observed`
- `Correlated`
- `Confirmed`
- `Hypothesis`
- `Rejected`

Do not promote parser or playback behavior above the evidence level currently supported by tests and research artifacts.
