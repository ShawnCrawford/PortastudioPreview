# Phase 3 Remembered Locations MVP Implementation Plan

## Summary
Phase 3 adds app-owned persistence for manually opened SD/backup roots and individual songs, using SwiftData plus security-scoped bookmarks, while keeping all Portastudio folders read-only and leaving fingerprints/matching for Phase 4.

## Key Changes
- Add SwiftData persistence for remembered library entries:
  - `LibrarySourceRecord`: `id`, `displayName`, `kindRawValue`, `lastKnownPath`, `bookmarkData`, `isMissing`, `lastSeenAt`, `songs`.
  - `LibrarySongRecord`: `id`, optional `source` relationship, `displayName`, `lastKnownPath`, `bookmarkData`, `isMissing`, `isStandalone`, `lastSeenAt`.
  - Persist nested source songs discovered under source roots and standalone individual songs separately.
- Add a `SecurityScopedBookmarkService` in `Services/` to create, resolve, and refresh bookmarks; expose deterministic test seams so unit tests can avoid real security scope dependence.
- Refactor `SourceLibraryStore` to hydrate from SwiftData at launch, persist successful `addSourceRoot(at:)` and `openIndividualSongFolder(at:)`, and mark unresolved records as missing instead of deleting them.
- Extend source/song models with stable persisted IDs and missing-state fields; keep the existing `SourceLibrarySelection` shape, but ensure selections can survive reload through persisted IDs.
- Add sidebar affordances:
  - Missing rows stay visible and muted in the `Missing` section.
  - `Reveal in Finder` for available source/song rows.
  - `Forget` removes only the app-owned SwiftData record.
  - `Relocate` lets the user pick a new folder, reclassifies it, refreshes bookmark/path/display data, and moves the row out of Missing if valid.
- Wire context menus and detail/empty-state buttons using native macOS SwiftUI patterns; keep toolbar/menu add/open actions from Phase 2 unchanged.

## Implementation Notes
- Use SwiftData because the roadmap explicitly chooses it and the project targets modern macOS (`MACOSX_DEPLOYMENT_TARGET = 26.4`).
- Inject `ModelContainer` from `PortastudioPreviewApp`; use an in-memory container in tests.
- Preserve current read-only guarantees: no writes, renames, normalization, hashes, copies, or metadata files inside selected Portastudio folders.
- Resolving a bookmark should call `startAccessingSecurityScopedResource()` only around classification/loading/scanning work and always balance it with `stopAccessingSecurityScopedResource()`.
- Relocate must validate the chosen folder with `SourceFolderClassifier`:
  - Missing source records accept `.mediaRoot` or `.backupRoot`.
  - Missing individual-song records accept `.songFolder`.
  - Unsupported or wrong-kind folders show a clear error and leave the old missing record intact.
- Do not implement Phase 4 fingerprints, copied-source matching, automatic removable-media detection, backup/export, annotations, AudioDepot browsing, or change detection.

## Test Plan
- Add `RememberedLocationStoreTests` with in-memory SwiftData:
  - successful source add persists source plus nested songs.
  - successful individual song open persists one standalone song.
  - store initialization hydrates persisted rows after simulated relaunch.
  - unresolved bookmark/path becomes a muted missing item and is not deleted.
  - forget removes the persisted record without touching source files.
  - relocate updates bookmark/path/display data only after classifier validation.
  - wrong-kind relocate keeps the missing record and records an error.
  - repeated open/add upserts existing persisted records without duplicates.
  - read-only guard still proves selected folders are unchanged.
- Keep existing parser/playback/classifier tests unchanged.
- Validate with:
  - `xcodebuild -list -project PortastudioPreview.xcodeproj`
  - `xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' build`
  - `xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' test`

## Manual Acceptance
- Add an SD/backup root, quit/relaunch, and confirm it reappears with nested songs.
- Open an individual song, quit/relaunch, and confirm it reappears under `Individual Songs`.
- Move or disconnect a remembered folder, relaunch, and confirm it appears under `Missing` with plain missing-location copy.
- Use `Relocate` to point a missing item to the valid moved folder and confirm it becomes available again.
- Use `Forget` and confirm only app memory is removed; the original folder contents are unchanged.
- Use `Reveal in Finder` on available rows and confirm Finder opens the remembered location.

## Assumptions
- Target saved artifact: `Plans/Phase3RememberedLocationsMVP.md`.
- Phase 2 is already implemented as documented in `Plans/Phase2ManualAddFlows.md`.
- New Swift files are picked up by the existing Xcode file-system-synchronized groups without manual project-file edits.
- Missing-state identity is path/bookmark based only in Phase 3; source/song fingerprints begin in Phase 4.
