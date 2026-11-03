#!/usr/bin/env python3
"""Read-only inventory and focused binary comparison for existing DP-32SD evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
from pathlib import Path

CAPTURE_RE = re.compile(r"(?:SONG|TONG)_\d{4}", re.I)
WAV_RE = re.compile(rb"ZZ\d{4}_\d\.wav", re.I)
EDL_WINDOW = (0x41600, 0x50000)
KNOWN_OFFSETS = {
    "track1_mute_low": 0x268,
    "track2_mute_low": 0x269,
    "track3_mute_low": 0x26A,
    "track1_mute_mirror": 0xA2D,
    "track2_mute_mirror": 0xA2E,
    "track3_mute_mirror": 0xA2F,
    "track1_active_take_candidate": 0xB01A38,
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def wav_metadata(path: Path) -> dict:
    result = {"name": path.name, "size": path.stat().st_size, "sha256": sha256(path)}
    try:
        with path.open("rb") as stream:
            header = stream.read(12)
            if len(header) != 12 or header[:4] != b"RIFF" or header[8:] != b"WAVE":
                return result | {"riff": "unrecognized"}
            chunks = {}
            while True:
                chunk_header = stream.read(8)
                if len(chunk_header) != 8:
                    break
                name, length = struct.unpack("<4sI", chunk_header)
                data = stream.read(length)
                if len(data) != length:
                    break
                chunks[name] = data
                if length & 1:
                    stream.seek(1, 1)
            fmt = chunks.get(b"fmt ", b"")
            data = chunks.get(b"data", b"")
            if len(fmt) >= 16:
                codec, channels, rate, byte_rate, align, bits = struct.unpack_from("<HHIIHH", fmt)
                result.update({"codec": codec, "channels": channels, "sample_rate": rate,
                               "bits_per_sample": bits, "block_align": align,
                               "data_bytes": len(data),
                               "frames": len(data) // align if align else None,
                               "duration_seconds": len(data) / byte_rate if byte_rate else None})
    except OSError as error:
        result["error"] = str(error)
    return result


def read_bytes(path: Path) -> bytes | None:
    try:
        return path.read_bytes()
    except OSError:
        return None


def edl_details(path: Path) -> dict:
    data = read_bytes(path)
    if data is None:
        return {}
    matches = list(WAV_RE.finditer(data))
    entries = [{"index": i, "offset": f"0x{m.start():X}", "filename": m.group().decode("ascii")}
               for i, m in enumerate(matches)]
    begin, end = EDL_WINDOW
    candidates = []
    for offset in range(begin, min(end, len(data) - 3), 4):
        value = struct.unpack_from("<I", data, offset)[0]
        if 44_100 <= value <= 44_100 * 60 * 20:
            candidates.append({"offset": f"0x{offset:X}", "value": value,
                               "seconds_at_44100": value / 44_100})
    selector = struct.unpack_from("<B", data, KNOWN_OFFSETS["track1_active_take_candidate"])[0] \
        if len(data) > KNOWN_OFFSETS["track1_active_take_candidate"] else None
    return {"size": len(data), "sha256": sha256(path), "file_list_entries": entries,
            "track1_active_take_candidate": selector, "timeline_window_words": candidates}


def current_timeline_heuristic(folder: Path, entries: list[dict], wavs: list[dict]) -> dict:
    """Mirror ProjectPreviewBuilder's current anchor and sequential fallback rules."""
    edl_path = folder / "edltable.sys"
    data = read_bytes(edl_path)
    ordered = []
    wav_by_name = {w["name"].casefold(): w for w in wavs}
    if entries:
        for entry in entries:
            wav = wav_by_name.get(entry["filename"].casefold())
            if wav:
                ordered.append(wav)
    ordered_names = {w["name"].casefold() for w in ordered}
    ordered.extend(w for w in wavs if w["name"].casefold() not in ordered_names)
    if not ordered or data is None:
        return {"ordered_wavs": [w["name"] for w in ordered], "timeline_anchors": [],
                "inferred_starts": [], "start_source": "no-input"}

    begin, end = 0x41600, min(len(data), 0x42D00)
    raw = []
    for offset in range(begin, max(begin, end - 3), 4):
        value = struct.unpack_from("<I", data, offset)[0]
        if value < 44_100 or value > 44_100 * 60 * 20:
            continue
        remainder = value % 44_100
        if remainder <= 800 or 44_100 - remainder <= 800:
            raw.append(value)
    groups = []
    for value in sorted(raw):
        if groups and abs(value - groups[-1][-1]) <= 800:
            groups[-1].append(value)
        else:
            groups.append([value])
    anchors = [round(group[0] / 44_100) * 44_100 for group in groups]
    count = len(ordered)
    if count == 0:
        starts = []
    elif len(anchors) == count:
        starts = [max(x, 0) for x in anchors]
    elif count > 1 and len(anchors) == count - 1:
        starts = [0] + anchors
    else:
        starts = [0] * count
    source = "whole-second-anchor-pairing" if any(starts) else "zero-default"

    if all(x == 0 for x in starts) and count > 1:
        trim = 441
        primary_lengths = {}
        for wav in ordered:
            parsed = re.match(r"^(ZZ\d{4})_(\d)\.wav$", wav["name"], re.I)
            if parsed and int(parsed.group(2)) == 1 and wav.get("frames") is not None:
                primary_lengths[parsed.group(1).casefold()] = max(wav["frames"] - trim, 0)
        staircase, pointer = [], 0
        for index, wav in enumerate(ordered):
            parsed = re.match(r"^(ZZ\d{4})_(\d)\.wav$", wav["name"], re.I)
            if not parsed:
                staircase.append(pointer)
                continue
            stem, suffix = parsed.group(1).casefold(), int(parsed.group(2))
            if suffix == 1:
                staircase.append(pointer)
                pointer += primary_lengths.get(stem, 0)
            else:
                prior = next((i for i in range(index - 1, -1, -1)
                              if (m := re.match(r"^(ZZ\d{4})_1\.wav$", ordered[i]["name"], re.I))
                              and m.group(1).casefold() == stem), None)
                staircase.append(staircase[prior] if prior is not None else pointer)
        boundaries = {x for x in staircase if x > 0}
        found = False
        if boundaries:
            scan_end = min(len(data) - 3, 0x50000)
            for offset in range(0x41600, scan_end, 4):
                value = struct.unpack_from("<I", data, offset)[0]
                if any(abs(value - boundary) <= 5 for boundary in boundaries):
                    found = True
                    break
        if boundaries and found:
            starts = staircase
            source = "sequential-wav-length-fallback"

    return {"ordered_wavs": [w["name"] for w in ordered], "timeline_anchors": anchors,
            "anchor_raw_samples": raw, "inferred_starts": starts, "start_source": source}


def song_details(path: Path) -> dict:
    data = read_bytes(path)
    if data is None:
        return {}
    values = {name: (data[offset] if offset < len(data) else None)
              for name, offset in KNOWN_OFFSETS.items() if name != "track1_active_take_candidate"}
    # Mixer byte offsets: low-bank rows use 0x14 stride; mirror level/pan rows use the same.
    values["track1_level_low"] = data[0xC4] if len(data) > 0xC4 else None
    values["track1_pan_low"] = data[0xC6] if len(data) > 0xC6 else None
    values["track1_level_mirror"] = data[0x81C] if len(data) > 0x81C else None
    values["track1_pan_mirror"] = data[0x81E] if len(data) > 0x81E else None
    return {"size": len(data), "sha256": sha256(path), "fields": values}


def project_folders(root: Path) -> list[Path]:
    return sorted((p for p in root.iterdir() if p.is_dir() and CAPTURE_RE.fullmatch(p.name)),
                  key=lambda p: p.name)


def inventory(root: Path) -> dict:
    projects = []
    for folder in project_folders(root):
        files = sorted(p for p in folder.iterdir() if p.is_file())
        song = folder / "song.sys"
        edl = folder / "edltable.sys"
        wavs = [wav_metadata(p) for p in files if p.suffix.lower() == ".wav"]
        edl_result = edl_details(edl) if edl.exists() else None
        project = {"project": folder.name,
                   "files": [{"name": p.name, "size": p.stat().st_size, "sha256": sha256(p)}
                             for p in files],
                   "song_sys": song_details(song) if song.exists() else None,
                   "edltable_sys": edl_result,
                   "wavs": wavs}
        if edl_result:
            project["current_timeline_heuristic"] = current_timeline_heuristic(
                folder, edl_result["file_list_entries"], wavs)
        projects.append(project)
    return {"root": str(root), "project_count": len(projects), "projects": projects}


def compare_pair(root: Path, baseline: str, variant: str) -> dict:
    left, right = root / baseline, root / variant
    out = {"baseline": baseline, "variant": variant, "files": {}}
    for name in ("song.sys", "edltable.sys"):
        a, b = read_bytes(left / name), read_bytes(right / name)
        if a is None or b is None:
            out["files"][name] = {"available": False}
            continue
        length = min(len(a), len(b))
        changed = [i for i in range(length) if a[i] != b[i]]
        if len(a) != len(b):
            changed.extend(range(length, max(len(a), len(b))))
        ranges = []
        for offset in changed:
            if ranges and offset == ranges[-1][1]:
                ranges[-1][1] += 1
            else:
                ranges.append([offset, offset + 1])
        out["files"][name] = {
            "same_length": len(a) == len(b), "left_size": len(a), "right_size": len(b),
            "changed_byte_count": len(changed),
            "changed_ranges": [[f"0x{x:X}", f"0x{y - 1:X}"] for x, y in ranges],
            "changed_bytes": [{"offset": f"0x{i:X}", "before": f"{a[i]:02X}" if i < len(a) else None,
                               "after": f"{b[i]:02X}" if i < len(b) else None} for i in changed[:1000]],
            "sha256_before": sha256(left / name), "sha256_after": sha256(right / name)}
    wav_a = sorted((p.name, sha256(p)) for p in left.glob("*.wav"))
    wav_b = sorted((p.name, sha256(p)) for p in right.glob("*.wav"))
    out["wav_inventory_equal"] = wav_a == wav_b
    out["wav_inventory_before"] = [{"name": n, "sha256": h} for n, h in wav_a]
    out["wav_inventory_after"] = [{"name": n, "sha256": h} for n, h in wav_b]
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path, help="directory containing SONG_#### folders")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--pairs", nargs="*", default=[], help="baseline:variant pairs")
    args = parser.parse_args()
    result = {"inventory": inventory(args.root), "comparisons": []}
    for pair in args.pairs:
        baseline, variant = pair.split(":", 1)
        result["comparisons"].append(compare_pair(args.root, baseline, variant))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"wrote {args.output}: {result['inventory']['project_count']} projects, {len(result['comparisons'])} comparisons")


if __name__ == "__main__":
    main()
