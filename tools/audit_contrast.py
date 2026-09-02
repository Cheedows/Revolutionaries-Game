#!/usr/bin/env python3
"""Can the colours actually be read, and can they be told apart?

A palette is not a mood board. Two things about it are measurable, and this
measures both for every scheme in game/ui/theme/palette.gd.

**Contrast.** WCAG 2.1 gives a formula for the ratio between two colours and
thresholds for what is readable: 4.5:1 for body text, 3:1 for large text and
for the edges of controls. Dark themes fail this quietly, because a colour that
looked fine against white is often too dark against near-black.

**Telling two things apart.** This game puts more meaning on one colour pair
than on anything else: green means the Squad and red means the opposition. That
is the exact pair about one man in twelve cannot distinguish. So each scheme's
faction colours are run through a simulation of the three kinds of colour
blindness and checked for whether they are still two colours afterwards.

Neither is a matter of taste, and both are cheap to check, so they are checked.

    python3 tools/audit_contrast.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PALETTE = ROOT / "game" / "ui" / "theme" / "palette.gd"

# (foreground, background, ratio, what it is) — every pair the interface
# actually draws, at the threshold WCAG sets for that kind of text.
PAIRS = [
    ("text", "background", 4.5, "body text on the page"),
    ("text", "surface", 4.5, "body text on a panel"),
    ("text", "raised", 4.5, "the label on a button"),
    ("dim", "surface", 4.5, "the line under an option"),
    ("dim", "raised", 4.5, "a price beside a button"),
    ("faint", "surface", 3.0, "text that cannot be used"),
    ("accent", "surface", 4.5, "a panel heading"),
    ("accent", "background", 4.5, "a screen title"),
    ("liberal", "surface", 4.5, "one of the Squad"),
    ("conservative", "surface", 4.5, "one of the opposition"),
    ("moderate", "surface", 4.5, "somebody in between"),
    ("income", "raised", 4.5, "money coming in"),
    ("expense", "raised", 4.5, "money going out"),
    ("border", "surface", 1.4, "the line around a panel"),
    ("accent", "raised", 3.0, "the focus ring"),
]

# Two colours can be told apart by hue or by brightness, and the two are worth
# measuring separately: a pair that survives only on brightness is legible in a
# row of names and useless on a map or a chart.
#
# HUE_APART is the distance between the two colours after the difference in
# brightness has been divided out, so it is the part of the difference that
# colour blindness actually takes away. BRIGHT_APART is the ordinary contrast
# ratio between them, which no kind of colour blindness affects.
#
# A pair needs one or the other. Below both, the two sides of this game are one
# colour and nothing on screen says which is which.
HUE_APART = 40.0
BRIGHT_APART = 1.5


def _rgb(hexed):
    return tuple(int(hexed[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def _linear(channel):
    return channel / 12.92 if channel <= 0.04045 \
        else ((channel + 0.055) / 1.055) ** 2.4


def luminance(hexed):
    r, g, b = (_linear(c) for c in _rgb(hexed))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(one, two):
    a, b = luminance(one), luminance(two)
    lighter, darker = max(a, b), min(a, b)
    return (lighter + 0.05) / (darker + 0.05)


# Brettel/Viénot-style simulation, in the simplified matrix form that is
# standard for design checking. Good enough to answer "are these still two
# colours?", which is the only question being asked.
BLINDNESS = {
    "protanopia": ((0.567, 0.433, 0.0), (0.558, 0.442, 0.0), (0.0, 0.242, 0.758)),
    "deuteranopia": ((0.625, 0.375, 0.0), (0.7, 0.3, 0.0), (0.0, 0.3, 0.7)),
    "tritanopia": ((0.95, 0.05, 0.0), (0.0, 0.433, 0.567), (0.0, 0.475, 0.525)),
}


def _seen_as(hexed, kind):
    r, g, b = (_linear(c) for c in _rgb(hexed))
    rows = BLINDNESS[kind]
    return tuple(sum(row[i] * c for i, c in enumerate((r, g, b)))
                 for row in rows)


def hue_apart(one, two, kind):
    """How different two colours stay once brightness is taken out of it."""
    def flatten(seen):
        lit = 0.2126 * seen[0] + 0.7152 * seen[1] + 0.0722 * seen[2]
        return tuple(c / lit for c in seen) if lit > 0.001 else seen
    a = flatten(_seen_as(one, kind))
    b = flatten(_seen_as(two, kind))
    return 100.0 * sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def schemes():
    """Every scheme in palette.gd, as {name: {role: hex}}."""
    text = PALETTE.read_text()
    found = {}
    for name, body in re.findall(
            r"^const ([A-Z]+) := \{(.*?)^\}", text, re.S | re.M):
        colours = dict(re.findall(r'&"(\w+)": "([0-9a-fA-F]{6})"', body))
        if colours:
            found[name.lower()] = colours
    return found


def main():
    wrong = []
    for name, colours in sorted(schemes().items()):
        print("%s" % name)
        for front, back, want, what in PAIRS:
            if front not in colours or back not in colours:
                continue
            got = contrast(colours[front], colours[back])
            mark = " " if got >= want else "  <- too close to read"
            print("  %5.2f:1  needs %.1f  %-28s %s" % (got, want, what, mark))
            if got < want:
                wrong.append("%s: %s is %.2f:1 against its background,"
                             " needs %.1f" % (name, what, got, want))

        lit = contrast(colours["liberal"], colours["conservative"])
        print("  the Squad against the opposition, to a colour-blind player"
              " (%.2f:1 apart in brightness):" % lit)
        for kind in BLINDNESS:
            gap = hue_apart(colours["liberal"], colours["conservative"], kind)
            if gap >= HUE_APART:
                mark = "two colours"
            elif lit >= BRIGHT_APART:
                mark = "one colour, two brightnesses"
            else:
                mark = "  <- the same colour"
            print("  %5.1f    needs %.1f    %-24s %s"
                  % (gap, HUE_APART, kind, mark))
            if gap < HUE_APART and lit < BRIGHT_APART:
                wrong.append("%s: the Squad and the opposition are one colour"
                             " under %s — %.1f apart in hue (needs %.1f) and"
                             " %.2f:1 in brightness (needs %.2f)"
                             % (name, kind, gap, HUE_APART, lit, BRIGHT_APART))
        print()

    if wrong:
        print("%d problem(s):\n" % len(wrong))
        for said in wrong:
            print("  %s" % said)
        print("\nContrast is WCAG 2.1: 4.5:1 for body text, 3:1 for large text"
              " and control edges.\nA scheme whose two sides collapse under"
              " colour blindness is still shippable —\nthe alignment is"
              " written in words beside the colour — but it should be a\n"
              "decision rather than a surprise.")
        return 1
    print("Every scheme is readable, and its two sides stay two colours.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
