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

## Card-Root Findings

Evidence level: `Observed`.

The SD card root file `/Volumes/DP-32SD/dp-24.sys` was inspected on 2026-05-06. It is a small 2,488-byte card-level file, not a song-folder parser input. Do not copy this live SD-card file into the app repo unless a deliberate small fixture is needed for future SD-root tests.

Observed fields from the inspected card:

| Offset | Value | Notes |
| --- | --- | --- |
| `0x0000` | `DP-24   ` | Card-level signature. This matches the manual-derived research note that DP-32SD formatting creates a root `dp-24.sys` file. |
| `0x0008` | `0x01` | Observed non-zero byte, meaning unknown. |
| `0x000A` | `0x01` | Observed non-zero byte, meaning unknown. |
| `0x0428` | `SONG_0046` | Looks like a current or last-loaded song pointer. `/Volumes/DP-32SD/MUSIC/SONG_0046` existed during inspection. |
| `0x0438` onward | `USER 01` through `USER 10` repeated in several fixed-width groups | Likely global user/preset/default labels, but not decoded. |

Current app impact:

- No current preview parsing should depend on `dp-24.sys`; project reconstruction still comes from each opened song folder's `song.sys`, `edltable.sys`, and WAV inventory.
- `dp-24.sys` presence at a folder root is now used by `SourceFolderClassifier` as the primary signal for `.mediaRoot` classification (versus `.backupRoot` for roots that have `MUSIC/` and valid songs but no `dp-24.sys`). It is treated as a structural presence check only — no field parsing is performed.
- The `SONG_0046` interpretation at `0x0428` remains a hypothesis for future controlled testing, not confirmed song-selection semantics.

## Current Parser Evidence

### Core offset table

| Parameter | File | Offsets | Evidence |
| --- | --- | --- | --- |
| Level, T1–T8 (low bank) | `song.sys` | `0x00C4 + i*0x14` | **Confirmed** (SONG_0092) |
| Level, T9–T32 (low bank) | `song.sys` | same stride continued | **Confirmed** stride, `Correlated` values (SONG_0095) |
| Pan, T1–T8 (low bank) | `song.sys` | `0x00C6 + i*0x14` | **Confirmed** (SONG_0092); center = `0x40` |
| Pan, T9–T32 (low bank) | `song.sys` | same stride continued | **Confirmed** stride (SONG_0095) |
| Level/pan, T1–T8 (mirror bank) | `song.sys` | `0x081C`/`0x081E + i*0x14` | **Confirmed** (SONG_0092) |
| Level/pan, T9/T10–T31/T32 (mirror bank) | `song.sys` | same stride, logical-pair indexing | **Confirmed** (SONG_0095, see stereo pair note) |
| Mute, T1–T18 (low bank) | `song.sys` | `0x0268 + i` (stride 1) | **Confirmed** T1–T2; **Correlated** T3–T18 (SONG_0093, SONG_0094) |
| Mute, T1–T8 (mirror bank) | `song.sys` | `0x0A2D + i` (stride 1, 1:1) | **Confirmed** T1–T2; **Correlated** T3–T8 (SONG_0093) |
| Mute, T9/T10–T19/T20 (mirror bank) | `song.sys` | `0x0A35`–`0x0A40`, one entry per pair | **Correlated** (SONG_0093) |
| Mute, T21–T32 (mirror bank) | `song.sys` | `0x0A41`–`0x0A4C` | **Rejected** — these were `0x00` even with T21–T32 muted (SONG_0093 stopped at T18 in low bank, T20 in mirror) |
| Track 1 active-take candidate | `edltable.sys` | `0x00B01A38` | **Correlated** |
| EDL position → physical track | `edltable.sys` / `song.sys` | position 0 = T1, 1 = T2, 2 = T3, continuing sequentially | **Confirmed** for V1 track-to-WAV assignment |
| Track-type field (stereo/mono) | `song.sys` | `0x09F0 + pairIndex` | **Strong hypothesis** (SONG_0095, T27 stereo→mono changed byte `0x09F9` from `0x02` to `0x01`) |

### Level scale (Confirmed, SONG_0092)

| Raw byte | Fader position |
| --- | --- |
| `0x00` | −∞ (minimum) |
| `0x28` | −20 dB |
| `0x3E` | −10 dB |
| `0x4E` | ≈ −6.4 dB (device fader sensitivity limit) |
| `0x5C` | ≈ −3 dB |
| `0x6A` | 0 dB (unity) |
| `0x7F` | +6 dB (maximum — device fader does not go higher) |

Continuous preview mapping between anchors is implemented for V1 playback.

### Pan scale (Confirmed, SONG_0092)

| Raw byte | Pan position |
| --- | --- |
| `0x01` | L (hard left) |
| `0x3C` | L4 |
| `0x3E` | L2 |
| `0x40` | C (center, baseline default) |
| `0x42` | R2 |
| `0x44` | R4 |
| `0x7F` | R (hard right) |

### Stereo pair layout in the mirror bank (Confirmed, SONG_0095)

Tracks 9–32 are stereo pairs on the DP-32SD. In the mirror bank (`0x081C`/`0x081E` region), stereo pairs each occupy a single logical entry rather than two physical-channel entries:

| Stereo pair | Physical tracks | Mirror logical index |
| --- | --- | --- |
| Pair 1 | T9 / T10 | 8 |
| Pair 2 | T11 / T12 | 9 |
| … | … | … |
| Pair 12 | T31 / T32 | 19 |

Formula: `logicalIndex = 8 + (pairNumber - 1)` where pair 1 = T9/T10.

The low bank still uses a physical-channel-per-row layout (T9 = stride index 8, T10 = stride index 9, …), but the device writes fader changes to the left-source channel only in some configurations. For display and playback, prefer the mirror bank for stereo-pair level/pan.

### Low-bank mute table boundary (Confirmed, SONG_0093)

The low-bank mute byte table at `0x0268` covers physical channels up to T18 in the SONG_0093 capture (8 mono + 5 active stereo pairs × 2 channels = 18 entries). Bytes at `0x0279`–`0x0287` are a different field; they contained non-zero pre-existing data in the baseline. Do not read those bytes as mute flags.

The mirror-bank mute table at `0x0A2D` covers 20 logical tracks (8 mono + 12 stereo pairs) in SONG_0093. Entries `0x0A41`–`0x0A4C` (logical T21–T32) remained `0x00` even with all device-accessible tracks muted.

### EDL position–to–track mapping (SONG_0094 update)

Muting only Track 3 from the three-track capture SONG_0086 produced `song.sys` byte `0x026A = 0x01` (T3 mute low bank) and `0x0A2F = 0x01` (T3 mute mirror). The WAV at EDL position 2 was the one excluded from the expected playback set. Current V1 evidence confirms the sequential EDL-position-to-physical-track pattern used by the app.

### Pre-existing notes on WAV / EDL evidence

Track-to-WAV assignment is confirmed from EDL file-list position to physical track. Sorted filename-to-track assignment remains `Rejected`.

`AUDIT-PREVIEW-SAMPLE-001` observes that populated samples' `edltable.sys` file-list entries match folder WAV inventory as a set, while the EDL order often differs from filename sort.

`Docs/TEST-SONGS` adds stronger negative evidence for sorted filename-to-track assignment. Single-track captures mostly reused `ZZ0000_1.wav` regardless of physical track, `SONG_0063` unexpectedly contains two WAVs for the Track 4-only action, and `SONG_0084`, `SONG_0085`, `SONG_0086`, `SONG_0090`, and `SONG_0091` show EDL file-list order can differ from sorted filename order.

Additional capture findings:

- Multiple WAVs / regions are `Observed`: multi-clip and record-over captures create multiple WAVs and matching EDL file-list entries, without proving general physical-track playback assignment.
- Timeline offsets are `Confirmed`: delayed captures expose 44,100 Hz sample-domain values near `0x41898`–`0x42C10`, including about 10 seconds as `441000`/`441600`, 20 seconds as `882000`, and 60 seconds as `2646655`/`2646656`. Region lengths appear trimmed by about `441` samples.
- Track 1 active virtual take is `Correlated` at `edltable.sys` byte `0x00B01A38`: `0x00` for take 1 active (`SONG_0083`, `SONG_0085`) and `0x01` for take 2 active (`SONG_0084`).
- Active-take selection is not encoded reliably by the WAV filename suffix. See `SONG_0084` notes for the EDL file-list selector pattern.
- Stereo-pair track type field is `Strong hypothesis` at `0x09F0`: repeated `0x02` (stereo) entries, one per pair; converting T27/T28 to mono changed entry index 9 from `0x02` to `0x01` (SONG_0095).

## Preview Playback Notes

The stereo preview is read-only. It opens assigned WAV files with AVFoundation and applies confirmed mute, pan, and level handling without modifying source files or metadata.

Current playback assumptions:

- Physical track-to-WAV mapping is applied from confirmed EDL file-list order. Remaining unassigned WAV regions are previewed with neutral center pan and unity gain after active virtual-take filtering.
- Track 1 active virtual-take filtering is applied in two narrow cases: same-stem filename alternatives such as `ZZ0003_1.wav` / `ZZ0003_2.wav`, and the `SONG_0084`-backed EDL file-list selector where byte `0x00B01A38 == 0x01` selects `ZZ0002_1.wav`. Do not extend this behavior to Track 2+ until more captures identify the selector stride/order.
- Mute bytes are read and suppressed through the confirmed EDL-position-to-track mapping. Mute parsing currently covers the app's supported low-bank and mirror-bank ranges.
- Pan byte `0x40` is confirmed center; `0x01` is confirmed hard left; `0x7F` is confirmed hard right. Playback uses these confirmed anchors and linear interpolation for intermediate values.
- Level byte `0x00` maps to minimum gain. Playback applies the same level scale shown in the mixer UI.
- Timeline candidates extracted from `edltable.sys` are confirmed delayed placements. Pair starts to WAV regions only when counts make the pairing unambiguous.
- Preview scheduling normalizes the earliest inferred region to playback time zero while preserving relative offsets.

## Playback Troubleshooting

If pressing Play yields no immediate audio:

- Confirm at least one unassigned WAV region is visible in the region table.
- If testing virtual takes, confirm the active-take byte shown for Track 1 matches the expected capture (`0x00` for `SONG_0083` / `SONG_0085`, `0x01` for `SONG_0084`).
- Confirm at least one previewed region is not muted by the interpreted mute byte when track mapping is available.
- Check the project has audible WAV content (some captured takes are near-silent).
- Wait briefly if a project contains only delayed clips, then verify timeline evidence in `edltable.sys` parsing output.

CoreAudio/HAL log lines such as sandbox lookup warnings or optional factory registration messages can appear during preview startup. Treat these as diagnostics unless playback actually fails.

## Implementation Boundary

The app should implement a read-only preview path first:

1. Open a project folder.
2. Validate `song.sys`, `edltable.sys`, and WAV inventory.
3. Parse correlated mixer bytes into a visible track table.
4. Keep stereo preview playback read-only and backed by visible, testable parsed values.

Do not write back to project folders. Do not modify or normalize source samples.
