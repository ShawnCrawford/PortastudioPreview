# Phase 8 First-Round Polish and Validation Implementation Plan

## Summary

Phase 8 turns the implemented Part 1 feature set into a coherent first-round macOS app experience. The work should stay focused on polish and validation: source/song search, tighter toolbar and menu affordances, clearer empty and missing states, accessibility coverage, and targeted tests around the source library, remembered locations, selected-song loading, and app-owned annotation persistence.

This phase must not expand into backup/export, media asset browsing, waveform/timeline visualization, automatic removable-media detection, or any write workflow against Portastudio media. Portastudio source folders remain read-only; only app-owned SwiftData records may be changed.

## Scope

- In:
  - Add sidebar search/filter for available source roots, nested source songs, individual songs, and missing remembered items.
  - Preserve selection stability when search text changes or clears.
  - Improve toolbar/menu command naming, help text, enabled states, and keyboard discoverability for the existing add/open flows and inspector toggle.
  - Improve empty states for first launch, empty sidebar sections, no search results, source roots with no songs, selected sources with no loaded song, and missing remembered locations.
  - Add accessibility labels, values, hints, and identifiers where they improve VoiceOver and UI-testability.
  - Add or extend focused Swift Testing coverage for source classification, remembered-location hydration/relocation/forget flows, selected source-song loading, annotation persistence gates, and read-only guarantees.
  - Update README and roadmap docs after implementation with actual Phase 8 behavior and test results.
- Out:
  - Do not implement automatic removable-media detection.
  - Do not implement backup, export, AudioDepot staging, restore, waveform/timeline visualization, media asset browser, or master-mix browsing.
  - Do not add track colors, notes, tags, templates, favorites, archive state, or ambiguity-resolution UI.
  - Do not change parser evidence levels, track-to-WAV assignment semantics, fingerprint format, playback planning, or audio engine behavior unless a polish bug directly requires it.
  - Do not introduce third-party frameworks.
  - Do not write sidecars or mutate `song.sys`, `edltable.sys`, WAV files, `AudioDepot`, or any source folder structure.

## Current Baseline

- The app is macOS-only SwiftUI using a `WindowGroup`, `NavigationSplitView`, native sidebar `List(selection:)`, SwiftData, and `@MainActor @Observable` stores.
- `PortastudioPreviewApp` creates a SwiftData schema with `LibrarySourceRecord`, `LibrarySongRecord`, and `TrackAnnotationRecord`, and installs `ProjectCommands`.
- `ProjectCommands` currently replaces `.newItem` with:
  - `Open Individual Song...` (`Command-O`)
  - `Add SD Card or Backup...` (`Command-Shift-O`)
- `ContentViewBody` owns `SourceLibraryStore` and `TrackAnnotationStore`, wires toolbar buttons for add/open actions, hydrates persistence on launch, loads selected source songs, and reloads annotation context for the selected project.
- `SourceLibrarySidebarView` renders three sections: `SD Cards & Backups`, `Individual Songs`, and `Missing`. It has context menus for Reveal in Finder, Relocate, and Forget, but no `.searchable` support yet.
- Empty sidebar sections are currently plain muted text rows such as `No sources added`, `No songs opened`, and `No missing items`.
- `ProjectOpenView` is the detail empty state shown when no project is selected. It has two primary actions and explanatory text.
- `SourceLibraryStore` handles persistence hydration, add/open, source-song loading, forget, relocate, fingerprint match state recomputation, and selected annotation context construction.
- `SourceFolderClassifier` already accepts non-standard song folder names and ignores hidden Apple metadata.
- `TrackAnnotationStore` loads and mutates app-owned labels. It only writes when `SongAnnotationContext.isEditable` is true, which requires a non-empty fingerprint and `.exact` match state.
- `ProjectDetailView` already has accessibility labels on major group boxes, an inspector toggle toolbar button, track/region selection, a track-name column, and a song display-name override row.
- Existing test coverage includes parser tests, source classification tests, source library store tests, fingerprint tests, annotation store tests, playback-planner/audio tests, and read-only guard checks.

## Implementation Direction

### Search and Filtering

- Add `@State private var sidebarSearchText = ""` in `ContentViewBody` or `SourceLibrarySidebarView`, choosing the owner that keeps the sidebar reusable without creating global state.
- Add `.searchable(text:placement:prompt:)` to the sidebar list or surrounding sidebar view. Prefer a short prompt such as `Search Sources and Songs`.
- Implement filtering in a small, testable helper rather than burying logic in nested SwiftUI expressions. Good options:
  - `Models/SourceLibrarySearch.swift` with pure functions over `[SourceLibrarySource]`, `[SourceLibrarySong]`, and `[SourceLibraryMissingItem]`.
  - Or focused computed methods on `SourceLibraryStore` only if they remain pure and do not mutate selection.
- Filter with `localizedStandardContains()` for all user-entered search text.
- Search fields should match:
  - source display name
  - source kind label (`SD Card`, `Backup`)
  - source folder path
  - nested song display name
  - nested song path
  - individual song display name/path
  - missing item display name/detail/path text currently available
  - fingerprint match labels only if this stays simple and does not make row copy noisy
- Preserve source rows when any nested song matches. For matching nested songs, either:
  - show only matching children, or
  - show all children under a matching source.
  Prefer showing matching children only when the source itself did not match, and all children when the source itself matched; document the chosen behavior in tests.
- Do not destructively mutate `store.sources` or `store.individualSongs` while filtering. Filtering must be view-derived or helper-derived.
- Do not automatically clear `store.selection` just because the selected row is filtered out. A filtered-out selected project can remain visible in detail while search narrows the sidebar.
- Add a no-results row when search text is non-empty and all filtered sections are empty.

### Toolbar and Commands

- Keep the existing add/open actions, shortcuts, and focused-value routing, but polish discoverability:
  - Add `.help(...)` to toolbar buttons.
  - Use concise labels and system images already present: `externaldrive.badge.plus` and `folder`.
  - Keep menu names exactly aligned with toolbar labels: `Add SD Card or Backup...`, `Open Individual Song...`.
- Review whether the two primary toolbar items should be grouped in a `ControlGroup` or remain separate. Prefer separate items if grouping hurts label discoverability.
- Consider adding an app-level command for `Forget` or `Reveal in Finder` only if it can be correctly routed from current selection without broad responder-chain work. Otherwise keep these as context-menu actions for Phase 8.
- For the inspector toggle in `ProjectDetailView`, add an explicit keyboard shortcut only if it does not conflict with standard macOS conventions and can be tested or manually verified. If uncertain, keep the toolbar button plus help text.
- Avoid adding new menu groups unrelated to the current source-library workflow.

### Empty and Missing States

- Replace bare muted text rows with small native rows that are concise, accessible, and do not turn the sidebar into cards.
- Sidebar empty rows should remain lightweight: one line, optional system image, secondary style, no nested cards.
- Add a specific no-search-results row when a search is active.
- Improve `ProjectOpenView` copy only enough to explain the first-run path. Keep the two actual actions as the primary screen, not a landing page.
- Add selected-source detail state if selecting a source row currently leaves the previous project or open screen confusing. A simple source summary is acceptable:
  - display source name, kind, path, song count, and match state
  - list the next action in plain language, such as selecting a song in the sidebar
  - do not add backup/export/media browsing actions
- Missing rows should explain what is missing through accessible labels/hints, but keep visible row text compact.
- Wrong-kind relocate errors should stay non-destructive and leave the missing row intact.

### Accessibility

- Add `.accessibilityLabel`, `.accessibilityValue`, and `.accessibilityHint` where the visible row text is not enough, especially:
  - add/open toolbar buttons
  - source rows with kind, path, song count, and match state
  - nested song rows with load state and match state
  - missing source/song rows with Relocate/Forget affordances
  - no-results and empty rows
  - inspector toggle button
  - track label editor clear buttons
- Prefer native labels with text plus SF Symbol where possible. Avoid image-only buttons unless a text label is also present or accessibility labels are explicit.
- Add stable `.accessibilityIdentifier(...)` only for high-value UI-test anchors and simple future automation:
  - sidebar search field if practical
  - add/open toolbar buttons
  - source list
  - missing section rows
  - track label editor text field
- Do not add UI tests solely to assert static labels unless Swift Testing cannot cover the logic. The project guidance prefers unit tests for core logic.

### Focused Tests

- Extend `SourceFolderClassifierTests` for:
  - hidden AppleDouble files inside `MUSIC/` do not create fake songs
  - source roots with valid songs plus hidden metadata still classify correctly
  - user-named song folders with spaces remain accepted
- Extend `SourceLibraryStoreTests` for:
  - hydration keeps missing records visible when bookmark/fallback resolution fails
  - wrong-kind relocate leaves the missing record and records an error
  - Forget removes only SwiftData records and clears selected project when relevant
  - selecting a nested source song calls the loader once and sets `selectedProject`
  - selected source-song annotation context is available after source load when fingerprint exists
  - source and song folders remain unchanged after add/open/hydrate/forget/relocate failure using `FileReadOnlyGuard`
- Extend `TrackAnnotationStoreTests` only where Phase 8 exposes a real gap:
  - changed or unknown match state cannot save labels
  - clearing labels and display-name override remain app-owned only
  - no writes occur when annotation context is nil
- Add pure search/filter tests if a helper type is introduced:
  - matches source display name
  - matches nested song display name and keeps parent visible
  - matches path fragments using localized standard matching
  - returns no-results state for unmatched text
  - does not mutate the original source/song arrays
- Avoid brittle SwiftUI snapshot tests. If a UI behavior can be expressed as pure filtering/state logic, test that helper instead.

## Expected Files

### Likely new files

| File | Purpose |
| --- | --- |
| `Plans/Phase8FirstRoundPolishAndValidation.md` | Durable handoff plan for this phase |
| `PortastudioPreview/Models/SourceLibrarySearch.swift` | Optional pure search/filter helper for sidebar filtering |
| `PortastudioPreviewTests/SourceLibrarySearchTests.swift` | Optional focused tests for search/filter behavior |

### Likely modified files

| File | Change |
| --- | --- |
| `PortastudioPreview/Views/ContentView.swift` | Own sidebar search state if search is rooted at the split-view level; add toolbar help/labels if not handled in child views |
| `PortastudioPreview/Views/SourceLibrarySidebarView.swift` | Add `.searchable`, filtered section rendering, no-results empty state, row accessibility, and lightweight missing/empty row polish |
| `PortastudioPreview/Views/ProjectOpenView.swift` | Refine first-run empty state and accessibility labels without changing the add/open flows |
| `PortastudioPreview/Views/ProjectDetailView.swift` | Polish inspector toggle help/accessibility and any detail empty/source-selected state if added |
| `PortastudioPreview/Views/TrackLabelEditorView.swift` | Add accessibility labels/identifiers for text field and clear button if missing |
| `PortastudioPreview/App/PortastudioPreviewApp.swift` | Polish command labels/help/shortcuts only if needed |
| `PortastudioPreviewTests/SourceFolderClassifierTests.swift` | Add hidden metadata and classification edge coverage |
| `PortastudioPreviewTests/SourceLibraryStoreTests.swift` | Add remembered-location, selected-song loading, annotation-context, and read-only guard coverage |
| `PortastudioPreviewTests/TrackAnnotationStoreTests.swift` | Add Phase 8 validation coverage only for real gaps |
| `README.md` | Document implemented Phase 8 behavior and validation commands/results after completion |
| `Docs/ProductVisionAndRoadMapPlanning.md` | Mark Phase 8 implemented after completion and summarize actual behavior |
| `Docs/ProductVisionAndRoadmap.md` | Update current baseline and roadmap status after completion |

## Testing Plan

- Run focused tests during implementation:

```bash
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' test \
  -only-testing:PortastudioPreviewTests/SourceFolderClassifierTests \
  -only-testing:PortastudioPreviewTests/SourceLibraryStoreTests \
  -only-testing:PortastudioPreviewTests/TrackAnnotationStoreTests
```

- If `SourceLibrarySearchTests` is added, include it in the focused run.
- Before finishing, run the documented full build and test:

```bash
xcodebuild -list -project PortastudioPreview.xcodeproj
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' build
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' test
```

- If SwiftLint is installed, run it and resolve warnings before committing.

## Manual Acceptance Criteria

- First launch/no selection shows a native empty state with `Add SD Card or Backup...` and `Open Individual Song...` actions.
- Adding a source root still scans songs, shows the source in `SD Cards & Backups`, and does not load a song until one is selected.
- Searching for a source name shows the source and its relevant songs according to the documented filter behavior.
- Searching for a nested song name keeps the parent source visible and shows the matching song.
- Searching for path fragments works with localized standard matching.
- Clearing the search restores the full sidebar and keeps the selected project stable.
- Searching for unmatched text shows a clear no-results row without deleting or changing library records.
- Missing remembered rows remain visible, muted, and actionable with Relocate and Forget.
- Wrong-kind relocation keeps the missing row intact and surfaces a load error.
- Toolbar/menu add/open actions still work with `Command-Shift-O` and `Command-O`.
- VoiceOver can distinguish source rows, song rows, missing rows, no-results rows, toolbar buttons, and the inspector toggle.
- Track labels and song display-name overrides still save only to SwiftData and never touch source folders.

## Evidence Discipline

- Preserve current evidence labels exactly: `Observed`, `Correlated`, `Confirmed`, `Hypothesis`, and `Rejected`.
- Do not promote track-to-WAV assignment above `Hypothesis`.
- Do not imply that app-owned track labels or song display-name overrides are stored on the TASCAM device.
- Do not use search/filter behavior as evidence for parser identity or media matching.
- Keep fingerprint match labels conservative. If the app shows `.changedSinceLastSeen`, it must not silently apply annotations to a new fingerprint.

## Risks and Guardrails

- Filtering nested sources can accidentally mutate the source tree or reset expansion/selection. Keep filtering pure.
- Search can hide the selected row while detail still shows the selected project. This is acceptable if no destructive selection clearing occurs and no-results copy is clear.
- `SourceLibraryStore` already has many responsibilities. Do not fold UI search text into it unless the filtering API remains pure and testable.
- `@Observable` stores must remain `@MainActor`.
- Use `localizedStandardContains()` for all user-entered search.
- Keep sidebar rows native and compact: one icon, one title, one optional secondary line. Do not add card-style rows.
- Keep empty states useful but modest. Phase 8 is app polish, not a marketing or onboarding redesign.
- Be careful with SwiftData schemas in tests. Any test container must include `LibrarySourceRecord.self`, `LibrarySongRecord.self`, and `TrackAnnotationRecord.self`.
- Prefer SwiftUI APIs for commands, toolbar, search, and accessibility. Avoid AppKit except for the existing `NSOpenPanel` and `NSWorkspace` integration.
- Do not introduce third-party dependencies.

## Documentation Updates Required After Implementation

- Update `README.md`:
  - Replace the `Planned Next: First-Round Polish and Validation (Phase 8)` section with implemented behavior.
  - Document search/filter behavior, command polish, empty/missing states, accessibility notes, and validation results.
- Update `Docs/ProductVisionAndRoadMapPlanning.md`:
  - Mark Phase 8 implemented with the actual date.
  - Summarize files/behaviors changed and tests added.
- Update `Docs/ProductVisionAndRoadmap.md`:
  - Add Phase 8 implemented status under the suggested roadmap.
  - Update the `Current App Baseline` table for search, command polish, empty states, accessibility, and any new tests.
- Keep all documentation clear that backup/export/removable-media detection remain future phases.

## Assumptions

- Phase 1 through Phase 7 are implemented as documented on May 7, 2026.
- The app target remains macOS 26.0 or later, Swift 6.2+, SwiftUI-first, SwiftData-backed, and read-only toward Portastudio files.
- Existing `NSOpenPanel` and `NSWorkspace` usage remains acceptable for folder selection and Reveal in Finder.
- The implementing thread has access to the same local source tree, roadmap docs, and sibling research repo references.
- This saved plan does not implement Phase 8 app code. The implementing thread must update docs with actual behavior after code lands.
