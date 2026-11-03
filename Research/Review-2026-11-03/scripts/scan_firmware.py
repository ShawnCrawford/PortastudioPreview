#!/usr/bin/env python3
"""Static signature, string, and entropy scan for an extracted firmware update."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
import zipfile
from collections import Counter
from pathlib import Path

SIGNATURES = {
    "ELF": b"\x7fELF", "PE": b"MZ", "Mach-O 32 BE": b"\xfe\xed\xfa\xce",
    "Mach-O 32 LE": b"\xce\xfa\xed\xfe", "Mach-O 64 BE": b"\xfe\xed\xfa\xcf",
    "Mach-O 64 LE": b"\xcf\xfa\xed\xfe", "ARM Thumb branch": b"\x00\xbf",
    "ZIP": b"PK\x03\x04", "gzip": b"\x1f\x8b", "LZMA": b"\x5d\x00\x00",
}


def entropy(data: bytes) -> float:
    if not data:
        return 0.0
    counts = Counter(data)
    size = len(data)
    return -sum((n / size) * math.log2(n / size) for n in counts.values())


def find_all(data: bytes, needle: bytes) -> list[int]:
    offsets, start = [], 0
    while True:
        offset = data.find(needle, start)
        if offset < 0:
            return offsets
        offsets.append(offset)
        start = offset + 1


def scan(path: Path) -> dict:
    data = path.read_bytes()
    signatures = {name: [f"0x{x:X}" for x in find_all(data, magic)]
                  for name, magic in SIGNATURES.items()}
    strings = []
    for match in re.finditer(rb"[ -~]{6,}", data):
        value = match.group().decode("ascii", "replace")
        if re.search(r"tascam|dp[-_ ]?32|version|update|firmware|boot|flash|kernel|rom|wav|song|edl|arm|sh|mips|dsp|copyright", value, re.I):
            strings.append({"offset": f"0x{match.start():X}", "text": value[:240]})
    block = 64 * 1024
    windows = [{"offset": f"0x{offset:X}", "length": len(data[offset:offset + block]),
                "entropy_bits_per_byte": round(entropy(data[offset:offset + block]), 4)}
               for offset in range(0, len(data), block)]
    return {"path": str(path), "size": len(data), "sha256": hashlib.sha256(data).hexdigest(),
            "first_64_bytes_hex": data[:64].hex(" "),
            "signature_occurrences": signatures, "entropy_64k_windows": windows,
            "printable_strings_of_interest": strings}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("firmware", type=Path)
    parser.add_argument("--zip", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = scan(args.firmware)
    if args.zip:
        with zipfile.ZipFile(args.zip) as archive:
            report["archive"] = {"path": str(args.zip), "sha256": hashlib.sha256(args.zip.read_bytes()).hexdigest(),
                                 "members": [{"name": info.filename, "size": info.file_size,
                                              "compressed_size": info.compress_size,
                                              "crc32": f"{info.CRC:08X}"}
                                             for info in archive.infolist()]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(f"wrote {args.output}: {report['size']} bytes, sha256 {report['sha256']}")


if __name__ == "__main__":
    main()
