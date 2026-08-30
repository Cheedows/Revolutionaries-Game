#!/usr/bin/env python3
"""Generates game/core/disguise_rules.gd from hasdisguise().

Whether a squad passes for staff is decided by a two-hundred-line switch in
src/sitemode/stealth.cpp: one block per kind of site, listing the outfits that
belong there, with side conditions for high-security sites and for laws that
change who is allowed to wear what.

It is a table written as code, so it is read back out as a table rather than
transcribed. Anything this parser does not recognise is a hard error: a rule
dropped in silence would let a squad walk through a wall of guards.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src" / "sitemode" / "stealth.cpp"
OUT = ROOT / "game" / "core" / "disguise_rules.gd"

ARMOR = r'cr\.get_armor\(\)\.get_itemtypename\(\)=="(ARMOR_[A-Z0-9_]+)"'
## uniformed=(location[cursite]->highsecurity?1:2)
HIGH_SECURITY_VALUE = "high_security_or_partial"


def body(text, opener, closer):
    start = text.index(opener)
    return text[start:text.index(closer, start)]


def joined(lines):
    """Joins the continuation lines of a multi-line if condition."""
    out = []
    held = ""
    for raw in lines:
        line = re.sub(r"//.*", "", raw).strip()
        if held:
            line = held + line
            held = ""
        if line.endswith("&&") or line.endswith("||"):
            held = line
            continue
        out.append(line)
    if held:
        raise SystemExit("dangling condition: " + held)
    return out


def parse_rules(lines, site_context):
    """Turns one case block into a list of rule dictionaries.

    Conditions that wrap a block — a restricted area, a high-security site, a
    pair of laws — become context carried onto every rule inside it.
    """
    rules = []
    context = dict(site_context)
    stack = []
    last_block = None

    for line in joined(lines):
        if not line or line == "break;":
            continue
        if line == "{":
            continue
        if line == "}":
            if stack:
                outer, added = stack.pop()
                last_block = added
                context = outer
            continue

        negated = None
        if line.startswith("else"):
            if last_block is None:
                raise SystemExit("else without a preceding block: " + line)
            negated = dict(last_block)
            line = line[len("else"):].strip()
            if not line:
                inner = dict(context)
                merge_negated(inner, negated)
                stack.append((context, delta(context, inner)))
                context = inner
                continue

        opener = re.fullmatch(r"if\((.+)\)", line)
        if opener:
            inner = dict(context)
            if negated:
                merge_negated(inner, negated)
            for clause in split_conditions(opener.group(1)):
                apply_clause(inner, clause)
            stack.append((context, delta(context, inner)))
            context = inner
            continue

        entry_context = dict(context)
        if negated:
            merge_negated(entry_context, negated)
        rules.append(rule(line, entry_context))

    return rules


def delta(outer, inner):
    """What a block's condition added on top of the context around it."""
    added = {}
    for key, value in inner.items():
        if outer.get(key) != value:
            added[key] = value
    return added


def merge_negated(context, negated):
    """Adds the inverse of a block's conditions, for its else branch."""
    for key, value in negated.items():
        if key == "laws":
            context.setdefault("not_laws", []).extend(value)
            continue
        raise SystemExit("cannot negate condition: %s (%r)" % (key, negated))


## Context keys carried from a wrapping condition onto the rules inside it.
CARRIED = ("restricted", "high_security", "laws", "not_laws", "escalation",
           "armor", "naked")


def rule(statement, context):
    """One `uniformed = N` assignment and everything that has to be true first."""
    statement = statement.strip()
    entry = {key: context[key] for key in CARRIED if context.get(key)}

    plain = re.fullmatch(r"uniformed=(.+);", statement)
    if plain:
        entry["value"] = value_of(plain.group(1))
        return entry

    guarded = re.fullmatch(r"if\((.+)\)uniformed=(.+);", statement)
    if not guarded:
        raise SystemExit("unhandled disguise rule: " + statement)
    for clause in split_conditions(guarded.group(1)):
        apply_clause(entry, clause)
    entry["value"] = value_of(guarded.group(2))
    return entry


def split_conditions(condition):
    """Splits an && chain, tolerating the parentheses inside each clause."""
    parts = []
    depth = 0
    current = ""
    index = 0
    while index < len(condition):
        char = condition[index]
        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
        if depth == 0 and condition[index:index + 2] == "&&":
            parts.append(current)
            current = ""
            index += 2
            continue
        current += char
        index += 1
    parts.append(current)
    return [part.strip() for part in parts if part.strip()]


def apply_clause(entry, clause):
    armor = re.fullmatch(ARMOR, clause)
    if armor:
        entry["armor"] = armor.group(1)
        return
    law = re.fullmatch(r"law\[LAW_([A-Z0-9_]+)\]==(-?\d+)", clause)
    if law:
        entry.setdefault("laws", []).append((law.group(1), law.group(2)))
        return
    if clause == "cr.is_naked()":
        entry["naked"] = True
        return
    escalation = re.fullmatch(
        r"location\[cursite\]->siege\.escalationstate(==|>)(\d+)", clause)
    if escalation:
        entry["escalation"] = (escalation.group(1), int(escalation.group(2)))
        return
    if clause == "location[cursite]->highsecurity":
        entry["high_security"] = True
        return
    if clause == "levelmap[locx][locy][locz].flag & SITEBLOCK_RESTRICTED":
        entry["restricted"] = True
        return
    raise SystemExit("unhandled disguise condition: " + clause)


def value_of(raw):
    raw = raw.strip()
    if raw == "(location[cursite]->highsecurity?1:2)":
        return HIGH_SECURITY_VALUE
    return int(raw)


def cases(text):
    """Splits a switch body into (labels, lines) pairs."""
    found = []
    labels = []
    lines = []
    for raw in text.splitlines():
        line = re.sub(r"//.*", "", raw).strip()
        label = re.fullmatch(r"case (SITE|SIEGE)_([A-Z0-9_]+):", line)
        if label:
            if lines:
                found.append((labels, lines))
                labels, lines = [], []
            labels.append(label.group(2).lower())
            continue
        if line == "default:":
            if lines:
                found.append((labels, lines))
            labels, lines = ["*"], []
            continue
        if labels:
            lines.append(raw)
    if lines or labels:
        found.append((labels, lines))
    return found


def emit(name, table, lines):
    lines.append("const %s: Dictionary = {" % name)
    for key in sorted(table):
        rows = ", ".join(gd(entry) for entry in table[key])
        lines.append('\t&"%s": [%s],' % (key, rows))
    lines.append("}")
    lines.append("")


def gd(entry):
    parts = []
    if "armor" in entry:
        parts.append('&"armor": &"%s"' % entry["armor"])
    if entry.get("naked"):
        parts.append('&"naked": true')
    if entry.get("restricted"):
        parts.append('&"restricted": true')
    if entry.get("high_security"):
        parts.append('&"high_security": true')
    if entry.get("laws"):
        laws = ", ".join('[&"%s", %s]' % (name.lower(), value)
                         for name, value in entry["laws"])
        parts.append("&\"laws\": [%s]" % laws)
    if entry.get("not_laws"):
        laws = ", ".join('[&"%s", %s]' % (name.lower(), value)
                         for name, value in entry["not_laws"])
        parts.append("&\"not_laws\": [%s]" % laws)
    if entry.get("escalation"):
        operator, level = entry["escalation"]
        parts.append('&"escalation": [&"%s", %d]' % (operator, level))
    value = entry["value"]
    parts.append('&"value": %s' % (
        '&"%s"' % value if isinstance(value, str) else value))
    return "{%s}" % ", ".join(parts)


IN_CHARACTER_LAW = re.compile(r"law\[LAW_([A-Z0-9_]+)\]==(-?\d+)")


def in_character(text):
    """Reads weapon_in_character() into a list of outfit-and-weapon rules.

    The original writes it as a run of ifs over string comparisons, some of
    them nested one level so a weapon set is tried against several outfits.
    Each rule names the creature type the pairing passes for; -1, meaning it
    passes for nobody, is simply the absence of a rule.
    """
    function = body(text, "char weapon_in_character(const string& wtype, const string& atype)",
                    "\n/* checks if a creature's weapon is suspicious */")
    function = function[function.index("{") + 1:]
    lines = joined([line.strip() for line in function.splitlines() if line.strip()])

    rules = []
    outer = None    # a condition guarding a braced block
    pending = None  # a condition awaiting the return that it guards
    for line in lines:
        line = re.sub(r"\s+", "", line)
        if not line:
            continue
        if line == "{":
            outer = pending
            pending = None
            continue
        if line == "}":
            outer = None
            continue
        if line == "return-1;":
            continue

        match = re.fullmatch(r"(?:else)?if\((?P<cond>.+)\)", line)
        if match:
            pending = match.group("cond")
            continue

        match = re.fullmatch(r"return CREATURE_(?P<who>[A-Z0-9_]+);".replace(" ", ""), line)
        if not match:
            raise SystemExit("unrecognised in-character line: %r" % line)

        parts = [part for part in (outer, pending) if part]
        if not parts:
            raise SystemExit("in-character rule with no condition")
        condition = "&&".join("(%s)" % part for part in parts)
        pending = None

        weapons = sorted(set(re.findall(r'wtype=="(WEAPON_[A-Z0-9_]+)"', condition)))
        armors = sorted(set(re.findall(r'atype=="(ARMOR_[A-Z0-9_]+)"', condition)))
        laws = [[name.lower(), int(value)]
                for name, value in IN_CHARACTER_LAW.findall(condition)]
        if not weapons or not armors:
            raise SystemExit("in-character rule names no pair: %r" % condition)
        rule_entry = {"armors": armors, "weapons": weapons,
                      "type": "CREATURE_" + match.group("who")}
        if laws:
            rule_entry["laws"] = laws
        rules.append(rule_entry)
    if not rules:
        raise SystemExit("no weapon_in_character rules found")
    return rules


def gd_plain(value):
    if isinstance(value, int):
        return str(value)
    if isinstance(value, str):
        return '&"%s"' % value
    if isinstance(value, list):
        return "[%s]" % ", ".join(gd_plain(item) for item in value)
    if isinstance(value, dict):
        return "{%s}" % ", ".join('&"%s": %s' % (k, gd_plain(v))
                                  for k, v in value.items())
    raise SystemExit("cannot write %r" % value)


def main() -> int:
    text = SOURCE.read_text(errors="replace")
    function = body(text, "char hasdisguise(const Creature &cr)",
                    "\n/* returns true if the entire site is not open to public */")

    siege_body = body(function, "switch(location[cursite]->siege.siegetype)",
                      "\n   }\n   else\n")
    site_body = function[function.index("switch(type)"):function.index("\n   if(!uniformed)")]

    siege = {}
    for labels, lines in cases(siege_body):
        rules = parse_rules(lines, {})
        for label in labels:
            siege[label] = rules

    sites = {}
    for labels, lines in cases(site_body):
        rules = parse_rules(lines, {})
        for label in labels:
            sites[label] = rules

    out = [
        "class_name DisguiseRules",
        "extends RefCounted",
        "## Which outfit passes for staff, and where.",
        "##",
        "## GENERATED by tools/extract_disguises.py from hasdisguise() in",
        "## src/sitemode/stealth.cpp — do not edit by hand.",
        "##",
        "## Each rule sets how convincing the outfit is: 1 passes, 2 is a partial",
        "## disguise that halves the roll, 0 gives the game away. Rules are applied",
        "## in order and the last one that matches wins, which is how the original's",
        "## run of ifs behaves.",
        "##",
        '## A value of &"%s" means the site decides: convincing where' % HIGH_SECURITY_VALUE,
        "## the staff are armed and expected, partial anywhere else.",
        "##",
        '## &"laws" requires every listed law to hold; &"not_laws" requires that',
        "## they do not all hold, which is what the original's else branch means.",
        "",
        "",
        "## Site type -> rules, for a squad walking in off the street.",
    ]
    emit("BY_SITE", sites, out)
    out += ["", "## Siege type -> rules, for a squad defending its own safehouse."]
    emit("BY_SIEGE", siege, out)

    pairs = in_character(text)
    out += ["", "## Outfit-and-weapon pairings that pass for somebody who would",
            "## carry that weapon, from weapon_in_character(). A rule holds when",
            "## the creature wears one of the listed outfits and carries one of",
            '## the listed weapons; &"laws" must also hold where present.',
            "const IN_CHARACTER: Array = ["]
    for entry in pairs:
        out.append("\t%s," % gd_plain(entry))
    out += ["]", ""]

    OUT.write_text("\n".join(out))
    print("wrote %s: %d site rules, %d siege rules, %d in-character pairings"
          % (OUT.relative_to(ROOT), len(sites), len(siege), len(pairs)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
