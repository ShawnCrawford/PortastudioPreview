# DP-32SD Timeline and Mixer Evidence Report

Research date: November 3, 2026

## Executive summary

PortastudioPreview can show the WAV inventory, mixer values supported by the documented capture comparisons, and a scrollable track-aligned interface that distinguishes known, candidate, and unresolved data. It cannot yet reconstruct arbitrary DP-32SD timelines faithfully: the available evidence does not identify a general region record, its owning track and virtual track, its source offset, or its exact start and end.

The highest-value next step is to expose uncertainty and remove unsupported placement and take-selection assumptions. General multi-region reconstruction requires controlled device comparisons that identify the records linking physical tracks and virtual tracks to source WAV segments.

**Research limitation:** The canonical research repository was unavailable at `/Users/shawn/Projects/SwiftUI/PortastudioResearch` and at the checked alternate volume path. The original `BinaryDiffLog.md`, specifications, captures, and firmware details could not be independently inspected. Local evidence below is attributed to [PortastudioResearchReferences.md](PortastudioResearchReferences.md), which summarizes those findings. Its labels are preserved, but the original observations and their full scope could not be audited. No source folders or device files were modified during this research.

## Evidence table

“Manual” refers to TASCAM's [DP-32SD Owner's Manual, revision D](https://cf.tascam.com/wp-content/uploads/downloads/products/tascam/dp-24_dp-32/e_dp-32sd_om_vd.pdf); its publication date was not established. Manual claims describe device operation, not undocumented byte layouts. Research-index labels below are reported labels, not independently revalidated findings.

| Question / behavior | Finding and source | Confidence label | Model / firmware scope | Remaining uncertainty |
| --- | --- | --- | --- | --- |
| Device timeline | Home screen shows playback position and which tracks have recordings. Manual p. 22. | Confirmed by manufacturer for UI behavior | DP-32SD, manual revision D | Does not document storage records or precise timeline semantics. |
| Gaps and edits | SILENCE removes selected audio while retaining track length; CUT removes a section and shifts later material; CLONE copies a whole track. Manual pp. 50–51. | Confirmed for UI behavior | DP-32SD | Representation of gaps, splits, source offsets, shared sources, and edit history is undocumented. |
| Timeline values | The research index reports delayed-capture sample-domain values in `edltable.sys` around `0x41898–0x42C10`, including `441000`/`441600`, `882000`, and `2646655`/`2646656`. | Confirmed, as reported by the index, for delayed placements | DP-32SD captures; firmware unknown | Does not establish every scanned word as a start, record boundaries, track association, source position, or general 48 kHz behavior. |
| Region length | Index reports apparent approximately 441-sample trimming in captures; the app uses WAV frame count as displayed region length. | Observed trim pattern; general semantics unresolved | Captured 44.1 kHz material | Full WAV duration need not equal edited duration. Neither a universal trim nor an end-field offset is established. |
| Virtual tracks | Eight virtual tracks per physical track; virtual track 1 is initially assigned. Recording, playback, and editing use the assigned virtual track. Manual p. 47. | Confirmed for UI behavior | DP-32SD | Manual does not identify on-disk selection or region records. |
| Active take | Index reports `edltable.sys` byte `0x00B01A38`: `0x00` in `SONG_0083`/`0085`, `0x01` in `SONG_0084`. | Correlated, Track 1 candidate | Cited DP-32SD captures; firmware unknown | General indexing, other tracks, unused selections, save/reload, and file-entry relationships remain unresolved. |
| Track-to-WAV order | Index reports EDL file-list position to physical track as Confirmed for V1, including a three-track mute comparison (`SONG_0094`). Filename sorting is Rejected. | Confirmed for documented V1 cases; not a general edited-song rule | DP-32SD captures; firmware unknown | Multiple clips, sparse tracks, cloning, alternate takes, deletion, and stereo pairing may break a simple positional rule. Single-track captures reportedly reused `ZZ0000_1.wav` on different tracks. |
| File-list order | Index reports EDL order differing from sorted filenames in `SONG_0084–0086`, `0090`, and `0091`. | Observed | Cited DP-32SD captures | File-list order need not be displayed-track order when tracks have multiple entries. |
| Track level | `song.sys` low bank `0x00C4 + i × 0x14`; mirror `0x081C + i × 0x14` for T1–T8. Index reports a scale from `SONG_0092`. | Confirmed for T1–T8 and stated anchors; extended low-bank values Correlated | DP-32SD captures | Exact gain curve between measured anchors and behavior after reload need measurement. |
| Pan | `song.sys` low bank `0x00C6 + i × 0x14`; mirror `0x081E + i × 0x14` for T1–T8. `0x40` is center; `0x01` and `0x7F` are hard left and right. | Confirmed for cited anchors | DP-32SD captures | Device pan law and interpolation remain unverified. |
| Stereo mixer indexing | Index reports mirror-bank logical-pair indexing for T9/T10 through T31/T32; low bank uses physical-channel rows. | Confirmed, `SONG_0095` | DP-32SD captures | The `0x09F0 + pairIndex` track-type interpretation remains a Hypothesis: one stereo-to-mono conversion changed `0x09F9` from `0x02` to `0x01`. |
| Mute | `song.sys` low bank starts at `0x0268`, one byte per physical track: T1/T2 confirmed, T3–T18 correlated. Mirror starts `0x0A2D`: T1/T2 confirmed, T3–T8 correlated, and pair entries `0x0A35–0x0A40` correlated. | Confirmed / Correlated by range | DP-32SD captures `SONG_0093–0094` | Do not read `0x0279–0x0287` as low-bank mute flags. Proposed `0x0A41–0x0A4C` mirror entries for T21–T32 are Rejected by the index. |
| Solo | The manual describes Solo mode and permits multiple soloed tracks; it does not document saved bytes. | Confirmed for operation; saved representation unresolved | DP-32SD | No reliable solo offset or persistence across save/reload established. |
| Internal WAVs | A DP-32SD owner reports that internal work WAVs need not line up in time or correspond one-to-one with tracks; another describes tracks comprising multiple snippets. [2017 discussion](https://www.tascamforums.com/threads/backing-up-tracks-on-computer.4423/); [2023 discussion](https://www.tascamforums.com/threads/what-is-the-_z-wav-file.9846/). | Observed user reports, independently unverified | Claimed DP-32SD use | Neither establishes an offset, ordering rule, or complete reconstruction algorithm. |
| Other devices | The [DP-03SD manual, revision C](https://www.tascam.eu/en/docs/DP-03SD_OM_RevC.pdf), describes a FAT-partition/WAVE import workflow and 44.1 kHz restriction. The [DP-32 downloads page](https://www.tascam.eu/en/downloads/DP-32) identifies a separate non-SD model and manual dated September 27, 2012. | Confirmed for documented workflows | Respective models | Similar branding or shared update procedures do not prove shared binary layouts. |

No public DP-32SD format specification, service document, or open-source parser independently establishing these region fields was found in this search. This is not proof that none exists. TASCAM's manual and the forum advice agree that AudioDepot export is the supported way to obtain track WAVs; the forum explanation of internal work files is a lead, not a format specification.

## Evidence-supported timeline mapping

1. Inventory song files and read each WAV's duration and sample rate as source-file properties. Keep source file and device track distinct.
2. Parse the EDL file list, preserve original entry identity and order, and apply the documented V1 track mapping only where the input matches controlled evidence. Missing files, extra entries, alternate takes, edits, or sparse tracks must not silently shift subsequent assignments.
3. Preserve raw candidate timing words and offsets as diagnostic evidence. Delayed-position observations justify investigating the EDL window; they do not justify sorting plausible numbers and attaching them to WAVs by count.
4. Place a region at song time only when its track, selected virtual track, source file, timeline start, source start, and length/end are established for that record. Otherwise show the file or candidate as unresolved without inventing a position or gap.
5. Once a validated decoder exists, render every resolved record on its track lane. Records `[0, 10)` and `[45, 55)` would produce two regions and a gap. The gap is meaningful only when the decoded active arrangement establishes that no other region occupies it.
6. Select an active virtual track only when its selector and relationship to records are supported for that physical track. Label app-selected audition options as overrides.

A single saved folder may contain the relevant data but cannot validate its interpretation by itself. Controlled before/after saves are needed to identify field ownership and semantics. Exact general reconstruction remains unresolved.

### Current implementation

- `ProjectPreviewBuilder` groups filenames by stem, assigns groups sequentially to tracks, constructs one region per option, and defaults ambiguous starts to zero. Its sequential fallback accepts one matching boundary and lays out an entire staircase.
- `EdlTableParser` scans for near-whole-second values and rounds them. This can miss arbitrary placements and cannot prove associations. Several resulting values are labelled `.confirmed` despite these heuristics.
- `TimelineVisualizationBuilder` and `TimelineVisualizationView` provide lanes, horizontal scrolling, and zoom, but a selected option is reduced to one region.
- `StereoPreviewEngine` likewise takes the first selected region and schedules a full file. A visual-only multi-region change would not make playback faithful.
- The builder applies the Track 1 candidate's derived take number when choosing defaults for every track and labels grouped options and timelines confirmed. That exceeds the documented evidence. The unassigned-region playback planner has a narrow captured selector fallback that can suppress other unassigned files and needs an explicit scope check.

## Saved mixer state

The following are per-song file observations with per-track or logical-channel interpretations as scoped in the table; they are not a complete device mix.

- **Level:** Reported anchors: `0x00` = minimum/−∞, `0x28` = −20 dB, `0x3E` = −10 dB, `0x4E` ≈ −6.4 dB, `0x5C` ≈ −3 dB, `0x6A` = 0 dB, `0x7F` = +6 dB. Intermediate preview mapping is approximate.
- **Pan:** Reported anchors: `0x01` = hard left, `0x3C` = L4, `0x3E` = L2, `0x40` = center, `0x42` = R2, `0x44` = R4, `0x7F` = hard right. App interpolation does not establish the hardware pan law.
- **Mute:** Read supported ranges with their actual confidence. Unknown must remain distinct from unmuted. Solo mode and mute indicators are operationally related, but this does not establish shared saved bits.
- **Solo:** No device-saved field is established. `PreviewMixState` initializes solo off and persists app-owned overrides when an editable exact-fingerprint context exists. Its solo behavior is a preview feature, not recovered device state.
- **Active take:** `0x00B01A38` is a Correlated Track 1 candidate in the cited captures. It does not establish selectors for all tracks or prove that a filename suffix is the device's virtual-track number.

## Implementation backlog

| Priority | Change and expected behavior | Relevant app files | Evidence and focused tests / fixtures |
| --- | --- | --- | --- |
| 1 | Represent unknown start, length, track, and active take explicitly. Show unresolved files without placing them at zero or labelling timing confirmed. Disable staircase and count-based pairing for authoritative timeline and playback. | `TimelineModels.swift`, `EdlTableParser.swift`, `ProjectPreviewBuilder.swift`, `TimelineVisualizationBuilder.swift`, `TimelineVisualizationView.swift` | Existing index supports this boundary. Synthetic tests: equal candidate/file counts with wrong associations, no candidates, simultaneous starts, arbitrary offsets, accidental matching boundary. |
| 2 | Preserve EDL entry identity; do not treat grouped stem order as physical-track order or propagate Track 1's selector to other tracks. Label candidates and app overrides separately; do not suppress unrelated files. | `ProjectPreviewBuilder.swift`, `TrackPreview.swift`, `VirtualTrackOption.swift`, `PreviewPlaybackPlanner.swift`, `PreviewMixState.swift` | Recheck original V1 captures. Tests: sparse tracks, reordered filenames, same stem, unrelated tracks, unknown selector, missing WAV, selected-but-empty take. |
| 3 | Show device-derived mixer values with range-specific confidence and app-owned edits as overrides. Preserve unknown mute and solo; do not claim device-exact gain or pan. | `SongSysParser.swift`, `TrackMixerSetting.swift`, `PreviewMixState.swift`, `TrackRegionInspectorView.swift`, `ProjectWorkspaceView.swift` | Compare parser labels with original `SONG_0092–0095` diffs. Synthetic tests: mute boundaries, pair indexing, conflicting banks, unknown values, reset behavior. |
| 4 | Model multiple regions per virtual track with timeline start, source start, duration, source identity, and provenance. Render disjoint blocks in one lane and preserve accessibility. | `TimelineModels.swift`, `TrackPreview.swift`, `TimelineVisualizationBuilder.swift`, `TimelineVisualizationView.swift` | Model/rendering tests can use synthetic data now; real population requires validated records. Test 0–10 / 45–55, overlap, split source, empty take, unknown timing. |
| 5 | Schedule the same resolved arrangement shown in the timeline. Honor source offsets and bounded durations, preserve song-time gaps, and distinguish audition of unresolved files from reconstructed playback. | `StereoPreviewEngine.swift`, `PreviewPlaybackPlanner.swift`, `PlaybackPlan.swift`, `PreviewPlaybackController.swift` | Requires validated timing/source mapping. Synthetic scheduling tests: gaps, trimmed source, seeking, overlap, mute/solo, multiple regions per track. |
| 6 | Carry an established song timebase instead of assuming 44,100 everywhere; mark unsupported or conflicting rates unresolved. | `EdlTableParser.swift`, `TimelineModels.swift`, `SampleTimeFormatter.swift`, `TimelineVisualizationBuilder.swift`, `StereoPreviewEngine.swift` | Manual discusses 44.1 and 48 kHz songs but does not establish EDL units at 48 kHz. Compare captures at both rates; test conversion and mismatched metadata. |
| 7 | Align the app's research index and product docs with corrected behavior and exact capture scope. | `README.md`, `Docs/PortastudioResearchReferences.md`, product vision and roadmap docs, relevant tests | Use small synthetic fixtures or deliberately approved minimal extracts; keep private captures as local integration checks. |

## Unknowns and next experiments

1. **Region record and gaps:** On a disposable song, record one identifiable clip on Track 1, save a copy, then record a second clip at a known later time on the same active virtual track and save again. Record device positions, sample rate, firmware, and inventory. Compare EDL changes against the device timeline and an AudioDepot export. Repeat at a non-whole-second start.
2. **Source offset and edits:** From the same baseline, perform one SILENCE, CUT, copy/paste, or punch operation per saved variant. Compare changes and exports to distinguish timeline start, source start, end/length, and undo or historical data.
3. **Assignment:** Make isolated recordings on a high-numbered track and sparse tracks in different recording orders; clone one track. Test whether list position identifies track or file creation/order.
4. **Virtual tracks:** Change only the selected virtual track, save and reload, on Tracks 1 and 2; include an unused selection and a take with two clips. Test selector scope, stride, empty states, and filename suffix meaning.
5. **Mixer:** Change one control at a time, save and reload, including solo, stereo-to-mono conversion, and high-numbered pair mutes. Capture display values and binary diffs; repeat across level and pan anchors.

Operate on copies, preserve original song folders, and record model and firmware. The official [AudioDepot export workflow](https://cf.tascam.com/wp-content/uploads/downloads/products/tascam/dp-24_dp-32/e_dp-32sd_om_vd.pdf) provides an audible reference, although an exported track alone does not reveal internal field structure.
