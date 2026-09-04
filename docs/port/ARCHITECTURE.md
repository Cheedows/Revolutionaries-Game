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
- `ui/**` must build its controls out of `ui/theme/atoms.gd` and the widgets over
  it, never `Label.new()`/`Button.new()`/`LineEdit.new()` or a literal `Color`,
  and must space them off the scale in `ui/theme/metrics.gd`
  (`tools/audit_design.py`; its exemption list is empty and adding to it is a
  decision, not a convenience)
- Layout is verified by rendering it: `tools/check_layout.sh` draws every screen
  under `xvfb` at four sizes and fails if anything is drawn outside the thing
  meant to contain it, or has wrapped into a column of single letters. The
  headless suite cannot see either — a container only lays its children out
  inside a live tree, and `--script` has none
- Colour is verified too: `tools/audit_contrast.py` fails on any text/background
  pair below its WCAG threshold, and on any scheme whose two political sides
  collapse into one colour under simulated colour blindness

### The design system

Six rules, each of which exists because breaking it shipped:

1. **Nothing below a screen names a colour or a number.** Widgets ask `Atoms`
   for a control and `Metrics` for a size. Colours come from `Palette`, which
   is a set of swappable schemes (`Palette.use`), so a widget that names a hex
   value is a widget that cannot follow a scheme.
2. **Gaps come off the scale** — 4, 8, 12, 16, 24, all multiples of four. The
   scale has to be able to say what the screens already say; an earlier one
   dropped 12 and grew the safehouse past the bottom of the window.
3. **Depth is a lighter surface, not a shadow.** Page, panel, control. There is
   no drop shadow in this interface.
4. **Wrapping is opt-in** (`Atoms.wrapped`). Most text here is a short value in
   a row; wrapping it by default drew a whole column as single letters.
5. **Type barely changes size.** Four steps spanning six points, because the
   original is a terminal where everything is one size and the hierarchy is
   carried by colour, capitals and position.
6. **Colour is never the only thing saying something.** State is carried by the
   control (a switch that is on, a row that is refused), and alignment is
   written in words beside its colour.
7. **Nothing that cannot be undone happens on one press.** Destructive actions
   are `ConfirmButton`s, drawn in the opposition's colour, which arm on the
   first press and act on the second — the shape the original uses (`C -
   Confirm`).

8. **One thing at a time, and the page stays behind it.** A panel comes to the
   front in a `Sheet` — over a scrim, edge to edge on a phone and centred on a
   desk — rather than taking a share of the page. Tapping the scrim or pressing
   escape is the way back, and the page underneath stops scrolling while it is
   up, so the only thing that moves is the thing being read.

The components, in the order a screen reaches for them: `Sheet` (what is in
front), `Card` (a panel: head, notice, scrolling body, action bar),
`PanelHeader`, `ActionBar`, `IntentDialog`, `ListRow`, `ToggleRow` /
`OptionRow` over `RowButton`, `ConfirmButton`, and `Atoms` for everything
smaller. A button is one of four weights — `primary` (the one action on the
screen), `button` (the default), `quiet` (Close, Back), `danger` (destroys
something). `PressFeel` gives every one of them a press to feel, because a
touchscreen has no hover and a tap with no response reads as a tap that
missed.

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
    theme/                      # palette, scale, theme, and atoms — the design system
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
- Files stay small. Target ≤300 lines. Two kinds of file are exempt, for the
  same reason: their length is content rather than complexity. Generated files,
  marked with a "GENERATED by" line near the top, are as long as the thing they
  were lifted from. Files under `data/` are lists — `data/` may hold no
  behaviour at all, which the checker already enforces, so a long one is a long
  list and splitting it in half at an arbitrary entry helps nobody. `sitemode.cpp` at 2,784 lines becomes
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
