# Phase 2 status: systems

What is ported and diffed against the original, and what is not. Every "green"
row is asserted by `tools/run_tests.sh` against a recording from the real game;
nothing here is claimed on inspection alone.

Two kinds of evidence are used:

- **Probes** (`tools/trace_harness/record_probes.sh`) run one piece of the
  original in isolation against loaded content and record what it produced. A
  divergence names a function.
- **Traces** (`tools/trace_harness/record_all.sh`) record whole playthroughs.
  They are the end-to-end check, and are used once enough systems exist to
  replay one.

## Green

| System | Ported from | Evidence |
|---|---|---|
| RNG | `compat.cpp` | 3 seeds x 10,000 draws; every swap-free frame of every trace |
| Creature construction | `creatureinit()` | 200 probe samples |
| Creature types | `make_creature()` | 848 probe samples (106 types x 8 seeds) |
| Attribute rules | `get_attribute()` | folded into the two above |
| Training | `train()`, `skill_up()` | 120 samples x 12 steps |
| Dice system | `roll_check()`, skill and attribute rolls | abilities 0-40, 80 creature samples |
| Equipment | `src/items/`, `take_clips()`, `reload()` | 40 armor types, 36 weapons |
| Public opinion | `publicmood()`, `stalinview()`, `randomissue()` | 6 scenarios x 22 laws |
| Voters and legislators | `getswingvoter()`, `presidentapproval()`, … | 6 scenarios, 1,000-voter approval |
| Congress | `congress()` | 10 scenarios: 435 House and 100 Senate votes each |
| Elections | `elections_house()`, `elections_senate()` | 10 scenarios, every election law |
| Supreme Court | `supremecourt()` | 12 scenarios, laws and bench |
| Names | `firstname()`, `lastname()`, `generate_name()` | 40 samples x 44 names |
| Opinion shifts | `change_public_opinion()` | 12 scenarios x 972 shifts |
| Crime and heat | `criminalize()`, `lawflagheat()` | crime list checked against a trace |
| Street fundraising | `doActivitySolicitDonations()` and the three sales | 8 scenarios x 4 days |
| Brownie selling | `doActivitySellBrownies()` | same probe, both Liberal drug laws |
| Reputation | `addjuice()` | folded into the activities probe |
| Wounds and armor | `healthmodroll()`, `damagemod()` | 60 samples x 8 rolls, 6 armors x every body part |
| Session loop | the seam itself | headless run, 31 days into February |
| Save format | new, not ported | round-trip from recorded state |

## Not green

Named rather than skipped. Each is work, not a decision to leave it out.

- **Daily turn** is a skeleton: the date, time served, wounds and levelling.
  Recruitment, sieges, interrogation, dating, hacking, graffiti, prostitution,
  teaching, burial and the news pass are not ported.
- **Prostitution** is ported but not probed: a police sting in the original
  calls `find_police_station()`, which walks a world the probe does not build.
  The same probe would also need a Liberal drug law to keep a brownie seller out
  of the cells, which is why the recorded scenarios use one.
- **Arrests** are ported but not probed: an arrest in the original reaches
  `criminalize()` and the news system, which need a built world the probe does
  not have. The rule itself is small and unit-tested.
- **Stealth, disguise and driving rolls** are left out of the dice system: they
  read armor, a disguise and the current vehicle, and belong with the site and
  chase systems.
- **Monthly turn** — finances, justice, sleepers, elections, the endgame — is
  not started. The voter model and the legislative session it needs are green.
- **Constitutional endgames** are left out of the ported Congress: purging the
  court, imposing term limits, and the two ways an extreme Congress ends the
  game. Each is its own system.
- **News**, **combat**, **site infiltration** and **chases** are not started.
- **Site maps**: `art/sitemaps.txt` is a scripting language interpreted by
  `configfile.cpp`, not data, and is still unextracted.
- **UI** is Phase 3 and is a stub.

## Bugs found in the original along the way

Recorded because a port has to decide what to do about each, and because
"faithful" means reproducing them unless there is a reason not to.

1. `roll_gender()` has no `break` after the male-bias case, so a male-biased
   creature that fails its check falls through into the female-bias check.
   Reproduced: it changes the draw count as well as the result.
2. `art/weapons.xml` misspells `strength_min` as `strentgh_min` in two attacks,
   and eleven armors carry an `appropriate_weapon` element no reader looks at.
   Both are silently ignored by the original; both are ignored here too.
3. `bashstrengthmod` defaults to 1 in `WeaponType`'s constructor, though the
   XML's own documentation says 100. The code is what runs.
4. `fireprotection` is a boolean, not a rating — the extractor had been reading
   `<fireprotection>true</fireprotection>` as the number zero, which quietly
   turned firefighters' bunker gear into ordinary clothing.
5. Cutscenes cannot work in a 64-bit build: `loadmovie()` reads frame timings
   with `sizeof(long)` from files written where `long` was 4 bytes. Played to
   the end they hang or read out of bounds. Not ported at all.
6. `alarmwait()` can block forever if its timer fires before `pause()` is
   reached — the original's own comment says so. The port has no such wait.
