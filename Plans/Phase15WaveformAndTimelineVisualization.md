# Phase 15: Track Timeline Visualization

## Goal

Make the first selected-song surface a readable map of which tracks contain audio and where each region falls along song time. Users should be able to spot gaps and later entries, such as a region at 0–10 seconds and another at 45–55 seconds.

## In Scope

- Show track-aligned rows on the selected-song workspace, with all physical tracks available for orientation.
- Position region bars by start sample and length; display a time ruler and filename labels.
- Support fit, zoom in/out, horizontal time scrolling, and vertical track scrolling.
- Treat bars as parsed WAV-region extents. Do not claim to identify silence inside a WAV; a single long recording with gaps remains one continuous bar in this phase.
- Current `ProjectPreviewBuilder` supplies one selected WAV region per physical track (virtual-take alternatives are choices, not simultaneous clips). Showing multiple non-contiguous regions on one physical track requires additional parser evidence and model work.
- Show the selected virtual take's region for each track.
- Put files without a supported physical-track association in separate, explicitly unassigned rows. Never derive track identity from file-list or display order.
- Selecting a region selects its track and updates the existing inspector.
- Preserve evidence labels and clearly explain unresolved timing when regions overlap at zero.
- Keep all source folders read-only.

## Deferred

- Waveform rendering, including use of the existing `WaveformPeakBuilder`.
- Playback playhead synchronization, timeline scrubbing/seeking, and editing.
- Backup, export, media-asset browsing, AudioDepot, and restore.
- Any change that raises parser evidence levels.

## Current Implementation

- `TimelineVisualizationBuilder` creates one lane per physical track and separate lanes for unassigned regions. It follows the selected virtual take.
- `TimelineVisualizationView` displays the time ruler and region bars with zoom controls and nested horizontal/vertical scrolling.
- `ProjectWorkspaceView` puts the timeline before the mixer deck; the mixer remains available below it.
- `ProjectDetailView` owns selected track and region state and passes the selected region to `TrackRegionInspectorView`.
- The waveform peak service and its existing tests remain in the repository, but the timeline view does not draw or load waveforms.
- Current parser output does not yet represent multiple simultaneous clips on one physical track; the timeline view can render multiple regions per lane when the model provides them.
- The macOS target builds and the Xcode preview renders. Unit and UI tests have not been run for this change.

## Follow-up Validation

- Confirm that a multi-region song displays separated starts and gaps correctly, including delayed regions and unknown lengths.
- Research and implement evidence-backed grouping for multiple regions on one physical track before claiming punch-in or comped-region coverage.
- Confirm selected-take changes update the corresponding lane, unassigned audio is not mislabeled as a track, and region selection reaches the inspector.
- Check zoom, horizontal time scrolling, vertical track scrolling, and accessibility labels at normal and compact window sizes.
