# DP-32SD Playback and Timeline Review

This isolated folder contains read-only analysis scripts, generated reports, and test build artifacts for the November 3, 2026 review. Original song captures, firmware, and research samples remain in their source folders.

## Reproduce

From the PortastudioPreview repo root:

```sh
Research/Review-2026-11-03/.venv/bin/python Research/Review-2026-11-03/scripts/audit_captures.py Docs/TEST-SONGS \
  --output Research/Review-2026-11-03/output/capture_audit.json \
  --pairs SONG_0059:SONG_0092 SONG_0059:SONG_0093 SONG_0060:SONG_0075 \
  SONG_0083:SONG_0084 SONG_0084:SONG_0085 SONG_0086:SONG_0090 \
  SONG_0086:SONG_0091 SONG_0086:SONG_0094 SONG_0093:SONG_0094 \
  SONG_0059:SONG_0095 SONG_0094:SONG_0095
```

Re-scan firmware with:

```sh
Research/Review-2026-11-03/.venv/bin/python Research/Review-2026-11-03/scripts/scan_firmware.py \
  "/Volumes/Secondary SSD/Projects/SwiftUI/Porta Studio Preview/Porta Studio Research Firmware/DP-32SD030.111" \
  --zip "/Volumes/Secondary SSD/Projects/SwiftUI/Porta Studio Preview/Porta Studio Research Firmware/DP-32SD_v111.zip" \
  --output Research/Review-2026-11-03/output/firmware_scan.json
```

The scripts use the Python standard library. NumPy, SciPy, and SoundFile were not installed because no AudioDepot track exports or independent reference renders were found for audio matching. `ffprobe` 6.0 was used to independently check capture WAV metadata. Binwalk and Ghidra were not available; the firmware scan therefore uses a local signature/string/entropy script and does not attempt disassembly.

The focused Xcode test result is in `output/test_summary.json`; the `.xcresult` and isolated DerivedData are retained under `.derivedData/`. Input hashes before and after the review are in `output/source_hashes_before.json` and `output/source_hashes_after.json`.

See [findings report](output/DP32SD_Playback_Timeline_Findings.md).
