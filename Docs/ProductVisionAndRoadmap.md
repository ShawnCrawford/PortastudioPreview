# Product Vision and Roadmap

This document captures product and UX direction for Portastudio Preview beyond the current parser-focused MVP. It is intentionally organized as reorderable sections with a table of contents, so new ideas can be inserted, moved, or promoted into implementation plans without rewriting the whole document.

## Table of Contents

1. [Product Goal](#product-goal)
2. [Current App Baseline](#current-app-baseline)
3. [Final App Experience Target](#final-app-experience-target)
4. [Source Library Sidebar](#source-library-sidebar)
5. [Opening Media and Songs](#opening-media-and-songs)
6. [Remembered Locations and Missing Files](#remembered-locations-and-missing-files)
7. [Project Identity and Matching](#project-identity-and-matching)
8. [User Metadata and Track Labels](#user-metadata-and-track-labels)
9. [Master Mixes and AudioDepot](#master-mixes-and-audiodepot)
10. [Backups, Exports, Import Staging, and Restore](#backups-exports-import-staging-and-restore)
11. [Native macOS and SwiftUI Implementation Fit](#native-macos-and-swiftui-implementation-fit)
12. [Manual-Derived Research](#manual-derived-research)
13. [Real-World SD Card Research](#real-world-sd-card-research)
14. [Research Decisions](#research-decisions)
15. [Suggested Roadmap](#suggested-roadmap)
16. [Open Product Questions](#open-product-questions)

## Product Goal

Portastudio Preview should become a polished, read-only macOS app for browsing, inspecting, previewing, annotating, and safely managing TASCAM DP-24SD and DP-32SD projects. The app is macOS-only for now.

The app should be useful to normal users who want to:

- Insert or locate a Portastudio SD card.
- Browse the songs stored on that card.
- Open a copied backup of a full SD card.
- Open a single copied song folder.
- Preview the project without changing any Portastudio files.
- Listen to master mixes and track exports already created on the Portastudio.
- Understand which tracks, WAVs, takes, and regions are present.
- Add personal labels such as track names.
- Create backups and DAW-friendly exports.
- Stage compatible samples, loops, and custom WAV files for in-device import through `AudioDepot` in a future guarded workflow.
- Recognize when a previously seen folder or SD card has moved or changed.

The core safety rule remains: the app should not modify Portastudio project files unless a future restore/write workflow is deliberately designed, validated, and clearly separated from read-only preview.

## Current App Baseline

| Area | Current status |
| --- | --- |
| App shell | Uses a native SwiftUI `WindowGroup`. |
| Main layout | Uses `NavigationSplitView`. |
| Sidebar | Uses a source-library sidebar with native `List(selection:)`, `Section`, and `DisclosureGroup` rows (`SD Cards & Backups`, `Individual Songs`, `Missing`). Source rows show kind icon and secondary path/kind label. Available rows have **Reveal in Finder** and **Forget** context menu actions. Missing rows have **Relocate…** and **Forget** context menu actions. |
| Sidebar search | `.searchable` modifier on the sidebar list; `SourceLibrarySearch.filter` narrows sources, songs, and missing items. Source match shows all children; song-only match narrows children. No-results state shown when search active and all sections empty. |
| Source-selected state | Selecting a source row (without a loaded song) shows `SourceSelectedView` in the detail area with name, kind, path, song count, and match state. |
| Opening individual song | `Command-O` and toolbar/open-state action `Open Individual Song...` load a selected folder via `ProjectFolderLoader`. Folder is classified first; non-song folders show a clear error. |
| Adding SD card or backup | `Command-Shift-O` and toolbar/open-state action `Add SD Card or Backup...` classify a root folder, scan `MUSIC/` for song subfolders, and create a nested source row with song list. |
| Folder classification | `SourceFolderClassifier` classifies as `.mediaRoot`, `.backupRoot`, `.songFolder`, or `.unsupported`. Ignores hidden Apple metadata (`._*`, `.DS_Store`, `.Spotlight-V100`, `.fseventsd`). |
| Source deduplication | Sources upsert by canonical URL; reopening the same root updates the existing row and persisted record. |
| Source song loading | Selecting a nested source song loads the project on demand via `loadIfSourceSong()`. |
| Commands | Supports `Open Individual Song...` with `Command-O` and `Add SD Card or Backup...` with `Command-Shift-O`. Toolbar buttons have `.help(…)` tooltips. |
| Project detail | Uses a focused selected-song mixer workspace. `ProjectDetailView` owns selected track, inspector visibility, `PreviewPlaybackController`, `PreviewMixState`, and virtual-take selection. `ProjectWorkspaceView` shows header identity, transport, meters, and the horizontal mixer deck. |
| Track display | The primary track surface is `TrackMixerDeckView` inside `ProjectWorkspaceView`: one strip per visible mixer channel with identity, audio status, virtual-take picker when available, pan, mute, solo, fader, meter, and selected-channel affordance. The visible mixer list includes only channels with resolved assigned audio (candidate WAV or virtual-take options), while full parser track scope remains available in the underlying model for diagnostics. `TrackTableView` remains available as a raw/evidence table component for parser-oriented surfaces and tests. |
| Region display | Timeline-region model and waveform builders remain in the codebase. Current selected-song workspace emphasizes mixer-first preview; region/file details surface through `TrackRegionInspectorView` and the audio-file inspector section. |
| Waveform/timeline visualization | Model/service foundation exists. `TimelineVisualizationBuilder` builds `TimelineVisualizationModel` from project data and playback suppression state; `WaveformPeakBuilder` derives in-memory peak summaries from WAV files without writing caches. The SwiftUI timeline/waveform views from the Phase 15 plan are not currently present in the source tree. |
| Inspector | `TrackRegionInspectorView` is a native right-side `.inspector` panel. It shows song summary, selected-track identity, resolved audio source/take/evidence, parsed-vs-saved mix state, raw byte diagnostics, active-take byte (track 1), editable track-name field, audio-file list, Reveal in Finder, and reset selected channel. Toolbar toggle controls visibility. |
| Preview playback | Uses AVFoundation through `StereoPreviewEngine` under `PreviewPlaybackController`; transport supports Play/Pause/Stop, elapsed time, output meters, track meters, live level/pan/mute updates, solo-derived effective mutes, selected virtual takes, and reload-preserving-position when virtual take changes during playback. |
| Mix override persistence | `PreviewMixState` persists app-owned level, pan, mute, solo, and selected virtual-take overrides through SwiftData `MixOverrideRecord`, keyed by exact song fingerprint context. Overrides affect only app preview and are never written to Portastudio files. |
| Parser stance | Read-only and evidence-labeled. |
| Persistence | SwiftData (`LibrarySourceRecord`, `LibrarySongRecord`) injected via `ModelContainer`. Sources and standalone songs persist across relaunches. Nested source songs are cascade-deleted when their source is forgotten. |
| Security-scoped bookmarks | Created and resolved by `SecurityScopedBookmarkService`. `PassthroughBookmarkService` is available as a test seam. Stale bookmarks are refreshed on resolution. Fallback to last-known path when bookmark fails. Source-root scans and fingerprint passes run while the selected root's security scope is active. |
| Missing-location handling | Records that fail both bookmark resolution and fallback path check are surfaced as muted missing rows; not deleted. Sidebar shows them in `Missing` with Relocate and Forget context menu actions. |
| Sidebar context menus | Available rows: Reveal in Finder, Forget. Missing rows: Relocate…, Forget. |
| Relocate | Opens `NSOpenPanel`, classifies folder, validates kind-compatibility (source accepts `.mediaRoot`/`.backupRoot`; song accepts `.songFolder`), updates bookmark/path/displayName, moves row out of Missing. Wrong-kind selection leaves missing record intact and sets a load error. |
| Forget | Removes only the app-owned SwiftData record. Never modifies source files. |
| Fingerprinting | `FingerprintService` computes SHA-256 hashes for `dp-24.sys`, `song.sys`, `edltable.sys`, and metadata-only WAV inventory fingerprints. WAV contents are never hashed. Hidden Apple metadata is excluded. |
| Match states | `FingerprintMatchState`: `.exact`, `.changedSinceLastSeen`, `.ambiguous` (reserved), `.unknown`. Sidebar secondary labels show `· Exact match` or `· Changed since last seen` when match state is resolved. |
| Fingerprint persistence | `LibrarySourceRecord` and `LibrarySongRecord` store `aggregateFingerprintString`, `wavInventorySummaryString`, `fingerprintGeneratedAt`, `matchStateRawValue`. Fingerprints stored as `.exact` on add/open/relocate; match state recomputed on hydration without overwriting the stored baseline. |
| Accessibility | Interactive controls across sidebar, toolbar, detail views, and inspector have `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityIdentifier`, and `.accessibilityHidden(true)` on decorative icons. |
| Removable media detection | None. Manual add flows only (Phase 12). |


## Final App Experience Target

The shippable app should feel like a native macOS audio utility rather than a research tool.

Target user experience:

- The first screen is a source library.
- The user can add a full SD card, a full SD card backup folder, or an individual song folder.
- The app lists remembered sources and songs.
- Selecting a song opens a detailed project view.
- The project view shows tracks, track labels, WAV mapping evidence, timeline regions, and read-only playback controls.
- The media view shows project-region WAVs, rendered master files, exported tracks, and `AudioDepot` exchange files.
- The app clearly marks uncertain inferred behavior with evidence labels.
- The app provides practical management actions such as backup, export, reveal in Finder, relocate, and forget.

The final visual direction should use native macOS patterns: sidebar, toolbar, inspector, tables, split views, menus, keyboard shortcuts, and system-adaptive colors/materials.

## Source Library Sidebar

The sidebar should become a source library rather than a single project summary.

Suggested shape:

```text
Sources
  DP-32SD SD Card #1
    Waking Up To Music
      Master Mixes
      Project Tracks
    New Morning Breeze
    Other Song
    One More Song
    AudioDepot

  DP-24SD SD Card #1
    Another Project

Individual Songs
  Sunday Afternoon
  Open For Business

Missing
  Old Backup Song
```

Source types:

| Source type | Meaning |
| --- | --- |
| Removable media root | A currently mounted Portastudio SD card. |
| Full backup root | A local or external folder that preserves full SD card contents. |
| Individual song | A standalone song folder opened independently. |
| AudioDepot | A source-level WAV exchange area used by the hardware for track import/export. |
| Missing remembered source | A previously opened source whose bookmark/path no longer resolves. |

Native UI fit:

- `NavigationSplitView` for source list and selected detail.
- `List(selection:)` for selectable sources and songs.
- `Section` for grouping source roots and individual songs.
- `DisclosureGroup` or `OutlineGroup` for expandable SD card and backup roots.
- `.searchable` for filtering large libraries.
- Context menus for row-level actions.

## Opening Media and Songs

Initial implementation can stay manual and predictable:

| Action | Behavior |
| --- | --- |
| Add SD Card or Backup | User chooses a card root or full copied root folder. The app scans enough to classify it and list songs. |
| Open Individual Song | User chooses one song folder. The app adds it under Individual Songs. |
| Open Recent | User reopens a remembered source or song. |
| Reveal in Finder | Opens the selected source or song location. |
| Forget | Removes app memory of the source without touching files. |
| Relocate | Lets the user point a missing remembered item to its new location. |

Automatic removable-media detection can come later. Manual add plus remembered locations is lower risk and avoids surprising disk access.

Future automatic detection could check mounted volumes for:

- Expected root-level system files.
- Expected `MUSIC` folder structure.
- Optional `AudioDepot` and `UTILITY` folders.
- Song folders containing `song.sys`, `edltable.sys`, and WAV files.
- Card-level metadata such as the root `dp-24.sys` file.
- FAT32 removable-media properties from Disk Arbitration or `URLResourceValues`.
- Hidden Apple metadata files that should be ignored rather than treated as Portastudio project content.

See `Docs/PortastudioResearchReferences.md` for current card-root findings.

## Remembered Locations and Missing Files

The app should remember sources and individual songs that the user has opened.

For macOS, remembered external folders should use security-scoped bookmarks so the app can regain access after relaunch when possible.

When a remembered location cannot be resolved:

- Keep it visible in the library.
- Display it in a muted or disabled state.
- Show a plain explanation such as "Files no longer found at the original location."
- Offer actions to Relocate or Forget.
- Do not automatically delete the remembered item.

This helps users understand that the app did not lose their project history; the files are just no longer available where they were previously located.

## Project Identity and Matching

Identity matching needs careful design because Portastudio media may not have a single durable unique ID.

The app should use layered identity instead of one signal.

| Level | Possible signals | Purpose |
| --- | --- | --- |
| Source identity | Security-scoped bookmark, last known path, volume name, removable media metadata, root system file fingerprint, detected model, normalized root manifest | Recognize an SD card or full backup root. |
| Song identity | Song folder name, `song.sys` fingerprint, `edltable.sys` fingerprint, normalized WAV inventory fingerprint, decoded song metadata if confirmed | Match songs across moved folders, backups, and reinserted media. |
| Track identity | Song identity plus track number plus mapped WAV/timeline evidence | Attach user labels and notes to tracks. |
| Backup identity | Source identity plus file manifest and key file fingerprints at backup time | Detect changes since last backup. |

The app should expose confidence states rather than pretending identity is always exact:

| Match state | Meaning |
| --- | --- |
| Exact match | Same remembered location and matching fingerprints. |
| Likely same source | Location changed, but source and song fingerprints strongly match. |
| Likely copied source | Different source location with very similar or identical contents. |
| Same song, different location | Song fingerprints match but source identity differs. |
| Changed since last seen | Known source or song, but key fingerprints differ. |
| Ambiguous match | Multiple candidates match similarly; user confirmation required. |
| Unknown | Not enough evidence to match. |

Ambiguous cases should not silently merge metadata. The app should ask before applying saved labels or annotations to a newly detected folder that only appears to match.

## User Metadata and Track Labels

The Portastudio itself does not support user-facing track names in the same way a DAW does. The app can add this value without changing source files by storing app-specific annotations.

Useful annotation types:

- Song display name override.
- Track names such as "Kick Drum", "Snare", or "Lead Vocal".
- Track colors.
- Song notes.
- Track notes.
- Tags such as favorite, archived, needs mix, or needs backup.
- Optional role icons later.

Storage rule:

App metadata should live in app-owned storage, not in Portastudio project files. Do not write labels into `song.sys`, `edltable.sys`, WAV files, or the SD card folder structure.

Possible storage options:

| Option | Fit |
| --- | --- |
| SwiftData | Preferred app-owned persistence layer for the macOS-only app. Use it for remembered sources, security-scoped bookmark data, source/song fingerprints, user labels, colors, notes, tags, backup history, and ambiguity-resolution decisions. |
| JSON in Application Support | Useful only for export/debug snapshots or future migration fixtures, not the primary store. |
| SQLite | Keep as a fallback only if SwiftData becomes a poor fit for large manifest queries or migration control. |
| iCloud Drive or CloudKit | Future sync option after the local model is stable. |

Track labels should attach to a stable identity key, not just a visible folder name. A moved folder or copied backup should be able to recover labels when the app has enough evidence to match the song.

Suggested SwiftData entities:

| Entity | Purpose |
| --- | --- |
| `LibrarySource` | Remembered SD card, backup root, or standalone song source, including bookmark data and last known path. |
| `SongRecord` | One discovered song folder with display name, original folder name, parser status, and identity fingerprints. |
| `TrackAnnotation` | User-owned track label, color, notes, tags, and identity attachment. |
| `MediaAsset` | Indexed WAV-like assets, including project-region WAVs, master files, exported track WAVs, and `AudioDepot` files. |
| `SourceSnapshot` | Last-seen source manifest summary for change detection and backup comparison. |
| `BackupRecord` | Backup/export history, destination bookmark, manifest fingerprint, and completion status. |
| `MatchDecision` | User-confirmed resolution for ambiguous copied or relocated sources. |

## Master Mixes and AudioDepot

The app should treat Portastudio audio assets as user-facing media, not just parser inputs.

Manual-derived behavior from the sibling research repo:

- A song can contain one master file named `[song name].wav`.
- Creating a master records the range between IN and OUT points.
- Recreating a master overwrites the previous master.
- Mastering mode can apply EQ, compression, and normalize.
- The manual warns that mastering creates another unit-private file in addition to the WAV master; the app should not delete or hide this relationship.
- Track import/export uses `AudioDepot`.
- Import requires WAV files with matching sample rate and bit depth.
- Imported audio is placed at `00:00:00:00` by the device.
- Stereo WAV import requires an empty stereo track.
- Track export lists song tracks that contain audio; unrecorded tracks are not shown.

Product use cases:

| Use case | App behavior |
| --- | --- |
| Listen to master mixes | Show detected `[song name].wav` master files inside song folders with playback, file info, reveal, and export/copy actions. |
| Compare master versions | Store app-side notes and snapshot metadata for seen masters, even though the device may overwrite the same filename. |
| Browse exported tracks | Show `AudioDepot/SONG_####_TRK##.WAV` files as exported track assets, separate from song timeline reconstruction. |
| Build a sample/loop staging list | Let the user collect candidate WAVs in the app, validate format compatibility, and prepare them for future `AudioDepot` copying. |
| Inspect import readiness | Check sample rate, bit depth, channel count, file extension, size, and naming before the user tries in-device import. |
| Preserve a card completely | Include master files, private master companion files, `AudioDepot`, and song folders in backups. |

UI model:

- Each song detail should have a media section with Project Regions, Master Mixes, and Rendered/Other WAVs.
- Each source detail should have an `AudioDepot` section with exported tracks and staged import candidates.
- WAV rows should show duration, sample rate, bit depth, channels, file size, modified date, and whether the file appears device-created or app-staged.
- Playback controls should work for master files and depot WAVs even when project timeline reconstruction is uncertain.

Safety model:

- Reading and copying out master/depot WAVs is part of the read-only product.
- Copying user WAVs into `AudioDepot` is a future write workflow, not part of the initial read-only scanner.
- The app must never write directly into song folders to add samples, loops, or custom audio. The documented route is staging compatible WAV files in `AudioDepot` and letting the hardware import them into a song.
- Before any future `AudioDepot` write, the app should require a mounted card or user-selected backup destination, show exactly what files will be copied, validate free space, and avoid overwriting without explicit confirmation.

## Backups, Exports, Import Staging, and Restore

Backup, export, import staging, and restore should be treated as separate product layers above parsing.

Suggested actions:

| Action | Goal |
| --- | --- |
| Back Up Source | Preserve a full SD card or backup root exactly enough to reopen or restore later. |
| Back Up Song | Preserve one selected song folder. |
| Export WAVs | Create a DAW-friendly output folder with audio files and optional metadata summary. |
| Copy Out Master Mix | Copy or reveal the song's rendered master WAV without changing the card. |
| Copy Out AudioDepot Files | Copy track exports from `AudioDepot` to a local folder. |
| Stage WAVs for AudioDepot | Future guarded workflow to validate and copy compatible user WAVs into `AudioDepot` for in-device import. |
| Export Report | Produce a readable project summary for reference. |
| Restore to SD Card | Future guarded flow to write a validated backup back to removable media. |

Backup and export should be distinct:

| Flow | Behavior |
| --- | --- |
| Backup | Preserve original folder structure and files. Goal is safety and reversibility. |
| Export | Produce a cleaner user-facing or DAW-facing folder. Goal is convenience. |
| Import staging | Put compatible user WAVs where the hardware expects exchange files. Goal is device-assisted import, not direct song mutation. |
| Restore | Copy validated backup/song data back to removable media. Goal is device compatibility and requires stronger warnings. |

Implementation tools:

- `FileManager` for copying.
- `NSOpenPanel` and `NSSavePanel` for destination selection.
- Security-scoped bookmarks for remembered destinations.
- `ProgressView` for long operations.
- Cancellable `Task` for copy/export work.
- `FileCoordinator` for coordinated writes, especially when using iCloud Drive.

Backups should eventually include an app-created manifest.

Example manifest contents:

```text
backup-manifest.json
  app version
  backup creation date
  source display name
  detected device family/model
  source identity signals
  song list
  file sizes
  modified dates
  key .sys file hashes
  optional WAV hashes or partial fingerprints
```

The manifest lets the app answer "what changed since the last backup?" without rereading or hashing everything every time.

## Native macOS and SwiftUI Implementation Fit

Most of the discussed UI can be built with native SwiftUI and Foundation/AppKit platform APIs.

| Feature | Native fit |
| --- | --- |
| Source library | `NavigationSplitView`, `List`, `Section`, `DisclosureGroup`, `OutlineGroup`. |
| Selection-driven detail | `List(selection:)`, `NavigationSplitView`, explicit selection state. |
| Search | `.searchable`. |
| Tables | SwiftUI `Table`. |
| Toolbar | `.toolbar`, `ToolbarItem`, `ControlGroup`. |
| Menus and shortcuts | SwiftUI `Commands`, `CommandGroup`, `.keyboardShortcut`. |
| Inspector | SwiftUI inspector APIs where available, or a third split column. |
| Folder selection | `NSOpenPanel`. |
| Save/export destination | `NSSavePanel` and `NSOpenPanel`. |
| Remembered access | Security-scoped bookmarks. |
| Missing file state | Disabled/muted SwiftUI rows and context actions. |
| Track labels | Native text fields, inspector fields, inline rename patterns. |
| Track colors | `ColorPicker` or a controlled palette. |
| Backup progress | `ProgressView` plus cancellable tasks. |
| Audio preview | AVFoundation. |
| Master/depot playback | AVFoundation file playback with metadata inspection via `AVURLAsset` / `AVAudioFile`. |
| AudioDepot import validation | WAV header inspection, format checks, file-size/free-space checks, and explicit copy confirmation. |
| Waveforms | Custom SwiftUI drawing with `Canvas` using decoded/derived audio peak data. |
| Timeline | Custom SwiftUI layout/drawing with `ScrollView`, `Canvas`, and explicit zoom state. |
| Meters | `Gauge` for simple display; custom drawing for DAW-like meters. |

The hardest UI pieces are waveforms, DAW-style timeline behavior, and polished mixer controls. They are feasible in SwiftUI, but they require custom drawing and careful performance work rather than stock controls only.

## Manual-Derived Research

Research source: `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/ArchitectureAndDataModel.md`, which summarizes the DP-32SD owner's manual, DP-32 owner's manual, release notes, and service documentation. Evidence level here is `Observed` for documented device behavior, not byte-level parser semantics.

Manual findings with product impact:

| Area | Documented behavior | Product impact |
| --- | --- | --- |
| Card formatting | Device formatting creates `MUSIC`, `UTILITY`, `AudioDepot`, and `dp-24.sys`, and creates one initial song in `MUSIC`. | Card-root detection should expect all four root items, while tolerating empty `UTILITY` and `AudioDepot` folders. |
| Song metadata | Hardware song list shows size, sample rate, bit depth, and date. Song names allow up to 15 single-byte characters. | The app should display these fields when decoded or derived, and should not assume song folder names are always numeric. |
| DP-24/DP-32 compatibility | Loading a DP-24 song on DP-32SD can overwrite it in DP-32 format. | The app should identify device-family risk and avoid any automatic conversion or write behavior. |
| Virtual tracks | Each physical track has 8 virtual tracks; only assigned virtual tracks are playable/editable. | Preview must not assume every `ZZ....wav` in a song folder is currently audible. |
| Track editing | Editing is non-destructive and IN/OUT/TO points drive edit operations. | Timeline preview should keep evidence visible and avoid overconfident reconstruction until edit-table semantics are confirmed. |
| Undo history | Up to 10 undo events are stored with song data and persist across power cycles. | Backups need to preserve song folders exactly; parser should expect persistent edit/undo state. |
| Delete unused | The hardware can remove overwritten and unassigned virtual-track audio. | The app can explain why a song may contain unused WAVs, but should not perform cleanup itself. |
| Master files | A song can contain `[song name].wav`; mastering creates an additional private file; recreating a master overwrites the previous master. | Master files are first-class media assets, and backup/export flows must preserve companion files rather than deleting unknown private files. |
| Track import/export | `AudioDepot` is the documented exchange area. Import requires matching sample rate/bit depth; imported audio starts at zero; stereo import requires an empty stereo track; export lists recorded tracks only. | `AudioDepot` should be a first-class source section for listening, copy-out, and future guarded import staging. |
| Firmware release notes | Import/export, playback-start noise, edit timing, and stereo/mono import bugs were fixed across firmware versions. | The app should validate format strictly, keep firmware/version notes in diagnostics when available, and avoid promising perfect device-side behavior. |

Manual findings do not identify byte offsets in `song.sys` or `edltable.sys`. They constrain product behavior and test design only.

## Real-World SD Card Research

Research pass: `Observed` from `/Volumes/DP-32SD` on 2026-05-07. The volume was inspected read-only from the app/research workflow. No files were intentionally created, modified, deleted, or copied from the removable media.

### Mounted Media Shape

| Finding | Observed value |
| --- | --- |
| Volume name | `DP-32SD` |
| Filesystem | FAT32 / MS-DOS FAT32 |
| Connection | USB removable media |
| Reported capacity | 31.9 GB |
| Used space | 24.5 GB, about 76.7% |
| Free space | 7.4 GB, about 23.3% |
| Allocation block size | 32,768 bytes |
| macOS mount state | Writable volume, even though the app must treat it as read-only input |
| Volume UUID | `6D57A8BD-F04F-37BE-AABE-47F26FA4E60A` |

Root contents:

| Root item | Observed role |
| --- | --- |
| `dp-24.sys` | Card-level system file. Size 2,488 bytes. SHA-256 `d826a800a9672c98fe5938eaf868f12d26201b2587565b4b559f5cd74c5f235a`. |
| `MUSIC/` | Song library root. |
| `AudioDepot/` | Export/import-style WAV depot. |
| `UTILITY/` | Present but empty in this inspection. |
| `.Spotlight-V100`, `.fseventsd` | macOS-created hidden folders. Ignore for Portastudio identity and backup manifests unless a raw full-card clone mode is intentionally added. |

The root `dp-24.sys` begins with `DP-24   ` at `0x0000` and has the same broad shape documented in `Docs/PortastudioResearchReferences.md`. It is useful for card-family validation and a root fingerprint, but this inspection does not prove that it contains a durable unique card identity.

### Song Library Shape

The `MUSIC/` folder contained 124 first-level song folders. Every inspected song folder had both `song.sys` and `edltable.sys`.

The real card is not limited to strict `SONG_0001` naming:

- Numeric folders such as `SONG_0001` through `SONG_0095`.
- User-named folders such as `APPLETREE`, `DINNER TIME`, `IN BETH`, `OBITUARY`, `PRISMS`, `STILL SAD`, `SONG_Circles`, `SONG_Kismet1`, and `SONG_West`.
- Copy/variant-looking folders such as `SONG_0054#1`, `SONG_00542`, `PONG_0096`, `RONG_0096`, `SNOG_0057`, and `TONG_0055`.
- Empty-audio or setup/reference folders with `song.sys` and `edltable.sys` but no WAV files.

Audio inventory under `MUSIC/`:

| Finding | Observed value |
| --- | --- |
| WAV files | 1,337 files |
| WAV bytes | 19,430,960,072 bytes, about 18.10 GiB |
| Project-region WAV pattern | 1,293 files matched `ZZ####_#.wav` |
| Rendered/mixdown WAV pattern | 11 visible files matched `SONG_*.WAV` |
| Hidden AppleDouble WAV sidecars | 32 `._*.wav` / `._*.WAV` files observed |
| Other visible WAV name | `DEMO_SONG.WAV` |
| Song folders with no WAV files | 17 folders |

Largest song folders by visible WAV count included `SONG_0049` with 109 WAVs, `DEMO_SONG` with 58, `SONG_0032` with 52, `SONG_0031` with 51, `SONG_0040` with 47, and `SONG_Circles2` with 42. This means the source library and scanner should be designed for hundreds of songs and thousands of files, not just small parser fixtures.

Example WAV metadata:

| File kind | Example | Observed format |
| --- | --- | --- |
| Project-region WAV | `MUSIC/SONG_0049/ZZ0000_1.wav` | Mono, 48,000 Hz, 24-bit little-endian PCM. |
| Rendered/mixdown WAV | `MUSIC/SONG_0046/SONG_0046.WAV` | Stereo, 48,000 Hz, 24-bit little-endian PCM. |

### AudioDepot Shape

`AudioDepot/` contained 20 visible WAV files. Names followed `SONG_####_TRK##.WAV`, for example `SONG_0017_TRK01.WAV`, `SONG_0049_TRK10.WAV`, and `SONG_0050_TRK09.WAV`.

Product implication: the app should expose `AudioDepot` as a source-level media and exchange area, not as song timeline evidence. It is useful for listening to exported tracks, copying exports out of the card, backup completeness, and future validated sample/loop import staging. It should not be mixed into a song's active region inventory.

### Scanner Rules From Real Media

Use these rules for source-library and manifest implementation:

- Treat `MUSIC/` children as candidate songs when they contain `song.sys` and `edltable.sys`, regardless of folder naming style.
- Do not require WAV files for a valid song; blank/setup songs exist.
- Ignore hidden files and directories for normal library scanning and identity fingerprints, including `.Spotlight-V100`, `.fseventsd`, and AppleDouble `._*` files.
- Treat visible `SONG_*.WAV` files inside song folders as rendered or mixdown assets, separate from `ZZ####_#.wav` region candidates.
- Treat `AudioDepot/*.WAV` as source-level depot/export/import-staging files, separate from per-song project reconstruction.
- Preserve unknown or private companion files around master WAVs during backup; do not delete or reinterpret them as clutter.
- Preserve original names exactly in display and backup flows; folder names may include spaces, suffixes, and non-sequential variants.
- Expect scans over a mounted card to be moderately large. Use asynchronous scanning, progress reporting, cancellation, and cached SwiftData snapshots.
- Avoid whole-WAV hashing during routine source scans. Use key system file hashes, normalized inventory metadata, sizes, modification dates, and optional partial WAV fingerprints for faster change detection.
- Never rely on macOS volume UUID alone as durable identity. Use it as one signal alongside bookmark, volume name, root fingerprint, and normalized manifests.

## Research Decisions

Identity and matching can now move forward with conservative layered fingerprints. The remaining unknown binary fields do not block a Source Library MVP, user annotations, or backup manifests.

Decisions:

- Use SwiftData as the primary app-owned persistence layer for this macOS-only app.
- Keep all Portastudio files read-only. User labels, colors, notes, tags, source history, and backup history belong in SwiftData.
- Start with manual "Add SD Card or Backup" and "Open Individual Song" flows. Automatic removable-media detection can be added after the library model is stable.
- Classify SD card roots by root shape: `dp-24.sys`, `MUSIC/`, and candidate song folders with `song.sys` plus `edltable.sys`.
- Use source manifests and song manifests for identity. Hash `dp-24.sys`, `song.sys`, and `edltable.sys` with SHA-256; summarize WAV inventory with normalized names, sizes, dates, and optional partial hashes. WAV contents are not hashed during routine scans (Phase 4 implemented; partial/whole-WAV hashing may be added later).
- Treat `dp-24.sys` as card-family/root-state evidence, not as a confirmed durable media ID.
- Treat master WAVs and `AudioDepot` files as first-class `MediaAsset` records in SwiftData.
- Keep project-region WAVs, rendered master WAVs, exported track WAVs, and import-staged depot WAVs separate in the data model and UI.
- Match copied or relocated songs conservatively. Exact key-file hashes plus compatible WAV inventory can recover metadata automatically; ambiguous matches require user confirmation.
- Represent copied media as a separate `LibrarySource` that may be "likely copied from" another source, rather than silently merging sources.
- Ignore hidden Apple metadata in normal scans and manifests. A future raw clone/restore mode can decide whether to preserve every hidden filesystem artifact.
- Keep restore and `AudioDepot` write staging out of the read-only product path until manifests, format validation, destination validation, and overwrite warnings are designed and tested.

## Suggested Roadmap

The implementation roadmap is split into two parts. Part 1 is the first shippable product experience and should focus on making the current parser MVP feel like a coherent native macOS app. Part 2 covers pre-release or after-release expansion work that is valuable, but riskier or less feasible under first-round time constraints.

Each phase should be small enough to become one dedicated implementation plan for an AI agent. Prefer giving an agent enough room to implement a few related features well rather than bundling too many UI, persistence, and file-management concerns into one plan.

### Part 1: First-Round Implementation

Part 1 should result in an app that feels useful even without backup/export: users can add sources, browse songs, reopen remembered items, inspect tracks, preview audio, and add basic local labels.

#### Phase 1: Source Library Shell ✓ Implemented

- Replace the summary-only sidebar with a source library model.
- Use `NavigationSplitView`, `List(selection:)`, `Section`, and expandable source rows.
- Include groups for SD card or backup sources, individual songs, and missing remembered items.
- Keep selected-song loading wired to the current parser/detail path.
- Preserve read-only behavior.

#### Phase 2: Manual Add Flows ✓ Implemented

- Add toolbar/menu actions for "Add SD Card or Backup" (`Command-Shift-O`) and "Open Individual Song" (`Command-O`).
- Classify selected folders as media roots, backup roots, or song folders using `SourceFolderClassifier`.
- Recognize root items such as `dp-24.sys` (media root signal), `MUSIC/` (required for root classification), and validate song folders by `song.sys` + `edltable.sys` presence, regardless of folder naming style.
- Ignore hidden Apple metadata (`.DS_Store`, `._*`, `.Spotlight-V100`, `.fseventsd`) during classification.
- Sources upsert by canonical URL; reopening the same root updates the existing row.
- Selecting a nested source song loads the project on demand.
- Unsupported folders surface a clear non-destructive error.
- In-memory only. No security-scoped bookmarks or persistence.

#### Phase 3: Remembered Locations MVP

- Persist opened sources and songs with display name, source kind, last-known path, and security-scoped bookmark data.
- Show missing locations as muted rows.
- Add basic Relocate, Reveal in Finder, and Forget affordances.
- Do not automatically delete missing remembered items.
- Keep missing-state language plain and user-facing.

#### Phase 4: Source/Song Fingerprint MVP ✓ Implemented

- Create lightweight fingerprints for source roots and songs.
- Use folder names, root structure, `dp-24.sys` metadata/hash, `song.sys`, `edltable.sys`, and normalized WAV inventory metadata.
- Ignore hidden Apple metadata such as `.Spotlight-V100`, `.fseventsd`, and AppleDouble `._*` files.
- Use fingerprints for display and conservative matching only, not backup safety yet.
- Represent match states such as exact, changed since last seen, ambiguous, and unknown.
- WAV files are never content-hashed; only metadata (relative path, byte count, modification date) is used.
- Fingerprints persist to SwiftData; match state is recomputed on hydration against the stored "last seen" baseline.

#### Phase 5: Song Detail UI Refresh ✓ Implemented

- Turn the current parser table view into a more polished selected-song workspace.
- Add sections for overview, tracks, region/timeline summary, validation, and preview transport.
- Keep evidence labels visible, but make normal user interpretation easier.
- Preserve existing parser tables where they are still needed for research/debug visibility.
- Improve empty states and loading/error states.

#### Phase 6: Track Selection and Inspector

- Add selected track and selected region state.
- Add a right-side inspector or third column.
- Show track number, candidate WAV, evidence level, mute/pan/level values, raw bytes, and identity/match status.
- Reserve fields for app-owned labels and notes.
- Keep inspector actions read-only relative to Portastudio files.
- Implemented on May 7, 2026. `TrackTableView` and the unassigned-region table are selection-aware via `@Binding`. Track and region selections are mutually exclusive; each clears the other. `TrackRegionInspectorView` is a native `.inspector` panel showing mapped level/pan/mute values, raw byte offsets, mirror mismatch warnings, active-take byte for track 1, assigned WAV or unassigned status with evidence, region timing strings, EDL file-list match when available, identity context for Phase 7 annotation keying, and reserved placeholder rows for future track-name and notes fields. A toolbar toggle controls inspector visibility. Entirely read-only; no annotation persistence or source writes.

#### Phase 7: Basic App-Owned Track Labels

- Add simple local annotations for track names and optionally song display names.
- Keep storage app-owned and read-only relative to Portastudio files.
- Attach labels to a conservative key such as song fingerprint plus track number.
- Prefer SwiftData for app-owned persistence if the deployment target supports it cleanly.
- Keep advanced labels, colors, notes, tags, templates, and ambiguity history for Part 2.
- Implementation plan created on May 7, 2026: `Plans/Phase7BasicAppOwnedTrackLabels.md`.
- Implemented on May 7, 2026. Added `TrackAnnotationRecord` SwiftData model keyed by song fingerprint + track number. `TrackAnnotationStore` is a `@MainActor @Observable` service that owns load/upsert/clear for track names and song display-name override. `SongAnnotationContext` carries identity and editability state (`isEditable` requires `.exact` fingerprint match). `SourceLibraryStore.selectedSongAnnotationContext()` builds and exposes context for the selected song. `ContentView` owns `annotationStore` and reloads context on selection change. `TrackTableView` adds a "Name" column from live annotation data. `TrackRegionInspectorView` shows `TrackLabelEditorView` — an editable text field that saves on Return and on focus loss, with read-only fallback and an orange warning when the fingerprint has changed. `ProjectDetailView` navigation title and overview section show the song display-name override when set. No source folders are ever modified; all annotation data is app-owned SwiftData. 15 new tests in `TrackAnnotationStoreTests`; all tests pass.

#### Phase 8: First-Round Polish and Validation ✅

- Add search/filter for sources and songs.
- Polish toolbar/menu commands and keyboard shortcuts.
- Add native empty states, missing-folder states, and accessibility labels.
- Add focused tests for source classification, remembered locations, selected song loading, and annotation persistence.
- Validate build and test with the documented `xcodebuild` commands.
- Implementation plan: `Plans/Phase8FirstRoundPolishAndValidation.md`.
- **Implemented**: Sidebar `.searchable` with `SourceLibrarySearch` filter helper; `SourceSelectedView` for source-row detail state; toolbar `.help()` and `.accessibilityIdentifier`; accessibility labels/hints/identifiers across views; 20 new search tests, 2 new classifier tests, 5 new store tests, 3 new annotation store tests. All tests passing.

### Part 2: Pre-Release / After-Release Considerations

Part 2 contains important product features, but they carry more risk because they involve file management, media identity, user trust, large scans, and eventually write operations. These should be implemented, but they should not block the first round of source-library and song-inspection work.

Each Part 2 phase should become its own dedicated plan before implementation.

Release-planning update on May 7, 2026: Phase 15 is an exception to the original "after first round" positioning. It is now a first-release visual polish requirement, while its original phase number is preserved for roadmap continuity.

#### Phase 9: Backup MVP

- Add backup actions for sources and individual songs.
- Implement read-only copy workflows with progress, cancellation, and destination selection.
- Create backup manifests.
- Preserve original folder structure and unknown/private companion files.
- Exclude ignored macOS metadata from normal logical backups; document any future raw clone mode separately.
- Support iCloud Drive destinations through standard macOS file panels.

#### Phase 10: Export Workflows

- Add DAW-friendly Export WAVs and Export Report actions.
- Add explicit master-mix copy/export actions.
- Add `AudioDepot` export/copy-out actions.
- Keep export separate from backup: export is convenience, backup is preservation.
- Decide whether exported WAVs preserve original filenames, use app labels, or offer both.

#### Phase 11: Backup Change Detection

- Show "changed since last backup" indicators.
- Use backup manifests and source snapshots to identify new, changed, and missing files.
- Start with key `.sys` fingerprints, WAV inventory metadata, sizes, and modified dates.
- Avoid whole-WAV hashing during routine scans unless the user requests deeper verification.

#### Phase 12: Automatic Removable Media Detection

- Detect likely Portastudio removable media from mounted volumes.
- Validate with volume properties, `dp-24.sys`, `MUSIC/`, `AudioDepot/`, `UTILITY/`, and song-folder evidence.
- Offer detected media to the user instead of importing silently.
- Keep user confirmation in the loop for ambiguous matches.

#### Phase 13: Advanced Custom Metadata

- Expand local annotations beyond basic track labels.
- Add track colors, notes, tags, song display-name overrides, favorite/archive states, reusable label templates, and ambiguity-resolution history.
- Match annotations back to songs using conservative identity fingerprints.
- Add UI for ambiguous matches before applying labels to copied or relocated songs.

#### Phase 14: Media Asset Browser

- Add first-class browsing for master mixes, exported tracks, project WAVs, and `AudioDepot` assets.
- Show duration, sample rate, bit depth, channels, file size, modified date, playback, and Reveal in Finder.
- Add a source-level `AudioDepot` view.
- Add song-level Master Mixes and Rendered/Other WAV sections.
- Preserve project parser evidence separately from media browsing.

#### Phase 15: Waveform and Timeline Visualization

- Add custom SwiftUI `Canvas` waveform strips.
- Add region lanes, zoom, playhead display, and evidence-scoped timeline visualization.
- Keep ambiguous regions visually distinct.
- Preserve confirmed physical track mapping while keeping still-unknown parser fields evidence-labeled.
- Implementation plan created on May 7, 2026: `Plans/Phase15WaveformAndTimelineVisualization.md`.
- Promoted into the first-release visual polish path. The plan keeps this work read-only and selected-song scoped, using derived waveform peaks and custom SwiftUI timeline rendering while deferring editing, scrubbing, media asset browsing, export, backup, AudioDepot staging, restore, and source-folder waveform caches.
- Visual target: carry forward the supplied reference's compact audio-workstation structure, colored waveform lanes, ruler/playhead, transport/time header, and right inspector while keeping controls, materials, typography, and sidebar behavior native SwiftUI/macOS.

#### Phase 16: AudioDepot Import Staging

- Validate user-selected WAV files for sample rate, bit depth, channel count, extension, size, and destination free space.
- Compare candidate WAV format against the selected song or source expectations when known.
- Show warnings that the hardware imports files from `AudioDepot` at `00:00:00:00`.
- Make copying into `AudioDepot` explicit, reversible where possible, and never automatic.
- Do not write into song folders or edit `song.sys` / `edltable.sys`.

#### Phase 17: Restore to SD Card

- Design a guarded restore flow.
- Validate destination media before writing.
- Warn clearly about overwrites.
- Prefer restoring from known-good backup manifests.
- Treat restore as a separate mode from read-only browsing.

## Open Product Questions

- Should the app support DP-24SD and DP-32SD equally from the start, or begin with DP-32SD and detect DP-24SD as related?
- What should the app call a full SD card source: Card, Media, Library, Device, or Backup?
- Should app metadata sync through iCloud eventually, or remain local by default?
- How much uncertainty should be visible to normal users versus kept in an advanced/evidence view?
- Should backup/export be free-form file copy, manifest-backed, or both?
- Should the app ever write back to an SD card, or should restore be a separate advanced feature?
- Should `AudioDepot` import staging ship before restore, or remain an advanced mode because it writes to removable media?
- What is the right UI for ambiguous identity matches?
- Should track labels be per song only, or can the user create reusable naming templates?
- Should exported WAVs preserve original filenames, use track labels, or offer both?
- Should master mix version history be app-only notes/snapshots, copied-out files, or both, given the hardware reuses `[song name].wav`?
- How much WAV format conversion should the app offer for import staging, versus only validating already-compatible files?
