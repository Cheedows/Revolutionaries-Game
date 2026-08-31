#!/usr/bin/env python3
"""Generates game/core/sleeper_rules.gd from sleeper_influence().

How much a sleeper shifts the country is three switches in
src/monthly/sleeper_update.cpp: one adding a professional skill to their base
power, one multiplying it by how much their job is worth, and one spending the
result on the issues that job gets to talk about.

All three lean on C's fall-through — a judge collects the lawyer's issues on
top of their own, an eminent scientist collects the lab tech's — so the tables
are read back out with the fall-through resolved rather than transcribed by
hand. Anything this parser does not recognise is a hard error: a case dropped
in silence would quietly halve a sleeper's worth.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "src" / "monthly" / "sleeper_update.cpp"
OUT = ROOT / "game" / "core" / "sleeper_rules.gd"

CASE = re.compile(r"case\s+(CREATURE_[A-Z0-9_]+)\s*:")
SKILL = re.compile(r"power\+=cr\.get_skill\(SKILL_([A-Z0-9_]+)\)\s*;")
MULTIPLY = re.compile(r"power\*=(\d+)\s*;")
VIEW = re.compile(r"libpower\[VIEW_([A-Z0-9_]+)\]\+=power\s*;")

# The cases that do something the tables cannot describe. Each is written out
# by hand in the generated file's companion code and must not be silently
# folded into a plain list of views.
SPECIAL = {
    "CREATURE_RADIOPERSONALITY",
    "CREATURE_NEWSANCHOR",
    "CREATURE_POLITICIAN",
    "CREATURE_FIREFIGHTER",
}


def function_body(text, signature):
    start = text.index(signature)
    open_brace = text.index("{", start)
    depth = 0
    for index in range(open_brace, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return text[open_brace + 1:index]
    raise SystemExit("unterminated function: %s" % signature)


def switch_bodies(body):
    """Every top-level switch in [body], as source text."""
    found = []
    for match in re.finditer(r"\bswitch\s*\([^)]*\)\s*\{", body):
        depth = 0
        for index in range(match.end() - 1, len(body)):
            if body[index] == "{":
                depth += 1
            elif body[index] == "}":
                depth -= 1
                if depth == 0:
                    found.append(body[match.end():index])
                    break
    return found


def groups(switch):
    """Splits a switch into [(labels, statements)] runs, in source order.

    A run is a stack of `case` labels followed by the statements they share.
    Fall-through is resolved afterwards, by walking the runs backwards.
    """
    runs = []
    labels = []
    statements = []
    for line in switch.splitlines():
        # A trailing comment on a case label would otherwise read as the
        # statement that ends the run, splitting a stack of labels in two.
        stripped = re.sub(r"/\*.*?\*/", "", line.split("//")[0]).strip()
        if not stripped:
            continue
        label = CASE.match(stripped)
        if label:
            if statements:
                runs.append((labels, statements))
                labels, statements = [], []
            labels.append(label.group(1))
            rest = stripped[label.end():].strip()
            if rest:
                statements.append(rest)
            continue
        if stripped.startswith("default:"):
            if statements:
                runs.append((labels, statements))
                labels, statements = [], []
            labels.append("default")
            rest = stripped[len("default:"):].strip()
            if rest:
                statements.append(rest)
            continue
        statements.append(stripped)
    if labels or statements:
        runs.append((labels, statements))
    return runs


def resolve(switch, collect):
    """Maps each case label to what it collects, fall-through included.

    [collect] turns a run's statements into a list; a run that does not end in
    a `break` or a `return` inherits everything the next run collects.
    """
    runs = groups(switch)
    trailing = []
    result = {}
    for labels, statements in reversed(runs):
        own = collect(statements)
        ends = any(s.startswith("break") or s.startswith("return")
                   for s in statements)
        gathered = own if ends else own + trailing
        for label in labels:
            result[label] = list(gathered)
        trailing = gathered
    return result


def skills(statements):
    found = []
    for statement in statements:
        match = SKILL.match(statement)
        if match:
            found.append(match.group(1).lower())
    return found


def views(statements):
    found = []
    for statement in statements:
        match = VIEW.match(statement)
        if match:
            found.append(match.group(1).lower())
    return found


def multipliers(switch):
    found = {}
    for labels, statements in groups(switch):
        factor = None
        for statement in statements:
            match = MULTIPLY.match(statement)
            if match:
                factor = int(match.group(1))
        if factor is None:
            raise SystemExit("a multiplier case with no multiplier: %s" % labels)
        for label in labels:
            found[label] = factor
    return found


def creature_name(label):
    return label.lower() if label == "default" else label


def render_map(name, doc, table, value):
    lines = ["## %s" % doc, "const %s := {" % name]
    for key in sorted(table):
        lines.append("\t&\"%s\": %s," % (creature_name(key), value(table[key])))
    lines.append("}")
    return "\n".join(lines)


def main():
    text = SOURCE.read_text(encoding="latin-1")
    body = function_body(text, "void sleeper_influence(")
    found = switch_bodies(body)
    if len(found) != 3:
        raise SystemExit("expected three switches in sleeper_influence(), "
                         "found %d" % len(found))
    profession, worth, issues = found

    skill_table = {k: v for k, v in resolve(profession, skills).items() if v}
    multiplier_table = multipliers(worth)
    if "default" not in multiplier_table:
        raise SystemExit("the multiplier switch has no default case")

    view_table = resolve(issues, views)
    silent = [label for label, got in view_table.items()
              if not got and label not in SPECIAL and label != "default"]
    issue_table = {k: v for k, v in view_table.items() if v and k not in SPECIAL}

    # Everything the parser saw but could not turn into a rule has to be
    # accounted for, or a sleeper quietly stops working.
    unexplained = [label for label in silent
                   if label not in _no_influence(issues)]
    if unexplained:
        raise SystemExit("cases with no rule and no reason: %s"
                         % ", ".join(sorted(unexplained)))

    OUT.write_text(_render(skill_table, multiplier_table, issue_table,
                           _no_influence(issues)), encoding="utf-8")
    print("wrote %s: %d skill rules, %d multipliers, %d issue blocks, "
          "%d harmless" % (OUT.relative_to(ROOT), len(skill_table),
                           len(multiplier_table), len(issue_table),
                           len(_no_influence(issues))))


def _no_influence(switch):
    """The block that returns without spending any power at all."""
    for labels, statements in groups(switch):
        if any(s.startswith("return") for s in statements) \
                and not views(statements):
            return sorted(labels)
    raise SystemExit("no 'return' block found in the issue switch")


def _render(skill_table, multiplier_table, issue_table, harmless):
    header = '''class_name SleeperRules
extends RefCounted
## What a sleeper is worth to the cause, by what they do for a living.
##
## Generated by tools/extract_sleeper_influence.py from sleeper_influence() in
## src/monthly/sleeper_update.cpp. Do not edit by hand.
##
## The original writes this as three switches that lean on C's fall-through — a
## judge collects the lawyer's issues on top of their own, an eminent scientist
## collects the lab tech's — so the tables below have the fall-through already
## resolved. Four professions do something no table can describe and are
## handled in code: a radio host and a news anchor subvert their own station, a
## politician picks three issues at random, and a firefighter only has an
## opinion where free speech has been outlawed.

'''
    parts = [header]
    parts.append(render_map(
        "PROFESSIONAL_SKILL",
        "The skill each profession adds to its base power, in the order the\n"
        "## original adds them.",
        skill_table,
        lambda got: "[%s]" % ", ".join('&"%s"' % s for s in got)))
    parts.append("\n\n")
    parts.append(render_map(
        "WORTH",
        "How much each profession's word is worth. Everybody not listed\n"
        "## doubles, which is what the switch's default case does.",
        {k: v for k, v in multiplier_table.items() if k != "default"},
        str))
    parts.append("\n\n## What a profession the table does not name is worth.\n")
    parts.append("const DEFAULT_WORTH := %d\n\n" % multiplier_table["default"])
    parts.append(render_map(
        "ISSUES",
        "The issues each profession gets to talk about. A profession not\n"
        "## listed here influences one issue at random.",
        issue_table,
        lambda got: "[%s]" % ", ".join('&"%s"' % s for s in got)))
    parts.append("\n\n## Professions with nothing to offer: already Liberal, or\n")
    parts.append("## in no position to do any good at all.\n")
    parts.append("const HARMLESS: Array[StringName] = [\n")
    for label in harmless:
        parts.append('\t&"%s",\n' % label)
    parts.append("]\n")
    return "".join(parts)


if __name__ == "__main__":
    sys.exit(main())
