# Phase 15 Waveform and Timeline Visualization Implementation Plan

## Summary

Phase 15 adds a polished, evidence-scoped waveform and timeline surface to the selected-song workspace so the first release feels like a real macOS audio utility instead of a parser table. The implementation should build on the current read-only project model: derive lightweight waveform peak data from existing WAV files, render custom SwiftUI `Canvas` strips and region lanes, add zoom/playhead display, and keep every uncertain region or track mapping visibly labeled as `Hypothesis`.

This phase is now promoted into the first-release visual polish path. It must not expand into media asset browsing, export, backup, AudioDepot staging, restore, destructive editing, or stronger track-to-WAV claims.

## Visual Target

The initiating request included a reference mockup that should guide the Phase 15 visual direction. The implementation should look similar in information architecture and density while still feeling like a native SwiftUI macOS app, not a pixel-for-pixel custom skin.

Reference characteristics to carry forward:

- A three-column desktop layout: source library sidebar on the left, timeline/editor workspace in the center, inspector on the right.
- A strong selected-song header above the editor with thumbnail/device context, song title, project format metadata, read-only status, transport controls, time display, and simple level/meter affordance.
- A tab-like mode row for `Tracks`, `Timeline`, and `Inspector` style sections, with the active mode indicated by a restrained accent underline.
- A central timeline with a time ruler, vertical playhead, colored horizontal waveform lanes, compact track/region labels, and clear selected-region highlighting.
- Track/region lanes that feel DAW-inspired: dense, aligned, and scannable, with per-lane color accents and small mute/solo/status affordance space where future phases can grow.
- An inspector that uses compact native rows for song information, identity/evidence, labels, and actions, while Phase 15 only implements the information relevant to existing read-only preview.
- A bottom or lower detail area may eventually hold mixer-like controls, but Phase 15 should not implement a full mixer unless it is already trivial from existing data. The required first-release work is the visual timeline and waveform surface.

Native SwiftUI adaptation:

- Keep sidebars, toolbars, inspectors, controls, lists, buttons, materials, and typography aligned with macOS conventions.
- Prefer system-adaptive materials and semantic foreground styles over fixed light panels.
- Use the reference for layout rhythm, timeline density, and audio-workstation feel, not for adding out-of-scope backup/export actions or unsupported meter/mixer claims.
- Preserve the existing table and evidence views below or near the timeline so the polished view does not replace research precision.

## Scope

- In:
  - Add a song-level timeline visualization inside the existing `Regions / Timeline` area of `ProjectDetailView`.
  - Add read-only waveform strips for project-region WAVs using generated peak summaries.
  - Add region lanes, a time ruler, zoom controls, horizontal scrolling, selected-region highlighting, and playhead display.
  - Reuse existing `TimelineRegion`, `PreviewPlaybackPlanner`, `StereoPreviewEngine`, and selection state where possible.
  - Keep ambiguous and inferred data visually distinct through evidence labels, muted styling, dashed outlines, or uncertainty badges.
  - Add pure, testable presenter/layout logic for timeline extents, region frames, time formatting, zoom scales, and peak downsampling.
  - Add focused tests for peak generation, timeline layout math, zoom clamping, selection identity, empty states, and read-only guarantees.
  - Update `README.md`, `Docs/ProductVisionAndRoadMapPlanning.md`, and `Docs/ProductVisionAndRoadmap.md` after implementation with actual behavior and validation results.
- Out:
  - Do not implement waveform editing, trimming, moving, splitting, snapping, drag-rearrange, fades, markers, automation, or DAW-style editing gestures.
  - Do not implement backup, export, copy-out, media asset browser, master-mix browsing, AudioDepot browsing/staging, or restore workflows.
  - Do not write waveform cache files into Portastudio song folders or any source media folder.
  - Do not add third-party waveform, audio-analysis, charting, or layout frameworks.
  - Do not promote track-to-WAV assignment, EDL timeline anchors, active-take mapping, or inferred region timing beyond their current evidence levels.
  - Do not require Phase 14 media asset models; Phase 15 should work from the selected `PortastudioProject` already loaded today.

## Current Baseline

- The app is macOS-only SwiftUI, target macOS 26.0+, Swift 6.2+, with native `WindowGroup`, `NavigationSplitView`, toolbar commands, and a right-side SwiftUI `.inspector`.
- The selected-song detail surface is `ProjectDetailView`, a scroll view with `Overview`, `Validation`, `Tracks`, `Regions / Timeline`, and `Preview` group boxes.
- `RegionsTimelineGroupBoxView` currently shows a short explanation, a SwiftUI `Table` of `project.unassignedAudioRegions`, and `EDLSummaryView` for file-list entries and timeline candidates.
- `ProjectDetailView` owns `selectedTrackID`, `selectedRegionID`, and `isInspectorPresented`. Track and region selection are mutually exclusive.
- `TimelineRegion` already provides `startSample`, `endSample`, `lengthSample`, `sourceFilename`, `sourceURL`, `evidenceLevel`, `id`, and `resolvedLengthSample`.
- `ProjectPreviewBuilder` builds `unassignedAudioRegions` from `WAVInventoryScanner` plus `EdlTableParser` output. Regions are currently `Hypothesis`.
- `ProjectPreviewBuilder.inferredStartSamples` preserves delayed single regions, pairs an implicit zero region with delayed anchors when counts match, and falls back to zero when pairing is ambiguous.
- `ProjectPreviewBuilder.sequentialStartSamplesIfConfirmed` can infer sequential starts from WAV lengths only when binary evidence is found in `edltable.sys`; this remains `Hypothesis`.
- `EdlTableParser` extracts file-list entries and timeline candidate sample anchors from `edltable.sys`. File-list entries and timeline candidates are not physical track assignments.
- `WAVInventoryItem` only stores `url`, `rawFilename`, and `byteCount`; waveform peak data, sample rate, channel count, and duration are not persisted.
- `SampleTimeFormatter` formats approximate sample positions at 48,000 Hz for UI display.
- `PreviewPlaybackPlanner.plan(for:)` returns playable scheduled regions after active-take filtering and limited mute suppression. This is the best existing source for "what will preview play" state.
- `StereoPreviewEngine` starts/stops approximate AVFoundation playback and receives live level, pan, and mute updates from `PreviewPlaybackController`.
- `PreviewPlaybackController` owns shared transport state for the header and timeline. It applies level, pan, mute, and solo-derived mute edits while playback is paused so resume uses current mixer settings.
- `README.md` documents that track-to-WAV mapping remains `Hypothesis`, unassigned regions use EDL file-list order when available, timeline offsets are `Hypothesis` 44.1k/48k-domain candidates depending on source, and preview start normalization avoids long initial silence while preserving relative offsets.

## Implementation Direction

### 1. Data and Presenter Layer

- Add pure timeline presentation models rather than drawing directly from `PortastudioProject` in SwiftUI:
  - `TimelineVisualizationModel`
  - `TimelineLane`
  - `TimelineRegionPresentation`
  - `TimelineTimeRulerTick`
  - `TimelineZoomLevel` or a small zoom state type
- Keep these as value types in `PortastudioPreview/Models/` or `PortastudioPreview/Support/`, depending on whether they are reusable outside the view.
- Add `TimelineVisualizationBuilder` or `TimelineVisualizationPresenter` as a pure service that accepts:
  - `project: PortastudioProject`
  - optional selected region ID
  - optional playback plan
  - zoom state / visible sample range
- Output should include:
  - ordered region presentations
  - total sample extent
  - per-lane labels
  - region evidence labels
  - whether each region is playable, suppressed, missing a source file, or ambiguous
  - source filename and approximate start/length/end display strings
- Derive playable/suppressed state from `PreviewPlaybackPlanner.plan(for:)`, not by duplicating filtering rules in the view.
- Keep all timeline math in sample units until final pixel conversion. Convert samples to x-positions through one small tested mapping function.
- Preserve region identity by `TimelineRegion.id` so table selection, canvas highlighting, and inspector selection stay in sync.

### 2. Waveform Peak Generation

- Add a read-only waveform analysis service, for example `WaveformPeakBuilder`.
- Input should be a `TimelineRegion` or WAV `URL` plus a target maximum peak bucket count.
- Output should be a small `WaveformPeakSummary` value:
  - source URL or stable source ID
  - sample count read
  - channel count
  - sample rate
  - `[WaveformPeak]` buckets with min/max or absolute peak values
  - failure state if the WAV cannot be decoded
- Use AVFoundation (`AVAudioFile` / `AVAudioPCMBuffer`) because the project already uses AVFoundation and no third-party dependency is allowed.
- Downsample while streaming in chunks rather than loading full long WAVs into memory.
- Use a conservative max bucket count appropriate for the visible drawing width. Do not create one peak per sample.
- Treat waveform summaries as derived app data. For Phase 15, prefer in-memory `@State` / `@Observable` cache scoped to the selected project. If persistence is added later, it must be app-owned Application Support or SwiftData, never sidecars in song folders.
- Add cancellation support for waveform generation when the selected song changes.
- Keep failures non-fatal: a region with unreadable audio should still render as a region block with "Waveform unavailable" styling.

### 3. Timeline UI Surface

- Replace the table-only first impression in `RegionsTimelineGroupBoxView` with a compact native timeline panel above the existing table:
  - time ruler at the top
  - horizontal zoom control and reset button
  - horizontally scrollable canvas region
  - one lane for the current unassigned project-region set initially
  - region blocks with waveform strips when peak data is available
  - visible evidence marker, likely `Hypothesis`, in the panel header or on ambiguous blocks
- Design the central panel to echo the reference mockup: left-aligned lane labels, colored waveform lanes, a thin vertical playhead, light grid/ruler structure, and compact controls in the header.
- If physical track mapping is still unavailable, label lanes by source region/file order rather than pretending they are Track 1, Track 2, etc. Future correlated mapping can rename lanes later.
- Use stable per-region or per-file accent colors so adjacent waveform strips are easy to distinguish. Colors should be restrained and system-friendly, not a bright one-note palette.
- Keep the existing `UnassignedRegionsTableView` below the visual timeline for research/debug precision and accessibility.
- Use `Canvas` for dense waveform and lane drawing. Use normal SwiftUI controls around it for zoom, selection labels, and buttons.
- Keep the layout quiet, dense, and desktop-native:
  - system-adaptive backgrounds
  - restrained selection highlight
  - no marketing hero, no decorative gradients, no card nesting
  - region blocks with stable height and no text overflow
  - table remains available for exact sample values
- Add an empty state for songs with no parsed regions: a plain message inside the Regions/Timeline group, not a large onboarding panel.
- For songs with all regions at zero due to ambiguous timing, render stacked/overlapped regions clearly and add concise copy that timing is unresolved.
- For delayed clips, preserve timeline offset in the visual position; do not normalize the visual timeline to zero in a way that hides evidence. Playback may normalize start time, but visualization should show inferred project positions.

### 4. Zoom, Scroll, and Ruler

- Add local view state for zoom, probably in `ProjectDetailView` or a new `TimelineVisualizationView`, not in global stores.
- Provide a small set of zoom levels such as `Fit`, `Seconds`, `Detailed`, or a bounded slider. Avoid arbitrary unbounded scale.
- At minimum, support:
  - Fit all regions
  - Zoom in
  - Zoom out
  - Reset
- Use buttons with icons and text labels where needed:
  - `Button("Zoom In", systemImage: "plus.magnifyingglass", action: ...)`
  - `Button("Zoom Out", systemImage: "minus.magnifyingglass", action: ...)`
  - `Button("Fit", systemImage: "arrow.up.left.and.arrow.down.right", action: ...)`
- Add `.help(...)`, accessibility labels, and stable identifiers for zoom controls.
- Generate time ruler ticks from visible sample range and zoom scale with a pure tested helper.
- Prefer modern scroll APIs where practical. Avoid `ScrollViewReader` unless there is no simpler way.

### 5. Selection and Inspector Coordination

- Keep `selectedRegionID` as the single source of truth for region selection in `ProjectDetailView`.
- Pass `$selectedRegionID` into the new timeline view.
- Clicking a visual region should select it via `Button`/accessibility action where possible. If `Canvas` hit-testing requires gesture handling, isolate it in one small view and keep the table path fully keyboard-accessible.
- Selecting a visual region must clear the selected track through the existing `onChange(of: selectedRegionID)` logic.
- The existing `TrackRegionInspectorView` should continue to show region details without needing a new inspector.
- Add accessibility values so VoiceOver can identify region filename, approximate start, length, evidence, and playable/suppressed state.

### 6. Playhead Display

- Add a playhead overlay that can be displayed even before full synchronized transport is implemented:
  - idle state: hidden or pinned at zero
  - playing state: advances based on a lightweight playback clock
  - stopped state: returns to zero unless a later phase adds seek
- Prefer introducing a small `PreviewPlaybackController` or `@MainActor @Observable` transport model if playhead state needs to be shared between `PreviewTransportView` and `TimelineVisualizationView`.
- If this is too broad for Phase 15, keep `PreviewTransportView` as the owner but expose `isPlaying` and approximate elapsed time through a small binding or callback.
- Do not implement seeking in Phase 15 unless it falls out naturally. Playhead display is in scope; timeline scrubbing is out of scope.
- Use Swift concurrency (`Task`, `Task.sleep(for:)`) or SwiftUI timeline-driven updates. Do not add `DispatchQueue.main.async`.
- Keep playback completion main-actor safe. If touching `StereoPreviewEngine`, modernize existing callback dispatch to avoid old GCD while preserving behavior.

### 7. Evidence Styling

- Every visual region sourced from `project.unassignedAudioRegions` should carry `region.evidenceLevel`.
- The group explanation must continue to state that track-to-WAV assignment is `Hypothesis`.
- File-list ordering can be shown as EDL order, not track order.
- Visually distinguish:
  - playable regions
  - suppressed regions from active-take/mute filtering
  - regions with missing/unreadable WAVs
  - ambiguous all-zero timing
  - timeline candidates that are not assigned to specific regions
- Use existing evidence labels exactly: `Observed`, `Correlated`, `Confirmed`, `Hypothesis`, `Rejected`.
- Do not use waveform presence as evidence that a region is active, assigned to a physical track, or part of the final device mix.

### 8. Performance and Concurrency

- Generate peaks asynchronously after project load and cancel work when the project changes.
- Cap concurrent WAV reads to avoid hammering removable media. A simple serial actor or task group with small concurrency is acceptable.
- Use memory-bounded chunked reads for long WAV files.
- Render placeholder region blocks immediately, then fill waveforms as peak summaries arrive.
- Keep the UI responsive for real cards with hundreds of songs and large WAV folders.
- Avoid whole-WAV hashing or permanent WAV caches in this phase.
- Maintain read-only behavior with `FileReadOnlyGuard` coverage for waveform generation.

## Expected Files

### Likely new files

| File | Purpose |
| --- | --- |
| `Plans/Phase15WaveformAndTimelineVisualization.md` | Durable implementation handoff plan |
| `PortastudioPreview/Models/WaveformPeakSummary.swift` | Peak bucket value types |
| `PortastudioPreview/Models/TimelineVisualizationModel.swift` | Pure presentation model for lanes, regions, ruler ticks, and evidence state |
| `PortastudioPreview/Services/WaveformPeakBuilder.swift` | AVFoundation-based read-only peak generation |
| `PortastudioPreview/Services/TimelineVisualizationBuilder.swift` | Pure conversion from `PortastudioProject` + playback plan to visual timeline model |
| `PortastudioPreview/Views/TimelineVisualizationView.swift` | Native SwiftUI wrapper, zoom controls, scroll view, selection wiring |
| `PortastudioPreview/Views/WaveformCanvasView.swift` | Focused `Canvas` waveform and region drawing |
| `PortastudioPreviewTests/WaveformPeakBuilderTests.swift` | Synthetic WAV/fixture peak and read-only tests |
| `PortastudioPreviewTests/TimelineVisualizationBuilderTests.swift` | Timeline extent, region positioning, ruler, zoom, evidence tests |

### Likely modified files

| File | Change |
| --- | --- |
| `PortastudioPreview/Views/ProjectDetailView.swift` | Insert timeline visualization above the existing unassigned-region table and pass selection binding |
| `PortastudioPreview/Views/PreviewTransportView.swift` | Optionally expose/shared playback state for playhead display |
| `PortastudioPreview/Services/StereoPreviewEngine.swift` | Optionally modernize completion dispatch and expose enough timing for playhead state |
| `PortastudioPreview/Support/SampleTimeFormatter.swift` | Add modern `FormatStyle`-based formatting if timeline/ruler work touches it |
| `PortastudioPreviewTests/SampleTimeFormatterTests.swift` | Extend for ruler-friendly labels if formatter changes |
| `PortastudioPreviewTests/ProjectPreviewBuilderTests.swift` | Add coverage only if timeline extents reveal a region-model edge case |
| `README.md` | Document Phase 15 plan/implementation, current limitations, validation commands/results |
| `Docs/ProductVisionAndRoadMapPlanning.md` | Mark Phase 15 plan status and first-release promotion/implementation status |
| `Docs/ProductVisionAndRoadmap.md` | Update current baseline, roadmap status, and visual-timeline product direction |

## Testing Plan

- Add unit tests for `TimelineVisualizationBuilder`:
  - empty projects produce an empty timeline model and clear empty-state reason
  - single zero-start region begins at x = 0 in fit mode
  - delayed single region preserves its delayed start in project-time visualization
  - multiple regions compute total extent from max end sample
  - missing `endSample` / `lengthSample` falls back to a minimum visual width without crashing
  - all-zero multi-region timing is flagged as ambiguous
  - suppressed playback entries are reflected in presentation state
  - selected region ID is marked selected and does not alter region ordering
  - zoom scale clamps to supported min/max
  - time ruler ticks are stable for representative short and long projects
- Add unit tests for `WaveformPeakBuilder`:
  - generated synthetic silent WAV yields zero peaks
  - generated synthetic non-silent WAV yields non-zero peak buckets
  - bucket count is capped at the requested maximum
  - unreadable files return a controlled failure state
  - source folder snapshot is unchanged before/after peak generation
- Extend view-independent tests instead of adding brittle screenshots. UI tests are optional and should only be added if pure tests cannot cover a critical behavior.
- Run focused tests during implementation:

```bash
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' test \
  -only-testing:PortastudioPreviewTests/TimelineVisualizationBuilderTests \
  -only-testing:PortastudioPreviewTests/WaveformPeakBuilderTests \
  -only-testing:PortastudioPreviewTests/ProjectPreviewBuilderTests \
  -only-testing:PortastudioPreviewTests/StereoPreviewEngineTests \
  -only-testing:PortastudioPreviewTests/SampleTimeFormatterTests
```

- Before finishing implementation, run the documented full build and test:

```bash
xcodebuild -list -project PortastudioPreview.xcodeproj
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' build
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' test
```

- If SwiftLint is installed, run it and resolve warnings before committing.

## Manual Acceptance Criteria

- Open a song with parsed `unassignedAudioRegions`; the Regions/Timeline section shows a visual timeline above the existing table.
- The visual timeline looks polished in light and dark mode, uses native controls, and does not overlap or truncate important labels at normal window sizes.
- The central workspace visually resembles the supplied reference: compact audio-editor density, colored waveform lanes, time ruler, vertical playhead, source sidebar/detail/inspector relationship, and native SwiftUI styling.
- Region blocks show waveform detail when available and a stable placeholder when waveform generation is pending or unavailable.
- Selecting a visual region selects the matching table row and opens the existing region inspector.
- Selecting a table row highlights the matching visual region.
- Zoom in/out/fit controls work without resizing the surrounding layout unpredictably.
- The time ruler remains readable for short clips, delayed clips, and multi-minute projects.
- A delayed region appears at its inferred project offset instead of visually starting at zero.
- Songs with all regions at zero show an uncertainty/ambiguous timing cue.
- Playhead display appears during playback if implemented; stopping playback clears or resets it predictably.
- The existing Play/Stop flow still works and still warns that preview is approximate.
- VoiceOver can identify the timeline, zoom controls, region filename, approximate time, length, evidence level, and selected state.
- Running waveform generation does not create, modify, or delete anything in the selected Portastudio folder.

## Evidence Discipline

- Preserve current evidence labels exactly: `Observed`, `Correlated`, `Confirmed`, `Hypothesis`, and `Rejected`.
- Do not imply that EDL file-list order is physical track order.
- Do not imply that a displayed waveform is part of the active final mix unless `PreviewPlaybackPlanner` marks it playable under current evidence rules.
- Do not promote timeline anchors or sequential layout beyond `Hypothesis`.
- Keep current active-take and mute suppression caveats visible in copy, help text, inspector details, or presentation state.
- Do not hide the existing raw table; it is still the precise evidence/debug surface.

## Risks and Guardrails

- Waveform generation can become expensive on large cards. Keep peak building chunked, cancellable, and memory-bounded.
- Drawing every point in `Canvas` can be slow. Draw bucket summaries, not raw samples.
- Visual polish can accidentally overstate evidence. Use explicit evidence labels and uncertainty styling.
- Playhead synchronization can grow into seeking/scrubbing. Keep Phase 15 to display-only unless the user explicitly scopes seeking later.
- The current app has local transport state in `PreviewTransportView`. If sharing playback state becomes awkward, introduce a small `@MainActor @Observable` controller instead of threading many callbacks through views.
- `ProjectDetailView.swift` already contains several private subviews. If timeline work makes it large, move timeline-specific views into separate files rather than adding more nested complexity.
- Do not use `GeometryReader` unless a newer SwiftUI layout alternative is insufficient. Prefer stable dimensions, container-relative sizing, and explicit sample-to-pixel math.
- Do not use `onTapGesture` for normal selection if a `Button` or accessible control can express the interaction. If canvas hit-testing needs a gesture, isolate and document that exception.
- Avoid C-style formatting if touching timeline labels. Prefer `FormatStyle`.
- Do not introduce AppKit for drawing. Use SwiftUI `Canvas`; use AVFoundation only for audio decoding/metadata.

## Documentation Updates After Implementation

- Update `README.md` with:
  - implemented timeline/waveform behavior
  - limitations and evidence labels
  - validation command results
  - any performance or cache decisions
- Update `Docs/ProductVisionAndRoadMapPlanning.md` with:
  - Phase 15 implementation status
  - first-release promotion status
  - exact files and tests added
- Update `Docs/ProductVisionAndRoadmap.md` with:
  - Current App Baseline row for visual timeline/waveforms
  - Phase 15 roadmap status
  - any refined product direction discovered during implementation

## Assumptions

- Phases 1 through 8 are implemented as documented on May 7, 2026.
- Phase 14 media asset browser is not required for this work.
- `TimelineRegion` remains the canonical input for visualized project-region WAVs.
- Waveform data is derived read-only from WAV files and is not evidence of physical track assignment.
- First release now includes this Phase 15 visual timeline because the UI needs stronger polish before shipping.
