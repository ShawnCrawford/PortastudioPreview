# PortastudioPreview

PortastudioPreview is a macOS SwiftUI prototype for read-only preview of TASCAM DP-32SD project folders.

The app is designed for safe inspection and approximate playback during reverse-engineering. It does not write to project folders.

## Goals

- Open a DP-32SD project folder.
- Parse `song.sys` and `edltable.sys` with evidence-scoped behavior.
- Show track-level mixer bytes and candidate WAV inventory.
- Provide approximate stereo playback for quick validation.

## Non-Goals

- No project mutation, export, or normalization.
- No destructive operations on sample folders.
- No claims above documented evidence levels.

## Repository Layout

- `PortastudioPreview/` app source
- `PortastudioPreviewTests/` Swift Testing unit/integration tests
- `PortastudioPreviewUITests/` UI test target
- `Docs/` local documentation index into the research repo

## Build and Test

```bash
xcodebuild -list -project PortastudioPreview.xcodeproj
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' build
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' test
```

Run focused suites:

```bash
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' test \
  -only-testing:PortastudioPreviewTests/EdlTableParserTests \
  -only-testing:PortastudioPreviewTests/StereoPreviewEngineTests
```

## Playback Behavior (Current)

Preview playback is intentionally conservative.

- Track-to-WAV mapping remains `Hypothesis`.
- Mute/Pan/Level handling is approximate and evidence-scoped.
- Timeline offsets inferred from `edltable.sys` are treated as `Hypothesis`.
- Playback start normalization is applied so the earliest scheduled region starts at preview time zero while preserving relative offsets between tracks.

This avoids long initial silence when inferred anchors are far from zero (for example delayed clips around the 50-second region).

## Research Dependency

Canonical reverse-engineering evidence lives in the sibling repo:

- `/Users/shawn/Projects/SwiftUI/PortastudioResearch`

Use `Docs/PortastudioResearchReferences.md` in this repo as the local index.

## Evidence Discipline

Use the evidence labels exactly as defined in the research repo:

- `Observed`
- `Correlated`
- `Confirmed`
- `Hypothesis`
- `Rejected`

Do not promote parser or playback behavior above the evidence level currently supported by tests and research artifacts.
