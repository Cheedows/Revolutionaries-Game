#!/usr/bin/env python3
"""Generates game/core/site_loot_rules.gd from the loot switch in sitemode.cpp.

What the squad finds when it picks up a marked square is a 250-line switch on
the site type in src/sitemode/sitemode.cpp: a chain of one-in-N rolls per site,
sometimes picking from a local array, sometimes indexing one by a roll offset
against the gun laws.

Transcribing that by hand would be two hundred chances to fluff a number, and a
wrong denominator is a roll that still happens but produces the wrong thing —
which a draw-count test would not catch. So it is read out of the source
instead. The grammar the original happens to use is small; anything outside it
stops the run rather than being quietly dropped.

Emitted as an ordered list of steps per site type, each step a condition and
what it yields. Order matters: the original's chain is an if/else-if, so the
first step whose roll lands wins and the rest are never rolled at all.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "src/sitemode/sitemode.cpp"
OUT = ROOT / "game/core/site_loot_rules.gd"

ARRAY = re.compile(r'string\s+(\w+)\[\]\s*=\s*\{(.*?)\};', re.S)
STRINGS = re.compile(r'"([A-Z0-9_]+)"')

# What a branch can assign. The three variables are the three item classes.
TARGETS = {"newLootType": "loot", "newArmorType": "armor",
           "newWeaponType": "weapon"}


def fail(message):
    sys.exit("extract_site_loot: " + message)


def switch_body(text, opener):
    """The text between the braces of the switch that starts at `opener`."""
    start = text.index("{", text.index(opener))
    depth = 0
    for index in range(start, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return text[start + 1:index]
    fail("unterminated switch at %r" % opener)


def split_cases(body):
    """Splits a switch body into (site types, case body) pairs.

    Several sites share one body by stacking their labels, which the original
    does for the three places the Conservative Crime Squad might be holding.
    """
    cases = []
    labels = []
    current = []
    for line in body.splitlines():
        label = re.match(r'\s*case\s+SITE_([A-Z0-9_]+)\s*:\s*$', line)
        if label:
            if current:
                cases.append((labels, "\n".join(current)))
                labels, current = [], []
            elif labels:
                pass
            labels.append(label.group(1).lower())
            continue
        current.append(line)
    if current:
        cases.append((labels, "\n".join(current)))
    if not cases:
        fail("no cases found")
    return cases


def parse_value(expression, arrays):
    """One right-hand side: a literal, a pick from an array, or an index."""
    literal = re.fullmatch(r'"([A-Z0-9_]+)"', expression)
    if literal:
        return {"kind": "literal", "type": literal.group(1)}

    picked = re.fullmatch(r'pickrandom\((\w+)\)', expression)
    if picked:
        if picked.group(1) not in arrays:
            fail("pickrandom from unknown array %s" % picked.group(1))
        return {"kind": "pick", "types": arrays[picked.group(1)]}

    # rndWeps[LCSrandom(4) + 2 - law[LAW_GUNCONTROL]] and its variants: a roll
    # over part of the array, shifted by how strict the gun laws are.
    indexed = re.fullmatch(
        r'(\w+)\[LCSrandom\((\d+)\)\s*(?:\+\s*(\d+)\s*)?-\s*law\[LAW_GUNCONTROL\]\]',
        expression)
    if indexed:
        if indexed.group(1) not in arrays:
            fail("index into unknown array %s" % indexed.group(1))
        return {"kind": "indexed", "types": arrays[indexed.group(1)],
                "spread": int(indexed.group(2)),
                "offset": int(indexed.group(3) or 0)}

    # rndWeps[LCSrandom(6 - law[LAW_GUNCONTROL])]: the whole roll is narrowed
    # rather than the result shifted, so strict laws remove the good guns.
    narrowed = re.fullmatch(
        r'(\w+)\[LCSrandom\((\d+)\s*-\s*law\[LAW_GUNCONTROL\]\)\]', expression)
    if narrowed:
        if narrowed.group(1) not in arrays:
            fail("index into unknown array %s" % narrowed.group(1))
        return {"kind": "narrowed", "types": arrays[narrowed.group(1)],
                "spread": int(narrowed.group(2))}

    fail("unrecognised value %r" % expression)


def parse_assignments(text, arrays):
    """Every `newXType = ...;` in one branch, in order."""
    found = []
    for name, item_class in TARGETS.items():
        for match in re.finditer(re.escape(name) + r'\s*=\s*(.+?);', text,
                                 re.S):
            expression = " ".join(match.group(1).split())
            found.append((match.start(), item_class,
                          parse_value(expression, arrays)))
    found.sort()
    return [{"class": item_class, "value": value}
            for _, item_class, value in found]


def parse_condition(text):
    """The roll guarding a branch, or None for a bare `else`."""
    one_in = re.fullmatch(r'!LCSrandom\((\d+)\)', text)
    if one_in:
        return {"test": "one_in", "odds": int(one_in.group(1))}
    # The fire station's `else if(LCSrandom(2))`: true on the *non*-zero roll,
    # so it is the other way round from every other test in the switch.
    below = re.fullmatch(r'LCSrandom\((\d+)\)', text)
    if below:
        return {"test": "below", "odds": int(below.group(1))}
    fail("unrecognised condition %r" % text)


def strip_comments(text):
    """Comments out of the way. One of them contains the word "if"."""
    text = re.sub(r'/\*.*?\*/', "", text, flags=re.S)
    return re.sub(r'//[^\n]*', "", text)


def strip_arrays(text):
    """Pulls the local arrays out and returns them with the rest of the text."""
    text = strip_comments(text)
    arrays = {}
    for match in ARRAY.finditer(text):
        arrays[match.group(1)] = STRINGS.findall(match.group(2))
    return arrays, ARRAY.sub("", text)


def balanced(text, start, opener="(", closer=")"):
    """The index just past the bracket that closes the one at `start`."""
    depth = 0
    for index in range(start, len(text)):
        if text[index] == opener:
            depth += 1
        elif text[index] == closer:
            depth -= 1
            if depth == 0:
                return index
    fail("unbalanced %s from %d" % (opener, start))


def take_statement(text, start):
    """One statement or braced block beginning at `start`."""
    while start < len(text) and text[start] in " \t\r\n":
        start += 1
    if start >= len(text):
        return "", start
    if text[start] == "{":
        end = balanced(text, start, "{", "}")
        return text[start + 1:end], end + 1
    end = text.find(";", start)
    if end == -1:
        return text[start:], len(text)
    return text[start:end + 1], end + 1


def parse_chain(text, arrays):
    """One if/else-if chain, or a nested switch, into a list of steps."""
    steps = []
    index = 0
    while index < len(text):
        keyword = re.compile(r'\b(else\s+if|if|else|switch)\b').search(text, index)
        if not keyword:
            break
        word = " ".join(keyword.group(1).split())

        if word == "switch":
            # The bar-and-grill picks a class of thing first, then what within
            # it. Only LCSrandom switches appear here.
            head_end = balanced(text, text.index("(", keyword.end()))
            head = text[text.index("(", keyword.end()) + 1:head_end]
            spread = re.fullmatch(r'\s*LCSrandom\((\d+)\)\s*', head)
            if not spread:
                fail("unrecognised switch head %r" % head)
            body, index = take_statement(text, head_end + 1)
            branches = []
            for label, branch in split_numbered(body):
                branches.append({"roll": label,
                                 "steps": parse_chain(branch, arrays)})
            steps.append({"condition": {"test": "choose",
                                        "spread": int(spread.group(1))},
                          "fresh": True, "branches": branches})
            continue

        if word == "else":
            body, index = take_statement(text, keyword.end())
            steps.append({"condition": None, "fresh": False,
                          "gives": parse_assignments(body, arrays)})
            continue

        open_paren = text.index("(", keyword.end())
        close_paren = balanced(text, open_paren)
        condition = " ".join(text[open_paren + 1:close_paren].split())
        body, index = take_statement(text, close_paren + 1)
        # A bare `if` starts a chain of its own: the chief executive's house
        # rolls for a wardrobe and then, whatever happened, rolls again for
        # what is in the drawers.
        steps.append({"condition": parse_condition(condition),
                      "fresh": word == "if",
                      "gives": parse_assignments(body, arrays)})

    if not steps:
        # A site with one unconditional line, like the sweatshop's fine cloth.
        gives = parse_assignments(text, arrays)
        if gives:
            steps.append({"condition": None, "fresh": True, "gives": gives})
    return steps


def split_numbered(body):
    """A `switch(LCSrandom(n))` body into (label, text) pairs."""
    branches = []
    label = None
    current = []
    for line in body.splitlines():
        head = re.match(r'\s*(?:case\s+(\d+)|default)\s*:\s*$', line)
        if head:
            if label is not None:
                branches.append((label, "\n".join(current)))
            label = int(head.group(1)) if head.group(1) else -1
            current = []
            continue
        current.append(line)
    if label is not None:
        branches.append((label, "\n".join(current)))
    return branches


def to_gdscript(value):
    if isinstance(value, dict):
        pairs = ", ".join('&"%s": %s' % (key, to_gdscript(item))
                          for key, item in value.items())
        return "{%s}" % pairs
    if isinstance(value, list):
        return "[%s]" % ", ".join(to_gdscript(item) for item in value)
    if isinstance(value, str):
        return '&"%s"' % value
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def main():
    text = SOURCE.read_text(encoding="latin-1")
    body = switch_body(text[text.index("switch(sitetype)"):], "switch(sitetype)")

    rules = {}
    for labels, case in split_cases(body):
        if not labels:
            # Whatever sits before the first case label, which is nothing.
            continue
        arrays, stripped = strip_arrays(case)
        steps = parse_chain(stripped, arrays)
        if not steps:
            fail("no steps for %s" % ", ".join(labels))
        for label in labels:
            rules[label] = steps

    lines = [
        "class_name SiteLootRules",
        "extends RefCounted",
        "## What is on a marked square, by the kind of place it is in.",
        "##",
        "## Generated by tools/extract_site_loot.py from the loot switch in",
        "## src/sitemode/sitemode.cpp. Do not edit by hand.",
        "##",
        "## Each site is a list of steps read in order. A step marked \"fresh\"",
        "## starts a new if/else-if chain; the steps after it belong to that",
        "## chain and are skipped once one of them fires. A step with a null",
        "## condition is the chain's `else` and always fires.",
        "",
        "const BY_SITE: Dictionary = {",
    ]
    for site in sorted(rules):
        lines.append('\t&"%s": %s,' % (site, to_gdscript(rules[site])))
    lines.append("}")
    OUT.write_text("\n".join(lines) + "\n")
    print("wrote %s (%d site types)" % (OUT, len(rules)))


if __name__ == "__main__":
    main()
