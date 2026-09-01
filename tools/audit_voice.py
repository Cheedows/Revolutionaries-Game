#!/usr/bin/env python3
"""Every label the original has words for uses the original's words.

The other five audits ask whether the port still *does* what the original
does. This one asks whether it still *sounds* like it, which nothing else
could catch: a menu option renamed from "We Didn't Start The Fire" to "a
strong Conservative Crime Squad" passes every test in the tree and loses the
game's voice, and once a few of them have gone the rest read as normal.

Presentation is the port's to write where the original had no words — an event
the terminal never printed, a panel that did not exist. Where it did have
words, they are content, and paraphrasing them is a departure like any other.

So this holds a table of the port's user-visible labels against the string the
original prints for the same thing, and fails when they disagree. Adding a
label means adding a row; if the original genuinely has no wording for it,
that is what NO_ORIGINAL is for, with the reason written down.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# (port file, port key, original file, the original's exact string)
#
# The original's string is written out here rather than scraped, because
# scraping it would only prove the port agrees with whatever this tool
# scraped. It is checked against src/ below, so a row that misquotes the
# original fails too.
CARRIED = [
    # The assignment names, from getactivity() in src/common/getnames.cpp.
    ("game/ui/adapters/activity_text.gd", "none", "Laying Low"),
    ("game/ui/adapters/activity_text.gd", "donations", "Soliciting Donations"),
    ("game/ui/adapters/activity_text.gd", "sell_tshirts", "Selling T-Shirts"),
    ("game/ui/adapters/activity_text.gd", "sell_art", "Selling Art"),
    ("game/ui/adapters/activity_text.gd", "sell_music", "Selling Music"),
    ("game/ui/adapters/activity_text.gd", "sell_drugs", "Selling Brownies"),
    ("game/ui/adapters/activity_text.gd", "prostitution", "Prostituting"),
    ("game/ui/adapters/activity_text.gd", "polls", "Gathering Opinion Info"),
    ("game/ui/adapters/activity_text.gd", "communityservice", "Volunteering"),
    ("game/ui/adapters/activity_text.gd", "graffiti", "Making Graffiti"),
    ("game/ui/adapters/activity_text.gd", "trouble", "Causing Trouble"),
    ("game/ui/adapters/activity_text.gd", "stealcars", "Stealing a Car"),
    ("game/ui/adapters/activity_text.gd", "bury", "Disposing of Bodies"),
    ("game/ui/adapters/activity_text.gd", "ccfraud", "Credit Card Fraud"),
    ("game/ui/adapters/activity_text.gd", "dos_attacks", "Attacking Websites"),
    ("game/ui/adapters/activity_text.gd", "dos_racket", "Extorting Websites"),
    ("game/ui/adapters/activity_text.gd", "hacking", "Hacking Networks"),
    ("game/ui/adapters/activity_text.gd", "repair_armor", "Repairing Clothing"),
    ("game/ui/adapters/activity_text.gd", "wheelchair", "Procuring a Wheelchair"),
    ("game/ui/adapters/activity_text.gd", "heal", "Tending to Injuries"),
    ("game/ui/adapters/activity_text.gd", "clinic", "Going to Free CLINIC"),
    ("game/ui/adapters/activity_text.gd", "augment", "Augmenting Liberal"),
    ("game/ui/adapters/activity_text.gd", "write_letters", "Writing letters"),
    ("game/ui/adapters/activity_text.gd", "write_guardian", "Writing news"),
    ("game/ui/adapters/activity_text.gd", "teach_politics", "Teaching Politics"),
    ("game/ui/adapters/activity_text.gd", "teach_fighting", "Teaching Fighting"),
    ("game/ui/adapters/activity_text.gd", "teach_covert", "Teaching Covert Ops"),
    ("game/ui/adapters/activity_text.gd", "recruiting", "Recruiting"),
    ("game/ui/adapters/activity_text.gd", "sleeper_liberal", "Promoting Liberalism"),
    ("game/ui/adapters/activity_text.gd", "sleeper_conservative", "Spouting Conservatism"),
    ("game/ui/adapters/activity_text.gd", "sleeper_spy", "Snooping Around"),
    ("game/ui/adapters/activity_text.gd", "sleeper_recruit", "Recruiting Sleepers"),
    ("game/ui/adapters/activity_text.gd", "sleeper_joinlcs", "Quitting Job"),
    ("game/ui/adapters/activity_text.gd", "sleeper_scandal", "Creating a Scandal"),
    ("game/ui/adapters/activity_text.gd", "sleeper_embezzle", "Embezzling Funds"),
    ("game/ui/adapters/activity_text.gd", "sleeper_steal", "Stealing Equipment"),
    # The classes, named for the class rather than the skill, from the study
    # menu in src/basemode/activate.cpp.
    ("game/ui/adapters/activity_text.gd", "study_debating", "Public Policy"),
    ("game/ui/adapters/activity_text.gd", "study_business", "Economics"),
    ("game/ui/adapters/activity_text.gd", "study_psychology", "Psychology"),
    ("game/ui/adapters/activity_text.gd", "study_law", "Criminal Law"),
    ("game/ui/adapters/activity_text.gd", "study_science", "Physics"),
    ("game/ui/adapters/activity_text.gd", "study_driving", "Drivers Ed"),
    ("game/ui/adapters/activity_text.gd", "study_first_aid", "First Aid"),
    ("game/ui/adapters/activity_text.gd", "study_art", "Painting"),
    ("game/ui/adapters/activity_text.gd", "study_disguise", "Theatre"),
    ("game/ui/adapters/activity_text.gd", "study_martial_arts", "Kung Fu"),
    ("game/ui/adapters/activity_text.gd", "study_gymnastics", "Gymnastics"),
    ("game/ui/adapters/activity_text.gd", "study_writing", "Writing"),
    ("game/ui/adapters/activity_text.gd", "study_teaching", "Education"),
    ("game/ui/adapters/activity_text.gd", "study_music", "Music"),
    ("game/ui/adapters/activity_text.gd", "study_locksmithing", "Locksmithing"),
    ("game/ui/adapters/activity_text.gd", "study_computers", "Computers"),
]

# The new-game switches, whose labels and notes are split across two fields.
# From src/title/newgame.cpp, where each reads "Name: sentence."
SWITCHES = [
    ("classic", "Classic Mode", "No Conservative Crime Squad."),
    ("strong_ccs", "We Didn't Start The Fire",
     "The CCS starts active and extremely strong."),
    ("nightmare_laws", "Nightmare Mode",
     "Liberalism is forgotten. Is it too late to fight back?"),
    ("multiple_cities", "National LCS", "Advanced play across multiple cities."),
    ("no_court_purge", "Marathon Mode",
     "Prevent Liberals from amending the Constitution."),
    ("stalin", "Stalinist Mode",
     "Enable Stalinist Comrade Squad (not fully implemented)."),
    ("elite_liberal", "No Compromise Classic",
     "I will make all our laws Elite Liberal!"),
    ("easy", "Democrat Mode",
     "Most laws must be Elite Liberal, some can be Liberal."),
    ("fast", "Fast skills", "Grinding is Conservative!"),
    ("classic_rate", "Classic", "Excellence requires practice."),
    ("hard", "Hard Mode", "Learn from the best, or face arrest!"),
]

# Labels the port writes itself, and why the original has no words to carry.
NO_ORIGINAL = {
    "make_armor": "the original names the garment being sewn, so the label is"
                  " a format string rather than a fixed name",
    "hostagetending": "the original names the hostage; the port's picker names"
                      " them separately, so the label cannot be theirs",
}


def original_text():
    said = []
    for path in (ROOT / "src").rglob("*"):
        if path.suffix in (".cpp", ".h"):
            said.append(path.read_text(errors="ignore"))
    return "\n".join(said)


def port_labels(relative):
    """Every `&"key": "value"` pair in a port file."""
    text = (ROOT / relative).read_text()
    return dict(re.findall(r'&"([a-z_]+)":\s*"((?:[^"\\]|\\.)*)"', text))


def main():
    src = original_text()
    problems = []
    checked = 0

    tables = {}
    for path, key, wanted in CARRIED:
        tables.setdefault(path, port_labels(path))
        got = tables[path].get(key)
        checked += 1
        if wanted not in src:
            problems.append(f"{path}: this tool misquotes the original for"
                            f" {key!r}: {wanted!r} is not in src/")
        elif got is None:
            problems.append(f"{path}: no label for {key!r}")
        elif got != wanted:
            problems.append(f"{path}: {key!r} says {got!r},"
                            f" the original says {wanted!r}")

    screen = (ROOT / "game/ui/screens/new_game_screen.gd").read_text()
    for key, label, note in SWITCHES:
        checked += 2
        for words in (label, note):
            if words not in src:
                problems.append(f"new_game_screen.gd: this tool misquotes the"
                                f" original for {key!r}: {words!r}")
            elif f'"{words}"' not in screen:
                problems.append(f"new_game_screen.gd: {key!r} does not say"
                                f" {words!r}, which is what the original says")

    print(f"{checked} labels the original has words for.")
    print(f"  {checked - len(problems)} use them.")
    print(f"  {len(NO_ORIGINAL)} are the port's own, explained in this tool.")
    print(f"  {len(problems)} disagree with the original.")
    if problems:
        print("\nThe port is paraphrasing where the original had words:\n")
        for problem in problems:
            print(f"  {problem}")
        print("\nSee docs/port/ARCHITECTURE.md on the presentation seam.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
