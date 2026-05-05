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
| `song.sys` parser evidence | `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Specs/song.sys.md` |
| `edltable.sys` parser evidence | `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Specs/edltable.sys.md` |
| Open claims and hypotheses | `/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/ReverseEngineering/Tascam-Portastudio-DPxxSD/Notes/DiscoveriesAndHypotheses.md` |

## Local Sample Sources

Copied hardware projects are read-only local development inputs:

`/Users/shawn/Projects/SwiftUI/PortastudioResearch/Docs/TestProjects/DP-32SD`

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

## Preview Playback Notes

The stereo preview is approximate and read-only. It opens candidate WAV files with AVFoundation and applies provisional mute, pan, and level handling without modifying source files or metadata.

Current playback assumptions:

- Candidate WAV mapping is `Hypothesis`.
- Track 1 mute byte `0x0268` is treated as a correlated mute-like flag; other mute rows are not inferred.
- Pan byte `0x40` is treated as center-like for approximate playback.
- Raw level byte `0x00` is treated as unity/default gain, not silence. This matches audible populated MVP folders and avoids muting all preview audio while the true level scale remains unconfirmed.

## Implementation Boundary

The app should implement a read-only preview path first:

1. Open a project folder.
2. Validate `song.sys`, `edltable.sys`, and WAV inventory.
3. Parse correlated mixer bytes into a visible track table.
4. Add approximate stereo preview playback only after parsed values are visible and testable.

Do not write back to project folders. Do not modify or normalize source samples.
