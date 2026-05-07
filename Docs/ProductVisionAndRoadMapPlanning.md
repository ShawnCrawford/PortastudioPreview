# Product Vision and Roadmap Planning

This plan splits the roadmap into **Part 1: first shippable product experience** and **Part 2: pre-release/after-release expansion**. Part 1 focuses on making the current parser MVP feel like a useful native macOS app. Part 2 keeps the larger management workflows planned, but avoids blocking the first round of implementation.

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

### Phase 5: Song Detail UI Refresh

Turn the current parser table view into a more polished selected-song workspace with sections for overview, tracks, regions/timeline summary, validation, and preview transport.

### Phase 6: Track Selection and Inspector

Add selected track/region state and a right-side inspector or third column. Show track number, candidate WAV, evidence level, mute/pan/level values, raw bytes, and identity/match status.

### Phase 7: Basic App-Owned Track Labels

Add simple local annotations for track names and maybe song display names. Keep storage app-owned and read-only relative to Portastudio files. This can start modestly: track number plus song fingerprint plus label.

### Phase 8: First-Round Polish and Validation

Add search, toolbar/menu polish, empty states, missing-folder states, accessibility labels, and focused tests for source classification, remembered locations, selected song loading, and annotation persistence.

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

### Phase 16: AudioDepot Import Staging

Add a guarded workflow for validating and copying compatible user WAV files into `AudioDepot` for device-side import. This is a write workflow and should remain separate from read-only browsing.

### Phase 17: Restore to SD Card

Design restore as an advanced guarded workflow after backup identity and manifests are proven. Include destination validation, overwrite preview, free-space checks, manifest verification, and explicit warnings.

## Implementation Guidance

Part 1 should result in an app that feels coherent and useful even without backup/export: users can add sources, browse songs, reopen remembered items, inspect tracks, preview audio, and add local track labels.

Part 2 contains important product features, but they carry more risk because they involve file management, media identity, user trust, and eventually write operations. Each Part 2 item should become its own dedicated plan rather than being bundled into the first UI implementation.
