#!/usr/bin/env python3
"""Finds behaviour in the port that nothing can reach.

This is the failure mode the conversion kept having: a system is ported,
diffed against the original, covered by a probe — and then called by nothing,
so no player can ever get to it. Nothing fails. The probe passes, because the
probe calls it directly.

So this asks a blunt question of every public entry point in `game/core`: does
anything call it at all — qualified from another file, or by name inside its
own? A function nothing calls anywhere is behaviour the game cannot reach.

It deliberately does not care whether a function is more public than it needs
to be. That is style, and style does not lose a mechanic.

What is genuinely meant to be internal, or is deliberately kept for a caller
that does not exist yet, is listed in ALLOWED below with a reason.

    python3 tools/audit_reach.py           # summary, and anything unreachable
    python3 tools/audit_reach.py --list    # every entry point and its verdict
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"

CLASS_NAME = re.compile(r"^class_name (\w+)", re.MULTILINE)
PUBLIC_STATIC = re.compile(r"^static func ([a-z]\w*)", re.MULTILINE)

# Entry points nothing outside their file calls, and why that is right.
ALLOWED = {
    "Renting.monthly_rent": "a reading of the rent field that every caller "
                            "already has in front of it; kept because the "
                            "original has the same helper",
}


def sources() -> list[Path]:
    return sorted(p for p in (GAME / "core").rglob("*.gd"))


def everything() -> dict[Path, str]:
    found = {}
    for directory in ["core", "app", "ui"]:
        for path in (GAME / directory).rglob("*.gd"):
            found[path] = path.read_text()
    return found


def main() -> int:
    files = everything()
    reachable, internal = [], []
    for path in sources():
        text = files[path]
        found = CLASS_NAME.search(text)
        if found is None:
            continue
        owner = found.group(1)
        for name in PUBLIC_STATIC.findall(text):
            call = re.compile(r"\b%s\.%s\(" % (owner, name))
            outside = any(call.search(other) for where, other in files.items()
                          if where != path)
            # A bare call by name, which is how a file calls its own.
            here = len(re.findall(r"(?<![\w.])%s\(" % name, text)) > 1
            if outside or here:
                reachable.append("%s.%s" % (owner, name))
            else:
                internal.append("%s.%s" % (owner, name))

    unexplained = [name for name in internal if name not in ALLOWED]
    if "--list" in sys.argv:
        for name in sorted(reachable):
            print("%-52s reachable" % name)
        for name in sorted(internal):
            print("%-52s %s" % (name, ALLOWED.get(name, "UNREACHABLE")))

    print("%d public entry points in core." % (len(reachable) + len(internal)))
    print("  %d are called by something." % len(reachable))
    print("  %d are explained in this tool." % (len(internal) - len(unexplained)))
    print("  %d can be reached by nothing." % len(unexplained))
    for name in sorted(unexplained):
        print("    %s" % name)
    return 1 if unexplained else 0


if __name__ == "__main__":
    raise SystemExit(main())
