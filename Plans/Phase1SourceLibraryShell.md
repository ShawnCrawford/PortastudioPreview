# Phase 1 Source Library Shell Implementation Plan

## Scope
- Replace summary-only sidebar with a source-library sidebar shell using `NavigationSplitView`, native `List(selection:)`, `Section`, and `DisclosureGroup`.
- Keep all Portastudio parsing and project loading read-only and evidence behavior unchanged.
- Implement in-memory-only source library state for Phase 1 (no persistence, bookmarks, or classification).

## Data Model
- Add `SourceLibrarySelection` to support stable navigation selection across source nodes, individual songs, and missing items.
- Add `SourceLibrarySource` for SD card/backup display nodes with expandable song children.
- Add `SourceLibrarySong` for individual song entries, folder URL identity, display name, and load state.
- Add `SourceLibraryMissingItem` for muted placeholder-ready missing entries used by later phases.

## Store
- Add `@MainActor @Observable SourceLibraryStore` owning:
  - `sources`
  - `individualSongs`
  - `missingItems`
  - `selection`
  - `selectedProject`
  - `isLoading`
  - `loadError`
- Implement async `openIndividualSongFolder(at:)` that:
  - loads via `ProjectFolderLoader`
  - inserts/updates an `Individual Songs` row keyed by canonical folder URL
  - selects that row
  - updates `selectedProject` and error state

## UI
- Add `SourceLibrarySidebarView` with sections:
  - `SD Cards & Backups` (visible with muted native empty row; structural disclosure support)
  - `Individual Songs` (loaded rows + status/path secondary line)
  - `Missing` (visible with muted native empty row)
- Keep sidebar rows native and lightweight: one symbol + title + optional secondary line.
- Keep existing detail flow: selected project renders existing `ProjectDetailView`; empty detail prompts opening an individual song.
- Update app command and toolbar wording to `Open Individual Song...` while retaining `Command-O`.

## Tests
- Add `SourceLibraryStoreTests` (Swift Testing):
  - initial empty section state
  - successful open inserts one song row, selects it, and exposes loaded project
  - reopening same folder updates/selects existing row without duplicates
  - load failure records error and does not modify files in selected parent folder
- Continue running existing parser/read-only test suite including `loadingFolderDoesNotWriteCreateRenameOrDeleteFiles`.

## Validation
- `xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' build`
- `xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' test`
- Manual acceptance:
  - app launches with source-library sidebar sections
  - `Command-O` opens song folder picker
  - opened folder appears under `Individual Songs`
  - selection shows existing `ProjectDetailView`
