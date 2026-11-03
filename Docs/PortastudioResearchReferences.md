# Portastudio Research References

This app repo depends on the sibling research repo for format evidence:

`/Volumes/Secondary SSD/Projects/Experiments/PortastudioResearch`

## Canonical Entry Points

| Purpose | Path |
| --- | --- |
| Research overview | `/Volumes/Secondary SSD/Projects/Experiments/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Overview.md` |
| MVP review gate and diff index | `/Volumes/Secondary SSD/Projects/Experiments/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Methodology/BinaryDiffLog.md` |
| Controlled capture matrix | `/Volumes/Secondary SSD/Projects/Experiments/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Methodology/ControlledTestMatrix.md` |
| MVP testing plan | `/Volumes/Secondary SSD/Projects/Experiments/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Methodology/MVPBinaryTestingPlan.md` |
| Preview sample audit | `/Volumes/Secondary SSD/Projects/Experiments/PortastudioResearch/Docs/BinaryDiffs/DP-32SD/AUDIT-PREVIEW-SAMPLE-001/preview-sample-audit.md` |
| `song.sys` parser evidence | `/Volumes/Secondary SSD/Projects/Experiments/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Specs/song.sys.md` |
| `edltable.sys` parser evidence | `/Volumes/Secondary SSD/Projects/Experiments/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Specs/edltable.sys.md` |
| Open claims and hypotheses | `/Volumes/Secondary SSD/Projects/Experiments/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Notes/DiscoveriesAndHypotheses.md` |

The November 3, 2026 app-capture review and reproducible analysis are stored in `Research/Review-2026-11-03/`; start with `output/DP32SD_Playback_Timeline_Findings.md`.

## Local Sample Sources

Copied hardware projects are read-only local development inputs:

`/Volumes/Secondary SSD/Projects/Experiments/PortastudioResearch/Docs/TestProjects/DP-32SD`

The DP-32SD capture set from `Docs/DeviceCaptureWorksheet.md` is kept read-only in this app repo:

`Docs/TEST-SONGS`

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
| EDL position → physical track | `edltable.sys` / `song.sys` | Single-file cases correlate position 0 with T1; multi-file/clip/take identity unresolved | **Correlated** for the reviewed app capture set |
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

### EDL position–to-track mapping (reviewed November 3, 2026)

The `SONG_0094` mute capture correlates EDL position 2 with Track 3 for that three-track example. It does not generalize across multi-clip, record-over, take, and stereo-pair captures. `SONG_0077`/`0078` place multiple entries on Track 1, and `SONG_0084` contains three Track 1 takes. The app now retains EDL entry IDs and byte offsets, but leaves multi-file entries unassigned until those relationships are resolved.

### Pre-existing notes on WAV / EDL evidence

Sorted filename-to-track assignment remains `Rejected`. EDL file-list order preserves source ordering, but reviewed captures do not support interpreting each entry as one physical track in general.

`AUDIT-PREVIEW-SAMPLE-001` observes that populated samples' `edltable.sys` file-list entries match folder WAV inventory as a set, while the EDL order often differs from filename sort.

`Docs/TEST-SONGS` adds stronger negative evidence for sorted filename-to-track assignment. Single-track captures mostly reused `ZZ0000_1.wav` regardless of physical track, `SONG_0063` unexpectedly contains two WAVs for the Track 4-only action, and `SONG_0084`, `SONG_0085`, `SONG_0086`, `SONG_0090`, and `SONG_0091` show EDL file-list order can differ from sorted filename order.

Additional capture findings:

- Multiple WAVs / regions are `Observed`: multi-clip and record-over captures create multiple WAVs and matching EDL file-list entries, without proving general physical-track playback assignment.
- Delayed captures contain sample-domain candidates near expected offsets, but count-pairing or sequential WAV-length placement produces counterexamples in `SONG_0080–0082` and `SONG_0086`. Keep candidate words separate from region starts until record structure and audio alignment are corroborated.
- Track 1 active virtual take is `Correlated` at `edltable.sys` byte `0x00B01A38`: `0x00` for take 1 active (`SONG_0083`, `SONG_0085`) and `0x01` for take 2 active (`SONG_0084`). Do not apply this selector to other tracks or infer activity from WAV suffixes.
- Stereo-pair track type field is `Strong hypothesis` at `0x09F0`: repeated `0x02` (stereo) entries, one per pair; converting T27/T28 to mono changed entry index 9 from `0x02` to `0x01` (SONG_0095).

## Preview Playback Notes

The stereo preview is read-only. It opens assigned WAV files with AVFoundation and applies confirmed mute, pan, and level handling without modifying source files or metadata.

Current playback behavior after the November 3 review:

- Automatic reconstructed playback is withheld when track/take identity, region placement, or mute state is unresolved. Current corpus projects with multiple WAVs are intentionally withheld.
- Track 1 selector, candidate timeline words, and WAV suffixes are not used to select files or assign placement globally.
- Missing mute data is displayed as `Unknown`, separately from the app-owned preview mute override and from parsed `Off`.
- EDL file-list order and byte offsets remain available for diagnostics; file position is not used as a general physical-track identity rule.
- The evidence review found no AudioDepot or per-track exports that independently verify exact arrangement or saved mix content.

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
