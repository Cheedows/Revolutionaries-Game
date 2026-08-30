#!/usr/bin/env python3
"""Generates game/core/encounter_rules.gd from prepareencounter().

Who is standing in a building when the squad walks in is a 1,200-line switch in
src/sitemode/newencounter.cpp: a weight per creature type per site type, with
clauses that add or replace weights depending on the law, the endgame, whether
the squad is somewhere it should not be, and whether the alarm has gone off.

Transcribing that by hand would be a thousand chances to fluff a number, so it
is read out of the source instead. The grammar the original happens to use is
small and completely regular; anything outside it stops the run rather than
being quietly dropped, because a missing weight is a creature that never
appears and nothing would notice.

Emitted as an ordered list of steps per site type. Order matters: the same
creature is often weighted twice and the second statement may be an assignment
rather than an addition, and the spawn loops sit between statements.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "src/sitemode/newencounter.cpp"
OUT = ROOT / "game/core/encounter_rules.gd"

# Conditions the original tests, as (pattern, builder). Each builds one node of
# a tiny expression tree the runtime walks; see EncounterRules for the shapes.
CONDITIONS = [
    (r"sec", lambda m: {"test": "security"}),
    (r"sitealarm==1", lambda m: {"test": "alarm"}),
    (r"siteonfire", lambda m: {"test": "on_fire"}),
    (r"law\[LAW_([A-Z0-9_]+)\](==|<=|>=|<|>|!=)(-?\d+)",
     lambda m: {"test": "law", "law": m.group(1).lower(),
                "op": m.group(2), "value": int(m.group(3))}),
    (r"endgamestate<ENDGAME_([A-Z0-9_]+)",
     lambda m: {"test": "endgame_below", "state": m.group(1).lower()}),
    (r"endgamestate>ENDGAME_([A-Z0-9_]+)",
     lambda m: {"test": "endgame_above", "state": m.group(1).lower()}),
    (r"exec\[EXEC_PRESIDENT\]<ALIGN_CONSERVATIVE",
     lambda m: {"test": "president_below_conservative"}),
    (r"mode==GAMEMODE_SITE", lambda m: {"test": "in_site"}),
    (r"!\(levelmap\[locx\]\[locy\]\[locz\]\.flag&SITEBLOCK_RESTRICTED\)",
     lambda m: {"test": "unrestricted"}),
    (r"levelmap\[locx\]\[locy\]\[locz\]\.flag&SITEBLOCK_RESTRICTED",
     lambda m: {"test": "restricted"}),
]


def parse_condition(text: str) -> dict:
    """Turns one if-clause into an expression tree."""
    if "||" in text:
        if "&&" in text:
            raise SystemExit("mixed && and || in encounter condition: %r" % text)
        return {"test": "any",
                "of": [parse_condition(part) for part in text.split("||") if part]}
    parts = [part for part in text.split("&&") if part]
    nodes = []
    for part in parts:
        part = part.strip()
        for pattern, build in CONDITIONS:
            match = re.fullmatch(pattern, part)
            if match:
                nodes.append(build(match))
                break
        else:
            raise SystemExit("unrecognised encounter condition: %r" % part)
    if len(nodes) == 1:
        return nodes[0]
    return {"test": "all", "of": nodes}


def squash(text: str) -> list:
    """Strips comments and whitespace, and rejoins clauses split across lines."""
    text = re.sub(r"//[^\n]*", "", text)
    lines = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        if lines and re.search(r"(&&|\|\||,)$", lines[-1]):
            lines[-1] += line
        else:
            lines.append(line)
    return [re.sub(r"\s+", "", line) for line in lines]


WEIGHT = re.compile(
    r"^(?P<else>else)?(?:if\((?P<cond>.+?)\))?"
    r"creaturearray\[CREATURE_(?P<who>[A-Z0-9_]+)\](?P<op>\+=|=\+|=)"
    r"(?P<n>\d+|endgamestate\*\d+|endgamestate);$")
SPAWN = re.compile(r"^for\(intn=0;n<LCSrandom\((?P<span>\w+)\)\+(?P<plus>\d+);n\+\+\)$")
SETVAR = re.compile(r"^(?:int)?(?P<name>encnum)=(?P<value>\d+);$")
CASE = re.compile(r"^caseSITE_(?P<site>[A-Z0-9_]+):$")


def otherwise(chain, own):
    """The condition of an `else` arm: every earlier arm failed, and own holds."""
    parts = [{"test": "not", "of": tried} for tried in chain]
    if own is not None:
        parts.append(own)
    if not parts:
        return None
    if len(parts) == 1:
        return parts[0]
    return {"test": "all", "of": parts}


def combine(guards, when):
    """Ands the conditions of the enclosing blocks onto one statement's own."""
    parts = [guard for guard, _ in guards if guard is not None]
    if when is not None:
        parts.append(when)
    if not parts:
        return None
    if len(parts) == 1:
        return parts[0]
    return {"test": "all", "of": parts}


def parse_body(lines, start):
    """Reads the statements of one switch case into an ordered step list.

    Conditions come in two shapes: a clause guarding the single statement that
    follows it, and a clause guarding a braced block. Both nest, so the guards
    in force are kept as a stack and anded onto each statement.
    """
    steps = []
    index = start
    guards = []      # one entry per open brace: (condition, outer chain)
    pending = None   # a condition awaiting either a statement or a brace
    chain = []       # the conditions already tried in the current if/else run
    depth = 0
    while index < len(lines):
        line = lines[index]
        index += 1
        if line == "{":
            depth += 1
            guards.append((pending, chain))
            pending = None
            # A nested block starts its own if/else run.
            chain = []
            continue
        if line == "}":
            depth -= 1
            if guards:
                _, chain = guards.pop()
            if depth <= 0:
                break
            continue
        if line == "break;":
            break
        if CASE.match(line) or line == "default:":
            index -= 1
            break

        match = WEIGHT.match(line)
        if match:
            when = None
            if match.group("cond") and match.group("else"):
                # `else if (...)`: every earlier arm of the run must have
                # failed, and this one must hold.
                own = parse_condition(match.group("cond"))
                when = otherwise(chain, own)
                chain = chain + [own]
            elif match.group("cond"):
                when = parse_condition(match.group("cond"))
                chain = [when]
            elif match.group("else"):
                when = otherwise(chain, None)
                chain = []
            elif pending is not None:
                when = pending
            pending = None
            amount = match.group("n")
            step = {
                "op": "set" if match.group("op") in ("=", "=+") else "add",
                "who": "CREATURE_" + match.group("who"),
                "when": combine(guards, when),
            }
            if amount.isdigit():
                step["amount"] = int(amount)
            else:
                # A weight that scales with how far the endgame has run.
                scale = amount.split("*")
                step["amount"] = 0
                step["per_endgame"] = int(scale[1]) if len(scale) > 1 else 1
            steps.append(step)
            continue

        match = SPAWN.match(line)
        if match:
            span = match.group("span")
            conservatise = False
            inner = 0
            while index < len(lines):
                if lines[index] == "{":
                    inner += 1
                elif lines[index] == "}":
                    inner -= 1
                    if inner <= 0:
                        break
                elif lines[index].startswith("conservatise("):
                    conservatise = True
                index += 1
            index += 1
            steps.append({
                "op": "spawn",
                "span": int(span) if span.isdigit() else span,
                "plus": int(match.group("plus")),
                "conservatise": conservatise,
                "when": combine(guards, None),
            })
            continue

        match = SETVAR.match(line)
        if match:
            steps.append({"op": "var", "name": match.group("name"),
                          "value": int(match.group("value")),
                          "when": combine(guards, pending)})
            pending = None
            continue

        if line.startswith("if(") and line.endswith(")"):
            pending = parse_condition(line[3:-1])
            chain = [pending]
            continue
        if line.startswith("elseif(") and line.endswith(")"):
            own = parse_condition(line[7:-1])
            pending = otherwise(chain, own)
            chain = chain + [own]
            continue
        if line == "else":
            pending = otherwise(chain, None)
            chain = []
            continue

        raise SystemExit("unrecognised encounter statement: %r" % line)
    return steps, index


def gdscript(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if value is None:
        return "{}"
    if isinstance(value, str):
        return '&"%s"' % value
    if isinstance(value, list):
        return "[%s]" % ", ".join(gdscript(item) for item in value)
    if isinstance(value, dict):
        return "{%s}" % ", ".join('&"%s": %s' % (key, gdscript(item))
                                  for key, item in value.items())
    raise SystemExit("cannot write %r" % value)


def main() -> int:
    text = SOURCE.read_text(errors="replace")
    body = text[text.index("void prepareencounter"):text.index("char addsiegeencounter")]
    lines = squash(body)

    # The three blocks, in the order the original runs them.
    alarm = {}
    ccs = []
    sites = {}

    index = 0
    while index < len(lines):
        if lines[index] == "switch(sitetype)":
            index, alarm = parse_switch(lines, index + 1)
            continue
        if lines[index] == "if(location[cursite]->renting==RENTING_CCS)":
            ccs, index = parse_body(lines, index + 1)
            continue
        if lines[index] == "switch(type)":
            index, sites = parse_switch(lines, index + 1)
            continue
        index += 1

    if not sites:
        raise SystemExit("no site encounter tables found")

    write(alarm, ccs, sites)
    print("wrote %s: %d sites, %d alarm responses"
          % (OUT.relative_to(ROOT), len(sites), len(alarm)))
    return 0


def parse_switch(lines, index):
    """Reads a switch whose cases are site types, sharing bodies as written."""
    table = {}
    labels = []
    if index < len(lines) and lines[index] == "{":
        index += 1
    while index < len(lines):
        line = lines[index]
        match = CASE.match(line)
        if match:
            labels.append(match.group("site").lower())
            index += 1
            continue
        if line == "default:":
            labels.append("*")
            index += 1
            continue
        if line == "}" and not labels:
            index += 1
            break
        if not labels:
            index += 1
            continue
        steps, index = parse_body(lines, index)
        for label in labels:
            table[label] = steps
        labels = []
        # A braced case leaves its closing brace behind; step over it, but only
        # when another case follows, so the switch's own brace still ends this.
        if index + 1 < len(lines) and lines[index] == "}" \
                and (CASE.match(lines[index + 1]) or lines[index + 1] == "default:"):
            index += 1
    return index, table


def write(alarm, ccs, sites):
    lines = [
        "class_name EncounterRules",
        "extends RefCounted",
        "## Who is in a building when the squad walks in.",
        "##",
        "## GENERATED by tools/extract_encounters.py from prepareencounter() in",
        "## src/sitemode/newencounter.cpp — do not edit by hand.",
        "##",
        "## Each entry is an ordered list of steps. A weight step adds to or",
        '## replaces a creature type\'s weight, optionally under a &"when"',
        "## condition; a spawn step draws that many people from the weights as",
        "## they stand at that point. Order is load-bearing: the same creature",
        "## is often weighted twice and the second statement may replace rather",
        "## than add, and a spawn can sit in the middle of the list.",
        "",
        "## The response that arrives once the alarm has been up a long time.",
        "const ALARM_RESPONSE: Dictionary = {",
    ]
    for site in sorted(alarm):
        lines.append('\t&"%s": %s,' % (site, gdscript(alarm[site])))
    lines += ["}", "",
              "## Who turns out for a site the Conservative Crime Squad holds.",
              "const CCS_HELD: Array = %s" % gdscript(ccs), "",
              "## Site type -> the people who are there.",
              "const BY_SITE: Dictionary = {"]
    for site in sorted(sites):
        lines.append('\t&"%s": %s,' % (site, gdscript(sites[site])))
    lines += ["}", ""]
    OUT.write_text("\n".join(lines))


if __name__ == "__main__":
    sys.exit(main())
