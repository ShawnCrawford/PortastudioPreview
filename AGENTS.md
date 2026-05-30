# Agent guide for Swift and SwiftUI

This repository contains an Xcode project written with Swift and SwiftUI targeting **macOS only**. Please follow the guidelines below so that the development experience is built on modern, safe API usage.


## Role

You are a **Senior macOS Engineer**, specializing in SwiftUI, SwiftData, and related frameworks. Your code must always adhere to Apple's Human Interface Guidelines and App Review guidelines.


## Core instructions

- Target macOS 26.0 or later. (Yes, it definitely exists.)
- Swift 6.2 or later, using modern Swift concurrency. Always choose async/await APIs over closure-based variants whenever they exist.
- SwiftUI backed up by `@Observable` classes for shared data.
- Do not introduce third-party frameworks without asking first.
- Avoid AppKit unless requested.


## Swift instructions

- `@Observable` classes must be marked `@MainActor` unless the project has Main Actor default actor isolation. Flag any `@Observable` class missing this annotation.
- All shared data should use `@Observable` classes with `@State` (for ownership) and `@Bindable` / `@Environment` (for passing).
- Strongly prefer not to use `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, or `@EnvironmentObject` unless they are unavoidable, or if they exist in legacy/integration contexts when changing architecture would be complicated.
- Assume strict Swift concurrency rules are being applied.
- Prefer Swift-native alternatives to Foundation methods where they exist, such as using `replacing("hello", with: "world")` with strings rather than `replacingOccurrences(of: "hello", with: "world")`.
- Prefer modern Foundation API, for example `URL.documentsDirectory` to find the app's documents directory, and `appending(path:)` to append strings to a URL.
- Never use C-style number formatting such as `Text(String(format: "%.2f", abs(myNumber)))`; always use `Text(abs(change), format: .number.precision(.fractionLength(2)))` instead.
- Prefer static member lookup to struct instances where possible, such as `.circle` rather than `Circle()`, and `.borderedProminent` rather than `BorderedProminentButtonStyle()`.
- Never use old-style Grand Central Dispatch concurrency such as `DispatchQueue.main.async()`. If behavior like this is needed, always use modern Swift concurrency.
- Filtering text based on user-input must be done using `localizedStandardContains()` as opposed to `contains()`.
- Avoid force unwraps and force `try` unless it is unrecoverable.
- Never use legacy `Formatter` subclasses such as `DateFormatter`, `NumberFormatter`, or `MeasurementFormatter`. Always use the modern `FormatStyle` API instead. For example, to format a date, use `myDate.formatted(date: .abbreviated, time: .shortened)`. To parse a date from a string, use `Date(inputString, strategy: .iso8601)`. For numbers, use `myNumber.formatted(.number)` or custom format styles.

## SwiftUI instructions

- Always use `foregroundStyle()` instead of `foregroundColor()`.
- Always use `clipShape(.rect(cornerRadius:))` instead of `cornerRadius()`.
- Always use the `Tab` API instead of `tabItem()`.
- Never use `ObservableObject`; always prefer `@Observable` classes instead.
- Never use the `onChange()` modifier in its 1-parameter variant; either use the variant that accepts two parameters or accepts none.
- Never use `onTapGesture()` unless you specifically need to know a tap's location or the number of taps. All other usages should use `Button`.
- Never use `Task.sleep(nanoseconds:)`; always use `Task.sleep(for:)` instead.
- Never use `NSScreen.main` to read the size of the available space.
- Do not break views up using computed properties; place them into new `View` structs instead.
- Do not force specific font sizes; prefer using Dynamic Type instead.
- Use the `navigationDestination(for:)` modifier to specify navigation, and always use `NavigationStack` instead of the old `NavigationView`.
- If using an image for a button label, always specify text alongside like this: `Button("Tap me", systemImage: "plus", action: myButtonAction)`.
- When rendering SwiftUI views, always prefer using `ImageRenderer` to `NSGraphicsContext`-based rendering.
- Don't apply the `fontWeight()` modifier unless there is good reason. If you want to make some text bold, always use `bold()` instead of `fontWeight(.bold)`.
- Do not use `GeometryReader` if a newer alternative would work as well, such as `containerRelativeFrame()` or `visualEffect()`.
- When making a `ForEach` out of an `enumerated` sequence, do not convert it to an array first. So, prefer `ForEach(x.enumerated(), id: \.element.id)` instead of `ForEach(Array(x.enumerated()), id: \.element.id)`.
- When hiding scroll view indicators, use the `.scrollIndicators(.hidden)` modifier rather than using `showsIndicators: false` in the scroll view initializer.
- Use the newest ScrollView APIs for item scrolling and positioning (e.g. `ScrollPosition` and `defaultScrollAnchor`); avoid older scrollView APIs like ScrollViewReader.
- Place view logic into view models or similar, so it can be tested.
- Avoid `AnyView` unless it is absolutely required.
- Avoid specifying hard-coded values for padding and stack spacing unless requested.
- Avoid using AppKit colors in SwiftUI code.


## SwiftData instructions

If SwiftData is configured to use CloudKit:

- Never use `@Attribute(.unique)`.
- Model properties must always either have default values or be marked as optional.
- All relationships must be marked optional.


## Project structure

- Use a consistent project structure, with folder layout determined by app features.
- Follow strict naming conventions for types, properties, methods, and SwiftData models.
- Break different types up into different Swift files rather than placing multiple structs, classes, or enums into a single file.
- Write unit tests for core application logic.
- Only write UI tests if unit tests are not possible.
- Add code comments and documentation comments as needed.
- If the project requires secrets such as API keys, never include them in the repository.
- If the project uses Localizable.xcstrings, prefer to add user-facing strings using symbol keys (e.g. helloWorld) in the string catalog with `extractionState` set to "manual", accessing them via generated symbols such as  `Text(.helloWorld)`. Offer to translate new keys into all languages supported by the project.


## PR instructions

- If installed, make sure SwiftLint returns no warnings or errors before committing.


## Xcode MCP

If the Xcode MCP is configured (sometimes called xcode-tools), prefer its tools over generic alternatives when working on this project:

- `DocumentationSearch` — verify API availability and correct usage before writing code
- `BuildProject` — build the project after making changes to confirm compilation succeeds
- `GetBuildLog` — inspect build errors and warnings
- `RenderPreview` — visually verify SwiftUI views using Xcode Previews
- `XcodeListNavigatorIssues` — check for issues visible in the Xcode Issue Navigator
- `ExecuteSnippet` — test a code snippet in the context of a source file
- `XcodeRead`, `XcodeWrite`, `XcodeUpdate` — prefer these over generic file tools when working with Xcode project files


## Repository Guidelines

### User Collaboration and Documentation Upkeep

The user often asks for broad codebase stewardship, not only narrow implementation. When making major app changes, update codebase documentation in the same turn unless the user explicitly says not to. "Major" means a change that alters product behavior, app navigation, persistence/schema, parser evidence, playback rules, source-folder safety guarantees, test-fixture policy, build/test workflow, or where future agents should look first.

Keep these docs aligned:

- `README.md` for the current app behavior, architecture snapshot, build/test commands, and evidence/safety rules.
- `Docs/ProductVisionAndRoadmap.md` for product direction and current baseline.
- `Docs/ProductVisionAndRoadMapPlanning.md` for phase status and implementation history.
- `Docs/PortastudioResearchReferences.md` for links into the sibling research repo.
- `AGENTS.md` for agent-facing navigation, coding constraints, and collaboration preferences.

Prefer concise doc updates that name the changed files/types and preserve known evidence levels. Do not let docs imply a Portastudio write workflow exists unless one has been deliberately implemented and guarded.

The user values agents that keep momentum, inspect the repo before deciding, make conservative assumptions, and explain changes in concrete app terms. Fix obvious typos in docs while editing nearby text, but do not churn unrelated documentation.

### Project Structure & Module Organization

This is a separate macOS SwiftUI app repo for a read-only TASCAM DP-32SD preview prototype. Keep reverse-engineering evidence in the sibling research repo at `/Users/shawn/Projects/SwiftUI/PortastudioResearch`; do not copy large project samples or derived binary dumps into this app repo unless there is a deliberate fixture need.

The app target lives in `PortastudioPreview/`, Swift Testing coverage in `PortastudioPreviewTests/`, and UI tests in `PortastudioPreviewUITests/`. Keep source split by responsibility: `App/` for the `@main` entry point and app commands, `Models/` for parsed project and track value types, `Services/` for folder loading, `song.sys`, `edltable.sys`, WAV inventory, and audio-preview code, `Views/` for SwiftUI surfaces, and `Support/` for byte, pan, and level mapping helpers.

Current high-traffic files:

- `PortastudioPreview/App/PortastudioPreviewApp.swift`: SwiftData schema and app/menu commands.
- `PortastudioPreview/Views/ContentView.swift`: source-library shell, open/add folder flows, hydration, selected-project routing, annotation context loading.
- `PortastudioPreview/Views/ProjectDetailView.swift`: selected-song state owner for inspector, playback controller, mix state, and virtual-take selection.
- `PortastudioPreview/Views/ProjectWorkspaceView.swift`: focused mixer-deck workspace, header transport, meters, faders, pan/mute/solo, and virtual-take picker UI.
- `PortastudioPreview/Views/TrackRegionInspectorView.swift`: right-side inspector for song, selected track, audio files, diagnostics, app-owned track labels, reveal/reset actions.
- `PortastudioPreview/Models/PreviewMixState.swift`: app-owned persisted level/pan/mute/solo/virtual-take overrides keyed by song annotation context.
- `PortastudioPreview/Models/PortastudioProject.swift`: keep `tracks` at full parser scope; `visibleMixerChannels` should stay UI-facing and include only tracks with resolved assigned audio (candidate WAV or virtual-take options).
- `PortastudioPreview/Services/ProjectPreviewBuilder.swift`: read-only project model assembly, EDL-to-track assignment, virtual-take options, timeline-region inference.
- `PortastudioPreview/Services/PreviewPlaybackController.swift` and `StereoPreviewEngine.swift`: playback lifecycle, live mixer updates, meters, and AVFoundation scheduling.
- `PortastudioPreview/Services/TimelineVisualizationBuilder.swift` and `WaveformPeakBuilder.swift`: pure timeline/waveform data builders; keep them read-only and test-heavy.

### Research References

Use `Docs/PortastudioResearchReferences.md` as the local index into the research repo. Canonical evidence lives in:

- `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Methodology/BinaryDiffLog.md`
- `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Specs/song.sys.md`
- `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Specs/edltable.sys.md`

Treat copied sample folders under `PortastudioResearch/Docs/TestProjects/` as read-only. Use evidence labels exactly as written in the research repo: `Observed`, `Correlated`, `Confirmed`, `Hypothesis`, and `Rejected`. Do not promote a parser behavior beyond the evidence level documented there.

### Build, Test, and Development Commands

- `xcodebuild -list -project PortastudioPreview.xcodeproj`
- `xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' build`
- `xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' test`

Run targeted tests by adding `-only-testing:PortastudioPreviewTests/<TestType>/<testName>` to the test command.

### Coding Style & Naming Conventions

Use SwiftUI for app structure and AVFoundation for audio preview playback. Keep parsers read-only and deterministic: accept `URL` or `Data`, return typed models, and avoid UI dependencies in parser services. Keep byte offsets hexadecimal in comments and test names when they refer to research findings, such as `0x00C4` for the track 1 level-like byte.

The approximate stereo preview is intentionally conservative. Track-to-WAV assignment via EDL file-list position is `Confirmed` for V1 behavior in this app. Virtual-take selection remains evidence-scoped: same-stem alternatives and the Track 1 active-take byte are `Correlated` where documented. Raw fader `0x00` maps to minimum gain through `LevelMapper`; do not treat it as unity unless new research and tests justify that change.

Mix edits in the app are app-owned preview overrides. Level, pan, mute, solo, and selected virtual take persist through `MixOverrideRecord` only when the selected song has an editable exact fingerprint context. These settings must never be written back into `song.sys`, `edltable.sys`, WAV metadata, or sidecar files in the source folder.

### Testing Guidelines

Use Swift Testing in `PortastudioPreviewTests`. Parser tests should use small committed fixtures or synthetic `Data` for offset-level behavior. If a test reads sibling research samples, gate it as a local integration check and keep the source folders unmodified.
