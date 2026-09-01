#!/usr/bin/env python3
"""Every word a player reads is the original's, or is explained here.

The other five audits ask whether the port still *does* what the original
does. This one asks whether it still *sounds* like it, which nothing else
could catch: a menu option renamed from "We Didn't Start The Fire" to "a
strong Conservative Crime Squad" passes every test in the tree and quietly
loses the game, and once a few have gone the rest read as normal.

The line the port draws is that presentation is ours. That is right where the
terminal printed nothing — an event it never had, a panel that did not exist —
and wrong where it printed words. Where the original printed words, those
words are content, and rewording them is a departure like any other.

So: every string in game/ui/ that a player reads is either carried from the
original, or listed in OURS below with the reason it is not. Anything else
fails the build.

"Carried" is checked by looking for the port's words in the original's own
source. A string with a format hole in it is split at the hole and each piece
looked for, because the original builds its sentences by printing them in
pieces too.
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Words of the port's own, and why the original has none to carry.
#
# A reason has to say what the original does instead. "It reads better" is not
# a reason; the original's phrasing is the game's voice, and tidier is worse.
OURS = {}

EXCEPTIONS_FILE = ROOT / "tools" / "voice_exceptions.json"

# What has not been carried across yet.
#
# The rewording went in over a long time and there is a lot of it, so this is a
# ratchet rather than a wall: every line still in the backlog is one the port
# invented and the original had words for, and the build fails on anything that
# is *not* in it. Nothing new can be added; the list only comes down.
#
# Emptying it is the job. Do not add to it to make a build pass.
BACKLOG_FILE = ROOT / "tools" / "voice_backlog.json"


def original_strings():
    """Every string literal in src/, with adjacent literals joined as C joins."""
    out = []
    for path in sorted((ROOT / "src").rglob("*")):
        if path.suffix not in (".cpp", ".h"):
            continue
        # latin-1 rather than UTF-8: the original is a code-page terminal and
        # its dashes and box characters are single high bytes, which reading
        # as UTF-8 would drop on the floor along with the words around them.
        out.extend(_c_strings(path.read_text(encoding="latin-1")))
    return out


def _c_strings(text):
    out, parts, i, n = [], [], 0, len(text)
    while i < n:
        ch = text[i]
        if ch == "/" and text[i + 1:i + 2] == "/":
            i = text.find("\n", i)
            i = n if i < 0 else i
        elif ch == "/" and text[i + 1:i + 2] == "*":
            j = text.find("*/", i)
            i = n if j < 0 else j + 2
        elif ch == '"':
            j, buf = i + 1, []
            while j < n and text[j] != '"':
                if text[j] == "\\":
                    buf.append(text[j:j + 2])
                    j += 2
                else:
                    buf.append(text[j])
                    j += 1
            parts.append("".join(buf))
            i = j + 1
            k = i
            while k < n and text[k] in " \t\r\n":
                k += 1
            if k < n and text[k] == '"':
                i = k
                continue
            out.append("".join(parts))
            parts = []
        else:
            i += 1
    return out


def port_strings():
    """Every string in game/ui/ that a player reads, by file."""
    found = []
    for path in sorted((ROOT / "game" / "ui").rglob("*.gd")):
        text = path.read_text()
        text = re.sub(r"^\s*##.*$", "", text, flags=re.M)
        text = re.sub(r'(?<!["\w])#.*$', "", text, flags=re.M)
        text = text.replace("\\\n", "")
        for match in re.finditer(r'(&?)"((?:[^"\\]|\\.)*)"', text):
            if match.group(1) == "&":
                continue  # &"idname" is data, not words
            said = match.group(2)
            if _read_by_a_player(said):
                found.append((str(path.relative_to(ROOT)), said))
    return found


def _read_by_a_player(said):
    said = said.strip()
    if len(said) < 4 or said.startswith(("res://", "user://")):
        return False
    if re.fullmatch(r"[a-z0-9_]+", said):
        return False  # an idname
    if re.fullmatch(r"[A-Z][A-Za-z0-9]*", said):
        return False  # a class or theme-item name
    if not re.search(r"[A-Za-z]{3}", said):
        return False
    return True


def _plain(said):
    """One string with its escapes undone and its spacing evened out.

    The original escapes quotes inside its own dialogue and sometimes escapes
    apostrophes it did not need to, so both sides are flattened before they
    are compared; the words are what is being checked, not the C.
    """
    said = said.replace('\\"', '"').replace("\\'", "'").replace("\\n", " ")
    # The original is a code-page-437 terminal and draws a dash with two box
    # characters, \xc4\xc4, which read as mojibake in a UTF-8 world. The port
    # sets an em-dash instead. Same dash, so both are flattened to one before
    # the words are compared; everything else in the sentence still has to
    # match exactly.
    said = re.sub("[\u00c4\ufffd]{1,2}", "\u2014", said)
    said = said.replace("\u2014", " \u2014 ")
    return re.sub(r"\s+", " ", said).strip()


def _pieces(said):
    """The literal words, with the format holes taken out."""
    split = re.split(r"%[-\d.]*[sdxfv%]|\{[^}]*\}", _plain(said))
    return [piece for piece in (re.sub(r"\s+", " ", p).strip() for p in split)
            if len(piece) >= 4 and re.search(r"[A-Za-z]{3}", piece)]


def main():
    haystack = "\n".join(_plain(s) for s in original_strings())
    ours = dict(OURS)
    if EXCEPTIONS_FILE.exists():
        ours.update(json.loads(EXCEPTIONS_FILE.read_text()))

    backlog = set(json.loads(BACKLOG_FILE.read_text())) \
        if BACKLOG_FILE.exists() else set()

    carried, explained, waiting, unaccounted = 0, 0, [], []
    for where, said in port_strings():
        pieces = _pieces(said)
        if pieces and all(piece in haystack for piece in pieces):
            carried += 1
        elif said in ours:
            explained += 1
        elif said in backlog:
            waiting.append(said)
        else:
            unaccounted.append((where, said))

    total = carried + explained + len(waiting) + len(unaccounted)
    print(f"{total} strings in game/ui/ that a player reads.")
    print(f"  {carried} are the original's own words.")
    print(f"  {explained} are the port's, explained in this tool.")
    print(f"  {len(waiting)} have not been carried across yet.")
    print(f"  {len(unaccounted)} are unaccounted for.")

    stale = sorted(backlog - set(waiting))
    if stale:
        print(f"\n{len(stale)} lines in the backlog are no longer in the tree."
              " Take them out of tools/voice_backlog.json:\n")
        for said in stale[:20]:
            print(f"  {said[:70]!r}")
        return 1
    if unaccounted:
        print("\nThe port is using its own words where nothing says it may:\n")
        for where, said in unaccounted[:60]:
            print(f"  {where.replace('game/ui/', '')}: {said[:70]!r}")
        if len(unaccounted) > 60:
            print(f"  ... and {len(unaccounted) - 60} more")
        print("\nCarry the original's wording, or say in tools/"
              "voice_exceptions.json what the original does instead. The"
              " backlog is not for new lines.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
