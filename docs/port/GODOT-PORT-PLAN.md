# LCS → Godot 4.6 port: scaffolding plan

Working notes for converting Liberal Crime Squad (C++/curses) into a modern Godot 4.6 game
with new mechanics and a new UI. This document is the *scaffolding* — what has to exist
before a bulk conversion pass is worth attempting.

## 1. What we are actually porting

`src/` is 118,636 lines, but most of it is not game code:

| Area | Lines | Fate |
|---|---|---|
| `src/sdl/` (vendored SDL2 headers + .lib) | 31,471 | **Delete.** Godot replaces it. |
| `src/pdcurses/`, `cursesgraphics.*`, `cursesmovie.*` | ~9,000 | **Delete.** Godot UI replaces it. |
| `src/cmarkup/` (XML parser) | 5,971 | **Delete.** Godot `XMLParser` / Resources. Also commercially encumbered — see LICENSING-NOTES.md. |
| `src/sandbox/` (ad-hoc tests) | 3,442 | Reference only; replaced by GUT/gdUnit tests. |
| **Real game code** | **~62,000** | **Port.** |

Real game code by module:

| Module | Lines | Content |
|---|---|---|
| `sitemode/` | 14,958 | Tactical site infiltration, maps, dialogue, stealth, shops |
| `daily/` | 10,579 | Daily activity resolution, sieges, interrogation, calendar |
| `basemode/` | 6,413 | Safehouse, squad management, review, liberal agenda |
| `common/` | 6,046 | Shared display + actions + equipment + name generation |
| `monthly/` | 5,294 | Justice/trials, monthly turn, sleeper updates, endgame |
| `combat/` | 5,214 | Fights, car/foot chases, kidnapping |
| `creature/` | 4,966 | Creature model, skills, attributes, types, augmentations |
| `news/` | 4,896 | News generation, major events |
| `title/` | 3,382 | New game, save/load, high scores |
| `items/` | 2,348 | Weapon/armor/clip/loot type hierarchy |
| `politics/` | 2,193 | Laws, elections, public opinion |
| `locations/` | 1,366 | World locations, sieges |
| `vehicle/` | 598 | Vehicles |
| `includes.h` + `externs.h` + `common.h` | 4,457 | ~60 enums, 123 globals, core structs |

## 2. The central problem: logic and UI are the same code

The C++ code interleaves simulation, RNG, and screen drawing line by line, then blocks
for a keypress in the middle of resolution:

```cpp
// src/daily/activities.cpp
move(8,1);
addstr(cr.name, gamelog);
switch (LCSrandom(4)) {
   case 3: addstr(" peruses some sewing magazines.", gamelog);
           cr.train(SKILL_TAILORING,1); break;   // <-- state mutation inside a draw
}
getkey();                                        // <-- blocks mid-resolution
```

Counts outside the vendored dirs: **6,186 `addstr` + 427 `mvaddstr` + 1,845 `set_color`
= ~8,400 draw calls, and 736 blocking `getkey()` calls**, spread across 49 files.

This is why a naive transliteration fails. Port it literally and you get a curses emulator
in Godot — every `getkey()` becomes an `await`, and the "modern UI" is impossible because
the layout is baked into cursor coordinates.

**The port must split the program in two:**

- **Sim core** — headless, deterministic, no I/O. Advances state and *returns* a list of
  structured events instead of drawing. Runnable from a command line with no window.
- **Presentation** — Godot scenes that consume the event stream and render it however we
  like. New UI lives entirely here; the sim never knows a screen exists.

Every `addstr("...")` becomes an event with typed fields; every `getkey()` becomes a
*request for a decision* returned to the caller, not a block. That inversion is the port.

## 3. Proposed layout

```
game/
  project.godot                 # Godot 4.6
  core/                         # headless sim — NO node/UI references
    rng.gd                      # xorshift128 port, bit-exact with C++
    state/                      # GameState, Squad, Creature, Location, Law, Vehicle
    systems/                    # daily/, monthly/, combat/, sitemode/, politics/, news/
    events.gd                   # typed event structs the sim emits
    intents.gd                  # typed decisions the sim requests
    save/                       # versioned JSON/binary serializer (NOT the old fwrite format)
  data/                         # .tres Resources generated from art/*.xml
  ui/                           # Godot scenes: safehouse, site view, squad, news, politics
  audio/
  tests/
    golden/                     # recorded C++ traces (see §5)
    unit/
tools/
  extract_data.py               # art/*.xml + mapCSV_* -> data/*.tres
  trace_harness/                # patched C++ build that dumps a deterministic event trace
```

Hard rule: nothing under `core/` may reference a Node, a scene, or `print`. Enforced by a
CI grep. This is what keeps the "modernize the UI" goal achievable later.

## 4. Data pipeline (do this first — it is the cheap, safe win)

`art/*.xml` already externalizes most content: `creatures.xml` (60KB), `weapons.xml` (46KB),
`armors.xml` (28KB), `vehicles.xml` (25KB), `masks.xml`, `augmentations.xml`, `clips.xml`,
`loot.xml`, plus shop tables (`armsdealer`, `deptstore`, `pawnshop`, `oubliette`) and 18
`mapCSV_*` tile/special maps.

Convert these to Godot `Resource` files with a script, not by hand. Once `data/` exists and
loads in Godot, a large fraction of the "content" is ported with zero logic risk, and the
type hierarchy in `core/state/` has something concrete to be shaped against.

The `.cmv` / `.cpc` files are ASCII-art cutscenes and the `bigletters` / `newspic` /
`newstops` arrays are embedded ASCII bitmaps. These are almost certainly *not* worth porting
faithfully — flag them as replaced by new art in the modernization pass.

## 5. Verifying the logic actually converted (the part that usually gets skipped)

The RNG is a 4-word xorshift (`src/compat.cpp: r_num()`), seeded and *saved with the game*.
It is trivially reproducible in GDScript with 32-bit masking, and `LCSrandom`'s
`max*(r-1)/0xffffffff` is exact in a 64-bit float. **Determinism is therefore recoverable,
and that gives us differential testing:**

1. Patch the C++ build (`tools/trace_harness/`) to (a) accept a fixed seed, (b) accept a
   scripted keystroke file instead of stdin, and (c) dump every state-mutating event as
   JSON lines — not the screen text, the *events*.
2. Record golden traces: N seeds × scripted playthroughs covering each mode (base, site,
   chase, daily, monthly, trial, election, endgame).
3. The Godot sim core replays the same seed + same scripted decisions and must emit the
   same event stream.

Any divergence is a porting bug with an exact line number. Without this, "ensure all game
logic got converted properly" is unverifiable and the answer is always "probably".

Build the trace harness **before** the bulk conversion. It is a few hundred lines against a
codebase we are about to delete, and it is the only objective correctness signal we get.

## 6. Save games

Do not port `src/title/saveload.cpp`. It is raw `fwrite` of structs — endian-, padding- and
compiler-dependent, and it serializes the RNG state and every global in declaration order.
The new game gets a versioned, self-describing save from day one. Old saves are not
transferable; say so up front.

## 7. Sequencing

Phase 0 — scaffolding (this doc's job)
  - [ ] Godot 4.6 project skeleton with the `core/` / `ui/` split and the no-Node CI check
  - [ ] `tools/extract_data.py`: XML + mapCSV → `.tres`
  - [ ] `rng.gd` + a test proving bit-exactness against C++ for 10k draws
  - [ ] `tools/trace_harness/`: fixed seed, scripted input, JSON event dump
  - [ ] Golden traces recorded for each game mode
  - [ ] Event/intent vocabulary drafted from a sweep of the ~8,400 draw sites

Phase 1 — state model
  - Creature, Item hierarchy, Location, Squad, Law, Vehicle, Ledger, date/calendar
  - The 123 globals in `externs.h` collapse into one `GameState` resource

Phase 2 — systems, in dependency order
  - creature/items → politics/law → daily → monthly → news → combat → sitemode
  - Each system green against golden traces before the next starts

Phase 3 — UI
  - First pass mirrors the old information architecture so traces stay comparable
  - Then the modernization pass: real layout, mouse, tooltips, map view, squad panel

Phase 4 — new mechanics
  - Only once Phase 2 is trace-green. New mechanics before parity means no baseline to
    diff against, and every bug is ambiguous.

## 8. Open decisions

1. **Sim core language.** Pure GDScript (simple, hackable, slow-ish but this game is not
   perf-bound) vs. C++ GDExtension wrapping the existing logic (fast to reach parity, but
   drags the old architecture and the old bugs forward, and makes new mechanics harder).
   Recommendation: **pure GDScript**, given the goal is new mechanics, not preservation.
2. **Parity target.** Full mechanical parity first, then diverge? Or port selectively and
   accept divergence from the start? Parity-first is slower but is the only version where
   the golden-trace harness pays for itself.
3. **Scope of "one-shot conversion."** 62k lines of interleaved C++ is not a single pass.
   Realistic unit of one-shot work is one system at a time against a trace.
4. **Setting/branding.** The repo is named Revolutionaries-Game; a rename away from LCS
   branding is worth deciding early since it touches every string.
