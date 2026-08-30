# Architecture & code map

Binding rules for the Godot 4.6 rewrite. The point of this document is that no file in the
new codebase should ever be ambiguous about where it goes or what it may touch.

Locked decisions:

- **Pure GDScript.** No GDExtension, no C++ carried forward.
- **Parity first.** Mechanical parity with the C++ original, verified by golden traces,
  before any new mechanic ships.
- **Branding is a variable.** Ships as "Revolutionaries" pending a final name.

## 1. Layer rule

Four layers. Dependencies point **down only**. A CI check greps for violations.

```
  ui/        Godot scenes, Controls, input.       May read core/ state, may send Intents.
  ─────────────────────────────────────────────── never imported by anything below
  app/       Session, save/load, event routing.   Owns the loop that drives core/.
  ───────────────────────────────────────────────
  core/      Simulation. Headless, deterministic. May not reference Node, scenes, print,
             OS time, or randf(). Uses core/rng.gd only.
  ───────────────────────────────────────────────
  data/      Content Resources (.tres) + schema.  Depends on nothing.
```

Enforced mechanically:

- `core/**` must not match `Node|Scene|print(|randf|randi|Time\.|Input\.|await get_tree`
- `data/**` must not match `func ` outside schema helpers — content is data, not behaviour
- `ui/**` must not mutate `GameState` directly — it emits Intents and reads state

If a rule needs breaking, the rule changes in this file first, in its own commit.

## 2. Directory map

```
game/
  project.godot
  branding.gd                   # autoload: Branding — see §6

  data/
    schema/                     # Resource class definitions (typed, exported)
      creature_type.gd  weapon_type.gd  armor_type.gd  clip_type.gd
      loot_type.gd      vehicle_type.gd augment_type.gd shop_table.gd
      site_map.gd       law_def.gd      activity_def.gd
    creatures/*.tres            # generated from art/creatures.xml
    weapons/*.tres              # art/weapons.xml
    armor/*.tres                # art/armors.xml, art/masks.xml
    vehicles/*.tres             # art/vehicles.xml
    augments/*.tres  clips/*.tres  loot/*.tres
    shops/*.tres                # armsdealer, deptstore, pawnshop, oubliette
    sitemaps/*.tres             # mapCSV_*_Tiles + _Specials
    text/                       # extracted game strings, {ORG} tokens applied

  core/
    rng.gd                      # xorshift128, bit-exact with src/compat.cpp
    ids.gd                      # StringName constants; no magic strings anywhere else
    events.gd                   # Event vocabulary (§4)
    intents.gd                  # Intent vocabulary (§4)
    game_state.gd               # the single mutable root; replaces 123 C++ globals

    state/                      # dumb data holders + invariants, no cross-system logic
      creature.gd  skills.gd  attributes.gd  augment.gd
      item.gd  weapon.gd  armor.gd  clip.gd  loot.gd  money.gd
      squad.gd  location.gd  site_state.gd  vehicle.gd
      law.gd  government.gd  public_opinion.gd
      ledger.gd  calendar.gd  news_story.gd  siege.gd

    systems/                    # all behaviour. One concern per file. See §3.
      creature/    recruit.gd  train.gd  heal.gd  augment.gd  naming.gd  death.gd
      items/       equip.gd  quality.gd  shop.gd  loot_table.gd
      daily/       daily_turn.gd  activities/*.gd  siege.gd  interrogation.gd  dating.gd
      monthly/     monthly_turn.gd  finances.gd  sleepers.gd  justice.gd  endgame.gd
      politics/    laws.gd  elections.gd  opinion.gd  amendments.gd
      news/        generate.gd  major_event.gd  broadcast.gd
      combat/      resolve.gd  attack.gd  damage.gd  morale.gd  chase_car.gd  chase_foot.gd
      site/        infiltrate.gd  stealth.gd  alarm.gd  talk.gd  specials.gd  escape.gd
      world/       locations.gd  travel.gd  safehouse.gd  cities.gd

    save/
      serializer.gd  migrations.gd   # versioned, self-describing. Not the old fwrite format.

  app/
    session.gd                  # owns GameState, pumps systems, routes Events/Intents
    event_bus.gd                # typed signal fan-out to ui/
    input_queue.gd              # Intents in, one at a time, replayable from a script
    headless_main.gd            # CLI entry: --seed N --script file --trace out.jsonl

  ui/
    theme/                      # one theme resource, no per-scene inline styling
    screens/                    # safehouse, squad, site, chase, news, politics, review
    widgets/                    # creature_card, skill_bar, item_row, log_view, map_view
    adapters/                   # Event -> widget calls. The ONLY place that knows both.

tests/
  unit/                         # per-system, GUT
  golden/                       # recorded C++ traces + replay assertions
tools/
  extract_data.py               # art/*.xml + mapCSV_* -> data/*.tres
  trace_harness/                # patched C++ build: fixed seed, scripted input, JSONL dump
```

## 3. System file contract

Every file under `core/systems/` follows the same shape. This is the anti-spaghetti rule:

```gdscript
class_name DailyTurn
extends RefCounted

# 1. Pure functions or a small stateless class. No singletons, no globals.
# 2. Takes GameState + RNG explicitly. Never reaches for them.
# 3. Returns an Array[Event]. Never draws, never prints, never awaits.
# 4. When a player decision is needed, returns a PendingIntent instead of blocking.

static func run(state: GameState, rng: Rng) -> Array[Event]:
    ...
```

Consequences worth stating plainly:

- A system is testable by constructing a `GameState`, a seeded `Rng`, and asserting on the
  returned events. No engine, no scene tree.
- No system may call into another system's *internals*. Cross-system work goes through
  `GameState` or through an explicit call to that system's public `static func`.
- Files stay small. Target ≤300 lines. `sitemode.cpp` at 2,784 lines becomes
  `site/infiltrate.gd` + `stealth.gd` + `alarm.gd` + `talk.gd` + `specials.gd` + `escape.gd`.
- No file named `misc`, `common`, `utils`, or `helpers`. If something doesn't have a home,
  the module boundary is wrong — fix the boundary.

## 4. Events and Intents — the seam

This is what replaces 8,400 `addstr` calls and 736 blocking `getkey()` calls.

**Event** = something that happened. Emitted by `core/`, consumed by `ui/adapters/` and by
the golden-trace comparator. Data only, no formatting, no colour codes:

```gdscript
Event.new(&"creature_trained", {creature = id, skill = &"tailoring", amount = 1})
Event.new(&"armor_destroyed",  {creature = id, armor = &"black_robe"})
```

Display text lives in `data/text/` keyed by event type, so the same event can render as a
log line, a toast, or a tooltip — and a new UI never requires touching `core/`.

**Intent** = a decision the player must make. The sim *returns* one and stops; it never
waits. `app/input_queue.gd` supplies the answer and resumes. Because Intents are data, a
whole playthrough is a file of them — which is exactly what makes golden traces replayable.

## 5. Extensibility (the "easy to add onto" requirement)

- **Content is data.** New weapon, creature, augment, site map, law → a new `.tres`. No code.
- **Registries, not switch statements.** The C++ code is full of `switch(LCSrandom(n))` over
  hardcoded cases. Each becomes a table in `data/` iterated by one system. Adding a daily
  activity means adding an `activity_def.tres` and one `activities/*.gd` file that registers
  itself; nothing else changes.
- **`core/ids.gd` holds every StringName.** No magic strings in systems. Renaming a skill is
  one line.
- **New mechanics land as new files in `core/systems/`**, not as edits threaded through
  existing ones. If a feature requires touching more than ~3 existing files, that is the
  signal the seam is in the wrong place.

## 6. Branding

263 strings in the C++ source name the organisation. None are hardcoded in the rewrite.

`branding.gd` (autoload, `Branding`) exposes:

```gdscript
const GAME_TITLE  := "Revolutionaries"
const ORG_NAME    := "Revolutionaries"    # was "Liberal Crime Squad"
const ORG_SHORT   := "RVL"                # was "LCS"
const ORG_MEMBER  := "Revolutionary"      # was "Liberal"
```

All game text in `data/text/` uses `{GAME_TITLE}`, `{ORG_NAME}`, `{ORG_SHORT}`,
`{ORG_MEMBER}` tokens, resolved on load. Renaming the game later is a four-line edit and a
reimport, not a sweep of the codebase. `project.godot` reads the title from the same source.

Note: the ideological vocabulary ("Liberal"/"Conservative") is *game mechanics* in LCS, not
branding — it names alignment values. It is tokenised the same way so it can be re-themed,
but that is a design decision to make deliberately, not incidentally.

## 7. Definition of done, per system

A system is done when:

1. Its unit tests pass.
2. It replays its golden C++ trace event-for-event on at least 3 seeds.
3. It is reachable from `headless_main.gd` with no UI present.
4. No file in it exceeds 300 lines or references a Node.
