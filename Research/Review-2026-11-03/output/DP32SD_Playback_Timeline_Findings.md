# DP-32SD Playback and Timeline Findings

**Review date:** November 3, 2026

**Scope:** Existing song copies, capture notes, app source, research notes, available firmware, and read-only checks. No device recordings or source-song changes were made.

## Executive findings

1. **The current app can play inactive takes.** In `SONG_0084`, the worksheet identifies the active Track 1 take as `ZZ0002_1.wav`; the EDL selector is `0x01`. The builder instead groups the three distinct WAV stems as three sequential track groups, sees suffix `_1` on each, and assigns all three. The direct assigned-track engine path does not apply the EDL take selector. The captured `SONG_0084 → SONG_0085` switch strengthens the active-selector correlation: WAV hashes and `song.sys` are identical while the selector changes `0x01 → 0x00` and EDL list order changes. This remains **Correlated** evidence for the capture set, not proof of a general selector layout.
2. **The current timeline builder invents starts for several captures.** Its sequential fallback is activated when any one computed WAV-length boundary appears in the scan window. In `SONG_0086`, the worksheet says three tracks start at `00:00`; the builder replayed by the analysis script predicts `[0, 281799, 503328]` samples. The first boundary match is enough to accept both inferred later starts. For `SONG_0081`, with Track 2 recorded at `00:10`, the same fallback predicts `[0,183309]` (about 4.16 seconds), not 10 seconds. `SONG_0082` contains overlapping tracks and separated clips but receives a sequential staircase as well.
3. **Mute fields have stronger direct evidence than general playback assignment.** `SONG_0060 → SONG_0075` changes exactly `song.sys` bytes `0x0268` and `0x0A2D`, with unchanged EDL and WAV hashes. `SONG_0086 → SONG_0090` and `SONG_0086 → SONG_0094` similarly isolate Track 2 and Track 3 mute candidates. `SONG_0059 → SONG_0093` changes 18 low-bank bytes (`0x0268–0x0279`) and 20 mirror-bank bytes (`0x0A2D–0x0A40`) in the all-mute sweep. No disagreement was found in the paired mute bytes that both banks expose. This does not independently prove that each EDL position identifies a physical track: the captures contain no AudioDepot playback reference.
4. **No AudioDepot exports or exported per-track WAVs were present.** Existing audio is internal song WAV inventory and the DP-32 demo project. WAV metadata confirms 44.1 kHz PCM in sampled captures, but no independent exported-track identity/alignment reference was available. Silence in a capture WAV cannot be treated as proof that a region is absent.
5. **Firmware v1.11 is not yet suitable for defensible Ghidra analysis.** The available `DP-32SD030.111` is a 1,847,328-byte data file with a `DP-32SD` prefix and high-entropy ranges, but no validated executable/container signature or readable architecture marker was found. Ghidra and Binwalk were not installed. Random `MZ`, gzip, LZMA, and instruction-like byte sequences from the lightweight scan are not validated structures and are excluded from interpretation.

## Evidence provenance and integrity

The canonical repository is available at `/Volumes/Secondary SSD/Projects/Experiments/PortastudioResearch` (the older `/Users/shawn/Projects/SwiftUI/PortastudioResearch` path is absent). Its capture specs, methods, notes, and copied projects were read only. That checkout had pre-existing modified research Markdown and untracked audit artifacts when this review began; none were edited.

The app worksheet marks the `SONG_0059–SONG_0095` rows complete but leaves every **Actual song** cell blank. This report treats the expected folder IDs as the copied song IDs, as the local research index does, and records that provenance limit. Firmware version for these captures is `TBD` in the canonical matrix. The separate v1.11 update is not evidence of the capture firmware.

`source_hashes_before.json` and `source_hashes_after.json` cover 281 files: the app's `Docs/TEST-SONGS`, canonical research `Docs/TestProjects/DP-32SD`, the demo-song folder, the v1.11 update, and its ZIP. The manifests contain identical paths and SHA-256 hashes before and after analysis (0 changes). The v1.11 binary hash is `4f227c86f6202b242c48393049016afdab1a1e01f3f1f0502a43d5e00a7dbf4b`; the ZIP hash is `b53e3cab490ac17da3b0b12ea04d32227079f372c78aa8f7e01aa3adf97161c4`.

The canonical DP-32SD research corpus contains the `MVP-*` controlled mixer/take anchors and the larger `TONG_0055` project with many same-stem WAV alternatives. The app capture corpus contains 37 project folders and includes the focused multi-clip, record-over, active-take, mute, stereo-pair, and mixer captures. No AudioDepot directory or `*_TRK*.WAV` export was found in either test-project tree.

## Capture comparisons

| Comparison | Changed data | What it supports | Evidence and limit |
| --- | --- | --- | --- |
| `SONG_0060 → SONG_0075` | `song.sys`: `0x0268 00→01`, `0x0A2D 00→01`; EDL and WAV files identical | Track 1 mute candidate in low and mirror banks | **Confirmed** for this Track 1 capture pair per existing evidence notes. No independent playback render. |
| `SONG_0086 → SONG_0090` | `song.sys`: `0x0269 00→01`, `0x0A2E 00→01`, plus state bytes `0x0240` and `0x09C0`; EDL and WAV files identical | Track 2 mute candidate; demonstrates a non-Track-1 control | **Correlated** as previously documented. |
| `SONG_0086 → SONG_0094` | `song.sys`: `0x026A 00→01`, `0x0A2F 00→01`, plus `0x0240`, `0x09C0`; EDL and WAV files identical | Track 3 mute candidate | Raw byte change **Observed**; EDL-position-to-track interpretation remains **Correlated** in the worksheet. The project files do not encode the expected audible result. |
| `SONG_0059 → SONG_0093` | 40 mute bytes change: 18 low-bank entries `0x0268–0x0279`, 20 mirror entries `0x0A2D–0x0A40`, and two nearby state bytes `0x0240`, `0x09C0`; EDL and WAV inventory identical | All-mute sweep exposes the saved ranges and supports the documented bank boundaries | **Observed** for this all-mute sweep. It does not justify treating `0x027A–0x0287` or `0x0A41–0x0A4C` as mute flags; those bytes did not change here. Per-channel interpretation beyond documented ranges stays **Correlated** or unknown. |
| `SONG_0083 → SONG_0084` | New WAV `ZZ0002_1.wav`; `song.sys` metadata changes; many EDL differences | Take 2 record plus active-take operation | Not a one-action binary comparison: recording and active selection both differ. Keep the selector claim **Correlated**. |
| `SONG_0084 → SONG_0085` | Same WAV names and hashes; `song.sys` identical; EDL selector `0x00B01A38` changes `01→00`, plus sparse tail changes and EDL list reordering | Active selector follows the selected Track 1 virtual take in this controlled switch | **Correlated**. The exact selector-to-entry rule and applicability to other tracks are unresolved. |
| `SONG_0059 → SONG_0092` | 28 level/pan bytes change across low and mirror banks, plus `0x0240` and `0x09C0` | Multi-track mixer settings in the worksheet match their expected table positions | **Observed/Correlated** per current notes; the action changes many controls at once, so it is not evidence for each byte independently. |
| `SONG_0059 → SONG_0095` | 18 `song.sys` bytes change; WAV inventory is identical. EDL has many save/edit-area differences. | Selected high stereo-pair faders and T9/T10 pan controls | **Observed/Correlated**. The multi-setting capture supports the listed mirror-bank level values but cannot isolate all semantics; pan results are ambiguous as noted below. |
| `SONG_0094 → SONG_0095` | Many fader, pan, mute, track-type, and metadata differences; EDL differs widely | No controlled interpretation | Invalid as a controlled pair: worksheet says `SONG_0095` was copied from `SONG_0059`, not `SONG_0094`. Do not use this diff to infer a single action. |

No differing value was observed between low and mirror mute bytes where the current parser reads both in the controlled mute pairs and the all-mute sweep. The parser currently treats missing/unsupported mute fields as `false`; this collapses **unknown** into **unmuted** and can allow material through when the capture does not cover that channel. Existing app-owned mute settings are separate preview overrides.

There is a boundary typo in the current evidence wording: the low-bank table begins at `0x0268` and the all-mute sweep changes 18 bytes through `0x0279`, but the research reference and `MixerMapOffsets.swift` comment also describe `0x0279+` as outside the table. The count and address arithmetic put the next unsupported byte at `0x027A`; `0x027A–0x0287` did not change in `SONG_0059 → SONG_0093`. The byte at `0x0279` is **Observed** changing in the all-mute sweep; preserve the existing per-track confidence until an isolated T18 comparison is available, and correct the boundary description in the future documentation/code cleanup.

### Recoverable last-saved mixer values

`SONG_0092` is the cleanest broader mixer snapshot: compared with its documented `SONG_0059` source, its first eight low-bank and mirror-bank level/pan bytes agree. The captured settings and worksheet labels are:

| Mixer channel | Level byte (low / mirror) | Pan byte (low / mirror) | Worksheet display intent |
| --- | --- | --- | --- |
| T1 | `0x00C4` / `0x081C` = `00` / `00` | `0x00C6` / `0x081E` = `01` / `01` | minimum, hard left |
| T2 | `0x00D8` / `0x0830` = `28` / `28` | `0x00DA` / `0x0832` = `3C` / `3C` | −20 dB, L4 |
| T3 | `0x00EC` / `0x0844` = `3E` / `3E` | `0x00EE` / `0x0846` = `40` / `40` | −10 dB, center |
| T4 | `0x0100` / `0x0858` = `6A` / `6A` | `0x0102` / `0x085A` = `44` / `44` | 0 dB, R4 |
| T5 | `0x0114` / `0x086C` = `7F` / `7F` | `0x0116` / `0x086E` = `7F` / `7F` | +6 dB, hard right |
| T6 | `0x0128` / `0x0880` = `7F` / `7F` | `0x012A` / `0x0882` = `3E` / `3E` | maximum available (+6 dB), L2 |
| T7 | `0x013C` / `0x0894` = `4E` / `4E` | `0x013E` / `0x0896` = `40` / `40` | about −6.4 dB, center |
| T8 | `0x0150` / `0x08A8` = `5C` / `5C` | `0x0152` / `0x08AA` = `42` / `42` | −3 dB, R2 |

These are saved raw values plus the worksheet's display reading; playback gain interpolation between anchors remains approximate. For stereo pairs, the `SONG_0095` mirror fields align with several documented level settings: T9/10 minimum at `0x08BC=00`, T15/16 about −10 dB at `0x08F8=3D`, T23/24 0 dB at `0x0948=69`, and T31/32 +6 dB at `0x0998=7F`. This supports the existing **Confirmed** mirror-bank pair layout for those captured points. For T15/16, T23/24, and T31/32, the low physical-row level bytes do not match the pair-level mirror values; they should not be treated as independent fader settings for stereo-pair UI channels.

The same `SONG_0095` worksheet asked for T9 hard-left and T10 hard-right pan. The stored pair field `0x08BE` is `01` (hard left), while another logical pan field `0x08D2` changes `40→7F`. Because the notes say T9/T10 share a mixer control and the capture changes several settings together, this does not establish that a distinct T10 right-pan value was saved. Keep that interpretation unresolved rather than assigning the second value to T10.

## Playback path and failure mechanism

1. `ContentView` loads the project folder through `ProjectPreviewBuilder`: WAV inventory, `song.sys`, and `edltable.sys` are read into a project model.
2. `EdlTableParser` preserves EDL filename-list order and item offsets, reads the correlated Track 1 candidate at `0x00B01A38`, and scans only `0x41600–0x42D00` for 44.1 kHz values near whole-second boundaries.
3. `ProjectPreviewBuilder` first groups EDL WAV names by stem, then treats each new stem as the next physical track. It also applies `track1ActiveTakeCandidate + 1` as the preferred suffix on **every** group. A WAV suffix is not a validated take number for `SONG_0084`, where all three files end `_1.wav`.
4. Files assigned into those groups are excluded from `unassignedAudioRegions`. `StereoPreviewEngine`'s assigned path selects one option per group, schedules only that option's first region, and applies track mixer mute, level, and pan. Mute from `song.sys` reaches a mixer node and can silence an assigned track. Unknown mute parses as false.
5. `PreviewPlaybackPlanner`'s virtual-take filtering is applied only to unassigned regions. Its selector fallback can select one EDL-list item while suppressing every other unassigned file, without knowing those files belong to Track 1. It does not filter assigned inactive takes and does not receive per-track selected-option overrides for unassigned files. Mute suppression there enumerates the remaining unassigned list, so its index may no longer match the original EDL position. Unassigned files play through the main mixer at unity/center and bypass assigned-track mute and per-track overrides.
6. `PreviewMixState` starts from parsed device-like level/pan/mute defaults and can load or save app-owned level/pan/mute/solo/take choices in SwiftData under an editable exact song fingerprint. These are preview overrides; they are not written to `song.sys` or the source folder. A user override can intentionally audition a different option, but it must not be presented as recovered device state.

### Inactive take and mute consequence

For `SONG_0084`, EDL entries are at `0x00B025AA` (`ZZ0001_1.wav`), `0x00B025BE` (`ZZ0000_1.wav`), and `0x00B025D2` (`ZZ0002_1.wav`). The worksheet's captured expected playback is only `ZZ0002_1.wav` for active VT2. Current builder grouping makes three single-option groups, assigns them to Tracks 1–3, and the engine directly schedules all three. The correlated selector is never consulted by this assigned path. Thus inactive material is included and can also inherit the wrong physical-track mute/level/pan. The same shape appears in `SONG_0085` after switching back to VT1; file list order changes but all three files remain assigned.

Mute itself works for unambiguously assigned one-file-per-track cases: Track 3 in `SONG_0094` maps to the third group under current assumptions and is muted. But multi-clip captures are counterexamples to extending that mapping by EDL-list position: the worksheet says `SONG_0077` has two clips on Track 1, and `SONG_0078` has three clips on Track 1. Current grouping sends each distinct stem to a separate track. A mute on Track 1 can therefore silence only the first clip while later clips are routed through other channels. This is a mapping limitation, not evidence that the mute bytes themselves are wrong.

`SONG_0089` is another counterexample: `ZZ0000_1.wav` and `ZZ0000_2.wav` are observed stereo-pair output files with identical 10.133-second duration. Stem grouping turns them into two take options and selects one candidate, which can drop the paired channel. Stereo-pair handling remains **Observed**, not generalized.

## Timeline evidence and counterexamples

EDL list entry identity and original byte offset are retained in `capture_audit.json`. The app parser currently keeps only filenames and enumerated indices; downstream grouping loses the source EDL offset and conflates a file entry with a physical track or virtual-take option.

| Capture | Worksheet arrangement | WAV/EDL evidence | Current builder's inferred starts (44.1 kHz samples) | Assessment |
| --- | --- | --- | --- | --- |
| `SONG_0077` | Track 1 clips at 0 and 10 s | Two files; EDL entries `ZZ0000_1.wav`, `ZZ0001_1.wav`; candidate around `441000` | `[0,441000]` | Matches the action label, but not independent placement proof. |
| `SONG_0078` | Track 1 clips at 0, 10, 20 s | Three files; candidate words near `441000`, `882000` | `[0,441000,882000]` | Supports the recorded delayed-capture pattern; exact record semantics remain **Correlated**. |
| `SONG_0079` | One Track 1 clip at 10 s | One WAV; repeated candidate words near `441000` | `[441000]` | Correlates delay with sample-domain values. |
| `SONG_0080` | Track 1 recording then record-over later section | Three files; no whole-second anchors; one computed trimmed-length value `153909` appears in scan window | `[0,153909,316638]` by sequential fallback | Start/end/overlap not established. The fallback invents a continuous staircase from one matching length. |
| `SONG_0081` | Track 1 at 0; Track 2 at 10 s | Two files; a candidate around `442464` lies outside the parser's ±800-sample boundary tolerance; another matching WAV length is present | `[0,183309]` by sequential fallback | Reproducible counterexample: 183,309 samples is the first WAV length minus 441, not the documented 10-second Track 2 start. |
| `SONG_0082` | Track 1 has separated clips; Track 2 overlaps them | Four files; two accepted near-second candidate groups, which do not satisfy the WAV-count pairing rule; a WAV-length word matches | `[0,170079,390138,614607]` by sequential fallback | Reproducible counterexample to count-based pairing and sequential placement for overlaps. |
| `SONG_0086` | Tracks 1, 2, and 3 all start at 0 | Three WAVs; EDL order is `ZZ0002`, `ZZ0001`, `ZZ0000`; WAV-length values are present | `[0,281799,503328]` by sequential fallback | Strongest placement counterexample: three simultaneous starts become a staircase. |
| `SONG_0084–0085` | Track 1 takes; active take switches | Three WAV files, changing selector/list order | `SONG_0084`: `[0,152439,346038]`; `SONG_0085`: `[0,190659,343098]` | One track's take files are also spread across group/track rows and sequentialized. |

The timeline parser's near-second scan can miss a candidate slightly farther from a second boundary (as in `442464`). Its pairing rule accepts candidates only when the count equals the WAV count or is exactly one fewer; all other counts default to zero and then enter the sequential fallback. The fallback requires only one boundary match within `0x41600–0x50000`, not a complete set of boundaries or proof that files are contiguous. Region end, source offset, overlap ownership, and exact audio-to-region alignment remain unknown. WAV silence is not a region-deletion marker.

## Firmware and tool results

| Item | Result |
| --- | --- |
| Firmware update | ZIP contains one member `DP-32SD030.111`, uncompressed size 1,847,328 bytes; binary SHA-256 recorded above. |
| Header/type | `file` reports generic `data`; offset `0x00` begins ASCII `DP-32SD`. No ELF, Mach-O, or validated container header was identified at the start. |
| Entropy | 64 KiB window estimates are about 5.08–7.96 bits/byte; the `0xF0000–0x19FFFF` range is about 7.46–7.96, consistent with compressed/encrypted data but not distinguishing them. |
| Strings | No useful architecture, section, CPU, or file-format strings were recovered beyond the product prefix; most printable runs were short noise-like sequences. |
| Ghidra / Binwalk | Neither executable was available in PATH or the checked app locations. No architecture, load address, or section map was defensible, so disassembly was not attempted. The local Python scanner reports candidate byte patterns only; incidental `MZ`/gzip/LZMA-like sequences are not accepted as payload boundaries. |
| Python and WAV tools | Isolated Python 3.10 `.venv` uses only the standard library. `ffprobe` 6.0 verified sampled internal WAVs as mono PCM 16-bit, 44.1 kHz; e.g. `SONG_0077/ZZ0000_1.wav` is 138,180 frames (3.133333 s), and `SONG_0089/ZZ0000_1.wav` is 446,880 frames (10.133333 s). |
| Audio identity matching | Not run: no AudioDepot exports or independent reference WAVs were found. NumPy, SciPy, and SoundFile were therefore unnecessary. |

## Validation

Focused Xcode tests ran against the current checkout, with DerivedData isolated under this review folder:

```text
xcodebuild -scheme PortastudioPreview -project PortastudioPreview.xcodeproj \
  -destination 'platform=macOS' \
  -derivedDataPath Research/Review-2026-11-03/.derivedData test \
  -only-testing:PortastudioPreviewTests/ProjectPreviewBuilderTests \
  -only-testing:PortastudioPreviewTests/PreviewPlaybackPlannerTests \
  -only-testing:PortastudioPreviewTests/PreviewMixStateTests \
  -only-testing:PortastudioPreviewTests/StereoPreviewEngineTests
```

Result: **60 passed, 0 failed, 0 skipped** on macOS 27.2 with Xcode 27.2. These tests validate current intended behavior, including synthetic cases, but they do not cover the negative capture examples listed above. No app implementation was changed during this review.

## Evidence table and limits

| Claim | Evidence label | Scope / limit |
| --- | --- | --- |
| `song.sys` Track 1 mute bytes `0x0268` / `0x0A2D` | **Confirmed** (existing scoped label) | `SONG_0060 → SONG_0075`; does not establish all physical channels. |
| Track 2 mute bytes `0x0269` / `0x0A2E` | **Correlated** | `SONG_0086 → SONG_0090`; paired low/mirror values agree. |
| Track 3 mute bytes `0x026A` / `0x0A2F` | **Observed** byte change; **Correlated** channel interpretation | `SONG_0086 → SONG_0094`; no AudioDepot proof that a particular WAV is removed. |
| All-mute ranges `0x0268–0x0279` and `0x0A2D–0x0A40` change | **Observed** | One T1–T32 UI sweep; bytes beyond these spans did not change. Individual mappings retain existing scoped labels; extra mirror rows are **Rejected** by this capture as the expected T21–T32 continuation. |
| `0x00B01A38` tracks Track 1 active-take selection | **Correlated** | `SONG_0084 → SONG_0085`; no evidence for Track 2+ selector stride. |
| 44.1 kHz EDL words correlate with delayed placements | **Confirmed** in existing notes for delayed captures | Exact record boundaries/ownership/source offsets and arbitrary timing remain unproven. |
| EDL list index is a physical-track index | **Correlated** for simple one-file-per-track examples; broader rule remains **Hypothesis** | Multi-clip `SONG_0077/78` and stereo `SONG_0089` break stem-count assumptions; no external playback reference. |
| Stereo-pair filenames are separate active takes | **Rejected** as a general conclusion | `SONG_0089` observes paired output files; filename suffix alone does not say virtual take. |

## Prioritized implementation proposal (not implemented)

| Priority | Change | Files and focused tests |
| --- | --- | --- |
| 1 | Prevent unsupported files from being treated as active device takes. Preserve EDL entry ID and byte offset, separate device active-take evidence from filename suffix and app audition choice, and remove the global Track 1 selector fallback. Do not auto-play files whose active-track relationship is unknown in reconstructed playback; offer explicit file audition as a separate preview action. | `EdlTableParser.swift`, `ProjectPreviewBuilder.swift`, `PreviewPlaybackPlanner.swift`, `TrackPreview.swift`, `VirtualTrackOption.swift`, `PreviewMixState.swift`; tests for `SONG_0083–0085`, unrelated stems, sparse lists, unknown selector, missing files, user-selected audition. |
| 2 | Preserve unknown mute explicitly. Apply mute only after a file/region is assigned to a supported physical/logical channel; never infer mute list indices from a shortened unassigned list. Keep unknown distinct from unmuted and show the evidence scope. | `SongSysParser.swift`, `MixerMapOffsets.swift`, `TrackMixerSetting.swift`, `StereoPreviewEngine.swift`, `PreviewMixState.swift`; tests around `SONG_0075`, `0090`, `0093`, `0094`, mirror agreement/disagreement, unknown fields, stereo pair mapping. |
| 3 | Remove the one-boundary staircase as authoritative layout evidence. Represent start, end, source offset, region identity, owning track, and timebase as unresolved until a record association is validated. | `ProjectPreviewBuilder.swift`, `EdlTableParser.swift`, `TimelineModels.swift`, `TimelineVisualizationBuilder.swift`; tests for `SONG_0080–0082`, `0086`, arbitrary starts, simultaneous starts, and one accidental boundary match. |
| 4 | Model multiple regions per track and schedule the same resolved regions shown in the timeline, including source offsets and bounded lengths. Keep overlaps and gaps only where data identifies them. | `TrackPreview.swift`, `TimelineModels.swift`, `StereoPreviewEngine.swift`, `PreviewPlaybackPlanner.swift`; tests for gaps, overlaps, record-over, multi-clip single track, stereo-pair files, and mute across every region. |
| 5 | Preserve EDL offsets/order through UI diagnostics and display candidate versus confirmed assignment and app overrides separately. | `EdlTableSummary.swift`, `TimelineVisualizationView.swift`, `TrackRegionInspectorView.swift`; accessibility and diagnostic tests. |

### Smallest future device experiment

When hardware testing is next authorized, make a copy of a baseline song, record two short spoken identifiers on Track 1 virtual tracks 1 and 2, save and copy each active-selection state, then export Track 1 through AudioDepot. Compare the saved selector byte, EDL list identity/order, and exported audible identifier. This single controlled pair directly tests whether the active selector identifies a file-list entry and whether the mapping survives reload. A separate follow-up should record one second clip on the same take at a non-whole-second position and export it, to identify region start, source start, and duration without mistaking WAV silence for no region.
