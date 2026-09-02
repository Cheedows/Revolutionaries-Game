#!/usr/bin/env python3
"""Is the interface still built out of the same pieces?

The screens are laid out in code, and left alone that means every widget
invents its own. It did: 43 hand-built buttons, 73 hand-built labels, 155 theme
overrides and eight different hand-picked separations, no two agreeing. A
player cannot name that, but they can see it, and it is what produced a screen
with the Continue button drawn off the bottom, six switches with no visible on
state and a focus ring on the first row of every list.

So ui/theme/atoms.gd holds the primitives, ui/theme/metrics.gd holds the scale,
and ui/theme/palette.gd holds the colours. This fails the build when something
under ui/ goes around them.

Nothing here is about taste. Each rule names a thing that has already gone
wrong in this repository.

Files still to be moved over are listed in ALLOWED below. That list may only
get shorter — a file not on it that breaks a rule fails the build, and a file
on it that no longer needs to be fails the build too, so it cannot rot.

    python3 tools/audit_design.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UI = ROOT / "game" / "ui"

# The theme itself is where colours and sizes are allowed to be named.
THEME = {"atoms.gd", "metrics.gd", "palette.gd", "ui_theme.gd"}

# The gaps anything may ask for, from Metrics. Kept here as numbers because
# this reads GDScript as text; test_design_system.gd holds them to the scale.
SCALE = {0, 4, 8, 16, 24}

RULES = [
    (r"\bLabel\.new\(\)",
     "build labels with Atoms.body/dim/heading/title, not Label.new()"),
    (r"\bButton\.new\(\)",
     "build buttons with Atoms.button/primary, or OptionRow/ToggleRow"),
    (r"\bLineEdit\.new\(\)",
     "build text fields with Atoms.field()"),
    (r'add_theme_color_override\(\s*&?"[^"]+"\s*,\s*Color\(',
     "colours come from Palette, not from a literal Color()"),
]

SEPARATION = re.compile(
    r'add_theme_constant_override\(\s*&?"separation"\s*,\s*(-?\d+)\s*\)')

# Files not yet moved onto the atoms. Shrink this; never add to it.
ALLOWED = {
    "screens/base_layout.gd",
    "screens/title_screen.gd",
    "widgets/agenda_panel.gd",
    "widgets/dossier.gd",
    "widgets/fight_panel.gd",
    "widgets/justice_panel.gd",
    "widgets/kit_buttons.gd",
    "widgets/law_list.gd",
    "widgets/log_view.gd",
    "widgets/marshalling_panel.gd",
    "widgets/newspaper_panel.gd",
    "widgets/roster.gd",
    "widgets/safehouse_panel.gd",
    "widgets/settings_panel.gd",
    "widgets/site_map_view.gd",
    "widgets/sleeper_panel.gd",
    "widgets/squad_panel.gd",
    "widgets/status_bar.gd",
    "widgets/stores_panel.gd",
    "widgets/surgery_panel.gd",
}


def _broken(path):
    """Every rule [param path] breaks, as (line number, what, explanation)."""
    found = []
    for number, line in enumerate(path.read_text().splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        for pattern, explanation in RULES:
            if re.search(pattern, line):
                found.append((number, stripped, explanation))
        gap = SEPARATION.search(line)
        if gap and int(gap.group(1)) not in SCALE:
            found.append((number, stripped,
                          "a gap of %s is not on the scale (%s) — see Metrics"
                          % (gap.group(1),
                             ", ".join(str(n) for n in sorted(SCALE)))))
    return found


def main():
    offences, clean = {}, []
    for path in sorted(UI.rglob("*.gd")):
        if path.name in THEME:
            continue
        rel = str(path.relative_to(UI))
        found = _broken(path)
        if found:
            offences[rel] = found
        elif rel in ALLOWED:
            clean.append(rel)

    late = {rel: found for rel, found in offences.items() if rel not in ALLOWED}
    for rel, found in sorted(late.items()):
        print("game/ui/%s" % rel)
        for number, line, explanation in found:
            print("  %d: %s\n      %s" % (number, explanation, line))

    if late:
        print("\n%d file(s) go around the design system. Build them out of"
              " Atoms,\nOptionRow, ToggleRow and ActionBar instead — see"
              " game/ui/theme/atoms.gd." % len(late))
        return 1

    if clean:
        print("These are on the design system now and should come off the"
              " ALLOWED list\nin tools/audit_design.py, so they cannot drift"
              " back:\n")
        for rel in clean:
            print("  %s" % rel)
        return 1

    print("The interface is built out of its own pieces. %d file(s) still to"
          " move over." % len(ALLOWED))
    return 0


if __name__ == "__main__":
    sys.exit(main())
