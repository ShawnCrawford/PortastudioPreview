# Phase 5 Song Detail UI Refresh Implementation Plan

## Summary

Phase 5 is a UI-only refresh of the selected-song workspace (`ProjectDetailView`). It adds a polished, scrollable layout with grouped sections, overview metrics, clearer evidence labeling, improved transport copy, and focused tests for new formatting helpers. Parsing, fingerprinting, playback semantics, track-to-WAV assignment, and read-only guarantees are unchanged.

## Key Changes

- Refactored `ProjectDetailView` into a scrollable `VStack` of `GroupBox` sections:
  - **Overview** — folder name, path, track count, WAV count, unassigned region count, EDL file list count, timeline candidate count, preview availability.
  - **Validation** — wraps `ValidationIssuesView`; GroupBox label tint reflects severity (green / orange / red).
  - **Tracks** — wraps the existing `TrackTableView` (raw byte/mixer table preserved).
  - **Regions / Timeline** — explanatory label + unassigned region `Table` (with approximate time display) + optional EDL file list and timeline candidate summary.
  - **Preview** — wraps `PreviewTransportView` with improved empty/disabled copy.

- Added `SongDetailSummary` (internal struct, `Views/SongDetailSummary.swift`):
  - Derived from `PortastudioProject`; pure value-type summary for the Overview section.
  - Fields: `folderName`, `folderPath`, `trackCount`, `wavCount`, `assignedTrackCount`, `validationIssueCount`, `hasErrors`, `unassignedRegionCount`, `edlFileListCount`, `timelineCandidateCount`, `previewAvailable`.
  - `previewAvailable` delegates to `StereoPreviewEngine.hasPlayableTracks(_:)`.

- Added `SampleTimeFormatter` (internal enum, `Support/SampleTimeFormatter.swift`):
  - Converts a sample count to a display string at the standard 48 kHz rate.
  - `displayString(samples:sampleRate:)` — returns `"0s"` for zero/negative, `"N.Ns"` for sub-minute, `"Nm N.Ns"` for ≥ 60 s.
  - `displayString(optionalSamples:)` — returns `"Unknown"` for `nil`, delegates otherwise.
  - Used in the regions table (start, length) and EDL timeline candidate rows.
  - Approximate-time displays are preceded by `≈` to communicate the Hypothesis nature of sample positions.

- Updated `ValidationIssuesView`:
  - Removed internal "Validation" headline and padding; section header lives in the enclosing GroupBox label.

- Updated `PreviewTransportView`:
  - Added `accessibilityLabel` for Play and Stop buttons.
  - Added clearer empty/disabled copy when no playable WAV regions exist.
  - Kept Play/Stop logic, `onDisappear` stop, and `StereoPreviewEngine` unchanged.

## Interfaces and Files

No new persistence entities, migrations, parser fields, source-library models, or service APIs.

### New files

| File | Purpose |
| --- | --- |
| `Plans/Phase5SongDetailUIRefresh.md` | This plan artifact |
| `PortastudioPreview/Support/SampleTimeFormatter.swift` | Sample-to-time formatting helper |
| `PortastudioPreview/Views/SongDetailSummary.swift` | Pure view-model derived from `PortastudioProject` |
| `PortastudioPreviewTests/SampleTimeFormatterTests.swift` | Unit tests for formatter |
| `PortastudioPreviewTests/SongDetailSummaryTests.swift` | Unit tests for summary counts |

### Modified files

| File | Change |
| --- | --- |
| `PortastudioPreview/Views/ProjectDetailView.swift` | Full rewrite: scrollable GroupBox sections |
| `PortastudioPreview/Views/PreviewTransportView.swift` | Improved copy and accessibility labels |
| `PortastudioPreview/Views/ValidationIssuesView.swift` | Remove internal header and padding |
| `Docs/ProductVisionAndRoadMapPlanning.md` | Phase 5 implemented status |
| `Docs/ProductVisionAndRoadmap.md` | Baseline table and roadmap Phase 5 mark |
| `README.md` | Phase 5 Song Detail Workspace note |

## Evidence Discipline

- Overview and regions/timeline show the word **Hypothesis** wherever inferred track-to-WAV assignment is involved.
- Approximate time values prefixed with `≈`; Hypothesis label appears next to timeline candidate displays.
- EDL file-list evidence level is shown from the parsed `EdlTableSummary.evidenceLevel`.
- No evidence label is promoted beyond its documented level.

## Test Plan

### New tests

- `SampleTimeFormatterTests`: zero, negative, whole seconds (1s, 2s), fractional (0.5s), minutes+seconds (1m 30.5s), nil, nil passthrough.
- `SongDetailSummaryTests`: empty project, project with tracks/WAVs/issues/regions/EDL, preview-available vs unavailable.

### Unchanged tests (must continue to pass)

- `ProjectPreviewBuilderTests`
- `PreviewPlaybackPlannerTests`
- `StereoPreviewEngineTests`
- All parser and source-library suites

## Assumptions

- Phase 1–4 behavior is already implemented as documented on May 7, 2026.
- No new model fields, services, or persistence are introduced.
- Source folders remain read-only; only app source, tests, docs, and this plan artifact are changed.
- `SongDetailSummary.previewAvailable` is the canonical check for Play button enablement.
