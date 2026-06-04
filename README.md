# PortastudioPreview

PortastudioPreview is a macOS SwiftUI prototype for read-only preview of TASCAM DP-32SD song folders, with an app-owned source library that remembers opened SD card roots, backup roots, and individual songs across relaunches.

The app is designed for safe inspection, annotation, and stereo preview playback of validated DP-32SD project mappings. It does not write to project folders.

## Goals

- Add an SD card root or backup folder and browse all its songs.
- Open an individual DP-32SD song folder.
- Classify selected folders conservatively as media roots, backup roots, or song folders.
- Parse `song.sys` and `edltable.sys` with evidence-scoped behavior.
- Show only recorded/resolved channels in the mixer (assigned WAV or virtual-take options), with musician-facing track info first and parser diagnostics in expandable technical details.
- Provide read-only stereo preview playback using confirmed track-to-WAV, timeline, mute, pan, and level mapping.
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

The app is now organized around a source library plus a focused selected-song mixer workspace.

- `ContentView` owns the source-library shell and routes selection to either `ProjectOpenView`, `SourceSelectedView`, or `ProjectDetailView`.
- `SourceLibraryStore` handles remembered source/song hydration, add/open flows, relocate/forget, fingerprints, and missing-location state.
- `ProjectPreviewBuilder` assembles the read-only `PortastudioProject` by scanning WAV inventory, parsing `song.sys` and `edltable.sys`, assigning EDL file-list positions to tracks, creating virtual-take options, and inferring timeline regions.
- `PortastudioProject.tracks` keeps full parser scope (physical tracks), while `visibleMixerChannels` filters to displayable recorded channels for the UI mixer.
- `ProjectDetailView` owns selected-track state, inspector visibility, `PreviewPlaybackController`, `PreviewMixState`, and selected virtual-take IDs for the loaded song.
- `ProjectWorkspaceView` is the primary song UI: a cohesive utility header plus a horizontal mixer deck where selected channels receive subtle native emphasis and fader/meter controls remain the primary visual focus.
- `TrackRegionInspectorView` is the native right-side inspector for song summary, selected-track identity/audio/mix values, app-owned track labels, audio file list, Reveal in Finder, and reset selected channel, with parser-level data under a collapsed Technical Details disclosure.
- `PreviewMixState` persists app-owned preview overrides in SwiftData through `MixOverrideRecord`; source folders remain read-only.
- `PreviewPlaybackController` and `StereoPreviewEngine` own playback lifecycle, live mixer updates, selected virtual-take playback, elapsed time, per-track/output meters, and error state.
- `TimelineVisualizationBuilder` and `WaveformPeakBuilder` remain pure/read-only services for waveform and timeline presentation data. Keep waveform data in memory; do not write waveform caches next to Portastudio files.

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

### Waveform and Timeline Visualization (Phase 15)

- Detailed handoff plan: `Plans/Phase15WaveformAndTimelineVisualization.md`.
- Phase 15 currently has the read-only model/service foundation in the app source, while the visible selected-song workspace is mixer-first.
- **Timeline data**: `TimelineVisualizationBuilder` converts `PortastudioProject` plus playback-plan suppression into `TimelineVisualizationModel`, including lane order, extents, ruler ticks, zoom helpers, selection flags, and suppressed/missing/ambiguous states.
- **Waveform peaks**: `WaveformPeakBuilder` derives in-memory peak summaries from source WAVs with AVFoundation. No waveform caches or sidecar files are written to source folders.
- **Playback controller refactor**: `PreviewPlaybackController` (`@Observable @MainActor`) owns the `StereoPreviewEngine` instance and exposes playback state, elapsed seconds, errors, output meters, and track meters to the mixer workspace.
- **Live mix edits**: Level, pan, mute, and solo-derived mute changes are pushed to the live preview engine, so resumed or running playback reflects current app-owned mix state.
- **UI status**: SwiftUI timeline/waveform views are not present in the current app source. Future agents implementing them should reuse the existing builders instead of duplicating timeline math or WAV peak extraction.
- **Tests added**:
  - `WaveformPeakBuilderTests` (7 tests): silent WAV → zero peaks, non-silent → non-zero, bucket count capped, single frame, unreadable file throws, metadata correctness, read-only safety.

### Song Detail Workspace (Current)

- `ProjectDetailView` presents a focused selected-song workspace: song header, read-only playback controls, live output/track meters, horizontal mixer, and native inspector.
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

## Playback Behavior (Current)

Preview playback is read-only and evidence-scoped.

- Track-to-WAV mapping is confirmed from EDL file-list position to physical track.
- Track rows show mixer evidence, assigned WAVs, and active virtual-take options where available.
- The selected-song mixer lets the user choose available virtual takes. If changed during playback, playback reloads while preserving position.
- Level, pan, mute, solo, and selected virtual take are persisted as app-owned preview overrides only when the song annotation context is editable (`Exact match` fingerprint).
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
