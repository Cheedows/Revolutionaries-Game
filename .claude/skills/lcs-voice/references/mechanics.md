# Attaching prose to the simulation

Read this before touching `core/`, or before adding a string that isn't in the
original. Getting the wording right is half the job; the other half is wiring
it so the words survive contact with the port's architecture and its audits.

Contents: [Carry the roll](#carry-the-roll) · [Where prose may live](#where-prose-may-live) ·
[How the audit matches](#how-the-audit-matches) · [Writing an exception](#writing-an-exception) ·
[The other audits](#the-other-audits) · [A worked example](#a-worked-example)

---

## Carry the roll

This is the port's recurring failure mode, and it has cost several rounds of
rework. The original picks its wording with `pickrandom()`:

```cpp
template <class Container> inline typename Container::value_type&
pickrandom(const Container& x)
{
   return const_cast<typename Container::value_type&>(x[LCSrandom(len(x))]);
}
```

That call **consumes an RNG draw**. So the choice of words is not decoration —
it is part of the deterministic stream that golden traces verify. Two things
follow.

**One: you may not add a roll to make prose prettier.** An attempt to add a
car-nerves draw once took a probe from 417 draws to 2,042 and was reverted.
The recorded trace is the oracle. If the original did not roll there, you do
not roll there.

**Two: when the original does roll, the index must reach the adapter.** The
bug looks like this:

```gdscript
# core/systems/... — WRONG
var line := rng.below(LINES.size())     # draw consumed, index thrown away
events.append(Event.new(Event.BOUNCER_REFUSED, {}))
```

```gdscript
# ui/adapters/... — and so the adapter can only say
return "They look the squad over."      # one bland line for sixty
```

The fix is to carry it:

```gdscript
events.append(Event.new(Event.BOUNCER_REFUSED, {"line": line, "reason": reason}))
```

```gdscript
var lines: Array = CLUB.get(reason, [])
return String(lines[int(data.get("line", 0)) % lines.size()])
```

If you are writing a set of alternative lines, your first question is always:
*does the event payload carry which one?* If not, the set is unreachable and
`audit_reach.py` will say so.

---

## Where prose may live

From `docs/port/ARCHITECTURE.md`, and enforced by `tools/check_layers.py`:

- `core/` is deterministic and headless. It emits **structured Events** — an
  event type and a data dictionary of ids, indexes and flags. No prose, no
  `print()`, no `Time.`, no engine RNG.
- `ui/adapters/*_text.gd` turn Events into sentences. This is where the writing
  goes. Adapters read state and say it; they never mutate `GameState`.
- `ui/widgets/` and `ui/screens/` hold labels, headings and button text.
- Content that is really data — item names, augmentation descriptions, story
  tables — belongs in `data/` Resources where practical.

Files are capped at 300 lines. A text adapter that outgrows it splits by
subject (`door_text.gd` came out of `event_text.gd` this way), not by
alphabet.

---

## How the audit matches

`tools/audit_voice.py` extracts every player-facing string literal from
`game/ui/**/*.gd` and looks for it in the original. Understanding its rules
saves a lot of arguing with it.

**The haystack** is two things joined: every string literal in non-vendored
`src/**/*.{cpp,h}` (read as latin-1, because the original is a CP437 terminal),
and every text node in `art/*.xml`. Item names count as the original's words.

**Fragments.** Your string is split at its format holes (`%s`, `%d`, `{...}`)
and each fragment must be found. Fragments shorter than four characters or
without three consecutive letters are ignored — a string made only of holes has
no voice to check and passes.

**Two haystacks.** Each fragment is looked for in the strings one-per-line
*and* in the same strings run together in source order. The second is what a
news story actually reads like: the original assembles one from a run of
`strcat()` calls, so a sentence of it spans several literals. This is why
splitting your GDScript literals at the same points the original splits its
calls is what makes a carried line verifiably carried.

**Punctuation glued to a hole** — `$%d`, `(%s)` — belongs to the number. A
fragment is tried whole first (so `[tar]` matches), then again with brackets,
quotes and `$` stripped from its ends.

**Case is presentation.** Matching is case-insensitive, so a button may take a
line out of `(Press A to have your parents reconsider)` and capitalise it.

**Split sentences.** A fragment the original prints in two halves still counts,
if it can be cut at a space into two halves of at least ten characters that are
both present. Ten, so that finding both halves means something.

**Practical consequences.** A label like `"Wanted for: %s"` fails if the
original never wrote `Wanted for:`, even though it wrote `Wanted for` nowhere
and `charged with` somewhere. Two moves usually fix it: use the original's own
phrase (`"The defendant is charged with %s"`), or separate the label from the
value with spaces instead of a colon (`"SKILL   %s"`), which leaves `SKILL` as
the fragment and `SKILL` is a real column header.

Run it after every change to `game/ui/`:

```bash
python3 tools/audit_voice.py
```

---

## Writing an exception

`tools/voice_exceptions.json` maps a string to a reason. The bar is: **the
reason has to say what the original does instead.** "It reads better" is not a
reason; the original's phrasing is the game's voice and tidier is worse.

Good reasons name the mechanism:

> `"Not with the squad, so there is nothing to hand them."` — *the original's
> equip screen only ever lists the squad, so it never has to say why somebody
> cannot be handed anything; the port's record is opened from the roster, where
> they may not be in the squad at all*

> `"%d in the room."` — *the original shows who is in the room as a drawn row
> of encounter portraits, not as a count; the port says how many because the
> phone shows the map and the room in one line*

> `"Ammunition: %s"` — *the original folds spare clips into the weapon string
> as a (loaded/spare) count (Creature::get_weapon_string); the port lists them,
> because a phone shows the record as lines rather than one packed row*

The three legitimate categories, in practice:

1. **The original drew it, it didn't write it.** Character maps, colour, column
   position, portraits. A touchscreen has to say in words what a terminal said
   in glyphs.
2. **The original never reached this case.** An empty roster, a failed save, a
   member who isn't in the squad. The terminal's flow made it impossible.
3. **The port's structure differs for a stated reason.** Lines instead of a
   packed row, a running log instead of a screen that clears.

If your reason isn't one of those three, you probably haven't looked hard
enough for the original's words. Look again — `grep -rn` over `src/` is cheap,
and the original wrote 10,760 string literals, 3,474 of them prose.

`tools/voice_backlog.json` is `[]`. It stays `[]`. It is not a place to put new
lines.

---

## The other audits

Prose work trips these too:

- **`audit_content.py`** — 302 entries of the original's content must all be
  present. Cutting a story to a summary fails here.
- **`audit_reach.py`** — 587 entry points must be reachable. A table of thirty
  lines that the event payload can only index the first of fails here.
- **`audit_parity.py` / `audit_state.py` / `audit_choices.py`** — the port must
  still account for every function, global and decision. Adding a roll to pick
  a nicer line moves the RNG and fails the golden traces instead.

Write the strongest deterministic probe you can with each behaviour. If the
original's harness can't reliably reach a line, build a fixture that does
rather than leaving it unverified.

---

## A worked example

The execution the state carries out on a member on death row. It is worth
reading because it went in wrong first, and the way it was wrong is the way
this keeps going wrong.

The original picks the method with `pickrandom()`, which is `LCSrandom()`, so
picking it **costs a draw** — and the list it picks from depends on the death
penalty law. The port was not making that draw at all. Rare enough that no
trace had ever reached it, and wrong: every draw after an execution would have
been the wrong one.

```gdscript
# core/systems/monthly/justice/prison_month.gd
## How many ways there are of doing it, by what the law allows. A country that
## permits cruel and unusual punishment has twenty-four; an ordinary one has
## four; a Liberal one that still executes people has the one it calls
## painless. There is no entry for an Elite Liberal country: it has abolished
## the death penalty, and the sentence is commuted above before it gets here.
const METHODS := {-2: 24, -1: 4, 0: 4, 1: 1}

var ways := int(METHODS.get(state.law.get_value(&"deathpenalty"), 4))
var method := rng.below(ways)                       # the draw the original makes
...
return [Event.new(Event.EXECUTED,
        {"creature": prisoner.id, "method": method, "cruel": ways > 4})]
```

```gdscript
# ui/adapters/prison_text.gd
const EXECUTION_METHODS: Array[String] = [
    "lethal injection", "hanging", "firing squad", "electrocution",
]

const CRUEL_METHODS: Array[String] = [
    "beheading", "drawing and quartering", "disemboweling",
    "one thousand cuts", "feeding the lions", ...
]

static func _executed(state: GameState, data: Dictionary) -> String:
    var ways: Array[String] = CRUEL_METHODS if bool(data.get("cruel", false)) \
            else EXECUTION_METHODS
    var method: String = ways[int(data.get("method", 0)) % ways.size()]
    return "FOR SHAME: Today, the Conservative Machine executed %s by %s." \
            % [_who(state, data), method]
```

Everything this skill argues for is in those twenty lines. The draw is in
`core/` and sits where the original's sits in the stream. The index rides in
the payload, so all twenty-four endings are reachable and `audit_reach.py` is
satisfied. The law selects the vocabulary rather than the narrator selecting a
tone. The list is written out in full instead of summarised. The sentence
itself is short, declarative, and does not flinch — `FOR SHAME: Today, the
Conservative Machine executed Ida Kell by chipper-shredder.` — and every word
of it is the original's, so `audit_voice.py` passes without an exception.

Three things to check before you call any prose change done:

1. Does the draw exist, in `core/`, in the original's position in the stream?
2. Does the index reach the adapter in the event payload?
3. Does `python3 tools/audit_voice.py` pass without a new exception — and if it
   needs one, does the reason say what the original does instead?
