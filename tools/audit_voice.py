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
# This was a ratchet while the rewording was being undone: every line in it was
# one the port had invented where the original had words, and the build failed
# on anything that was *not* in it, so the list could only come down.
#
# It is empty. It stays empty: a line the original has words for is carried, and
# a line it has none for is explained in voice_exceptions.json with what the
# original does instead. Do not put anything back in here to make a build pass.
BACKLOG_FILE = ROOT / "tools" / "voice_backlog.json"


# Third-party code that happens to live in src/. It is not the game and its
# strings are not the game's voice: matching against an XML parser's error
# messages would let any sentence with the right words in it pass.
VENDORED = ("cmarkup", "sdl", "pdcurses", "sandbox")


def original_strings():
    """Every word the original shows, from its code and from its content.

    Its code is src/; its content is art/*.xml, which is where the names and
    descriptions of every weapon, item, piece of clothing and loot document
    live. Both are the original's own words, so a port line matching either
    is carried, not invented.
    """
    out = []
    for path in sorted((ROOT / "src").rglob("*")):
        if path.suffix not in (".cpp", ".h"):
            continue
        if any(part in VENDORED for part in path.parts):
            continue
        # latin-1 rather than UTF-8: the original is a code-page terminal and
        # its dashes and box characters are single high bytes, which reading
        # as UTF-8 would drop on the floor along with the words around them.
        out.extend(_c_strings(path.read_text(encoding="latin-1")))
    for path in sorted((ROOT / "art").rglob("*.xml")):
        out.extend(_xml_text(path.read_text(encoding="latin-1")))
    return out


def _xml_text(text):
    """The text between the tags: names, descriptions, everything readable."""
    return [t for t in re.findall(r">([^<>]+)<", text) if t.strip()]


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
        elif ch == "'":
            # A character literal. Skipped whole, because one of them is '"'
            # and letting it open a string desynchronises every literal in
            # the rest of the file.
            j = i + 1
            if text[j:j + 1] == "\\":
                j += 1
            j += 1
            i = j + 1 if text[j:j + 1] == "'" else i + 1
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
    # Runs of whitespace collapse, but the ends are left alone: the original
    # puts the space *between* two halves of a sentence at the end of the
    # first strcat(), so stripping here would run the halves together and lose
    # every story that is assembled that way.
    return re.sub(r"\s+", " ", said)


def _pieces(said):
    """The literal words, with the format holes taken out.

    A hole often has punctuation glued to it — "$%d", "(%s)" — which belongs
    to the number, not to the words, so it comes off the ends of a fragment
    before the fragment is looked for. Only brackets and the currency sign;
    letters and sentence punctuation stay, because those are the words.
    """
    split = re.split(r"%[-\d.]*[sdxfv%]|\{[^}]*\}", _plain(said))
    pieces = (re.sub(r"\s+", " ", p).strip() for p in split)
    return [piece for piece in pieces
            if len(piece) >= 4 and re.search(r"[A-Za-z]{3}", piece)]


# The shortest half a split sentence may have. Below this, matching two
# fragments proves nothing: almost any sentence contains "the" somewhere.
SPLIT_FLOOR = 10


def _found(piece, haystack):
    """Whether the original says this, in one print or in two.

    The original builds a sentence out of consecutive addstr() calls as often
    as it writes one whole, so a line it prints in two halves is still its
    line. Both halves have to be long enough that finding them means
    something.

    [param haystack] is a pair: the strings one per line, and the same strings
    run together in source order. The second is what a news story actually
    reads like — the original assembles one out of a run of strcat() calls, so
    a sentence of it spans several literals — and looking there is the only
    way a story carried across whole can be recognised as carried.
    """
    lines, running = haystack
    # Case is presentation, not voice: the original shouts its column headers
    # and whispers the same words in a sentence two screens later, and a
    # button that takes a line out of a "(Press A to ...)" prompt starts it
    # with a capital. The words are what is being checked.
    piece = piece.lower()
    if piece in lines or piece in running:
        return True
    # A hole often has punctuation glued to it — "$%d", "(%s)" — which belongs
    # to the number, not to the words, so the fragment is tried again without
    # it. Only brackets, quotes and the currency sign come off, and only after
    # the fragment has been looked for whole: the original writes "[tar]".
    bare = piece.strip(" $#([{)]}\"'")
    if bare != piece and (bare in lines or bare in running):
        return True
    haystack = lines
    for cut in range(SPLIT_FLOOR, len(piece) - SPLIT_FLOOR):
        if piece[cut] != " ":
            continue
        if piece[:cut] in haystack and piece[cut + 1:] in haystack:
            return True
    return False


def main():
    said = [_plain(s) for s in original_strings()]
    # The run-together copy has its seams collapsed as well: two literals that
    # each carry the space between them join into two spaces, which the words
    # they spell do not have.
    haystack = ("\n".join(said).lower(),
                re.sub(r"\s+", " ", "".join(said)).lower())
    ours = dict(OURS)
    if EXCEPTIONS_FILE.exists():
        ours.update(json.loads(EXCEPTIONS_FILE.read_text()))

    backlog = set(json.loads(BACKLOG_FILE.read_text())) \
        if BACKLOG_FILE.exists() else set()

    carried, explained, waiting, unaccounted = 0, 0, [], []
    for where, said in port_strings():
        pieces = _pieces(said)
        # A string with no words of its own — all format holes, or a fragment
        # too short to mean anything — has no voice to get wrong, so there is
        # nothing here to check and it passes.
        if all(_found(piece, haystack) for piece in pieces):
            carried += 1
        elif said in ours:
            explained += 1
        elif said in backlog:
            waiting.append(said)
        else:
            unaccounted.append((where, said))

    # An em dash in this port stands for one thing: the original's own "──",
    # which it writes as two CP437 0xC4 bytes and which a modern font draws as
    # a dash. It writes that twice in ten thousand strings — the title screen's
    # quote attributions, and one news story — so an em dash in a line the port
    # wrote itself is not a punctuation choice, it is a tell. The port had six
    # of them, all in separators it invented; the original separates with " - "
    # in every menu line it has, and with ": " between a thing and what it is.
    invented = []
    for path in sorted((ROOT / "game" / "ui").rglob("*.gd")):
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if "\u2014" not in line or line.lstrip().startswith("#"):
                continue
            for literal in re.findall(r'"((?:[^"\\]|\\.)*)"', line):
                if "\u2014" not in literal:
                    continue
                pieces = _pieces(literal)
                # A line whose only content is the dash — a separator such as
                # "%s \u2014 %s" — has nothing it could have carried, so the
                # dash is the port's and nothing else.
                if pieces and all(_found(p, haystack) for p in pieces):
                    continue
                where = str(path.relative_to(ROOT / "game" / "ui"))
                invented.append(("%s:%d" % (where, number), literal))
    if invented:
        print("\nThese lines are the port's own words and have an em dash in"
              " them:\n")
        for where, line in invented:
            print(f"  {where.replace('game/ui/', '')}: {line[:70]!r}")
        print("\nThe original writes \u2014 only where it drew \u2500\u2500."
              " Separate with \" - \" as its menus do,\nor with \": \""
              " between a thing and what it is.")
        return 1

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
