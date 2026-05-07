# Phase 6 Track Selection and Inspector Implementation Plan

## Summary

Phase 6 adds selection-driven track and region inspection to the Phase 5 selected-song workspace. The goal is to let users click a track or parsed region and see the important evidence, raw bytes, candidate media, and identity context in a native right-side inspector while keeping Portastudio project folders read-only and deferring app-owned labels/notes persistence to Phase 7.

## Scope

- In:
  - Add selected track state and selected region state inside the selected-song detail workspace.
  - Add a right-side inspector using SwiftUI inspector APIs; fall back to a third split column only if inspector APIs do not build cleanly in this target.
  - Make `TrackTableView` selection-aware while preserving the existing canonical raw track/mixer columns.
  - Make the unassigned regions table selection-aware.
  - Show a compact inspector with track number, candidate WAV status, evidence levels, mute/pan/level values, raw byte offsets, active-take byte where present, region timing, source filename/path, and identity/match context.
  - Reserve visible disabled/read-only placeholders for future app-owned labels and notes so Phase 7 has a clear home.
  - Update README and roadmap docs after implementation with the actual files and behavior.
- Out:
  - Do not add editable annotations, SwiftData annotation entities, migrations, track colors, tags, or notes persistence. Those belong to Phase 7.
  - Do not change parser behavior, track-to-WAV assignment, EDL timeline inference, playback scheduling, fingerprint generation, or source-library persistence.
  - Do not write sidecar files or modify `song.sys`, `edltable.sys`, WAV files, or source folder structure.

## Current Baseline

- `ContentView` uses a two-column `NavigationSplitView`: `SourceLibrarySidebarView` in the sidebar and either `ProjectOpenView` or `ProjectDetailView` in detail.
- `ProjectDetailView` is a scrollable workspace with `GroupBox` sections: Overview, Validation, Tracks, Regions / Timeline, and Preview.
- `TrackTableView` renders `Table(tracks)` with columns for track number, mapped WAV, mute, pan, level, raw bytes, and evidence. It currently has no selection binding.
- `UnassignedRegionsTableView` is private inside `ProjectDetailView` and renders `Table(regions)` with unassigned WAV, start, length, and evidence. It currently has no selection binding.
- `TrackPreview.id` is the physical `trackNumber`; `TimelineRegion.id` is derived from start/end/source filename.
- `ProjectPreviewBuilder` deliberately sets `TrackPreview.candidateWAV` and `TrackPreview.timeline` to `nil` for all tracks. Sorted filename-to-track assignment is rejected, so the inspector must not imply confirmed per-track WAV mapping.
- `ProjectDetailView` only receives `PortastudioProject`; it does not currently receive source-library records or persisted fingerprint records.
- Fingerprint and match state are persisted on `LibrarySourceRecord` and `LibrarySongRecord` and surfaced in sidebar rows, but `PortastudioProject` does not carry match state.

## Implementation Direction

### Selection Model

- Add a small view-local selection model in `ProjectDetailView`:
  - `@State private var selectedTrackID: TrackPreview.ID?`
  - `@State private var selectedRegionID: TimelineRegion.ID?`
  - `@State private var isInspectorPresented = true`
- Treat track and region selection as mutually exclusive in the inspector:
  - Selecting a track clears `selectedRegionID`.
  - Selecting a region clears `selectedTrackID`.
  - When a new project is shown, reset both selections if the selected IDs no longer exist.
- Prefer local `@State` for Phase 6 because this is per-detail-view UI state. Use `@SceneStorage` only if selection reset during normal navigation is visibly disruptive.

### Track Table

- Change `TrackTableView` to accept a binding:
  - `let tracks: [TrackPreview]`
  - `@Binding var selectedTrackID: TrackPreview.ID?`
  - Optional callback `var onSelectTrack: ((TrackPreview.ID?) -> Void)?` if needed to clear region selection cleanly.
- Use SwiftUI `Table(tracks, selection: $selectedTrackID)` or the equivalent initializer that builds on this app target.
- Keep all existing columns and display text intact unless needed for selection affordance.
- Add accessibility labels or values only where they clarify row-level selection; do not turn the table into a custom card list.

### Region Table

- Update `UnassignedRegionsTableView` to accept `@Binding var selectedRegionID: TimelineRegion.ID?`.
- Use `Table(regions, selection: $selectedRegionID)`.
- Preserve the current approximate-time display style already used by Phase 5 and keep `Hypothesis` evidence visible.
- If compiler constraints make `TimelineRegion.ID` awkward because it is a computed `String`, add a tiny wrapper or helper only inside the view layer. Do not change parser models unless necessary.

### Inspector UI

- Add a new file `PortastudioPreview/Views/TrackRegionInspectorView.swift`.
- Suggested public/internal surface:
  - `struct TrackRegionInspectorView: View`
  - inputs: `project: PortastudioProject`, `selectedTrack: TrackPreview?`, `selectedRegion: TimelineRegion?`
- Attach it from `ProjectDetailView` with `.inspector(isPresented: $isInspectorPresented) { ... }`.
- Inspector width target: roughly 260 to 340 points. Use native section layout (`Form`, `Grid`, or small `VStack` sections), system colors, and text that truncates middle for paths.
- Inspector empty state:
  - Show "No Track or Region Selected" and short neutral copy when nothing is selected.
  - Keep the inspector visible by default so users learn selection is available.
- Track inspector content:
  - Track number.
  - Candidate WAV: filename or "Unassigned"; evidence `Hypothesis` when non-nil, `Observed`/plain unassigned when nil.
  - Mute: display raw byte and evidence; include mirror mismatch warning if present.
  - Pan: mapped value from `PanMapper.displayValue`, primary raw byte, raw offset, mirror raw byte/offset when present, evidence.
  - Level: mapped value from `LevelMapper.displayValue`, primary raw byte, raw offset, mirror raw byte/offset when present, evidence.
  - Active take: show `edltable.sys` offset `0x00B01A38` and byte only for track 1 when `track1ActiveTakeCandidate` exists; evidence should remain correlated.
  - Raw bytes: reuse `MixerSetting.rawBytesDescription` and the existing active-take formatting.
  - Identity/match context: show "Track identity: song fingerprint + track number (Phase 7 key)" or equivalent read-only context. Do not claim persisted labels exist.
  - Future labels/notes: disabled fields or a read-only reserved section labeled as not yet editable/app-owned metadata.
- Region inspector content:
  - Source filename and path/reveal context if `sourceURL` exists.
  - Start sample and approximate time.
  - Length/end sample and approximate time when available.
  - Evidence level.
  - Mapping status: "Unassigned region; track-to-WAV assignment remains Hypothesis."
  - If the region source filename appears in `edlTableSummary.fileListEntries`, show file-list ID and that entry's evidence.
- Avoid action buttons that imply mutation. `Reveal in Finder` may be acceptable if implemented through `NSWorkspace` and read-only, but it is not required for Phase 6.

### Helper Types

- Add `PortastudioPreview/Views/TrackInspectionSummary.swift` only if the inspector view starts accumulating formatting logic.
- Keep helper types pure value/read-only and internal.
- Candidate helpers:
  - selected track lookup from `project.tracks`.
  - selected region lookup from `project.unassignedAudioRegions`.
  - field rows for label/value/evidence display.
  - raw offset display for `MixerSetting`.
- Reuse existing helpers:
  - `HexFormatter`
  - `PanMapper`
  - `LevelMapper`
  - `SampleTimeFormatter`
  - `EvidenceLevel`

## Expected Files

### Likely new files

| File | Purpose |
| --- | --- |
| `Plans/Phase6TrackSelectionInspector.md` | Durable implementation handoff plan |
| `PortastudioPreview/Views/TrackRegionInspectorView.swift` | Native right-side inspector for selected track or region |
| `PortastudioPreviewTests/TrackRegionInspectorSummaryTests.swift` | Only if a pure summary/helper type is introduced |

### Likely modified files

| File | Change |
| --- | --- |
| `PortastudioPreview/Views/ProjectDetailView.swift` | Own track/region selection state, attach inspector, pass bindings into track and region tables |
| `PortastudioPreview/Views/TrackTableView.swift` | Add single-selection binding while preserving columns |
| `Docs/ProductVisionAndRoadMapPlanning.md` | Mark Phase 6 implemented after completion and summarize behavior |
| `Docs/ProductVisionAndRoadmap.md` | Update current baseline and suggested roadmap Phase 6 status |
| `README.md` | Add current Phase 6 inspector behavior and read-only constraints |

## Testing Plan

- Add focused tests only for pure logic introduced by this phase:
  - track inspector summary includes track number, mapped pan/level display, raw offsets, evidence, mirror mismatch warning, and active-take byte when present.
  - region inspector summary includes source filename, start/length approximate strings, evidence, and EDL file-list ID when matched.
  - empty selection produces a stable empty summary.
- If the implementation stays view-only with no pure helper, do not force brittle SwiftUI snapshot tests; rely on build plus existing model tests.
- Keep existing parser/playback/library tests unchanged:
  - `ProjectPreviewBuilderTests`
  - `SongSysParserTests`
  - `EdlTableParserTests`
  - `PreviewPlaybackPlannerTests`
  - `StereoPreviewEngineTests`
  - `SourceLibraryStoreTests`
- Validation commands:

```bash
xcodebuild -list -project PortastudioPreview.xcodeproj
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' build
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' test
```

## Manual Acceptance Criteria

- Open or select any song and confirm the Phase 5 workspace still shows Overview, Validation, Tracks, Regions / Timeline, and Preview.
- Select a track row and confirm the inspector shows track number, mute/pan/level mapped values, raw byte offsets, evidence labels, and read-only identity context.
- Select an unassigned region row and confirm the inspector switches to region timing/source/evidence details.
- Confirm selecting a track clears region inspection, and selecting a region clears track inspection.
- Confirm songs with no WAV inventory, no EDL summary, or parser warnings still render the inspector without crashes.
- Confirm no selected Portastudio folder contents change after browsing, selecting rows, and opening/closing the inspector.

## Evidence Discipline

- Keep track-to-WAV assignment labeled `Hypothesis` wherever candidate WAV or timeline inference is discussed.
- Show `Observed`, `Correlated`, `Confirmed`, `Hypothesis`, and `Rejected` exactly as defined in the research repo.
- Do not promote active-take, pan/level, mute, timeline, or WAV mapping evidence beyond the levels already encoded in current models and docs.
- Be explicit that Phase 6 identity context is preparatory for Phase 7 labels; it is not annotation persistence.

## Risks and Guardrails

- SwiftUI `Table` selection initializers can be picky across macOS SDK versions. Prefer the smallest compile-clean refactor of `TrackTableView` and `UnassignedRegionsTableView`; do not replace the native tables with custom rows unless the SDK blocks table selection.
- `PortastudioProject` does not know source-library match state. Do not thread `SourceLibraryStore` into `ProjectDetailView` only to show match status. For Phase 6, show project-local identity context and source filename/path; richer persisted match display can be added when annotation identity is implemented.
- Avoid growing `ProjectDetailView` into one large file. Move inspector-specific formatting and sections to `TrackRegionInspectorView.swift` or a small summary helper.
- Keep the inspector read-only. Editable fields that do not persist would be misleading, and persisted annotations belong to Phase 7.

## Assumptions

- Phase 1 through Phase 5 are implemented as documented on May 7, 2026.
- The app remains macOS-only and uses SwiftUI with SwiftData already configured in `PortastudioPreviewApp`.
- New Swift source files are picked up by the existing Xcode file-system-synchronized groups without manual project-file edits.
- Phase 6 should update docs after implementation, but this saved plan does not itself implement app code.
