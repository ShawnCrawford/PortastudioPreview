# Phase 7 Basic App-Owned Track Labels Implementation Plan

## Summary

Phase 7 adds the first editable user metadata layer: local track names and a small optional song display-name override. The work must keep every Portastudio source folder read-only by storing annotations only in app-owned SwiftData, keyed conservatively by song fingerprint plus track number, and by exposing editing through the Phase 6 inspector and existing source-library/detail surfaces.

## Scope

- In:
  - Add SwiftData-backed app-owned annotation storage for basic track names.
  - Add an optional app-owned song display-name override if it can be implemented without broad source-library churn.
  - Key track labels by stored song aggregate fingerprint plus physical track number.
  - Thread a selected-song annotation context from `SourceLibraryStore` / `ContentView` into `ProjectDetailView`.
  - Replace the Phase 6 disabled metadata placeholders in `TrackRegionInspectorView` with editable track-label controls when a stable song fingerprint is available.
  - Show track labels in `TrackTableView` and the inspector without hiding raw track/mixer evidence.
  - Keep annotation writes limited to SwiftData. Do not write sidecars or mutate `song.sys`, `edltable.sys`, WAV files, or source folder structure.
  - Add focused Swift Testing coverage for annotation keying, upsert behavior, persistence reload, and read-only source-folder guarantees.
  - Update README and roadmap docs after implementation with the actual files, data model, and behavior.
- Out:
  - Do not add track colors, notes, tags, reusable label templates, favorites, archive states, ambiguity-resolution history, iCloud sync, JSON export/import, or backup/export integration.
  - Do not implement fuzzy copied-song matching or user confirmation for ambiguous matches. Phase 7 should only auto-apply labels when the song fingerprint key is exact and available.
  - Do not change parser behavior, track-to-WAV assignment, EDL timeline inference, playback scheduling, or fingerprint generation semantics.
  - Do not add any write workflow that targets Portastudio media.

## Current Baseline

- `PortastudioPreviewApp` creates a SwiftData schema containing `LibrarySourceRecord` and `LibrarySongRecord`.
- `LibrarySongRecord` already stores `aggregateFingerprintString`, `wavInventorySummaryString`, `fingerprintGeneratedAt`, and `matchStateRawValue`.
- `SourceLibraryStore` is `@MainActor @Observable`, owns source/song lists, selection, current `PortastudioProject`, and a private `ModelContext?`.
- Source and standalone song fingerprints are persisted as `.exact` on add/open/relocate, and match state is recomputed during hydration.
- `ContentView` owns `@State private var store: SourceLibraryStore`, renders `ProjectDetailView(project:)` for `store.selectedProject`, and uses the store for add/open/load flows.
- `ProjectDetailView` owns Phase 6 view-local selection state and attaches `TrackRegionInspectorView` through SwiftUI `.inspector`.
- `TrackRegionInspectorView` currently shows a read-only "Future Metadata" section with disabled Phase 7 placeholder rows for track name and notes.
- `TrackTableView` is the canonical raw track/mixer table. It should remain evidence-first even after a label column is added.
- `PortastudioProject` does not carry `LibrarySongRecord` identity, source-library match state, or SwiftData model references.

## Implementation Direction

### Annotation Identity

- Add a pure value type in `Models/TrackAnnotationKey.swift` or `Models/SongAnnotationContext.swift`:
  - `songFingerprintString: String`
  - `trackNumber: Int`
  - optional `songRecordID: UUID`
  - optional `folderURL: URL`
  - optional `matchState: FingerprintMatchState`
- Treat `songFingerprintString + trackNumber` as the Phase 7 track-label key.
- Only enable editing when `songFingerprintString` is non-empty and the selected song has a reliable stored or freshly computed fingerprint.
- If the selected song has `.changedSinceLastSeen`, show the existing match state and allow editing only against the current stored fingerprint if the implementation can explain that clearly. The safer default is to show labels read-only/disabled with copy such as "Labels need an exact song match." Do not silently merge labels across changed fingerprints.
- If fingerprint data is missing for older records, compute and persist a song fingerprint while the app already has security-scoped access during open/load. Do this through existing `FingerprintService` paths; do not invent a second fingerprint format.

### SwiftData Model

- Add a new `@Model final class TrackAnnotationRecord` in `PortastudioPreview/Models/TrackAnnotationRecord.swift`.
- Suggested fields:
  - `@Attribute(.unique) var id: UUID`
  - `var songFingerprintString: String`
  - `var trackNumber: Int`
  - `var trackName: String`
  - `var createdAt: Date`
  - `var updatedAt: Date`
  - `var lastKnownSongDisplayName: String?`
  - `var lastKnownSongPath: String?`
  - optional `var songRecordID: UUID?` for diagnostics/direct lookup, not as the durable key
- Do not rely on a composite uniqueness constraint. Upsert by fetching records where `songFingerprintString` and `trackNumber` match.
- Add optional display-name override storage in the least disruptive place:
  - Preferred: add `var displayNameOverride: String?` to `LibrarySongRecord`, keeping `displayName` as the source/folder-derived name.
  - Use `displayNameOverride?.isEmpty == false ? displayNameOverride : displayName` for UI display.
  - If this creates too much migration/UI surface area, defer song display-name override and ship track names only; document that choice in README and roadmap.
- Update `PortastudioPreviewApp` schema and every in-memory test schema to include `TrackAnnotationRecord`.

### Annotation Store

- Add `PortastudioPreview/Services/TrackAnnotationStore.swift` as `@MainActor @Observable`.
- Responsibilities:
  - Hold the current `SongAnnotationContext?`.
  - Load all `TrackAnnotationRecord` rows matching the current `songFingerprintString`.
  - Expose `trackName(for trackNumber: Int) -> String?`.
  - Upsert/delete a track name when the user edits a label. Trim whitespace; an empty string should delete or clear the annotation record rather than persist meaningless labels.
  - Expose and persist `songDisplayNameOverride` only if that part is included.
  - Keep saves app-owned through `ModelContext.save()`.
- Keep this store focused on annotations. Do not fold it into parser services, playback, or source-folder loading.
- Prefer direct method calls from views or small bindings over giving SwiftUI views raw `ModelContext` fetch logic.

### Selected Song Context

- Add a computed method/property on `SourceLibraryStore`, for example `selectedSongAnnotationContext() -> SongAnnotationContext?`.
- For source-nested songs, locate the selected `SourceLibrarySong`, then fetch the corresponding `LibrarySongRecord` by `id` or path to read the stored aggregate fingerprint and display override.
- For standalone songs, do the same against `individualSongs` and `LibrarySongRecord`.
- Include `folderURL`, folder-derived display name, effective display name, match state, and `aggregateFingerprintString`.
- When `loadIfSourceSong()` successfully loads a nested source song, ensure the matching song record has a stored fingerprint. Source roots normally persist fingerprints during add/hydrate, but this protects older stores and partial migrations.
- Avoid passing `ModelContext` into `ProjectDetailView`; pass value context plus an annotation store instead.

### View Wiring

- Update `ContentViewBody` to own one `@State private var annotationStore: TrackAnnotationStore`.
- Initialize it with the same `modelContext` used by `SourceLibraryStore`.
- When `store.selection` or `store.selectedProject?.folderURL` changes, load the annotation context into the annotation store.
- Update `ProjectDetailView` initializer to accept:
  - `project: PortastudioProject`
  - `songAnnotationContext: SongAnnotationContext?`
  - `annotationStore: TrackAnnotationStore`
- Keep `ProjectDetailView` responsible for view-local track/region selection only; keep persistence in `TrackAnnotationStore`.
- Update `ProjectDetailView.navigationTitle` to use the effective song display name when available, falling back to `project.folderName`.
- Consider adding a compact "Name" row to the Overview section for the song display override. Avoid turning Phase 7 into a full metadata editor.

### Track Table

- Update `TrackTableView` to accept a label lookup closure or annotation store input.
- Add a leading or near-leading "Name" column:
  - Display the saved track name when present.
  - Display a muted dash or "Track N" fallback when absent.
- Preserve all existing raw byte, mixer, candidate WAV, and evidence columns.
- Do not make table cells editable in Phase 7 unless it is trivial and native. The inspector should be the primary edit surface.

### Inspector Editing

- Replace the current `Future Metadata` placeholder rows in `TrackRegionInspectorView` with a small editable `TrackLabelEditorView`.
- Track inspector behavior:
  - Show the current track name in a `TextField`.
  - Save through `TrackAnnotationStore` for the selected track number.
  - Show disabled explanatory copy when no reliable song fingerprint is available.
  - Keep candidate WAV/evidence, mixer bytes, active-take byte, and identity context visible.
- If song display-name override is included, expose it in either:
  - Overview group as a single text field, or
  - Inspector identity/metadata section as a selected-song field.
- Do not add a notes field in Phase 7 unless the user asks later; notes belong to Phase 13.
- Use `Button` for explicit clear/reset actions if provided. Do not use `onTapGesture`.

## Expected Files

### Likely new files

| File | Purpose |
| --- | --- |
| `Plans/Phase7BasicAppOwnedTrackLabels.md` | Durable implementation handoff plan |
| `PortastudioPreview/Models/TrackAnnotationRecord.swift` | SwiftData record for app-owned track labels |
| `PortastudioPreview/Models/SongAnnotationContext.swift` | Value context for selected song identity and effective display name |
| `PortastudioPreview/Models/TrackAnnotationKey.swift` | Optional pure key type if not folded into context |
| `PortastudioPreview/Services/TrackAnnotationStore.swift` | Main-actor annotation load/upsert/delete service |
| `PortastudioPreview/Views/TrackLabelEditorView.swift` | Optional small inspector editor if `TrackRegionInspectorView` starts to grow |
| `PortastudioPreviewTests/TrackAnnotationStoreTests.swift` | SwiftData persistence and keying tests |

### Likely modified files

| File | Change |
| --- | --- |
| `PortastudioPreview/App/PortastudioPreviewApp.swift` | Add `TrackAnnotationRecord` to the SwiftData schema |
| `PortastudioPreview/Models/LibrarySongRecord.swift` | Add optional song display-name override only if included |
| `PortastudioPreview/Models/SourceLibraryModels.swift` | Add effective display-name fields only if needed for sidebar rows |
| `PortastudioPreview/Services/SourceLibraryStore.swift` | Provide selected-song annotation context and ensure fingerprints are available |
| `PortastudioPreview/Views/ContentView.swift` | Own/pass `TrackAnnotationStore` and selected annotation context |
| `PortastudioPreview/Views/ProjectDetailView.swift` | Accept annotation context/store, pass label data into tables and inspector, use effective title |
| `PortastudioPreview/Views/TrackTableView.swift` | Add track-name display while preserving existing columns |
| `PortastudioPreview/Views/TrackRegionInspectorView.swift` | Replace placeholders with editable local track-label UI |
| `PortastudioPreview/Views/SourceLibrarySidebarView.swift` | Show song display-name override if Phase 7 includes that field |
| `PortastudioPreviewTests/SourceLibraryStoreTests.swift` | Update test schema and add context/fingerprint coverage |
| `Docs/ProductVisionAndRoadMapPlanning.md` | Mark Phase 7 implemented after completion and summarize behavior |
| `Docs/ProductVisionAndRoadmap.md` | Update baseline and roadmap Phase 7 status after implementation |
| `README.md` | Document Phase 7 behavior and read-only annotation storage after implementation |

## Testing Plan

- Add `TrackAnnotationStoreTests` using an in-memory `ModelContainer` with `LibrarySourceRecord`, `LibrarySongRecord`, and `TrackAnnotationRecord`.
- Cover:
  - loading an empty context returns no labels.
  - saving a track name creates one `TrackAnnotationRecord`.
  - saving the same track again updates the existing record instead of duplicating it.
  - clearing a track name removes or empties the persisted annotation according to the chosen store behavior.
  - labels with the same song fingerprint but different track numbers do not collide.
  - labels with different song fingerprints do not bleed across songs.
  - a newly created `TrackAnnotationStore` reloads previously saved labels from SwiftData.
  - missing or empty song fingerprint disables/ignores writes.
  - song display-name override persists and falls back to folder-derived name when cleared, if included.
- Extend `SourceLibraryStoreTests` for selected annotation context:
  - standalone selected song returns context with stored aggregate fingerprint.
  - source-nested selected song returns context with stored aggregate fingerprint.
  - no selected song or missing fingerprint returns nil or non-editable context as designed.
- Use `FileReadOnlyGuard` in at least one annotation test to prove editing labels does not modify the selected Portastudio folder.
- Do not add brittle SwiftUI snapshot tests. If label formatting is factored into pure helper types, test those helpers.
- Validation commands:

```bash
xcodebuild -list -project PortastudioPreview.xcodeproj
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' build
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' test
```

## Manual Acceptance Criteria

- Open an individual song, select a track, type a track name in the inspector, switch tracks, and confirm the name appears in the track table and returns when reselecting the track.
- Quit and relaunch the app; reopen or select the same remembered song and confirm the track label persists.
- Add or select a source root song with the same stored song fingerprint and confirm labels attach by fingerprint plus track number.
- Select a different song with a different fingerprint and confirm labels do not appear there.
- Clear a track label and confirm it disappears from the inspector/table after reload.
- If song display-name override is included, edit it and confirm the navigation title and relevant sidebar/detail display use the override while the original folder path/name remains visible somewhere in the UI.
- Disconnect or move a remembered folder and confirm labels remain app-owned history; missing-location rows still behave as before.
- Compare a before/after `FileReadOnlyGuard` snapshot or manual folder diff and confirm no Portastudio files changed after editing labels.

## Evidence Discipline

- Keep labels visibly app-owned. Avoid copy that implies labels are stored on the TASCAM device.
- Keep track-to-WAV assignment labeled `Hypothesis` wherever candidate WAV or timeline inference is discussed.
- Do not use labels as evidence for parser behavior, active-take mapping, or WAV assignment.
- Use evidence labels exactly as documented: `Observed`, `Correlated`, `Confirmed`, `Hypothesis`, and `Rejected`.
- If a song fingerprint changed since last seen, do not silently apply annotations to a new fingerprint. Defer ambiguity handling to Phase 13 unless the user explicitly confirms a match in a later phase.

## Risks and Guardrails

- SwiftData schema changes can break tests if every in-memory schema is not updated. Search for all `Schema([LibrarySourceRecord.self, LibrarySongRecord.self])` instances and add `TrackAnnotationRecord.self`.
- `ProjectDetailView` currently lacks persisted song identity. Do not work around this by recomputing identity in the view. Thread a small context from the store layer.
- Avoid bloating `SourceLibraryStore` with annotation CRUD. It can expose selected-song context, but annotation persistence should live in `TrackAnnotationStore`.
- Do not make the inspector depend on a source-library row being selected forever. A loaded project plus annotation context should be enough for editing while the project remains visible.
- Avoid saving empty labels or whitespace-only names.
- Keep the UI native and compact: inspector text fields, table display, and optional clear button. Do not add a metadata dashboard in Phase 7.
- Do not introduce third-party dependencies.

## Assumptions

- Phase 1 through Phase 6 are implemented as documented on May 7, 2026.
- The app remains macOS-only, Swift 6.2+, SwiftUI-first, and SwiftData-backed.
- The target does not use SwiftData CloudKit, so the existing project pattern of unique UUID identifiers remains acceptable.
- New Swift source files are picked up by the existing Xcode project structure without manual project-file edits; verify with `xcodebuild`.
- This saved plan does not implement Phase 7 app code. The implementing thread must update docs with actual behavior after code lands.
