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
| [x] | `SONG_0084` |  | `SONG_0083` | Track 1 virtual take 2: record "take two"; make take 2 active. Save once. |  |
| [x] | `SONG_0085` |  | `SONG_0084` | Switch active virtual take back to take 1 only. Save once. |  |

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
