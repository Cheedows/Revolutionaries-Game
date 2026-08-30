#!/usr/bin/env python3
"""Generates game/core/ids.gd from the C++ enums.

The trace harness records attributes, skills, laws and public views as bare
arrays, so the port must agree with the original on the *order* of every one of
them. Deriving the names from the source removes the chance of a hand-copied
list drifting; run this whenever the enums change.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "game" / "core" / "ids.gd"
TABLES = ROOT / "game" / "core" / "tables.gd"

# (GDScript group name, source file, enum name, prefix to strip, terminator)
ENUMS = [
    ("ATTRIBUTES", "src/creature/creature.h", "CreatureAttribute", "ATTRIBUTE_", "ATTNUM"),
    ("SKILLS", "src/creature/creature.h", "CreatureSkill", "SKILL_", "SKILLNUM"),
    ("BODY_PARTS", "src/creature/creature.h", "Bodyparts", "BODYPART_", "BODYPARTNUM"),
    ("SPECIAL_WOUNDS", "src/creature/creature.h", "SpecialWounds", "SPECIALWOUND_", "SPECIALWOUNDNUM"),
    ("LAWS", "src/includes.h", "Laws", "LAW_", "LAWNUM"),
    ("VIEWS", "src/includes.h", "Views", "VIEW_", "VIEWNUM"),
    ("ACTIVITIES", "src/includes.h", "Activity", "ACTIVITY_", "ACTIVITYNUM"),
    ("LAW_FLAGS", "src/includes.h", "Lawflags", "LAWFLAG_", "LAWFLAGNUM"),
    ("SITE_TYPES", "src/locations/locations.h", "SiteTypes", "SITE_", "SITENUM"),
    ("SIEGE_TYPES", "src/locations/locations.h", "SiegeTypes", "SIEGE_", "SIEGENUM"),
]


def members(source: str, enum_name: str, prefix: str, terminator: str):
    """Returns the enum's non-negative members, lowercased and prefix-stripped.

    Several of these enums open with pseudo-members at -2 and -1 (the original
    computes those views from the real ones), so member values are tracked and
    anything below zero is left out — it has no slot in the arrays the traces
    record.
    """
    text = (ROOT / source).read_text(errors="replace")
    match = re.search(rf"enum\s+{enum_name}\s*\{{(.*?)\}};", text, re.S)
    if not match:
        raise SystemExit(f"enum {enum_name} not found in {source}")

    names = []
    value = 0
    for line in match.group(1).splitlines():
        line = re.sub(r"//.*|/\*.*?\*/", "", line).strip()
        for part in line.split(","):
            part = part.strip()
            if not part:
                continue
            name, _, assigned = part.partition("=")
            name = name.strip()
            if not re.fullmatch(r"[A-Z_][A-Z0-9_]*", name):
                continue
            if name == terminator:
                return names
            if assigned.strip():
                try:
                    value = int(assigned.strip(), 0)
                except ValueError:
                    raise SystemExit(f"{enum_name}: cannot read value of {name}")
            if value >= 0:
                if len(names) != value:
                    raise SystemExit(
                        f"{enum_name}: {name} is {value} but would land at index {len(names)}")
                names.append(name.removeprefix(prefix).lower())
            value += 1
    return names


def skill_attributes(skills):
    """Parses Skill::get_associated_attribute() into a skill -> attribute map.

    The switch falls through case labels, so a run of labels shares the
    attribute the run ends with; anything not listed falls to the default.
    """
    text = (ROOT / "src/creature/creature.cpp").read_text(errors="replace")
    match = re.search(r"CreatureAttribute Skill::get_associated_attribute[^{]*\{(.*?)\n\}",
                      text, re.S)
    if not match:
        raise SystemExit("get_associated_attribute not found")

    mapping = {}
    pending = []
    default = None
    for line in match.group(1).splitlines():
        line = re.sub(r"//.*", "", line).strip()
        case = re.fullmatch(r"case SKILL_([A-Z0-9_]+):", line)
        if case:
            pending.append(case.group(1).lower())
            continue
        if line == "default:":
            pending.append(None)
            continue
        returned = re.fullmatch(r"return ATTRIBUTE_([A-Z0-9_]+);", line)
        if returned:
            attribute = returned.group(1).lower()
            for skill in pending:
                if skill is None:
                    default = attribute
                else:
                    mapping[skill] = attribute
            pending = []
    if default is None:
        raise SystemExit("get_associated_attribute has no default branch")

    missing = [skill for skill in skills if skill not in mapping]
    for skill in missing:
        mapping[skill] = default
    return mapping


def crime_heat():
    """Parses lawflagheat() into a crime -> heat map."""
    text = (ROOT / "src/common/commonactions.cpp").read_text(errors="replace")
    body = re.search(r"int lawflagheat\(int lawflag\)\s*\{(.*?)\n\}", text, re.S)
    if not body:
        raise SystemExit("lawflagheat not found")
    heat = {}
    for flag, value in re.findall(r"case LAWFLAG_([A-Z]+):\s*return (\d+);", body.group(1)):
        heat[flag.lower()] = int(value)
    return heat


def worksites():
    """Parses verifyworklocation() into a creature -> allowed site types map.

    The switch falls through, so a run of creature labels shares the sites the
    run ends with.
    """
    text = (ROOT / "src/creature/creaturetypes.cpp").read_text(errors="replace")
    body = re.search(r"bool verifyworklocation\(Creature &cr[^{]*\{(.*?)\n\}", text, re.S)
    if not body:
        raise SystemExit("verifyworklocation not found")

    mapping = {}
    pending = []
    for line in body.group(1).splitlines():
        line = re.sub(r"//.*", "", line).strip()
        case = re.fullmatch(r"case CREATURE_([A-Z0-9_]+):", line)
        if case:
            pending.append(case.group(1).lower())
            continue
        site = re.fullmatch(r"okaysite\[SITE_([A-Z0-9_]+)\]\s*=\s*1;", line)
        if site and pending:
            for creature in pending:
                mapping.setdefault(creature, []).append(site.group(1).lower())
            continue
        if line == "break;":
            pending = []
    return mapping


def politics_tables():
    """Parses the public-mood and Stalinist-opinion tables out of politics.cpp.

    Both are switch statements over the law and view enums. Deriving them keeps
    a 50-row transcription honest.
    """
    text = (ROOT / "src/politics/politics.cpp").read_text(errors="replace")

    mood = {}
    body = re.search(r"int publicmood\(int l\)\s*\{(.*?)\n\}", text, re.S)
    if not body:
        raise SystemExit("publicmood not found")
    for law, view in re.findall(
            r"case LAW_([A-Z]+): return attitude\[VIEW_([A-Z]+)\];", body.group(1)):
        mood[law.lower()] = view.lower()

    stalin_law, stalin_view = {}, {}
    body = re.search(r"bool stalinview\(short view,bool islaw\)\s*\{(.*?)\n\}", text, re.S)
    if not body:
        raise SystemExit("stalinview not found")
    islaw_part, _, view_part = body.group(1).partition("else switch(view)")
    for prefix, target in ((islaw_part, stalin_law), (view_part, stalin_view)):
        for line in prefix.splitlines():
            line = line.strip()
            if line.startswith("//"):
                continue
            match = re.match(r"case (?:LAW|VIEW)_([A-Z]+): return (true|false);", line)
            if match:
                target[match.group(1).lower()] = match.group(2) == "true"
    return mood, stalin_law, stalin_view


def main() -> int:
    groups = [(name, members(source, enum_name, prefix, terminator))
              for name, source, enum_name, prefix, terminator in ENUMS]

    lines = [
        "class_name Ids",
        "extends RefCounted",
        "## Every identifier the simulation names, in the original's order.",
        "##",
        "## GENERATED by tools/generate_ids.py from the C++ enums — do not edit by",
        "## hand. Order is load-bearing: the golden traces record attributes, skills,",
        "## laws and public views as bare arrays indexed by these enums, so a list out",
        "## of order silently breaks every parity comparison.",
        "##",
        "## Systems refer to these constants and never to bare strings, so renaming a",
        "## skill is one edit here plus a regeneration.",
        "",
    ]
    for name, values in groups:
        lines.append(f"## {len(values)} entries, in enum order.")
        lines.append(f"const {name}: Array[StringName] = [")
        for value in values:
            lines.append(f'\t&"{value}",')
        lines.append("]")
        lines.append("")

    OUT.write_text("\n".join(lines))

    skills = dict(groups)["SKILLS"]
    mapping = skill_attributes(skills)
    mood, stalin_law, stalin_view = politics_tables()
    table_lines = [
        "class_name Tables",
        "extends RefCounted",
        "## Lookup tables lifted from the original's switch statements.",
        "##",
        "## GENERATED by tools/generate_ids.py — do not edit by hand. These are",
        "## transcriptions of rules that live as long switches in the C++, and",
        "## deriving them is what keeps a fifty-row table honest.",
        "",
        "## The attribute that caps each skill, from",
        "## Skill::get_associated_attribute().",
        "const SKILL_ATTRIBUTE: Dictionary = {",
    ]
    for skill in skills:
        table_lines.append(f'\t&"{skill}": &"{mapping[skill]}",')
    table_lines += ["}", "",
        "## The public view each law is judged by, from publicmood(). Laws with no",
        "## single matching view are handled in the opinion system.",
        "const LAW_VIEW: Dictionary = {"]
    for law in sorted(mood):
        table_lines.append(f'\t&"{law}": &"{mood[law]}",')
    table_lines += ["}", "",
        "## Whether Stalinists side with Elite Liberals on each law.",
        "const STALINIST_AGREES_ON_LAW: Dictionary = {"]
    for law in sorted(stalin_law):
        table_lines.append(f'\t&"{law}": {"true" if stalin_law[law] else "false"},')
    table_lines += ["}", "",
        "## Whether Stalinists side with Elite Liberals on each public view.",
        "const STALINIST_AGREES_ON_VIEW: Dictionary = {"]
    for view in sorted(stalin_view):
        table_lines.append(f'\t&"{view}": {"true" if stalin_view[view] else "false"},')
    table_lines += ["}", "",
        "## How vigorously the law pursues each crime, from lawflagheat(). Not how",
        "## severe the crime is: assault carries no heat because the squad picks up",
        "## too many charges for it to mean anything.",
        "const CRIME_HEAT: Dictionary = {"]
    for crime, value in sorted(crime_heat().items()):
        table_lines.append(f'\t&"{crime}": {value},')
    table_lines += ["}", "",
        "## Where each creature type can plausibly be found working, from",
        "## verifyworklocation(). Types not listed can be found anywhere.",
        "const CREATURE_WORKSITES: Dictionary = {"]
    for creature, sites in sorted(worksites().items()):
        listed = ", ".join(f'&"{site}"' for site in sites)
        table_lines.append(f'\t&"{creature}": [{listed}],')
    table_lines += ["}", ""]
    TABLES.write_text("\n".join(table_lines))
    print(f"wrote {TABLES.relative_to(ROOT)}: "
          f"skills={len(mapping)}, laws={len(mood)}, "
          f"stalin_laws={len(stalin_law)}, stalin_views={len(stalin_view)}")

    print(f"wrote {OUT.relative_to(ROOT)}: " +
          ", ".join(f"{name}={len(values)}" for name, values in groups))
    return 0


if __name__ == "__main__":
    sys.exit(main())
