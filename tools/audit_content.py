#!/usr/bin/env python3
"""Checks the port's content against the original's data files.

Everything the original loads at startup — its weapons, armour, clips, loot,
creature types, vehicles, augmentations and masks — was extracted into Godot
Resources under game/data/. A missing entry is a silent parity gap: nothing
crashes, the item simply never exists, and no probe can miss what it never
draws for.

So this compares the two, by idname, in both directions. It skips what the
original comments out — CLIP_MOLOTOV is commented out in clips.xml with a note
saying it should not be necessary, and the port is right not to have it — and
it skips the documentation block at the top of each file, which uses
idname="(string)" to describe the attribute.

    python3 tools/audit_content.py           # summary, and anything missing
    python3 tools/audit_content.py --list    # every table and its count
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "art"
DATA = ROOT / "game" / "data"

# The original's file, and the directory the port keeps its Resources in.
TABLES = {
    "weapons.xml": "weapons",
    "armors.xml": "armor",
    "clips.xml": "clips",
    "loot.xml": "loot",
    "creatures.xml": "creatures",
    "vehicles.xml": "vehicles",
    "augmentations.xml": "augments",
    "masks.xml": "masks",
}

# The idname the documentation block at the top of each file uses.
DOCUMENTATION = "(string)"

COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)
IDNAME = re.compile(r'idname="([^"]*)"')
RESOURCE_IDNAME = re.compile(r'^idname = &"([^"]*)"', re.MULTILINE)


def original(filename: str) -> set[str]:
    """Every idname the original actually loads from [filename]."""
    text = (ART / filename).read_bytes().decode("cp437")
    text = COMMENT.sub("", text)
    return {name for name in IDNAME.findall(text) if name != DOCUMENTATION}


def ported(directory: str) -> set[str]:
    """Every idname the port has a Resource for."""
    found = set()
    for path in (DATA / directory).glob("*.tres"):
        match = RESOURCE_IDNAME.search(path.read_text())
        if match:
            found.add(match.group(1))
    return found


def site_maps() -> tuple[set[str], set[str]]:
    """The prebuilt floor plans, which are CSV rather than XML."""
    theirs = {path.name.split("_")[1].lower()
              for path in ART.glob("mapCSV_*_Tiles.csv")}
    ours = {path.stem for path in (DATA / "sitemaps").glob("*.tres")}
    return theirs, ours


def main() -> int:
    missing, extra = {}, {}
    for filename, directory in sorted(TABLES.items()):
        theirs, ours = original(filename), ported(directory)
        if "--list" in sys.argv:
            print("%-20s %-12s original %-4d port %d"
                  % (filename, directory, len(theirs), len(ours)))
        if theirs - ours:
            missing[filename] = sorted(theirs - ours)
        if ours - theirs:
            extra[filename] = sorted(ours - theirs)

    theirs, ours = site_maps()
    if "--list" in sys.argv:
        print("%-20s %-12s original %-4d port %d"
              % ("mapCSV_*.csv", "sitemaps", len(theirs), len(ours)))
    if theirs - ours:
        missing["the site maps"] = sorted(theirs - ours)
    if ours - theirs:
        extra["the site maps"] = sorted(ours - theirs)

    total = sum(len(original(f)) for f in TABLES) + len(theirs)
    print("%d entries in the original's data files." % total)
    print("  %d tables compared." % (len(TABLES) + 1))
    print("  %d have something the port is missing." % len(missing))
    print("  %d have something the port invented." % len(extra))
    for filename, names in sorted(missing.items()):
        print("    %s is missing: %s" % (filename, ", ".join(names)))
    for filename, names in sorted(extra.items()):
        print("    %s does not have: %s" % (filename, ", ".join(names)))
    return 1 if missing or extra else 0


if __name__ == "__main__":
    raise SystemExit(main())
