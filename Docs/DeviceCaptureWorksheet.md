# DP-32SD Device Capture Worksheet

Use this worksheet while creating device-side test songs. Do not rename songs on the device. If the device creates a different song number than expected, write the actual number in the `Actual song` field.

## Rules

- Always copy from the listed source song.
- Make only the listed change for that capture.
- Save once after the intended change.
- Do not use `DELETE UNUSED`.
- Do not bounce, master, normalize, clone, or edit unless a step explicitly asks for it.
- Speak labels into recordings when possible, such as "track one start" or "track one ten seconds".
- After copying files to the Mac, keep each copied project folder unchanged.

## Result Log Template

Use this block for extra notes whenever a step does not go exactly as planned.

```text
Expected song:
Actual song:
Copied from:
Device action:
Track:
Virtual take:
Timeline position:
Approx clip length:
Saved once? yes/no
Notes:
```

## Phase 1: Baseline

Goal: create the clean source song used by later tests.

| Done | Expected song | Actual song | Copy from | Action | Notes |
| --- | --- | --- | --- | --- | --- |
| [x ] | `SONG_0059` |  | New song | Empty baseline. Save once. No audio. |  |

## Phase 2: Track-To-WAV Mapping

Goal: identify which WAV files correspond to physical tracks. Use unique spoken labels and approximate lengths.

| Done | Expected song | Actual song | Copy from | Action | Notes |
| --- | --- | --- | --- | --- | --- |
| [x] | `SONG_0060` |  | `SONG_0059` | Track 1 only. Record about 2s: "track one". Save once. |  |
| [x] | `SONG_0061` |  | `SONG_0059` | Track 2 only. Record about 3s: "track two". Save once. |  |
| [x] | `SONG_0062` |  | `SONG_0059` | Track 3 only. Record about 4s: "track three". Save once. |  |
| [x] | `SONG_0063` |  | `SONG_0059` | Track 4 only. Record about 5s: "track four". Save once. |  |
| [x] | `SONG_0064` |  | `SONG_0059` | Track 5 only. Record about 6s: "track five". Save once. |  |
| [x] | `SONG_0065` |  | `SONG_0059` | Track 6 only. Record about 7s: "track six". Save once. |  |
| [x] | `SONG_0066` |  | `SONG_0059` | Track 7 only. Record about 8s: "track seven". Save once. |  |
| [x] | `SONG_0067` |  | `SONG_0059` | Track 8 only. Record about 9s: "track eight". Save once. |  |

## Phase 3: Track 1 Mixer Scale

Goal: identify fader, pan, and mute bytes. Copy from `SONG_0060` because it should contain only Track 1 audio.

| Done | Expected song | Actual song | Copy from | Action | Notes |
| --- | --- | --- | --- | --- | --- |
| [x] | `SONG_0068` |  | `SONG_0060` | Track 1 fader minimum. Save once. |  |
| [x] | `SONG_0069` |  | `SONG_0060` | Track 1 fader about 25%. Save once. |  |
| [x] | `SONG_0070` |  | `SONG_0060` | Track 1 fader center/0 mark if available. Save once. |  |
| [x] | `SONG_0071` |  | `SONG_0060` | Track 1 fader maximum. Save once. |  |
| [x] | `SONG_0072` |  | `SONG_0060` | Track 1 pan hard left. Save once. |  |
| [x] | `SONG_0073` |  | `SONG_0060` | Track 1 pan center. Save once. |  |
| [x] | `SONG_0074` |  | `SONG_0060` | Track 1 pan hard right. Save once. |  |
| [x] | `SONG_0075` |  | `SONG_0060` | Track 1 mute on. Save once. |  |

## Phase 4: Multiple WAVs / Regions On One Track

Goal: identify how separate recordings on one track are stored and replayed. Use normal recording at different timeline positions, not edit commands.

| Done | Expected song | Actual song | Copy from | Action | Notes |
| --- | --- | --- | --- | --- | --- |
| [x] | `SONG_0076` |  | `SONG_0059` | Track 1: one clip at `00:00`, say "track one start". Save once. |  |
| [x] | `SONG_0077` |  | `SONG_0059` | Track 1: clip at `00:00`, second clip at `00:10`. Save once. |  |
| [x] | `SONG_0078` |  | `SONG_0059` | Track 1: clips at `00:00`, `00:10`, `00:20`. Save once. |  |
| [x] | `SONG_0079` |  | `SONG_0059` | Track 1: one clip at `00:10` only, leaving silence before it. Save once. |  |
| [x] | `SONG_0080` |  | `SONG_0059` | Track 1: clip at `00:00`, then record-over a later section on Track 1. Save once. |  |
| [x] | `SONG_0081` |  | `SONG_0059` | Track 1 at `00:00`; Track 2 at `00:10`. Save once. |  |
| [x] | `SONG_0082` |  | `SONG_0059` | Track 1 two separated clips; Track 2 one overlapping clip. Save once. |  |

## Phase 5: Virtual Takes

Goal: identify active take selection so inactive takes do not play.

| Done | Expected song | Actual song | Copy from | Action | Notes |
| --- | --- | --- | --- | --- | --- |
| [x] | `SONG_0083` |  | `SONG_0059` | Track 1 virtual take 1: record "take one". Save once. |  |
| [x] | `SONG_0084` |  | `SONG_0083` | Track 1 virtual take 2: record "take two"; make take 2 active. Save once. | `edltable.sys` active byte `0x00B01A38 == 0x01`; EDL file list `ZZ0001_1.wav`, `ZZ0000_1.wav`, `ZZ0002_1.wav`; preview should play only `ZZ0002_1.wav` for active VT2. |
| [x] | `SONG_0085` |  | `SONG_0084` | Switch active virtual take back to take 1 only. Save once. |  |

Implementation note: the active virtual-track selection is not reliably encoded by the WAV filename suffix. In `SONG_0084`, all candidate files end in `_1.wav`; the preview uses the correlated Track 1 active-take byte plus the EDL file-list pattern to avoid playing inactive takes.

## Phase 6: Combined Preview Sanity

Goal: approximate real song reconstruction with multiple tracks and simple mixer state.

| Done | Expected song | Actual song | Copy from | Action | Notes |
| --- | --- | --- | --- | --- | --- |
| [x] | `SONG_0086` |  | `SONG_0059` | Tracks 1, 2, 3 all start at `00:00`, each with spoken label. Save once. |  |
| [x] | `SONG_0087` |  | `SONG_0059` | Track 1 clip at `00:10` only. Save once. |  |
| [x] | `SONG_0088` |  | `SONG_0059` | Track 1 clip at `01:00` only. Save once. |  |
| [x] | `SONG_0089` |  | `SONG_0059` | Stereo-pair track test if easy on the device. Save once. | used track 9/10 at zero seconds used inputs an and b as source, normal track to source is 1 - 8 a-h but stereo it a combination chosen fyi. |
| [x] | `SONG_0090` |  | `SONG_0086` | Mute Track 2 only. Save once. |  |
| [x] | `SONG_0091` |  | `SONG_0086` | Pan Track 1 hard left, Track 2 hard right. Save once. |  |

## Phase 7: Pan and Level Scale Calibration

Goal: establish the byte-to-scale mapping for fader level and pan, and confirm the pan offsets for tracks 3 and 7 which were absent in `DIFF-MVP-MIXMAP-001` (the MIXMAP variant did not change those pans). No audio recording is required; the mixer state change alone is sufficient. Document the exact value shown on the device display for each track before saving.

Copy from `SONG_0059`. Set the mixer as follows, then save once. Write the exact display readout for each entry in the Notes column of the log.

| Parameter | Track 1 | Track 2 | Track 3 | Track 4 | Track 5 | Track 6 | Track 7 | Track 8 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Fader | –∞ (min) | –20 dB | –10 dB | 0 dB | +6 dB | +10 dB (max if available) | –6 dB | –3 dB |
| Pan | L (hard left) | L4 | C (center) | R4 | R (hard right) | L2 | C (center) | R2 |

Evidence expected: pan offsets for all 8 tracks including T3 (`0x00EE`) and T7 (`0x013E`) both Observed; byte values at 8 distinct level positions and 7 distinct pan positions establish the scale lookup table.

| Done | Expected song | Actual song | Copy from | Action | Notes |
| --- | --- | --- | --- | --- | --- |
| [x] | `SONG_0092` |  | `SONG_0059` | Set T1–T8 fader and pan to the table above. No audio. Save once. Record exact display readout for every track level and pan. | Track 6 unit faders can only go up to +6db, Track 7 I could only get it to stay at -6.4db due to fader sensitivity. |

## Phase 8: All-32-Track Mute Sweep

Goal: confirm the mute byte position for all 32 tracks in a single diff. This fills in all even-track positions (T4, T6, T8) that were absent in `DIFF-MVP-MIXMAP-001`, and extends mute coverage to tracks 10–32 which have never been tested. No audio is required.

| Done | Expected song | Actual song | Copy from | Action | Notes |
| --- | --- | --- | --- | --- | --- |
| [x] | `SONG_0093` |  | `SONG_0059` | Press the MUTE button for every track: T1 through T32. Verify all 32 mute indicators are lit. Save once. |  |

Evidence expected: all 32 mute byte positions `0x0268`–`0x0287` and their mirrors `0x0A2D`–`0x0A4C` Observed in one diff. Covers even-track gaps and the entire T10–T32 range.

## Phase 9: EDL Position–to–Track Correlation, Track 3

Goal: confirm that EDL position 2 corresponds to physical track 3. `SONG_0086` already contains audio on tracks 1, 2, and 3 with three EDL entries. Muting track 3 only, while leaving tracks 1 and 2 unmuted, will show which EDL entry disappears from the expected playback set. Combined with the existing Observed evidence that position 0 = track 1 (SONG_0075) and position 1 = track 2 (SONG_0090), confirming position 2 = track 3 establishes the sequential pattern, which can then be extended as a Hypothesis for tracks 4–32.

| Done | Expected song | Actual song | Copy from | Action | Notes |
| --- | --- | --- | --- | --- | --- |
| [x] | `SONG_0094` |  | `SONG_0086` | Mute track 3 only. Tracks 1 and 2 must remain unmuted. Save once. |  |

Evidence expected: `song.sys` byte `0x026A` = `0x01` (T3 mute, Observed); the WAV previously at EDL position 2 is absent from playable output (EDL position-to-track correlation Correlated for track 3).

## Phase 10: High-Track Level Stride Probe, Tracks 9–32

Goal: verify that the stride-`0x14` formula holds for the full upper half of the mixer map (tracks 9–32). Setting a distinct, documented level on four widely-spaced tracks is sufficient to confirm or break the stride at the extremes. Also sets pan on track 9 and 10 to probe whether mirror bank entries exist beyond track 8 (`0x081C` bank was only Correlated up to track 8).

Copy from `SONG_0059`. Set the mixer only — no audio required. Document exact display readout for each changed parameter.

| Parameter | Track 9 | Track 16 | Track 24 | Track 32 | Track 9 pan | Track 10 pan |
| --- | --- | --- | --- | --- | --- | --- |
| Fader | –∞ (min) | –10 dB | 0 dB | +10 dB (max if available) | L (hard left) | R (hard right) |

| Done | Expected song | Actual song | Copy from | Action | Notes |
| --- | --- | --- | --- | --- | --- |
| [x] | `SONG_0095` |  | `SONG_0059` | Set T9, T16, T24, T32 faders to documented positions above. Set T9 pan hard left, T10 pan hard right. Save once. Record exact display readout for each change. | Track 32 Mac fader level is +6db same for all tracks. Each of these tracks share their partnering track. So track 9 shares the same settings as track 10 and 15 shares same fader controls and settings as trade 16 as tracks 8 - 32 are all grouped by two stereo tracks. They can be made mono but that only utilizes tracks 9,11,13,15,17,19,21,23,25,27,29,31 and the second track for each of those groups are basically ignored and the fader is just treating one track not two. So in this I provided the stereo pan and stereo fader changes. Mono should be easy for you to manage and understand. |

Evidence expected: level offsets `0x0154` (T9), `0x01C4` (T16), `0x0244` (T24), `0x0330` (T32) all Observed, stride-`0x14` formula Correlated for full 32-track range; T9/T10 pan offsets `0x0156`/`0x016A` Observed; any change in mirror bank (`0x081C` region) beyond T8 distinguishes Correlated from Hypothesis for high tracks.

---

## Copy-Off Checklist

After all captures are complete:

| Done | Item | Notes |
| --- | --- | --- |
| [x] | Copy all project folders from the SD card to the Mac. | `/Docs/TEST-SONGS` |
| [x] | Preserve original copied project folders unchanged. |  |
| [x] | Include this completed worksheet with the copied folders. |  |
| [x] | Note any skipped tests or device behavior that differed from the plan. |  |

If you want descriptive names, put the unchanged project folder inside a descriptive enclosing folder:

```text
SONG_0077_track1_two_regions/
  SONG_0077/
```
