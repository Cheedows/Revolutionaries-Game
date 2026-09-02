#!/usr/bin/env python3
"""Does the original have words for this?

The first move when writing any player-facing line is to find out what Liberal
Crime Squad already said, because tools/audit_voice.py will insist on it. This
searches the same haystack that audit uses — every string literal in src/ plus
every text node in art/*.xml — and shows where each hit lives, so you can go
and read the surrounding lines for the rest of the passage.

    python3 .claude/skills/lcs-voice/scripts/find_original.py "flag burning"
    python3 .claude/skills/lcs-voice/scripts/find_original.py --check "The squad slips out."

Plain search reports every literal containing the phrase, case-insensitively.
--check asks the narrower question the audit asks: would this exact string pass
audit_voice.py as carried? Use it on a draft line before you paste it into
game/ui/.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
VENDORED = ("cmarkup", "sdl", "pdcurses", "sandbox")


def _literals():
    """Every string the original prints, with the file and line it lives on."""
    for path in sorted((ROOT / "src").rglob("*")):
        if path.suffix not in (".cpp", ".h"):
            continue
        if any(part in VENDORED for part in path.parts):
            continue
        # latin-1: the original is a code-page-437 terminal and its dashes and
        # box characters are single high bytes.
        text = path.read_text(encoding="latin-1")
        for number, line in enumerate(text.splitlines(), 1):
            if line.lstrip().startswith("//"):
                continue
            for said in re.findall(r'"((?:[^"\\]|\\.)*)"', line):
                if said.strip():
                    yield path, number, said
    for path in sorted((ROOT / "art").rglob("*.xml")):
        text = path.read_text(encoding="latin-1")
        for number, line in enumerate(text.splitlines(), 1):
            for said in re.findall(r">([^<>]+)<", line):
                if said.strip():
                    yield path, number, said.strip()


def search(phrase):
    wanted = phrase.lower()
    hits = [(p, n, s) for p, n, s in _literals() if wanted in s.lower()]
    if not hits:
        print(f"The original never says {phrase!r}.\n")
        print("Try a shorter phrase, or a synonym it might have used. If it "
              "really has no words for this,\nwrite it in the voice and add an "
              "entry to tools/voice_exceptions.json saying what it does\ninstead.")
        return 1
    print(f"{len(hits)} place(s) say {phrase!r}:\n")
    for path, number, said in hits[:60]:
        where = f"{path.relative_to(ROOT)}:{number}"
        print(f"  {where:<44} {said}")
    if len(hits) > 60:
        print(f"  ... and {len(hits) - 60} more")
    print("\nRead around the hits — the original builds a passage out of "
          "consecutive addstr() calls,\nso the rest of the sentence is usually "
          "on the next few lines.")
    return 0


def check(draft):
    """The audit's own question, asked about one string."""
    sys.path.insert(0, str(ROOT / "tools"))
    import audit_voice as audit

    said = [audit._plain(s) for s in audit.original_strings()]
    haystack = ("\n".join(said).lower(),
                re.sub(r"\s+", " ", "".join(said)).lower())
    pieces = audit._pieces(draft)
    if not pieces:
        print(f"{draft!r} has no words of its own to check — it would pass.")
        return 0
    missing = [p for p in pieces if not audit._found(p, haystack)]
    for piece in pieces:
        mark = "carried" if piece not in missing else "NOT FOUND"
        print(f"  [{mark:>9}] {piece!r}")
    if missing:
        print(f"\n{draft!r} would fail audit_voice.py.")
        print("Either carry the original's wording, or add an entry to "
              "tools/voice_exceptions.json\nwith a reason saying what the "
              "original does instead.")
        return 1
    print(f"\n{draft!r} would pass audit_voice.py.")
    return 0


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2
    if args[0] == "--check":
        if len(args) < 2:
            print("--check needs a string to check.")
            return 2
        return check(" ".join(args[1:]))
    return search(" ".join(args))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BrokenPipeError:
        # Piping into head is the normal way to read a long result.
        sys.exit(0)
