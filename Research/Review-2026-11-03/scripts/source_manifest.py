#!/usr/bin/env python3
"""Hash read-only evidence trees and explicit files into a reproducibility manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("paths", nargs="+", type=Path)
    args = parser.parse_args()
    files: set[Path] = set()
    for path in args.paths:
        if path.is_file():
            files.add(path)
        elif path.is_dir():
            files.update(child for child in path.rglob("*") if child.is_file())
    entries = [{"path": str(path), "size": path.stat().st_size, "sha256": digest(path)}
               for path in sorted(files)]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({"algorithm": "SHA-256", "file_count": len(entries),
                                       "files": entries}, indent=2) + "\n")
    print(f"wrote {args.output}: {len(entries)} files")


if __name__ == "__main__":
    main()
