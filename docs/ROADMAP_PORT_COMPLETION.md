# Revolutionaries — Port Completion Roadmap

**Status:** canonical active roadmap  
**Goal:** complete the remaining Liberal Crime Squad → Godot 4.6 conversion to mechanical parity in one sustained implementation push, without introducing new mechanics until parity is closed.  
**Mainline:** the repository's default/canonical branch is currently `master` (there is no `main` branch).  
**Architecture:** `docs/port/ARCHITECTURE.md` is binding.

This document is the single source of truth for conversion progress. Do not create phase-status documents, handoff documents, conversion plans, or per-system roadmaps. Update this file instead.

## 1. How much is left?

These are effort-weighted estimates, not line-count claims. The old C++ interleaves UI, input, simulation and data, so literal LOC percentages would be misleading.

| Area | Approx. complete | Approx. remaining | Notes |
|---|---:|---:|---|
| Port architecture / deterministic harness | 90–95% | 5–10% | Core/app/data/UI boundaries, RNG parity, trace harness, save framework and CI rules exist. |
| Data/state model | 80–90% | 10–20% | Major resources and state holders exist; long-tail state discovered by remaining systems may still be needed. |
| Mechanical parity overall | 40–45% | 55–60% | Creature/items/politics/world/site construction are strongest; several entire gameplay modes remain. |
| Godot UI parity shell | 10–15% | 85–90% | Safehouse/base screen proves the seam; most screens and Intent presentation do not exist. |
| **Whole Godot parity port** | **35–40%** | **60–65%** | Best current estimate including simulation and the UI needed to play all original modes. |

The work already completed is disproportionately valuable: the architecture, deterministic RNG, extracted content, trace/probe machinery, state model, save format and headless session remove much of the risk from finishing the remaining systems.

## 2. Baseline already established

Do not redo these unless a parity test proves them wrong.

- Pure GDScript Godot 4.6 project under `game/`.
- Strict `data/ -> core/ -> app/ -> ui/` dependency direction.
- Deterministic RNG compatible with the original, including temporary/side RNG stream swaps.
- Trace harness and golden/probe comparisons against the real C++ game.
- Typed content Resources for the major XML/CSV content families.
- Core state for creatures, body/wounds, items/equipment, squads, locations/sites, government/laws/opinion, calendar/ledger and related systems.
- Versioned new save serializer and migrations framework.
- Creature construction/types, attributes, checks, training, naming and a meaningful portion of spawning.
- Weapons/armor/equipment/reload and damage/wound primitives.
- Public opinion, voters, Congress, elections, Supreme Court and win-condition spine.
- Classic world/location construction, rent/eviction and site/floor-plan construction.
- A subset of daily activities including fundraising/street trade and supporting crime/reputation pieces.
- Headless Session/command/event seam.
- First functional Godot safehouse/base screen with centralized theme, roster, laws/status and event log.

## 3. Definition of complete parity

The conversion is **not done** merely because the Godot project launches or because representative systems work. It is done when all of the following are true:

1. Every reachable original gameplay mode has a Godot implementation or an explicit, documented exclusion because the original path is unreachable/obsolete.
2. Every simulation system is headless and respects `docs/port/ARCHITECTURE.md`.
3. Every player decision that used to block on `getkey()` is represented through Commands/Intents rather than UI-driven state mutation or `await` inside core logic.
4. Content remains data-driven where practical; new giant switch statements are not recreated.
5. Golden/probe coverage exists for every tractable system, using at least three deterministic seeds for end-to-end mode traces where possible.
6. Full-session tests cover new game → base management → site action → combat/chase → daily/monthly progression → justice/politics/news → win/loss paths.
7. All original player-facing modes can be operated through Godot UI, even if final art/polish is deferred.
8. `tools/run_tests.sh` and layer checks are green.
9. Remaining differences from the original are listed in this roadmap under **Deliberate parity exceptions**—not hidden in session notes.

## 4. One-shot execution order

Work top-to-bottom. Dependencies were chosen so later systems can reuse earlier behavior. Do not stop after a milestone merely to write a status document: update the checkboxes here and continue.

### A. Close foundational gaps

- [x] Finish long-tail creature spawn kits: police, agents, CCS types, armed hicks, prisoners/recursive types, thieves and every remaining `CreatureType` behavior.
  - Probed across all 106 types x 8 legal/political climates, half of them
    mid-infiltration so the site-dependent branches are reached. Every field is
    compared, raw attribute values included.
- [x] Finish context-sensitive check rules needed later: stealth, disguise and driving.
  - Disguise rules are generated from `hasdisguise()` rather than transcribed;
    the extractor refuses to run rather than drop a rule it does not recognise.
  - Probed as a table (every outfit at every kind of site, restricted or not,
    high security or not, under three legal climates) plus the rolls themselves
    for every garment and every car.
- [x] Verify safehouse ownership cleanup behavior (locks/alarms/staff-only markers).
  - Ported in `core/systems/site/site_builder.gd`; not probed, because nothing is
    held outright at the start of a game so the recorded worlds never take the
    branch. Needs a fixture once renting is playable.
- [x] Wire site-plan LOOT steps only if parity requires behavior; preserve the original no-op if it is genuinely empty.
  - Genuinely empty: `configSiteLoot::build()` has no body. Recorded as a
    parity exception below.
- [ ] Add any missing state fields discovered by the remaining systems without leaking UI concerns into `core/`.
- [ ] Add targeted probes for currently unit-tested-but-unprobed arrest/prostitution branches where practical.

**Gate A:** all foundational primitives required by later modes are callable headlessly and green.

### B. Finish base mode and daily simulation

Port the remaining behavior primarily from `src/basemode/`, `src/daily/` and shared actions.

- [ ] Recruitment and recruit management.
- [ ] Complete activity assignment semantics and a reliable parity probe/trace.
- [ ] Remaining daily activities: hacking, graffiti, prostitution, teaching, burial and other activity variants from the original.
- [ ] Dating/relationship activity behavior used by the original.
- [ ] Interrogation.
- [ ] Siege daily processing and safehouse consequences.
- [ ] Daily arrests/criminalization integration with built world and news hooks.
- [ ] Injury recovery, hospital/time-served/levelling edge cases not yet represented.
- [ ] Safehouse/base actions not already covered by Commands.
- [ ] Liberal agenda/review-management behavior that belongs to simulation rather than presentation.
- [ ] Ensure a full `advanceday()` equivalent exists as composable systems rather than one monolith.

**Gate B:** a player can remain in base mode for months, assign the full original activity set, recruit/manage people, incur arrests/sieges and advance days with deterministic parity.

### C. Finish monthly, justice and endgame simulation

Port the remaining behavior primarily from `src/monthly/` plus missing political integration.

- [ ] Monthly finances and organization expenses/income.
- [ ] Sleeper updates and sleeper actions.
- [ ] Justice pipeline: charges, attorneys, trials, sentencing and prison consequences.
- [ ] Attorney side-RNG behavior and any other RNG splice points.
- [ ] Election timing/integration beyond already-ported election primitives.
- [ ] Constitutional/extreme-government branches: court purge, term limits and original endgame transitions.
- [ ] Complete strict/relaxed win/loss/endgame flow around the already-ported checks.
- [ ] Decide legacy bugs only after parity is demonstrated; do not silently "fix" behavior during conversion.

**Gate C:** multi-year headless simulations can pass through elections, trials, prisoners, sleepers, government shifts and all original end states.

### D. Port the news system

Port from `src/news/` without coupling prose generation to state mutation.

- [ ] News-story state and queue lifecycle.
- [ ] Story selection/prioritization.
- [ ] Major events.
- [ ] Squad/site/crime stories.
- [ ] Broadcast/newspaper effects on public opinion.
- [ ] Headlines/text generation through UI/text adapters, not `core/` prose calls.
- [ ] Replace legacy ASCII/cutscene presentation rather than reproducing terminal rendering.

**Gate D:** daily/monthly/site/crime events can generate and resolve mechanically equivalent news effects headlessly.

### E. Port combat completely

Port from `src/combat/` and remaining combat helpers.

- [ ] Attack selection and attack resolution.
- [ ] Hit/miss, dodge and defense checks.
- [ ] Ranged ammunition/burst/fire behavior.
- [ ] Melee/unarmed behavior.
- [ ] Armor penetration/protection integration around the existing damage primitives.
- [ ] Body-part injury, severing/permanent damage/death outcomes.
- [ ] Morale/hostage/surrender behavior used in fights.
- [ ] Kidnapping/hauling consequences.
- [ ] Combat event vocabulary sufficient for any future visual presentation.
- [ ] Deterministic combat probes covering every weapon family and representative armor/body states.

**Gate E:** arbitrary squads can fight headlessly to a deterministic conclusion with parity-level wounds, deaths, ammo and aftermath.

### F. Port car and foot chases

- [ ] Foot pursuit state and resolution.
- [ ] Vehicle pursuit state and resolution.
- [ ] Driving checks and vehicle stats/damage.
- [ ] Escape/capture transitions.
- [ ] Build deterministic pursuit fixtures so chase traces no longer depend on randomly provoking a chase in a normal playthrough.

**Gate F:** both chase types have repeatable parity tests and clean transitions into/out of combat/site/base state.

### G. Finish site mode / infiltration

Site construction is already strong; now port the gameplay that occurs inside the site from `src/sitemode/`.

- [x] Enter/leave site lifecycle and squad placement.
- [x] Movement across floors and stairs.
- [ ] Visibility/encounters and enemy population.
- [ ] Stealth, suspicion, disguise and alarm states.
- [x] Restricted areas/doors/locks/security behavior.
- [ ] Site specials and interaction rules from `mapspecials.cpp`.
- [ ] Dialogue/talk/persuasion/intimidation/recruit-like site interactions.
- [ ] Loot pickup/drop/carry and site inventory consequences.
- [ ] Hostages/kidnapping/hauling.
- [ ] Graffiti/vandalism/burning/destruction actions present in the original.
- [ ] On-site shops and shop interaction behavior.
- [ ] Escape, pursuit and post-site consequences.
- [ ] Connect site combat to the completed combat system rather than embedding combat logic in site code.
- [ ] Add end-to-end site traces using deterministic constructed fixtures when fixed keystroke traces are too brittle.

**Gate G:** every original site can be entered, traversed, interacted with and exited in Godot simulation, including stealth → alarm → combat/chase transitions.

### H. Finish title/new-game/save lifecycle

Do not port the old raw save format; the new serializer is already the canonical format.

- [ ] Character/founder creation and all original starting choices worth preserving for parity.
- [ ] New-game world/session initialization.
- [ ] Load/save UI-facing commands around the versioned serializer.
- [ ] Autosave behavior.
- [ ] Game-over/victory/restart transitions.
- [ ] High-score/history behavior if retained.
- [ ] Replace legacy cutscenes/title ASCII with modern presentation hooks rather than porting broken 64-bit `.cmv/.cpc` playback.

**Gate H:** a real player can start, save, load, lose, win and restart a game without test-only setup.

### I. Complete the Godot parity UI

This is functional UI coverage, not final art direction. Keep mechanics in `core/` and presentation in `ui/`.

- [ ] Render all PendingIntents with reusable choice/confirmation/select-target widgets.
- [ ] New-game/title/load screens.
- [ ] Safehouse/base management screens beyond the current first pass.
- [ ] Creature dossier/equipment/squad management.
- [ ] Activity assignment/recruitment interfaces.
- [ ] Site/infiltration map view and interaction controls.
- [ ] Combat presentation and target/action controls.
- [ ] Chase presentation.
- [ ] Shops/inventory/loot interfaces.
- [ ] News/newspaper/broadcast presentation.
- [ ] Politics/agenda/review screens.
- [ ] Justice/trial/prison presentation.
- [ ] Save/load/settings/game-over flows.
- [ ] Mouse/keyboard navigation, focus handling and scalable layout.
- [ ] Headless scene-instantiation smoke tests for every major screen.

**Gate I:** all parity mechanics are accessible without a terminal/curses fallback.

### J. Parity closure sweep

- [ ] Sweep every non-vendored legacy source module and map each meaningful function to: **ported**, **presentation-only/replaced**, **unreachable/obsolete**, or **deliberately deferred as a post-parity feature**.
- [ ] Search for all original state mutations and ensure each has an equivalent or documented exception.
- [ ] Search the original blocking input sites and ensure every meaningful decision is covered by Command/Intent flow.
- [ ] Record final golden traces/probes for all tractable modes.
- [ ] Add deterministic fixture-based tests where the original interactive harness cannot reliably reach a mode.
- [ ] Run long deterministic simulations across multiple seeds.
- [ ] Fix accidental divergences.
- [ ] Move intentional bug fixes or enhancements to `docs/ROADMAP_FUTURE.md` unless explicitly approved for the parity baseline.
- [ ] Update the completion estimate in this file to 100% only when all gates are green.

**Gate J / PORT DONE:** Godot is the complete playable implementation and the legacy C++ is no longer required at runtime or as an implementation dependency.

## 5. Deliberate parity exceptions

These are not forgotten tasks. Preserve this list rather than spawning exception/status docs.

- The pre-`sitemaps.txt` fallback site generator is currently excluded because a shipped data set makes it unreachable and retaining two generators would add dead complexity.
- Legacy `.cmv/.cpc` cutscene playback is not to be ported literally; its 64-bit behavior is broken and presentation should be replaced.
- The new save format intentionally replaces raw C++ struct serialization; old binary saves are not a parity requirement.
- The original site LOOT plan step is a no-op unless later evidence proves otherwise.

Any additional exception must be added here with the original source path/function and the reason.

## 6. Known original bugs to preserve until parity closes

Do not silently fix these while converting because some change RNG draw counts or behavior. After parity, candidates belong in `docs/ROADMAP_FUTURE.md`.

- `roll_gender()` male-bias fallthrough.
- Ignored/misspelled XML fields such as `strentgh_min` and unused `appropriate_weapon`.
- `WeaponType::bashstrengthmod` constructor default mismatch.
- Legacy `fireprotection` interpretation quirks already identified during extraction.
- `wincheck()` dangling-`else` relaxed-win behavior.
- `generatestairsrandom()` secure/unsecure list indexing bug.
- `alarmwait()` race/hang.

## 7. Rules for executing this roadmap

- **Parity first.** Do not add new gameplay mechanics while conversion work remains unless the user explicitly changes the goal.
- **One system at a time, but one overall push.** Finish and test a subsystem, update this roadmap, then immediately continue to the next dependency.
- **No document spawning.** Findings go in this roadmap, `docs/ROADMAP_FUTURE.md`, `docs/port/ARCHITECTURE.md`, or code/tests. Git history is the session log.
- **No UI logic in core.** Never solve a UI problem by weakening the layer rules.
- **No giant transliterations.** Split legacy monoliths into focused systems using the architecture contract.
- **Tests are the progress meter.** A checkbox is complete only when the behavior is implemented and its strongest practical parity test is green.
- **Keep unfinished work visible.** If blocked, leave the checkbox open and add one concise indented note beneath it; do not create a separate blocker document.

## 8. Final cleanup after 100% parity

Only after Gate J:

- [ ] Remove obsolete port-only trace scaffolding that no longer provides maintenance value, while retaining useful regression tests.
- [ ] Decide whether the legacy `src/`, vendored SDL/PDCurses and old build files remain as historical reference or move out of the production tree.
- [ ] Collapse obsolete migration-era documentation.
- [ ] Rebaseline `docs/ROADMAP_FUTURE.md` as the active product roadmap for post-LCS expansion.
- [ ] Begin visual/UI modernization and new mechanics without parity ambiguity.
