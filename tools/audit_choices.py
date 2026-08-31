#!/usr/bin/env python3
"""Finds every decision the original stops to ask for, and who answers it now.

Gate J of docs/ROADMAP_PORT_COMPLETION.md asks that every meaningful decision
behind one of the original's blocking input sites is reachable through the
port's Command/Intent flow. The original asks by calling getkey(), and a call
whose answer is only "press any key to continue" is not a decision — so what
this looks for is a getkey() whose result is afterwards compared against a
particular key.

Each such site is attributed to the function it sits in, and that function's
verdict is the one tools/audit_parity.py already reached: a decision inside a
function the port names is a decision the port makes, and a decision inside a
function classified there is answered by whatever the classification says
replaced it. So this does not repeat that judgement; it proves the judgement
covers every place the original stops for an answer.

    python3 tools/audit_choices.py           # summary, and anything unaccounted
    python3 tools/audit_choices.py --list    # every asking function
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_parity import CLASSIFIED, functions, named_in_the_port, port_text, sources

# A key the answer is tested against: a character literal, a named key, or one
# of the interface constants. `getkey()` alone, with nothing compared to it, is
# the original's "press any key".
TESTED = re.compile(
    r"""(?:==\s*|<=?\s*|>=?\s*)(?:'.'|KEY_\w+|ENTER|ESC|SPACEBAR|
        interface_pg(?:up|dn))""", re.VERBOSE)

# Where a function starts: the same shape audit_parity looks for.
OPENS = re.compile(r"^([A-Za-z_][\w:<>,\s\*&]*?[\s\*&])([A-Za-z_]\w*)\s*\("
                   r"[^;]*$", re.MULTILINE)


def asking_functions() -> dict[str, str]:
    """Every function that stops for an answer, and the file it is in."""
    found: dict[str, str] = {}
    for path in sources():
        text = path.read_bytes().decode("cp437")
        opens = [(m.start(), m.group(2)) for m in OPENS.finditer(text)]
        if not opens:
            continue
        for call in re.finditer(r"\bgetkey(?:_cap)?\s*\(", text):
            # Only a call whose answer is tested against a key is a decision.
            window = text[call.start():call.start() + 2000]
            if not TESTED.search(window):
                continue
            owner = ""
            for start, name in opens:
                if start > call.start():
                    break
                owner = name
            if owner:
                found.setdefault(owner, str(path.relative_to(
                    Path(__file__).resolve().parent.parent)))
    return found


def main() -> int:
    asking = asking_functions()
    mentioned = named_in_the_port(port_text())
    ported, classified, unaccounted = [], [], []
    for name in sorted(asking):
        if name in mentioned:
            ported.append(name)
        elif name in CLASSIFIED:
            classified.append(name)
        else:
            unaccounted.append(name)

    if "--list" in sys.argv:
        for name in sorted(asking):
            verdict = "the port makes this decision" if name in mentioned \
                else CLASSIFIED.get(name, "UNACCOUNTED")
            print("%-38s %-34s %s" % (name, asking[name], verdict))

    print("%d functions stop for a decision." % len(asking))
    print("  %d are named by the port." % len(ported))
    print("  %d are classified in audit_parity.py." % len(classified))
    print("  %d are unaccounted for." % len(unaccounted))
    for name in unaccounted:
        print("    %-36s %s" % (name, asking[name]))
    return 1 if unaccounted else 0


if __name__ == "__main__":
    raise SystemExit(main())
