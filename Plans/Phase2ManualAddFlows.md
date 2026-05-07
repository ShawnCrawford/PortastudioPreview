# Phase 2 Manual Add Flows Implementation Plan

## Summary
Phase 2 adds user-driven "Add SD Card or Backup..." and "Open Individual Song..." flows, classifies selected folders conservatively, and populates the existing Phase 1 source library without persistence, bookmarks, or automatic removable-media detection.

## Key Changes

### SourceFolderClassifier (new, `Services/`)
Classify selected folders as:
- `.songFolder` — folder contains `song.sys` and `edltable.sys`.
- `.mediaRoot` — folder contains `dp-24.sys`, `MUSIC/`, and at least one direct child song folder under `MUSIC/`.
- `.backupRoot` — folder has a full-card-like `MUSIC/` structure with song folders but does not satisfy the stronger `dp-24.sys` media-root signal.
- `.unsupported` — anything else; carries a user-facing reason string.

Classification rules:
- Ignore hidden Apple/system metadata: `.Spotlight-V100`, `.fseventsd`, `.DS_Store`, AppleDouble `._*` files.
- Treat valid song folders by contents (`song.sys` + `edltable.sys`), not names. Names may be numeric, user-named, contain spaces, or use variant-looking prefixes.
- All selected folders remain read-only. Do not write, rename, normalize, bookmark, persist, hash whole WAVs, or copy files.

## Implementation Changes

### `SourceLibraryModels`
- Add a `SourceKind` enum with cases `.mediaRoot` and `.backupRoot`.
- Add `folderURL: URL`, `kind: SourceKind`, and a load/classification state to `SourceLibrarySource`.
- Keep `SourceLibrarySong` usable for both nested source songs and standalone individual songs.

### `SourceLibraryStore`
- Add `addSourceRoot(at: URL) async` for SD card/backup selection.
- Keep `openIndividualSongFolder(at: URL) async`, routing it through classification first so unsupported folders surface a clear error.
- For source roots, scan only `MUSIC/` direct child folders containing `song.sys` and `edltable.sys`, create nested song rows, select the added source, and do not auto-load every song project.
- Add a selection-loading path so selecting a nested source song loads that song through `ProjectFolderLoader`.
- Upsert sources by canonical URL to avoid duplicates; reopening the same root updates the row and song list.

### `ContentView` and App Commands
- Add toolbar button "Add SD Card or Backup..." using SF Symbol `externaldrive.badge.plus`.
- Keep "Open Individual Song..." toolbar button and `Command-O`.
- Add a menu command "Add SD Card or Backup..." with shortcut `Command-Shift-O`.
- Use separate focused actions for add-source and open-song flows.

### `ProjectOpenView`
- Present both primary actions when no project is selected.
- Copy should explain that adding a source scans a card/backup root, while opening a song loads one project folder.

### `SourceLibrarySidebarView`
- Render SD cards/backups with native source-list rows and a short secondary path/kind label.
- Render nested songs under disclosure rows.
- Keep empty and error states lightweight and native.
- Do not add persistence/missing-location UX yet beyond existing placeholder section.

## Tests

### Classifier Tests (`SourceFolderClassifierTests`)
- Valid individual song folder → `.songFolder`.
- Media root with `dp-24.sys`, `MUSIC/`, and one or more valid songs → `.mediaRoot`.
- Backup root with `MUSIC/` and valid songs but no `dp-24.sys` → `.backupRoot`.
- Root with `AudioDepot/` and `UTILITY/` present but no valid songs → `.unsupported`.
- Song folders with spaces or non-`SONG_####` names are accepted (classified by contents).
- Hidden Apple metadata (`.DS_Store`, `._*`, `.Spotlight-V100`, `.fseventsd`) is ignored during classification.

### Store Tests (`SourceLibraryStoreTests` additions)
- Adding a media root creates one source row with nested songs and no standalone duplicates.
- Adding a backup root creates a backup source row.
- Reopening the same source URL updates the existing row without adding a duplicate source entry.
- Opening an individual song still inserts/selects one standalone song.
- Unsupported folder records an error and leaves existing library state unchanged.
- Classification/loading does not write to selected folders (enforced via `FileReadOnlyGuard`).

### Unchanged
- All existing parser tests (`SongSysParserTests`, `EdlTableParserTests`, `ByteReaderTests`).
- All existing playback tests (`StereoPreviewEngineTests`, `PreviewPlaybackPlannerTests`).
- All existing integration and audit tests.

## Validation

### Build and Test Commands
```
xcodebuild -list -project PortastudioPreview.xcodeproj
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' build
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' test
```

### Manual Acceptance Criteria
- App launches with Phase 1 sidebar intact.
- "Add SD Card or Backup..." accepts a full-card-like root and shows songs under the SD Cards & Backups section.
- "Open Individual Song..." accepts one song folder and shows it under Individual Songs.
- Selecting a nested source song loads the existing `ProjectDetailView`.
- Unsupported folders show a clear non-destructive error; no state changes.
- No Portastudio source folder contents change after classification or loading.

## Assumptions
- `Plans/Phase2ManualAddFlows.md` is the target saved artifact.
- Phase 2 remains in-memory only; security-scoped bookmarks and remembered missing locations start in Phase 3.
- Phase 2 does not implement automatic mounted-media detection.
- Phase 2 does not implement fingerprints, identity matching, backup, export, AudioDepot browsing, or SwiftData.
- New Swift source files are picked up by existing Xcode synchronized root groups without manual project-file edits.
