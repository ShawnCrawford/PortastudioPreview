# Portastudio Research References

This app repo depends on the sibling research repo for format evidence:

`/Users/shawn/Projects/SwiftUI/PortastudioResearch`

## Canonical Entry Points

| Purpose | Path |
| --- | --- |
| Research overview | `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Overview.md` |
| MVP review gate and diff index | `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Methodology/BinaryDiffLog.md` |
| Controlled capture matrix | `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Methodology/ControlledTestMatrix.md` |
| MVP testing plan | `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Methodology/MVPBinaryTestingPlan.md` |
| Preview sample audit | `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/BinaryDiffs/DP-32SD/AUDIT-PREVIEW-SAMPLE-001/preview-sample-audit.md` |
| `song.sys` parser evidence | `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Specs/song.sys.md` |
| `edltable.sys` parser evidence | `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Specs/edltable.sys.md` |
| Open claims and hypotheses | `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Notes/DiscoveriesAndHypotheses.md` |

## Local Sample Sources

Copied hardware projects are read-only local development inputs:

`/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/TestProjects/DP-32SD`

The DP-32SD capture set from `Docs/DeviceCaptureWorksheet.md` is kept read-only in this app repo:

`/Users/shawn/Projects/SwiftUI/PortastudioPreview/Docs/TEST-SONGS`

All worksheet rows are checked and all `Actual song` cells are blank, so the expected song IDs `SONG_0059`-`SONG_0091` are treated as the actual copied project IDs. No matching capture folders were found under the sibling research repo at the time of the audit.

Useful MVP folders:

- `MVP-BASE-001`: populated baseline with five WAV files.
- `MVP-TAKE-001`: active-take variant with unchanged WAV inventory.
- `MVP-MUTE-001`: track 1 mute anchor.
- `MVP-PAN-001`: track 1 pan anchor.
- `MVP-LEVEL-001`: track 1 level/fader anchor.
- `MVP-MIXMAP` and `MVP-MIXMAP-001`: valid blank-project mixer-state comparison pair.

Do not compare `MVP-BASE-001` directly to `MVP-MIXMAP-001` as a controlled mixer-only diff. The valid mixmap evidence is `MVP-MIXMAP` -> `MVP-MIXMAP-001`.

## Current Parser Evidence

Evidence level: `Correlated`, not `Confirmed`.

| Parameter | File | Offset Evidence |
| --- | --- | --- |
| Track 1 level/fader-like byte | `song.sys` | `0x00C4`, mirrored at `0x081C` |
| Track 1 pan-like byte | `song.sys` | `0x00C6`, mirrored at `0x081E` |
| Track 1 mute-like byte | `song.sys` | `0x0268`, mirrored at `0x0A2D` |
| Track 1 active-take candidate | `edltable.sys` | `0x00B01A38` |

Likely track table pattern for the first prototype:

- Level low bank: `0x00C4 + trackIndex * 0x14`
- Pan low bank: `0x00C6 + trackIndex * 0x14`
- Mirrored bank starts at `0x081C` and `0x081E`, but current app validation only compares mirrors for the evidence-backed first repeated level/pan block visible in `MVP-MIXMAP` -> `MVP-MIXMAP-001`.

Do not extend mirror mismatch warnings across all 32 rows. `MVP-PAN-001` shows false warnings if the mirror stride is extrapolated into unsupported offsets such as track 19 pan (`0x022E` vs `0x0986`). Rows outside the evidence-backed mirror block may still display primary low-bank bytes, but should be treated as `Hypothesis` unless the research repo adds stronger evidence.

Track-to-WAV assignment is still a hypothesis. The populated MVP sample contains `ZZ0000_1.wav`, `ZZ0001_1.wav`, `ZZ0002_1.wav`, `ZZ0003_1.wav`, and `ZZ0003_2.wav`, but the binary structure has not yet fully confirmed physical track mapping.

`AUDIT-PREVIEW-SAMPLE-001` observes that populated samples' `edltable.sys` file-list entries match folder WAV inventory as a set, while the EDL order often differs from filename sort. Treat this as file-list evidence, not physical-track order evidence.

`Docs/TEST-SONGS` adds stronger negative evidence for sorted filename-to-track assignment. Single-track captures mostly reused `ZZ0000_1.wav` regardless of physical track, `SONG_0063` unexpectedly contains two WAVs for the Track 4-only action, and `SONG_0084`, `SONG_0085`, `SONG_0086`, `SONG_0090`, and `SONG_0091` show EDL file-list order can differ from sorted filename order. Track-to-WAV mapping remains `Hypothesis`; sorted filename-to-track assignment is `Rejected` as evidence.

Additional capture findings:

- Multiple WAVs / regions are `Observed`: multi-clip and record-over captures create multiple WAVs and matching EDL file-list entries, without proving general physical-track playback assignment.
- Timeline offsets are `Correlated`: delayed captures expose 44,100 Hz sample-domain values near `0x41898`-`0x42C10`, including about 10 seconds as `441000`/`441600`, 20 seconds as `882000`, and 60 seconds as `2646655`/`2646656`. Region lengths appear trimmed by about `441` samples.
- Track 1 active virtual take is `Correlated` at `edltable.sys` byte `0x00B01A38`: `0x00` for take 1 active (`SONG_0083`, `SONG_0085`) and `0x01` for take 2 active (`SONG_0084`). Filename-to-active-take mapping remains unconfirmed.
- Track 1 fader bytes are `Correlated`, while audible gain remains `Hypothesis`: `0x00` min/default, `0x11` about 25%, `0x69` 0 mark, and `0x7F` maximum at `0x00C4`, mirrored to `0x081C`.
- Pan scale is `Correlated`: Track 1 and Track 2 support `0x01` hard left, `0x40` center, and `0x7F` hard right.
- Mute behavior is `Correlated` for Tracks 1-2: Track 1 uses `0x0268` / `0x0A2D`; `SONG_0090` supports Track 2 mute at `0x0269` / `0x0A2E`. Nearby `0x0240` / `0x09C0` changes remain only `Observed`.
- Stereo-pair behavior is `Observed` only: `SONG_0089` created mono `ZZ0000_1.wav` and `ZZ0000_2.wav`, both 10.133s, for track 9/10.

## Preview Playback Notes

The stereo preview is approximate and read-only. It opens candidate WAV files with AVFoundation and applies provisional mute, pan, and level handling without modifying source files or metadata.

Current playback assumptions:

- Physical track-to-WAV mapping is not applied. Unassigned WAV regions are previewed from EDL file-list order when available, with neutral center pan and unity gain.
- Track 1 mute byte `0x0268` is treated as a correlated mute-like flag; other mute rows are not inferred.
- Track 2 mute byte `0x0269` is treated as a correlated mute-like flag based on `SONG_0090`; Track 3+ mute rows are not inferred.
- Pan byte `0x40` is treated as center-like; `0x01` maps hard left and `0x7F` maps hard right for approximate playback.
- Raw level byte `0x00` is treated as unity/default gain, not silence. This matches audible populated MVP folders and avoids muting all preview audio while the true level scale remains unconfirmed.
- Timeline candidates extracted from `edltable.sys` are `Hypothesis` and may represent delayed placements. Pair starts to unassigned WAV regions only when counts make the pairing unambiguous.
- Preview scheduling normalizes the earliest inferred region to playback time zero while preserving relative offsets.

## Playback Troubleshooting

If pressing Play yields no immediate audio:

- Confirm at least one track shows a candidate WAV in the track table.
- Confirm at least one candidate track is not muted by the interpreted mute byte.
- Check the project has audible WAV content (some captured takes are near-silent).
- Wait briefly if a project contains only delayed clips, then verify timeline evidence in `edltable.sys` parsing output.

CoreAudio/HAL log lines such as sandbox lookup warnings or optional factory registration messages can appear during preview startup. Treat these as diagnostics unless playback actually fails.

## Implementation Boundary

The app should implement a read-only preview path first:

1. Open a project folder.
2. Validate `song.sys`, `edltable.sys`, and WAV inventory.
3. Parse correlated mixer bytes into a visible track table.
4. Add approximate stereo preview playback only after parsed values are visible and testable.

Do not write back to project folders. Do not modify or normalize source samples.
