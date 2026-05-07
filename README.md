# PortastudioPreview

PortastudioPreview is a macOS SwiftUI prototype for read-only preview of TASCAM DP-32SD song folders, with an app-owned source library that remembers opened SD card roots, backup roots, and individual songs across relaunches.

The app is designed for safe inspection and approximate playback during reverse-engineering. It does not write to project folders.

## Goals

- Add an SD card root or backup folder and browse all its songs.
- Open an individual DP-32SD song folder.
- Classify selected folders conservatively as media roots, backup roots, or song folders.
- Parse `song.sys` and `edltable.sys` with evidence-scoped behavior.
- Show track-level mixer bytes and candidate WAV inventory.
- Provide approximate stereo playback for quick validation.
- Remember opened sources and songs using SwiftData and security-scoped bookmarks.
- Show missing remembered locations as muted rows with Relocate and Forget affordances.

## Non-Goals

- No project mutation, export, or normalization.
- No destructive operations on sample folders.
- No claims above documented evidence levels.
- No automatic removable-media detection (Phase 12).
- No source/song fingerprinting or identity matching (Phase 4).

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

## Current App Shell (Phase 3)

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

Preview playback is intentionally conservative.

- Track-to-WAV mapping remains `Hypothesis`; sorted filename-to-track assignment is `Rejected` as evidence.
- Track rows show mixer evidence, but WAVs are previewed as unassigned regions unless a future parser has correlated physical-track mapping.
- Unassigned regions use EDL file-list order when available, neutral center pan, and unity gain.
- Track 1 active virtual-take playback is applied where current captures support it. `edltable.sys` byte `0x00B01A38` is correlated with Track 1 active take; `SONG_0084` uses `0x01` and previews only `ZZ0002_1.wav`, even though all three WAV filenames end in `_1.wav`.
- Filename suffixes such as `_1` and `_2` are not sufficient active-take evidence. Current playback first handles same-stem take alternatives, then falls back to the `SONG_0084` EDL file-list pattern for Track 1 VT2.
- Mute/Pan/Level handling is approximate and evidence-scoped. Track 1 and Track 2 mute bytes are correlated; raw fader `0x00` is not treated as silence.
- Timeline offsets inferred from `edltable.sys` are treated as `Hypothesis` 44.1k sample-domain candidates.
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
