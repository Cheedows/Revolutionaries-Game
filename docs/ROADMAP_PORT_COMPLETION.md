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
  - Was blocked on the chase system: in the original an arrest runs straight
    into `footchase()`, so the branch could not be recorded in isolation. The
    foot chase now has its own probe, so the arrest branch can be probed once
    the daily arrest path calls into it (Gate B).

**Gate A:** all foundational primitives required by later modes are callable headlessly and green.

> **Order note.** Gates E and F are taken before the rest of B. A daily arrest
> runs into a foot chase and site mode runs into combat, so B and G cannot be
> finished — or honestly probed — until those exist. Everything else in the
> roadmap keeps its order.

### B. Finish base mode and daily simulation

Port the remaining behavior primarily from `src/basemode/`, `src/daily/` and shared actions.

- [x] Recruitment: `recruitment_activity()` and `completerecruitmeeting()`,
    with `recruitFindDifficulty()`, the subordinate limits from
    `maxsubordinates()`/`subordinatesleft()`, and `Creature::talkreceptive()`.
  - Verified by the `recruit` probe: every recruitable type at three levels of
    street sense for the search, and both approaches against recruits of three
    standings for the meetings — compared on draw counts, how many candidates a
    day turns up, whether a meeting was missed or was the last one, the
    eagerness and level it left behind, the funds spent, and what the recruiter
    learned.
  - **Known original quirk preserved.** Only the mutant's difficulty varies
    with the law, and it is recalculated in `recruitSelect()` — the menu — not
    when the search runs. A player who has not opened that menu since the laws
    changed goes looking under the old number, so the difficulty table is
    stored state in the port too, refreshed by the same step.
- [x] Recruit management: the evening's meeting queue from `advanceday()` —
    whose meetings happen, what becomes of the ones that cannot (a recruiter
    who died, lost their safehouse, is under siege, or is in the wrong city),
    and the bookings counter that decides who turns up. Covered by deterministic
    fixture tests rather than a probe: the original runs this as a keystroke
    loop that a recorded script cannot steer.
  - This is also the first system to ask the player several questions in one
    turn, which found a gap in the seam: `Session.answer()` called `resume` and
    threw the result away, so a resumed system's events were lost and a second
    question never arrived. Answers now go back through `Session.submit()`.
- [ ] Lining a recruit up for a task rather than for membership
    (`recruitst::task`), and the meeting-queue entry points in `talk.cpp`.
- [x] Activity assignment semantics: the original groups Liberals by what they
    are doing and runs the groups in a fixed order, so a mixed roster rolls in
    an order that has nothing to do with the roster. The port was dispatching
    per creature; it now groups. Prostitution's group is walked from the back,
    which is how its loop happens to be written and decides who rolls first.
  - Verified by the `activities_day` probe: a whole day at three crowd sizes,
    each job isolated as well as mixed, and the mixed roster handed in forwards
    and reversed so the grouping is doing real work. Compared on draw counts,
    funds, both opinion arrays, and every Liberal's skills, standing, income
    and unfinished mural.
- [x] Graffiti, including murals across several nights and being caught.
- [x] Daily arrests: `checkforarrest()` and `attemptarrest()`, wired into the
    four street-fundraising activities, brownies and graffiti. Being noticed is
    not a note in a file — it is a foot chase, and the player runs it.
- [x] Remaining daily activities: teaching, study, community service, burial,
    trouble, letters and Guardian essays — plus the clinic visit and a sleeper
    surfacing, which the original resolves inline while it is still sorting the
    roster rather than in a group pass of their own.
  - **Known original bug preserved.** The sleeper case has no `break`, so a
    sleeper who comes in from the cold also spends the day writing a letter to
    the editor — and one whose shelter is under siege, and so stays a sleeper,
    writes the letter anyway.
  - `funds_and_trouble()` filters the roster on nothing but "alive" and "has
    somewhere to be". The port was additionally skipping anybody jailed,
    hospitalised or on a squad; it no longer does, because the original does
    not and a stale assignment really is still carried out.
  - Verified by the extended `activities_day` probe: 19 jobs across three
    crowd sizes, each in isolation and mixed, the mixed roster handed in
    forwards and reversed, now also compared on where the day leaves each
    Liberal (location, base, months in a clinic and whether they are still a
    sleeper).
- [x] Hacking: the team break-in, credit-card fraud, and the two
    denial-of-service jobs that the original collects but never acts on beyond
    the practice they give.
  - **Known original bug preserved.** `MAX()` is a macro, so
    `hack_skill = MAX(hack_skill, skill_roll(SKILL_COMPUTERS))` rolls once to
    compare and rolls *again* when the first roll won — and keeps the second,
    which can be lower than the best so far. A team of good hackers costs far
    more draws than it appears to and can end up with a worse number than it
    had. This is the only place in the original where a macro double-evaluates
    a roll; the rest were checked.
- [ ] Dating/relationship activity behavior used by the original.
- [ ] Interrogation.
- [ ] Siege daily processing and safehouse consequences.
- [ ] News hooks for daily arrests (the story types the original queues).
- [x] The individual half of the day: `advanceday()`'s "ACTIVITIES FOR
    INDIVIDUALS" loop, which runs before anybody is sorted into a group.
    Mending clothes (`repairarmor()`), sewing them (`makearmor()`), finding a
    wheelchair, reading the polls (`survey()`), the visit that cancels itself,
    the siege that calls everything else off, and the idle Liberal who washes
    their own bloody shirt without being told to.
  - The survey is the player's only picture of public opinion and it is a
    deliberately bad one, so the probe records the figures it produced rather
    than only the rolls it consumed. `survey()` in the original now hands them
    to the harness on the way past, the way `getkey()` already does.
  - Verified by the `activation` probe: six jobs across three crowd sizes, each
    in isolation and mixed, half of them under siege, compared on draw counts,
    funds, each Liberal's skills, clothes and assignment afterwards, the poll
    figures, and the state of the pile on the floor.
  - **Not yet covered, and excluded from the probe:** `ACTIVITY_RECRUITING`
    sets up a meeting, which is a conversation and waits on the talk system —
    the port does the asking-around half and stops. `ACTIVITY_STEALCARS` is an
    interactive minigame of its own and is listed separately below.
- [ ] Stealing a car (`stealcar()`): the theft minigame, its alarms and the
    police response.
- [x] Injury recovery: the night's nursing block of `advanceday()`. Whoever is
    at a safehouse with the steadiest hands treats everybody hurt enough to
    need a clinic but not in one, and the building itself counts as a medic —
    a clinic as a skill of 6, a teaching hospital as 12. A besieged safehouse
    with an empty larder cannot nurse anybody, which needs `fooddaysleft()`
    and so the compound's stores.
  - The organ table is the original's switch written out. That switch has no
    `break`s in it, so a heart falls through the lungs into the abdomen and
    collects all three sets of consequences: difficulty 16, nine points of
    bleeding, and permanent damage. Teeth, eyes, the nose and the tongue are
    never treated, because the loop starts at the first lung.
  - **Subtle original behavior, easy to get wrong.** The floor that stops
    permanent damage killing somebody outright tests the *effective* health
    figure, not the raw one. A broken lower spine quarters health on its own,
    so a patient can go from raw 4 to the floor on a single point of damage.
  - Verified by the `recovery` probe: four patient counts against three
    standards of care, at a safehouse and at a clinic, half of them besieged,
    compared on draw counts and on every patient's blood, wounds, organs,
    attributes, skills and whether they were sent to a real clinic.
- [x] The nightly dispersal check (`dispersalcheck()`) and the promotions it
    triggers (`promotesubordinates()`). Everybody was recruited by somebody,
    and that chain is the only way an order travels: a link that is dead, in
    prison or in hiding cuts off everybody below it. The check walks the chain
    down from the founder each night and cuts loose whoever it cannot reach,
    promoting the keenest recruit into a dead link's place — or, if the
    founder dies, whoever is Revolutionary enough to lead.
  - Love slaves bleed juice on any night they are not on the same side of the
    bars as their lover, and abandon the squad below -50.
  - Also ports `cleangonesquads()`, which the check calls on its way out, and
    completes the eviction path: losing a lease now loses the compound with it.
  - Verified by the `dispersal` probe: chains one to four links deep, every
    rung of each in turn dead and in prison, with and without a love slave,
    somebody brainwashed and somebody already hiding indefinitely. Compared on
    draw counts, who is left, who now reports to whom, and where the rest went.
    The end-of-game check on the tail of `dispersalcheck()` is left out of the
    transcription the probe drives: it belongs to the day around the check, and
    it ends the run whenever a sample deliberately kills the last Liberal.
- [ ] Safehouse/base actions not already covered by Commands.
- [ ] Liberal agenda/review-management behavior that belongs to simulation rather than presentation.
- [x] A day passing for everybody (`advanceday()`'s "AGE THINGS" pass) and a
    month at a clinic (`passmonth()`'s "HEAL CLINIC PEOPLE" pass). Stunning
    expires, the very old decline and occasionally die of it, birthdays turn a
    child into a teenager and a teenager into an activist, a point of blood
    closes, people come back out of hiding — but not into a besieged safehouse
    — a kidnapping the papers had not caught up with is reported, and banked
    experience becomes levels. A clinic then does in a month what a safehouse
    cannot: every wound closed, every organ back, the ribs knitted.
  - **Subtle original behavior, easy to get wrong.** The clinic's health line
    is unconditional and reads the *effective* figure: a patient whose spine
    has just been rebuilt has their raw health overwritten with the quartered
    reading whether or not anything cost them a point. That is what makes a
    spinal injury permanently ruinous rather than merely expensive.
  - `clinic` and `sentence` are counted in months and come off in the monthly
    turn. The port had been decrementing both daily; it no longer does.
  - Verified by the `ageing` probe: both passes at six points in the calendar,
    three crowd sizes, besieged and not, compared on draw counts, news stories
    queued, and every Liberal's age, type, blood, wounds, organs, attributes,
    skills, whereabouts and time left.
- [x] `advanceday()` is now composable systems in the original's order, which
    is load-bearing: the date does not move until most of the day is over, so
    rent falls due before the day counter ticks and a birthday is checked after
    it. The port had been advancing the calendar first and paying rent a day
    early.

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

- [x] Attack selection and attack resolution.
- [x] Hit/miss, dodge and defense checks.
- [x] Ranged ammunition/burst/fire behavior.
- [x] Melee/unarmed behavior.
- [x] Armor penetration/protection integration around the existing damage primitives.
- [x] Body-part injury, severing/permanent damage/death outcomes.
- [ ] Morale/hostage/surrender behavior used in fights.
  - The rhetorical attacks are ported (judges, CEOs, broadcasters, musicians)
    up to the point where a losing squad member is converted and changes sides;
    that transfer needs the encounter roster, so it lands with Gate G.
- [ ] Kidnapping/hauling consequences.
- [ ] Combat event vocabulary sufficient for any future visual presentation.
- [x] Deterministic combat probes covering every weapon family and representative armor/body states.
  - All 38 weapon types, four blows each, against three states of defence under
    three legal climates, compared on blood, every wound flag, every organ,
    ammunition, standing, site crime and the alarm — and on the number of RNG
    draws each blow consumed, which is what makes a missing roll findable.

- [x] The round itself: `youattack()`, `enemyattack()` and `creatureadvance()`
    (with `advancecreature()`), plus the encounter roster helpers `enemy()`,
    `delenc()` and `makeloot()`, `alienationcheck()`, `squadgrab_immobile()`
    and the site's own between-rounds tick — the alarm timers and the fire
    spreading through the building.
  - Verified by the `fight` probe: each half of a round on its own and then all
    three together, in a room holding police, secretaries and a security guard
    so the targeting has to choose between a dangerous enemy, an ordinary one
    and a bystander, with a third of the samples standing the squad in a fire.
    Compared on draw counts, both sides' wounds and blood, the alarm, the site
    crime list, the alienation level and every fire and debris flag on the
    ground floor.
- [ ] The rhetorical-attack conversion: a squad member who loses an argument
    changes sides. Needs the talk system (Gate G).

**Gate E:** arbitrary squads can fight headlessly to a deterministic conclusion with parity-level wounds, deaths, ammo and aftermath.

**Known original bugs preserved.** A fire at its height tries to spread
sideways and, failing all four directions, is meant to climb — but the test
guarding that branch asks for a try count the loop cannot reach, so fire never
spreads upward. The same loop reads a tile's *special index* as though it were
a bit mask when deciding whether a floor has stairs, which is what limits how
far up the building the fire is simulated at all. Both reproduced in
`core/systems/site/site_round.gd`.

### F. Port car and foot chases

- [x] Raising a pursuit: who responds to trouble at each site type, how many of
    them, in what, and whether they will take a surrender (`makechasers()`).
- [x] Foot pursuit state and resolution (`evasiverun()`): speed rolls, chasers
    dropping out, Liberals breaking away one at a time, and being caught by
    police, a death squad or a tank.
- [x] Vehicle pursuit state and resolution (`drivingupdate()`, `evasivedrive()`,
    `dodgedrive()`, `obstacledrive()`), including the road obstacles.
- [x] Driving checks and vehicle stats (`driveskill()`), and both crashes
    (`crashfriendlycar()`, `crashenemycar()`).
- [x] Escape/capture transitions: `chase_giveup()`, `capturecreature()`,
    `freehostage()` and `kidnaptransfer()`.
- [x] Build deterministic pursuit fixtures so chase traces no longer depend on
    randomly provoking a chase in a normal playthrough. The `chase` probe
    raises a pursuit at all 54 site types under three legal climates, then runs
    single car-chase turns (reseating, evading, swerving, both crashes) and one
    to three foot-chase rounds, comparing draw counts as well as outcomes. It
    records the generator state at the start of each measured turn, because a
    turn cannot be replayed from a seed: building the squad and raising the
    pursuit draw first.
- [x] Wire the chase loop into base mode: `core/systems/chase/chase_loop.gd`
    runs a chase round by round as a question the player answers, and
    `core/systems/daily/arrest_chase.gd` starts one from an activity with the
    one-person fictitious squad the original builds. Exercised end to end by
    the `activities_day` probe, where a Liberal busted selling brownies is
    chased and surrenders.
- [ ] Wire the chase loop into site mode: leaving a site with the police
    outside.

**Gate F:** both chase types have repeatable parity tests and clean transitions into/out of combat/site/base state.

**Known original bug preserved.** `drivingupdate()` picks a replacement driver
by calling `driveskill()` three times per passenger — once to compare, once to
store the best, and once more to find who has it — and every one of those
rolls. The stored best is therefore a different number from the one that beat
the previous best, and the third roll rarely matches it, so a car whose driver
is incapacitated usually crashes rather than being reseated. Reproduced call
for call in `core/systems/chase/driving.gd`.

### G. Finish site mode / infiltration

Site construction is already strong; now port the gameplay that occurs inside the site from `src/sitemode/`.

- [x] Enter/leave site lifecycle and squad placement.
- [x] Movement across floors and stairs.
- [x] Enemy population: `prepareencounter()` and `addsiegeencounter()`, with
    the weights generated into `core/encounter_rules.gd` by
    `tools/extract_encounters.py` rather than transcribed — 784 weight
    statements and 28 spawn loops across 29 site tables.
  - Verified by the `encounters` probe: every site type under three climates,
    with and without the squad standing somewhere restricted, in three states
    of the building (quiet, alarmed, burning with a response on the way), plus
    the siege waves for every attacker, besieged and not, on foot and armoured.
  - **Deliberately excluded.** An `org` siege reaches `addsiegeencounter()`'s
    switch with no matching case, so the original makes nobody and the roster
    keeps whoever was left in the slots from the previous wave, re-marked as
    present. That is leftover state rather than a rule, and unreachable in
    play: an organisation siege does not send attackers through the door.
- [ ] Visibility: what the squad can see of the people in the room.
- [x] Stealth, suspicion and alarm states: `noticecheck()`, `disguisecheck()`,
    `weaponcheck()`, `weapon_in_character()` and `disguisesite()`. The
    outfit-and-weapon pairings that make a weapon look like part of the job are
    generated by `tools/extract_disguises.py` alongside the disguise table.
  - Verified by the `stealth` probe: both checks against a room the site would
    really hold, with the squad naked, in plain clothes, in a uniform with a
    sidearm that goes with it, and carrying a rifle that goes with nothing;
    inside and outside the restricted parts; under all three training rates and
    at three stages of suspicion. Compared on draw counts, the alarm, the
    suspicion countdown and what each Liberal learned.
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
- `initlocation()` overflows a 20-character buffer when an apartment block's
  name is long enough — "Saxe-Coburg-Gotha Condominiums" aborts the original
  outright. The port simply has no fixed-size buffer there.

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
