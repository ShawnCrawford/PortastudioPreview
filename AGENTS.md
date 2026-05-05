# Repository Guidelines

## Project Structure & Module Organization

This is a separate macOS SwiftUI app repo for a read-only TASCAM DP-32SD preview prototype. Keep reverse-engineering evidence in the sibling research repo at `/Users/shawn/Projects/SwiftUI/PortastudioResearch`; do not copy large project samples or derived binary dumps into this app repo unless there is a deliberate fixture need.

The app target lives in `PortastudioPreview/`, Swift Testing coverage in `PortastudioPreviewTests/`, and UI tests in `PortastudioPreviewUITests/`. Keep source split by responsibility: `App/` for the `@main` entry point and app commands, `Models/` for parsed project and track value types, `Services/` for folder loading, `song.sys`, `edltable.sys`, WAV inventory, and audio-preview code, `Views/` for SwiftUI surfaces, and `Support/` for byte, pan, and level mapping helpers.

## Research References

Use `Docs/PortastudioResearchReferences.md` as the local index into the research repo. Canonical evidence lives in:

- `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Methodology/BinaryDiffLog.md`
- `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Specs/song.sys.md`
- `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Specs/edltable.sys.md`

Treat copied sample folders under `PortastudioResearch/Docs/TestProjects/` as read-only. Use evidence labels exactly as written in the research repo: `Observed`, `Correlated`, `Confirmed`, `Hypothesis`, and `Rejected`. Do not promote a parser behavior beyond the evidence level documented there.

## Build, Test, and Development Commands

- `xcodebuild -list -project PortastudioPreview.xcodeproj`
- `xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' build`
- `xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' test`

Run targeted tests by adding `-only-testing:PortastudioPreviewTests/<TestType>/<testName>` to the test command.

## Coding Style & Naming Conventions

Use SwiftUI for app structure and AVFoundation for audio preview playback. Keep parsers read-only and deterministic: accept `URL` or `Data`, return typed models, and avoid UI dependencies in parser services. Keep byte offsets hexadecimal in comments and test names when they refer to research findings, such as `0x00C4` for the track 1 level-like byte.

The approximate stereo preview is intentionally conservative. Track-to-WAV assignment remains `Hypothesis`, and `StereoPreviewEngine` currently treats raw level byte `0x00` as unity gain because populated MVP folders use `0x00` on audible tracks and the real level scale is not confirmed.

## Testing Guidelines

Use Swift Testing in `PortastudioPreviewTests`. Parser tests should use small committed fixtures or synthetic `Data` for offset-level behavior. If a test reads sibling research samples, gate it as a local integration check and keep the source folders unmodified.
