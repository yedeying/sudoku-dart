#!/usr/bin/env python3
"""Build the bundled `AppSans` font subset.

Flutter Web (CanvasKit) has no access to system fonts; until it finishes
downloading Noto CJK from the font CDN every Chinese glyph renders as tofu.
Bundling a subset that covers exactly the characters used in `lib/` removes
that startup flash while keeping the asset small.

Run after adding new Chinese copy:

    python3 tools/build_font_subset.py
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "fonts"

SOURCE = Path("/System/Library/Fonts/Hiragino Sans GB.ttc")
FACES = {
    # face index inside the .ttc -> output file
    0: "AppSans-Regular.ttf",
    2: "AppSans-Bold.ttf",
}

# Glyphs that never appear in source but are produced at runtime or by Material.
EXTRA = (
    "".join(chr(c) for c in range(0x20, 0x7F))
    + "，。、；：？！“”‘’（）《》—…·×÷→←↑↓√°％"
    + "0123456789"
)


def collect_chars() -> set[str]:
    chars: set[str] = set(EXTRA)
    for dart in (ROOT / "lib").rglob("*.dart"):
        chars.update(dart.read_text(encoding="utf-8"))
    return {c for c in chars if c.isprintable() and c not in "\r\n\t"}


def main() -> int:
    if not SOURCE.exists():
        print(f"source font missing: {SOURCE}", file=sys.stderr)
        return 1

    chars = collect_chars()
    unicodes = ",".join(f"U+{ord(c):04X}" for c in sorted(chars))
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    for index, name in FACES.items():
        target = OUT_DIR / name
        subprocess.run(
            [
                sys.executable,
                "-m",
                "fontTools.subset",
                str(SOURCE),
                f"--font-number={index}",
                f"--unicodes={unicodes}",
                "--layout-features=*",
                "--no-hinting",
                "--desubroutinize",
                f"--output-file={target}",
            ],
            check=True,
        )
        print(f"{name}: {target.stat().st_size // 1024} KiB, {len(chars)} glyphs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
