# Xcode Canvas Previews Plan

Create Xcode canvas previews for the mixer workspace and tweakable mixer controls using Apple's current SwiftUI `#Preview` macro approach. The preview data should be purely synthetic so previews stay fast, deterministic, and independent of committed test songs or sibling research samples.

## Scope

- In: Mixer deck previews, individual track strip previews, pan/fader/meter control previews, inspector/detail preview states, synthetic preview fixtures, build validation.
- Out: Parser changes, playback engine behavior changes, real song-folder mutation, third-party preview tooling, or previews that read private device captures.

## Decisions

- Use synthetic preview fixtures only.
- Refactor mixer controls into separate files when it improves development ergonomics or preview targeting.
- Keep refactors scoped to view and preview support structure, not model or parser behavior.
- Prefer modern SwiftUI previews with `#Preview("Name") { ... }`; use `@Previewable @State` only where a preview needs interactive bindings.

## Action Items

1. Audit `PortastudioPreview/Views/ProjectWorkspaceView.swift`, `TrackRegionInspectorView.swift`, and mixer-related models to identify useful preview states: empty, active tracks, muted, selected, stereo-paired, missing WAV, loud/quiet meter, and hard-left/center/hard-right pan.

2. Add a DEBUG-only synthetic fixture helper, likely `PortastudioPreview/Support/PreviewFixtures.swift`, that builds sample `PortastudioProject`, `MixerChannel`, `TrackPreview`, `PreviewMixState`, `PreviewPlaybackController`, and annotation data without reading project folders or requiring SwiftData persistence.

3. Refactor large private mixer subviews from `ProjectWorkspaceView.swift` where it makes sense from a developer standpoint. Likely candidates are `TrackMixerDeckView`, `TrackMixerStripView`, `PanControlView`, `FaderTrackView`, `OutputLevelView`, mixer metrics, and strip presentation helpers under `PortastudioPreview/Views/Mixer/`.

4. Add `#Preview` blocks for the full `ProjectWorkspaceView`: a normal DP-32SD-style mixer, a compact/minimum data case, and a selected/muted/edited-level state. Give these previews macOS-sized frames so the canvas resembles the app window.

5. Add focused `#Preview` blocks for individual mixer pieces: `TrackMixerStripView`, `PanControlView`, `FaderTrackView`, and `OutputLevelView`, with enough state variation to quickly remodel pan and fader designs.

6. Add `#Preview` blocks for `TrackRegionInspectorView` with no selection, selected track, missing audio file, and editable annotation contexts so inspector layout can be tuned alongside mixer selection.

7. Guard preview-only helpers with `#if DEBUG` where appropriate and confirm no preview code writes to Portastudio source folders, creates sidecars, or depends on local research samples.

8. Validate with:

   ```bash
   xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' build
   xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj -destination 'platform=macOS' test -only-testing:PortastudioPreviewTests/MixerChannelLayoutTests -only-testing:PortastudioPreviewTests/PreviewMixStateTests
   ```

9. If Xcode MCP preview rendering is available, render the key previews. Otherwise, open the preview files in Xcode canvas and confirm the previews compile, resize cleanly, and allow pan/fader interaction.

## Risks

- Preview fixtures can become brittle if they duplicate too much production construction logic. Keep fixtures small and model-facing.
- Large private nested views may make previews awkward. Refactor only the mixer pieces that benefit directly from standalone previews.
- Interactive previews can accidentally pull in runtime-only services. Keep playback and annotation dependencies stubbed or synthetically initialized.
