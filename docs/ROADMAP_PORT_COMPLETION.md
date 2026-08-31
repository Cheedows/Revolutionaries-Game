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
- [x] Lining a recruit up for a task rather than for membership
    (`recruitst::task`): **obsolete in the original**. The field is
    initialised to `TASK_NONE`, written to the save file and read back, and
    never read anywhere else — nothing in the game ever sets or acts on it, so
    there is no behaviour to port. The meeting-queue entry points in
    `talk.cpp` are Gate G's, with the rest of the talk system.
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
- [x] Dating and relationships: `state/date_plan.gd` mirrors `datest`,
    `systems/daily/dating/` ports `dateresult()`, `completedate()`,
    `completevacation()` and the kidnapping branch, and `date_queue.gd` ports
    the "DO DATES" pass of `advanceday()`. `systems/creature/relationships.gd`
    ports `loveslaves()`/`loveslavesleft()`, which is the cap on how many
    people one Liberal can juggle.
  - **Subtle original behavior, easy to get wrong.** The evening's two rolls
    are made before the menu is read, so breaking it off costs the same draws
    as going through with it. A week away judges the other person as a
    Conservative whatever their politics, and asks each of them for a skill
    roll before deciding whether to roll it again for real. The list of ways a
    three-date evening ends badly looks like eight lines but is seven: two of
    them are missing a comma and the compiler joins them.
  - Verified by the `dating` probe: five kinds of person, five ways to play
    the evening, one date or three, three grades of Liberal, three things to
    be holding, wanted or not, and the week away as well as the night out
    (5400 samples), compared on draw counts, whether the arrangement survives,
    the money, who ended up in the pool and on what terms, whose workplace was
    given away, and both people's skills and attributes.
  - **Not yet covered:** the re-education a kidnapped Conservative gets is the
    interrogation system's, and the option to leave a new love slave where
    they work as a sleeper is the recruitment prompt's — the port brings them
    home, which is the answer with no rolls in it.
- [x] Interrogation: `state/interrogation.gd` mirrors the `interrogation`
    struct, and `systems/daily/interrogation/` ports `tendhostage()` — who is
    on the job, the escape an unattended or unrestrained hostage tries, who
    leads the session and how strong a case they can make, the execution, the
    hallucinogens, the beating, the argument and the five ways it fails, the
    despair, the death and the conversion. `hostage_queue.gd` ports the
    "HOSTAGES" pass of `advanceday()`, which runs before anybody else's day.
  - **Subtle original behavior, easy to get wrong.** The plan is chosen after
    the escape check and after the day's rolls, so the restraint the escape
    check reads is yesterday's. The prose is rolled for throughout — which
    torture, what was screamed, what the hostage breaks into — and every one
    of those rolls moves the generator. A hostage nobody can bring themselves
    to execute still spends the day restrained and fed, with talking, beating
    and drugs called off. A doctor good enough to save an overdose undoes the
    health damage and clears the drugs from the record entirely.
  - Verified by the `interrogation` probe: five kinds of hostage, twelve
    plans, none to two guards, three grades of interrogator, three lengths of
    captivity, restrained yesterday or not, and with rapport already built or
    none (12960 samples), compared on draw counts, how the day ended, the
    money, everybody's skills and attributes, who is still on the job, whose
    workplace was given away, and the days of drugs on the record.
  - **Not yet covered:** the option to leave a converted hostage where they
    work as a sleeper is the recruitment prompt's; the port brings them home,
    which is the answer with no rolls in it.
- [x] The nightly siege watch (`siegecheck()`): how close the police are to
    each safehouse, and who else has decided to pay a visit. Heat accumulates
    from whoever is staying there — a corpse and a hostage draw far more of it
    than a wanted Liberal does — and bleeds off them again as it does. Once the
    house is hotter than it can hide, a raid is planned, and a business out
    front halves how fast the police close in. A house found empty is emptied:
    the loot is confiscated, the cars are taken and anybody left behind is not
    seen again.
  - All six other raids too: a corporation the squad has embarrassed, the
    intelligence services, the Conservative Crime Squad, the mob a talk-radio
    host or a news anchor can raise once enough of the country has stopped
    listening to them, and the fire brigade — which only turns out where free
    speech has been outlawed and the squad is running a printing press.
  - Also `Location::update_heat_protection()`, and the nightly cleansing of
    charges nobody can be held on any more, which is how an amendment empties
    a cell block.
  - Verified by the `siege_watch` probe: three endgame stages by five heat
    levels by four occupancies by four safehouse arrangements, compared on
    draw counts, every site's heat, protection, siege state and three
    countdowns, and every Liberal's heat and charge sheet.
- [x] A day of being under siege (`siegeturn()`): the stores are eaten, the
    house starves without them, the power goes, snipers work on whoever has the
    least standing to protect them, helicopters arrive once the escalation is
    high enough, and the tank traps eventually come down. A house nobody is
    left to defend falls and is stripped — and a warehouse the Conservative
    Crime Squad takes, they keep.
  - On a day when none of that happens, a reporter occasionally gets in, which
    is the one thing a siege is good for: whoever is best at talking does the
    talking, and the segment moves the organisation's name, its standing and
    five issues at random. Their name comes off the main RNG stream here,
    unlike the attorney's.
  - Verified by the `siege_turn` probe: every combination of what a compound
    can have built into it, four levels of escalation, three of stores and four
    occupancies, compared on draw counts, the stores, the compound, the siege
    state, the lease, the loot left, public opinion and every defender.
- [x] Surrendering a besieged safehouse (`giveup()`) and what a siege leaves
    behind when the fighting stops (`escapesiege()`). Who is outside decides
    everything: the police and the fire brigade charge whoever is holding a
    hostage or an undocumented worker, confiscate the money — a small purse
    survives, and a large one very nearly does not — dismantle the compound and
    take away anybody wanted; everybody else simply kills whoever is inside,
    and the Conservative Crime Squad keeps a warehouse it takes.
  - Winning buys a few weeks before the police come back with the army, and
    pushes the national heat up. Losing rebuilds the site from scratch through
    `initlocation()` — a fresh generator stream and a new name, both of which
    cost draws in a fixed order — and scatters the survivors into hiding.
  - Verified by the `surrender` probe (five attackers, four purses, four
    occupancies, three safehouse arrangements — 720 samples) and the
    `siege_outcome` probe (won and lost, three attackers, rented and held, four
    occupancies, five levels of national heat — 720 samples).
- [ ] The assault itself (`sally_forth()`, `sally_forth_aux()`,
    `escape_engage()`): a siege defence is site mode with the compound as the
    map, so it waits on Gate G's site loop.
- [x] News hooks for daily arrests: `systems/news/news_queue.gd` ports the
    `sitestory` global — the story currently being written, which every crime
    the chase and the site loop record goes onto — and the drug, graffiti,
    burial, nudity and catch-all arrests each open theirs where the original
    does. Parity exception: the original never closes a story, so `sitestory`
    keeps pointing at freed memory after the paper runs; here the paper closes
    it, which is what makes `attemptarrest()`'s "only if nothing is open"
    guard mean anything on a later day. Verified by the `activities_day` probe,
    which now records the queue a day files.
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
- [x] Stealing a car (`stealcar()`): `systems/daily/car_theft.gd` looks for a
    car and gets into it, `systems/daily/car_ignition.gd` gets it started and
    drives it away. The minigame is a chain of prompts in the original, so it
    is a chain of Intents here, and every round of both loops can end with a
    passerby and a chase.
  - **Subtle original behavior, easy to get wrong.** The lines the thief
    mutters are rolled for even though nothing reads them, and three of the
    key searches print a fixed line and roll for nothing — so the rummaging
    consumes a draw on every round but the fifth, tenth and fifteenth. The
    notice check rolls its second die whether or not an alarm is going off.
    The getaway's second roll is only made when the first got away with it,
    and only for a police cruiser.
  - Verified by the `cartheft` probe: five cars, three ways in, three ways to
    start them, three weapons, three grades of thief and all three field
    training rates (3645 samples), compared on draw counts, the state of the
    window, the thief afterwards, the car driven home and the story filed. The
    probe is a transcription: the minigame's own prompts are answered by
    policy, because a scripted keyboard cannot answer both those prompts and
    the chase they can end in.
  - `ACTIVITY_STEALCARS` is wired into the individual half of the day,
    including the charge for being caught at it in a police station car park.
- [ ] Vehicle upkeep the fleet needs once cars can be acquired: the fence
    refuses a car with heat on it, which needs the shop system.
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
- [x] Safehouse/base actions not already covered by Commands:
    `systems/base/safehouse_upgrades.gd` ports `investlocation()` — walls,
    cameras, booby traps, tank traps, a generator, an anti-aircraft gun, a
    printing press, twenty days of tinned food, and a legitimate business to
    hide behind — and `systems/base/business_front.gd` ports the front's
    naming, which rolls a trade, a surname and a speciality until no other
    place in the city shares the short name.
  - **Subtle original behavior, easy to get wrong.** Only four of the nine
    purchases ask whether the squad owns the place: the walls, the traps, the
    tank traps and the front. Cameras, a generator, a printing press, an
    anti-aircraft gun and a pantry can be installed anywhere the menu can be
    reached from. A bunker is already fortified and already ringed with tank
    traps; a bar and grill can have none of it. The gun costs $35,000 where
    anybody may own one and $200,000 where they may not.
  - Verified by the `safehouse` probe: six kinds of place, nine things to buy,
    four states of the compound, three sizes of purse, gun control either way
    and whether the squad owns the place (7776 samples), compared on draw
    counts, the money, the walls, the stores and the name over the door.
  - The rest of `baseactions.cpp` is presentation or a Command the port
    already has: the flag-burning animation, the slogan prompt, reordering a
    squad, choosing a destination and assigning cars.
- [x] Liberal agenda/review-management behavior that belongs to simulation
    rather than presentation: `liberalagenda()` is a status screen and belongs
    to Gate I, and so does review mode. The one piece of simulation in either
    is disbanding, which `systems/base/disbanding.gd` ports:
    `confirmdisband()` scatters everybody who is not a sleeper into hiding
    with no end date, takes the hostages off the books, and dates the disband
    from the current year; `show_disbanding_screen()`'s monthly thinning then
    forgets whoever has not earned enough standing to still be worth finding,
    a hundred points harder every year up to a ceiling of a thousand. After
    fifty years there is nobody left and the game is over. The day is gated on
    it the way `advanceday()` gates every one of its passes.
  - **Parity exception.** The original deletes a hostage from the pool without
    taking them out of their squad first, then decides whether the squad is
    empty by reading the freed creature's `alive` flag. The port disbands the
    squad; the probe's answer there is undefined, so the test compares squad
    counts only where nobody was deleted.
  - Verified by the `disband` probe: one to six members in six shapes of
    roster, and the monthly forgetting at five distances from the year it
    happened (1080 samples), compared on draw counts, who is left, who is
    alive, who is in hiding and which squads survive.
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

- [x] The month's opinion drift and graffiti upkeep. Conservative talk radio
    and cable news push every issue rightward every month and sleepers, essays
    and tags push back — but the tug-of-war is settled with a
    four-hundred-sided die, so a month of hard work is a bias and not a result.
    A tag somewhere with guards is scrubbed off within the month and is worth
    five times a lasting one for having been seen on the way out; a tag on the
    squad's own wall becomes theirs, and one on the enemy's becomes theirs.
    Also the seduction stipends that follow.
  - The monthly `dispersalcheck()` is wired in here too: the original runs it
    twice a month-end, once daily and once monthly.
  - Verified by the `drift` probe: three stages of the endgame against three
    densities of graffiti and three arrangements of love slaves, compared on
    draw counts, both opinion arrays, every tag left on every wall, and the
    practice everybody came out of the month with.
- [x] Monthly finances: the original has no separate pass — income and
    expenses accrue as they happen and the month only resets the totals and
    prints `fundreport()`. The reset is ported and runs in `MonthlyTurn`; the
    report itself is presentation and belongs to Gate I.
- [x] Sleepers: `sleepereffect()` and every job in
    `src/monthly/sleeper_update.cpp`. Influencing the room, snooping through
    filing cabinets, skimming the accounts, taking things home, and quietly
    recruiting the next one. (The scandal job is a stub in the original and is
    a stub here; the roadmap for after parity can fill it in.)
  - What a sleeper is worth is three switches leaning on C's fall-through — a
    judge collects the lawyer's issues on top of their own, an eminent
    scientist the lab tech's — so `game/core/sleeper_rules.gd` is generated by
    `tools/extract_sleeper_influence.py` with the fall-through resolved. Only
    the four professions no table can describe are written out in code.
  - Infiltration is a C `float`, updated in hundredths and then compared
    against a d100, so every write to it goes through [SinglePrecision]. A
    double would drift in the seventh digit and eventually disagree with the
    original about whether a sleeper was caught.
  - Added `GameState.mode`. The encounter rules test the game mode directly —
    an apartment block only fields security guards for a squad actually
    standing in it — and the port had been inferring it from whether a site was
    loaded, which is wrong for a sleeper recruiting from their workplace during
    the monthly turn.
  - Verified by the `sleepers` probe: twenty-two professions across six jobs
    and three depths of infiltration, compared on draw counts, what each
    argued for per issue, funds, the pile at the shelter, the CCS exposure
    state, standing, whereabouts and whoever they recruited.
- [x] The justice pipeline: the "THE SYSTEM!" block of `passmonth()`, `trial()`,
    `penalize()`, `imprison()`, `prison()`, `reeducation()`, `laborcamp()` and
    `prisonscene()`. A month in the cells with the police leaning on somebody
    to name their recruiter, a trial with a jury drawn from the country's mood
    and a defense the player pays for, sentencing off a table of charges, and
    a month inside that is therapy, hard labor or plain prison depending on
    what kind of prisons the country runs — escapes included.
  - **Subtle original behavior, easy to get wrong.** A sleeper judge is found
    by `infiltration*100 >= LCSrandom(100)`, computed in C `float`: an
    infiltration of seven tenths reads as exactly seventy there and a hair
    under it in a double, which is the difference between a friendly bench and
    a hostile one. The comparison goes through [SinglePrecision].
  - **Another.** When the ace attorney's jury tampering fails — one time in
    ten — his own arch-nemesis turns up to prosecute and the case against the
    defendant gains a hundred. It is a single line in the middle of the jury
    selection message and it swings the verdict.
  - **And another.** `addjuice()` trickles a fifth of every change up the chain
    of command via `hireid`. The port had been using the separate
    `recruiter_id`, so nothing ever reached anybody's boss.
  - The time-served rolls are the last term of an `&&` chain, so somebody with
    a life sentence or a single month left costs no draw at all.
- [x] Attorney side-RNG: the ace attorney's name is drawn from `attorneyseed`,
    spliced in with `copyRNG()` and spliced straight back out — so the main
    stream is untouched *and* the seed never advances, which is why the same
    attorney is offered at every trial for the whole game. The harness now
    brackets those draws (`lcs_trace_side_begin/end`) so a probe can subtract
    them from the main stream's count.
  - Verified by the `justice` probe: three scenarios by six records by four
    severities, the trial run through all five defenses and sentencing driven
    on its own as well, compared on draw counts, the jury, the prosecution's
    case, the defense's answer, leniency, funds, and every person's sentence,
    charges, standing, whereabouts and clothes.
- [x] Election timing and integration: `ElectionRules.run()` ports the shape
    of `elections()` — the presidency every fourth year, both chambers every
    second, and the propositions every year — and
    `systems/politics/presidential.gd` and `systems/politics/propositions.gd`
    port the two halves that were missing. The presidency is a hundred-voter
    primary in each party, the incumbency rules that can hand the nomination
    to a president or a vice president outright, a thousand voters, and a
    cabinet built from scratch when somebody new wins. The propositions are
    four to seven laws chosen by how far each has drifted from what people
    want and how much they care, each put to a thousand voters.
  - **Subtle original behavior, easy to get wrong.** A party's primary is
    decided by strict comparisons that cascade, so a tie goes to the *less*
    extreme candidate. The candidates' titles and the propositions' numbers
    are only rolled for when somebody is watching, so a squad that is dating,
    hiding, imprisoned or disbanded consumes a different number of draws —
    which is a fork in the world, not just in the screen; `run()` takes it as
    a parameter. The whole ballot is settled before a single vote is counted.
    The title roll is skipped for a vice president who inherited the
    nomination, because they already have one.
  - **Original quirk, reproduced.** A law's priority adds
    `public_interest[law]` — the interest in the *view* of that index, not the
    law's own issue. The arrays are different lengths and the indices do not
    correspond; the port indexes it the same way.
  - Verified by the `election_day` probe: four points in the presidential
    cycle, five tempers of the country, a president in either term, all three
    parties in the White House and Stalin mode either way (720 samples),
    compared on draw counts, the party and term, every seat in both chambers,
    the executive and their names, which laws made the ballot and which way,
    and the laws the propositions changed.
- [x] Constitutional/extreme-government branches:
    `systems/politics/amendments.gd` ports `ratify()` — both chambers voting
    with a point of waver either way, then thirty-eight of the fifty states
    voting on the country's mood bent by how each state leans — and
    `systems/politics/constitution.gd` ports the four amendments that use it
    and the conditions Congress checks them under: purging the court,
    abolishing incumbency (which throws every seat open at once), and the two
    repeals of the constitution.
  - **Original defect, reproduced.** The Stalinist repeal is put to the states
    at level 3, but a state's vote starts at -2 and gains one for each of four
    rolls, so it can never exceed 2. No state can ever vote for it: the
    Stalinist ending cannot be reached however Stalinist the country becomes.
    The port keeps the arithmetic — changing it would be a new game rather
    than a port of this one — and the probe confirms it never passes.
  - Verified by the `amendments` probe: four amendments, six tilts of
    Congress, five tempers of the country and whether it has happened already
    (720 samples), compared on draw counts, whether it passed, the amendment
    count, the laws, the court, the executive and the justices' names.
- [x] Complete strict/relaxed win/loss/endgame flow: `WinCheck.is_won()`
    already covered both win conditions; `systems/monthly/end_check.gd` now
    ports `endcheck()`, the loss condition — no living Liberal anywhere, with
    the exception the original makes for a sleeper who answers to nobody, who
    is what is left of the organisation and may carry on alone. The cause is
    the siege that finished them, or simply that they are dead. The day checks
    it before it starts and again after the night's sieges, and a lost game
    stops there.
  - The two constitutional repeals are the other two losses, and the fifty
    years of a disband running out is the third.
  - **A defect this found.** A body was starting with every organ missing:
    the original's creature constructor sets them all present and counts the
    teeth and ribs, and the port only did it in the creature factory, so
    anything built by hand bled to death in a week. Bodies are born intact
    now.
- [x] Decide legacy bugs only after parity is demonstrated; do not silently
    "fix" behavior during conversion. **Standing policy, held to throughout.**
    Where the original does something plainly wrong, the port reproduces it
    and the roadmap records it as a parity exception with the reasoning. The
    ones found so far: the unparenthesised `ABS` macro in the newspaper's
    opinion impact; the Stalinist repeal that no state can ever vote for; the
    `sitestory` pointer left dangling after the paper frees it (the one place
    the port deliberately differs, because the original's behaviour there is
    undefined); the squad emptiness test that reads a freed creature; the
    seven-item list that looks like eight; and `recruitst::task`, which is
    dead code. Nothing has been "improved" on the way through.

**Gate C:** multi-year headless simulations can pass through elections, trials, prisoners, sleepers, government shifts and all original end states.

### D. Port the news system

Port from `src/news/` without coupling prose generation to state mutation.

- [x] News-story state and queue lifecycle: `state/news_story.gd` mirrors
    `newsstoryst`, and `systems/news/newspaper.gd` runs `majornewspaper()`'s
    passes — the overnight stories, dropping the ones with nothing in them,
    laying the rest out across the pages, and clearing the queue. The paper is
    run from `DailyTurn._close_the_day`, and `run()` hands the stories that ran
    back to its caller so a UI can print them without `core/` writing prose.
- [x] Story selection/prioritization: `systems/news/news_priority.gd` ports
    `setpriority()` — the crime sheet scored three ways, the story-type bonus,
    the places nobody reports and the places that double everything — and the
    layout loop that walks the paper's page bands.
- [x] Major events: `systems/news/news_events.gd` ports `new_major_event()`,
    including its rejection loop over the issues the original has no stories
    for and the ones the law has already settled.
- [x] Squad/site/crime stories, and the other side's: `news_events.gd` also
    ports `ccs_strikes_story()`, `ccs_exposure_story()` (the mass arrests that
    end their funding) and `ccs_fbi_raid_story()` (the raid that ends them).
- [x] Broadcast/newspaper effects on public opinion:
    `Newspaper.impact()` ports `handle_public_opinion_impact()`, including the
    original's unparenthesised `ABS` macro, which makes a story that hurt an
    issue move gun control by its whole force and one that helped it move gun
    control by a tenth.
- [x] Verified end to end by the `newspaper` probe: twelve story types across
    six kinds of place, four stages of the endgame and four shapes of crime
    sheet (3456 samples), compared on draw counts, every printed story's
    priority, page, Guardian page, politics, violence, location, slant and
    invented crime sheet, then on attitude, background influence, both
    chambers, exposure and endgame state.
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
- [x] Morale/hostage/surrender behavior used in fights: the flight check is
    `EnemyRound`'s opening pass — non-Conservatives run, unarmed bystanders
    facing an armed squad run unless their nerve holds, anybody who has lost
    more than half their blood runs, and a fire empties the room — and the
    hostage rules are `Capture`'s: a shot at somebody dragging a hostage hits
    the hostage half the time, a freed hostage turns Conservative again and
    rejoins the other side, and a captured squad member's hostage changes
    hands with them.
  - The rhetorical attacks are ported (judges, CEOs, broadcasters, musicians)
    up to the point where a losing squad member is converted and changes sides;
    that transfer needs the encounter roster, so it lands with Gate G.
- [x] Kidnapping/hauling consequences: `systems/combat/hauling.gd` ports
    `squadgrab_immobile()`, `Capture.free_hostage()` ports `freehostage()`,
    `Capture.kidnap_transfer()` ports `kidnaptransfer()`, and
    `systems/combat/kidnapping.gd` ports `kidnap()` and what the room makes of
    it: a weapon somebody can be held at makes the grab certain, bare hands
    make it hand-to-hand against the victim's agility, and a botched grab is
    heard at once while a clean one buys twenty rounds or so.
  - **Subtle original behavior, easy to get wrong.** A successful grab builds
    a whole creature to hold the copy in — rolling an age, a gender and a
    birthday — and then overwrites it. Those rolls are in the sequence, so
    they are in the port.
  - Verified by the `kidnap` probe: four things to hold against four kinds of
    victim, four grades of grabber and three states of injury (576 samples),
    compared on draw counts, whether they were taken, whether it was done bare
    handed, and what the grabber learned from it.
  - Choosing who grabs whom, and releasing somebody afterwards, are site-loop
    prompts and land with Gate G.
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
- [ ] Site specials and interaction rules from `mapspecials.cpp`, in
    `core/systems/site/specials/`. Each is transcribed with its prompt answered
    and the display taken out, because several of the original's rolls sit in
    the middle of the printing.
  - [x] Wrecking the fittings (`special_sweatshop_equipment()`,
      `special_polluter_equipment()`, `special_display_case()`,
      `special_graffiti()`), the two cages
      (`special_lab_cosmetics_cagedanimals()`,
      `special_lab_genetic_cagedanimals()`) and the reactor
      (`special_nuclear_onoff()`), in `vandalism.gd`, `cages.gd` and
      `reactor.gd`. Verified by the `site_specials` probe: seven acts against
      three squad sizes, four grades of skill, three rooms, nuclear power
      banned or not and a building with real security or without.
  - [x] Emptying the cells (`special_policestation_lockup()`,
      `special_courthouse_lockup()`, `special_prison_control()`) and the
      intelligence archive (`special_intel_supercomputer()`), in `lockups.gd`,
      `prison_control.gd` and `supercomputer.gd`, sharing the room-filling loop
      in `prisoner_rescue.gd`. Verified by the `lockup` and `prison_control`
      probes.
  - [x] The jury (`special_courthouse_jury()`), the armoury
      (`special_armory()`) and both safes (`special_corporate_files()`,
      `special_house_photos()`), in `jury.gd`, `armory.gd` and `safes.gd`.
      Verified by the `vaults` probe: four acts against three squad sizes, four
      grades of skill, three rooms, an army base or a corporate headquarters,
      the two unique guns already taken or not, and a squad already noticed or
      not — 3,456 samples compared on draw counts, the alarm and its clock, the
      crime sheet, who is left in the room, which unique guns are gone and
      every item carried out.
  - [ ] The bank (`special_bank_vault()`, `special_bank_teller()`,
      `special_bank_money()`), the oval office (`special_oval_office()`) and
      the CCS boss (`special_ccs_boss()`).
  - [ ] The door staff: `special_security()` and its three entry points,
      `special_bouncer_greet_squad()`, `special_bouncer_assess_squad()`.
      These are prompts before they are rules, so they land with the site loop.
  - [ ] `special_readsign()`, which is presentation, and the two broadcast
      studios (`special_radio_broadcaststudio()`,
      `special_news_broadcaststudio()`), which wait on Gate D's
      `radio_broadcast()`/`news_broadcast()`.
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
