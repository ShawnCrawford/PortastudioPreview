# Product Vision and Roadmap Planning

This plan splits the roadmap into **Part 1: first shippable product experience** and **Part 2: pre-release/after-release expansion**. Part 1 focuses on making the current parser MVP feel like a useful native macOS app. Part 2 keeps the larger management workflows planned, but avoids blocking the first round of implementation.

Update on May 7, 2026: Phase 15 is promoted into the first-release visual polish path because waveform and timeline presentation are needed for the app to feel credible at release. The phase number is preserved so it stays aligned with the broader roadmap, but its implementation should happen before the first release while backup/export/restore work remains separate.

## Scope

- In: A phased roadmap that can be turned into separate implementation plans by AI agents.
- Out: Treating backup/restore, AudioDepot writes, automatic removable-media detection, and full export workflows as first-round blockers.

## Part 1: First-Round Implementation

### Phase 1: Source Library Shell

Replace the current summary sidebar with a source library using `NavigationSplitView`, `List(selection:)`, `Section`, and expandable source rows. Include groups for SD card/backups, individual songs, and missing remembered items.

Status (implemented on May 7, 2026): in-memory source library shell is now active with `Open Individual Song...` wired through the existing read-only loader flow.

### Phase 2: Manual Add Flows

Add "Add SD Card or Backup" and "Open Individual Song" actions. Classify selected folders as media roots, backup roots, or song folders using expected Portastudio files and folders, but keep this user-driven.

### Phase 3: Remembered Locations MVP

Persist opened sources and songs with display name, source kind, last-known path, and security-scoped bookmark data. Show missing locations as muted rows with basic Forget and Relocate affordances.

Status (implemented on May 7, 2026): SwiftData persistence is now active. `LibrarySourceRecord` and `LibrarySongRecord` are persisted via `ModelContainer` injected from `PortastudioPreviewApp`. `SourceLibraryStore` hydrates from SwiftData at launch, upserts on add/open, marks unresolvable records as missing without deleting them, and exposes `forgetSource`, `forgetSong`, `relocateSource`, and `relocateSong`. `SecurityScopedBookmarkService` creates and resolves security-scoped bookmarks; `PassthroughBookmarkService` provides a test seam. Sidebar shows muted missing rows with Relocate and Forget context menus, and Reveal in Finder on available rows. `RememberedLocationStoreTests` covers all plan scenarios with an in-memory `ModelContainer`.

### Phase 4: Source/Song Fingerprint MVP

Create lightweight fingerprints for source roots and songs using folder names, root structure, `song.sys`, `edltable.sys`, and WAV inventory metadata. Use this only for display and conservative matching, not backup safety yet.

Status (implemented on May 7, 2026): `FingerprintService` computes SHA-256 hashes for `dp-24.sys`, `song.sys`, and `edltable.sys`, and builds metadata-only WAV inventory fingerprints (relative path, byte count, modification date; no WAV content hashing). `FingerprintMatchState` enum covers `.exact`, `.changedSinceLastSeen`, `.ambiguous` (reserved), and `.unknown`. Fingerprint fields added to `LibrarySourceRecord` and `LibrarySongRecord` via SwiftData lightweight migration. `SourceLibraryStore` persists fingerprints on add/open/relocate and computes match state on hydration. Sidebar rows show `· Exact match` or `· Changed since last seen` in secondary labels. All source folders remain read-only; no sidecar files or manifests are written.

### Phase 5: Song Detail UI Refresh

Turn the current parser table view into a more polished selected-song workspace with sections for overview, tracks, regions/timeline summary, validation, and preview transport.

Status (implemented on May 7, 2026; later superseded by mixer workspace): `ProjectDetailView` first used a scrollable selected-song workspace with native `GroupBox` sections for **Overview**, **Validation**, **Tracks**, **Regions / Timeline**, and **Preview**. Existing research-visible tables remained intact (`TrackTableView` and unassigned-region data), while view-only summaries reported folder/path context, counts for tracks/WAVs/issues/unassigned regions/EDL file-list/timeline candidates, and preview availability. This section is historical; the current app has since moved to a focused header-plus-mixer workspace in `ProjectWorkspaceView`.

### Phase 6: Track Selection and Inspector

Add selected track/region state and a right-side inspector or third column. Show track number, candidate WAV, evidence level, mute/pan/level values, raw bytes, and identity/match status.

Status (implemented on May 7, 2026): `TrackTableView` and the unassigned-region table are now selection-aware via `@Binding` passed from `ProjectDetailView`. Track and region selection are mutually exclusive: selecting one clears the other. `TrackRegionInspectorView` is a native right-side `.inspector` panel showing track number, mapped level/pan/mute values, raw byte offsets, mirror mismatch warnings, active-take byte (track 1, Correlated), candidate WAV or "Unassigned" with evidence, identity context for Phase 7 keying, and reserved placeholder rows for future track-name and notes fields. Region inspection shows source filename/path, start/length/end samples with approximate time, evidence, and EDL file-list ID when matched. A toolbar toggle button controls inspector visibility. Implementation is entirely read-only with no annotation persistence, no source-folder writes, and no evidence levels promoted beyond current model values.

### Phase 7: Basic App-Owned Track Labels

Add simple local annotations for track names and maybe song display names. Keep storage app-owned and read-only relative to Portastudio files. This can start modestly: track number plus song fingerprint plus label.

Plan status (created on May 7, 2026): detailed implementation handoff saved at `Plans/Phase7BasicAppOwnedTrackLabels.md`. The plan keeps Phase 7 focused on SwiftData-backed app-owned track labels, keyed by song fingerprint plus track number, with optional song display-name override only if it stays low-risk. It explicitly preserves the read-only Portastudio source-folder guarantee and defers colors, notes, tags, templates, ambiguity-resolution history, and copied-song matching to later phases.

Status (implemented on May 7, 2026): `TrackAnnotationRecord` is now part of the SwiftData schema, keyed by song fingerprint plus track number. `TrackAnnotationStore` loads, upserts, clears, and persists app-owned track names and song display-name overrides while writing only to SwiftData. `SongAnnotationContext` carries selected-song identity and requires an exact fingerprint match before labels are editable. `TrackTableView` shows saved names, `TrackRegionInspectorView` exposes `TrackLabelEditorView`, and `ProjectDetailView` uses the effective song display name in the navigation title and overview. `TrackAnnotationStoreTests` covers keying, persistence, editability gates, display-name override, and read-only source-folder guarantees.

### Phase 8: First-Round Polish and Validation

Add search, toolbar/menu polish, empty states, missing-folder states, accessibility labels, and focused tests for source classification, remembered locations, selected song loading, and annotation persistence.

Plan status (created on May 7, 2026): detailed implementation handoff saved at `Plans/Phase8FirstRoundPolishAndValidation.md`. The plan keeps Phase 8 limited to first-round app polish and validation: sidebar search/filter, command and toolbar discoverability, native empty and missing states, accessibility coverage, and focused tests. It explicitly defers backup/export, automatic removable-media detection, media browsing, waveforms, advanced metadata, and all Portastudio write workflows to later phases.

Status (implemented): Sidebar `.searchable` added to `SourceLibrarySidebarView` with `SourceLibrarySearch` pure filter helper (`Models/SourceLibrarySearch.swift`). Source name/kind/path and nested song matching is case-insensitive. Source match shows all children; song-only match narrows children. A unified "No results for…" row appears when search is active and all sections are empty. `SourceSelectedView` added to `ContentView.swift` to handle the source-selected-without-loaded-song detail state. Toolbar buttons have `.help(…)` and `.accessibilityIdentifier`. `ProjectOpenView` now uses matching text + `systemImage` SwiftUI buttons for its add-source and open-song actions. Accessibility labels, hints, and identifiers added to `ProjectOpenView`, `ProjectDetailView`, `TrackLabelEditorView`, and sidebar rows. Tests added: 20 `SourceLibrarySearchTests`, 2 `SourceFolderClassifierTests` additions, 5 `SourceLibraryStoreTests` additions, 3 `TrackAnnotationStoreTests` additions. All tests passing.

## Part 2: Pre-Release / After-Release Considerations

### Phase 9: Backup MVP

Add Back Up Source and Back Up Song as read-only copy workflows with progress, cancellation, destination selection, and a backup manifest. This is valuable but should not block the first UI/library milestone.

### Phase 10: Export Workflows

Add DAW-friendly Export WAVs, Export Report, Copy Out Master Mix, and Copy Out AudioDepot Files. Keep export separate from backup: export is convenience, backup is preservation.

### Phase 11: Backup Change Detection

Use backup manifests and source snapshots to show "changed since last backup," new files, missing files, and modified songs. Start with key file fingerprints and metadata before full-file hashing.

### Phase 12: Automatic Removable Media Detection

Detect mounted Portastudio-like removable media by checking volume properties, `dp-24.sys`, `MUSIC`, `AudioDepot`, `UTILITY`, and song folders. Present detected media as suggestions, not silent imports.

### Phase 13: Advanced Custom Metadata

Expand local annotations beyond track labels: track colors, notes, tags, song display-name overrides, favorite/archive states, reusable label templates, and ambiguity-resolution history.

### Phase 14: Media Asset Browser

Add first-class browsing for master mixes, exported tracks, project WAVs, and `AudioDepot` assets with duration, sample rate, bit depth, channels, file size, modified date, playback, and Reveal in Finder.

### Phase 15: Waveform and Timeline Visualization

Add custom SwiftUI `Canvas` waveform strips, region lanes, zoom, playhead display, and evidence-scoped timeline visualization. This is high-value polish but custom enough to defer.

Plan status (created on May 7, 2026): detailed first-release handoff saved at `Plans/Phase15WaveformAndTimelineVisualization.md`. The plan keeps Phase 15 read-only and UI-focused: derive in-memory waveform peak summaries from selected-song WAVs, render a custom SwiftUI timeline above the existing region table, add zoom/ruler/selection/playhead affordances, and preserve all current `Hypothesis` evidence caveats. It explicitly defers editing, scrubbing, backup/export, media asset browsing, AudioDepot workflows, restore, source-folder waveform caches, and any promotion of track-to-WAV assignment evidence.

Status (partially implemented): the read-only model/service foundation exists in the current app source. `WaveformPeakSummary.swift`, `TimelineVisualizationModel.swift`, `TimelineVisualizationBuilder.swift`, and `WaveformPeakBuilder.swift` build in-memory waveform/timeline data without source-folder writes. `PreviewPlaybackController` is active in the mixer workspace and exposes playback state, elapsed time, errors, and meters. The SwiftUI timeline views described in the original plan (`TimelineVisualizationView`, `WaveformCanvasView`, `RegionsTimelineGroupBoxView`) are not present in the current source tree; future implementation should reuse the existing builders rather than reimplementing timeline math or WAV peak extraction. `WaveformPeakBuilderTests.swift` covers waveform extraction/read-only safety.

### Current Mixer Workspace and Preview Overrides

Status (current): the selected-song experience is now a focused mixer workspace rather than a section/table-first project detail.

- `ProjectDetailView` owns selected-track state, inspector visibility, `PreviewPlaybackController`, `PreviewMixState`, and selected virtual-take IDs.
- `ProjectWorkspaceView` shows header identity, Play/Pause/Stop transport, elapsed time, output meters, issue status, and `TrackMixerDeckView`.
- `TrackMixerDeckView` provides per-channel pan, fader, mute, solo, reset-all, live track meter, and virtual-take picker controls.
- `PreviewMixState` persists app-owned level, pan, mute, solo, and selected virtual-take overrides through SwiftData `MixOverrideRecord`, but only when the song annotation context is editable.
- `TrackRegionInspectorView` is the diagnostics and utility surface for song summary, selected-track audio/take/evidence, parsed-vs-saved mix values, raw bytes, app-owned labels, audio file list, Reveal in Finder, and reset selected channel.
- This workflow remains read-only toward Portastudio folders. Mix overrides change app preview behavior and SwiftData only.

### Phase 16: AudioDepot Import Staging

Add a guarded workflow for validating and copying compatible user WAV files into `AudioDepot` for device-side import. This is a write workflow and should remain separate from read-only browsing.

### Phase 17: Restore to SD Card

Design restore as an advanced guarded workflow after backup identity and manifests are proven. Include destination validation, overwrite preview, free-space checks, manifest verification, and explicit warnings.

## Implementation Guidance

Part 1 should result in an app that feels coherent and useful even without backup/export: users can add sources, browse songs, reopen remembered items, inspect tracks, preview audio, and add local track labels.

Part 2 contains important product features, but they carry more risk because they involve file management, media identity, user trust, and eventually write operations. Each Part 2 item should become its own dedicated plan rather than being bundled into the first UI implementation.
