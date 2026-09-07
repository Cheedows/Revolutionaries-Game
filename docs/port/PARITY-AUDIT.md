# Original LCS / Godot port parity audit

Audited 2026-09-06 against master `ab5193eae126fa0b1fcfabc89f0e2e51b32fb14d`
and the bundled original C++ in `src/`. This is an evidence snapshot, not a
completion percentage. The user authorized documenting and repairing these gaps.
Implementation status belongs in the existing port completion roadmap.

## Conclusion and scope

The port is not feature-complete. The previous 100% claim confused static
accounting with playable parity. This audit traced original gameplay branches,
core continuations and their Godot UI consumers, and used deterministic runtime
fixtures for the failures below. It did not replay every campaign, law, site or
ending. Existing elections, sleepers, justice, recruitment, site specials and
high scores are implemented; absence of an entire system is not implied.

## Runtime-confirmed defects

| ID | Defect | Evidence and required behavior |
|---|---|---|
| A1 | Siege defense freezes | `SiegeAssault.engage` enters the site and prepares the floor but returns only events. `Commands.answer_siege` leaves mode=site, location=32, pending=false. Start and retain the site visit continuation. |
| A2 | Attack receives two enemy rounds | `SiteFight.run` attacks once; `SiteLoop._settle` calls `_react` again. A controlled single-enemy fixture emits two enemy ATTACK_MADE events for one Attack. Original sitemode.cpp fight branch performs one enemy round. |
| A3 | Ordinary site turns omit body progression | Wait leaves a bleeding member at blood=70; directly calling CombatAdvance lowers it to 69. Movement/Wait, pickup and reload must apply their original body progression without duplicating the fight tick. |
| A4 | Hospital outing strands members and labels months as days | Declining admission leaves location=19, home=32, clinic=0. Original daily.cpp returns the remaining squad home. HospitalVisit labels a two-month Treatment duration as “2 days”. |

## Missing or incomplete player features

| ID | Gap | Original / port evidence |
|---|---|---|
| A5 | Form, name and switch multiple squads | Original reviewmode.cpp and base TAB flow support this. SquadPanel only manages the active squad; core multi-squad state has no ordinary formation/selection UI. |
| A6 | Bulk activities and roster sorting | Original activatebulk/sorting_prompt/sortliberals have no equivalents in the one-member-at-a-time Roster UI. |
| A7 | Change equipment during a site visit | Original site E opens equip with turn consequences. SiteInventory is read-only; looted weapons and ammunition cannot be reassigned there. |
| A8 | Visible squad health and individual status in sites | Original printparty and keys 1–6 expose these throughout exploration/combat. Shared SiteScreen shows enemies and actions but lacks the equivalent squad condition view. |
| A9 | Organ injury detail | Original fullstatus lists damaged organs. DossierText.wounds reads body-part flags; a destroyed right lung still produces “Body: Liberal”. |
| A10 | Appointment workload overview | Original scheduledmeetings/scheduleddates counts are displayed. No UI reads recruit_meetings/dates counts. Missed-meeting notices exist, but players cannot see overbooking beforehand. |
| A11 | Recruitment appointment profile and eagerness | RecruitQueue provides IDs/eagerness; IntentText ignores ordinary appointment context. Original displays name, profession, workplace, stats and five eagerness descriptions. Overbooking is checked after selecting an approach; original checks before offering choices. |
| A12 | Dating/interrogation decision context | Pending contexts contain participants and interrogation details, but IntentText.detail returns empty. Original screens identify people and show relevant status. |
| A13 | Trial context and lawyer fee | The decision lacks the original defendant/indictment view. Attorney option cost=5000 renders an empty note because IntentText handles price but not cost. JusticePanel exists elsewhere. |
| A14 | Polling results | POLLS_SURVEYED carries 27 survey figures plus approval/concern, but DayText only says the member reads the polls. Agenda's exact underlying opinions are not the original noisy survey report. |
| A15 | Full-site map and siege overlays | Original M shows the full floor. SiteMapView only shows a small window and never reads map.get_siege for units/traps. Compact mode also hides the underfoot description. |
| A16 | Later dating narrative variation | DateNight consumes disaster/humiliation rolls but discards their values. DateText supplies generic prose instead of original completedate scenes. This is separate from restored in-site flirting. |
| A17 | Month-end financial report | MonthlyTurn resets ledger amounts without a report/acknowledgement. Safehouse accounts show only the current month. Original monthly.cpp calls fundreport before resetting. |
| A18 | Contextual music/audio | No Godot playback nodes/calls exist. Original has contextual music. Follow LICENSING-NOTES before carrying recordings forward. |

## Why green gates missed these

- `audit_parity.py` counts legacy function-name mentions across code, tests,
  tools and documentation; a mention is not behavioral equivalence.
- `audit_choices.py` inherits function classification rather than tracing every
  branch and deliberately excludes simple report acknowledgements.
- `audit_reach.py` accepts internal callers; it does not prove a UI-rooted,
  reachable state transition.
- State and catalog audits prove mappings/table equality, not complete flows.
- `test_long_run` explicitly is not a parity assertion and does not click the UI.

All passed during the audit: 444 original functions accounted for, 78 decision
functions, 107 globals, 593 core entries and 302 data entries across nine tables.
The runtime failures above nevertheless reproduced. Retain these gates, but
supplement them with deterministic action/continuation tests and rendered UI
checks. Do not use their counts as a completion percentage.

## Exclusions and repair priority

High scores were verified present. Squad stance controls are commented out in
the original. Guardian essay selection is unused there, and guardianupdate has
no original caller; these are not counted as missing gameplay.

Repair combat/siege progression first, then hospital/day continuations,
decision context and health/appointment visibility, squad management and field
equipment, then reports, narrative and audio. Each closed item needs focused
behavioral evidence; passing one fixture does not establish whole-system parity.


## Repair completion — 2026-09-07

The roadmap now closes all 18 identified items. The findings above remain the
historical audit, rather than being rewritten to conceal the missing features.

- A6: The roster supports individual selection, Select All, bulk activity
  assignment, and sorting by code name, health, juice, activity and location.
  Unavailable members are excluded from assignment by the existing condition
  rules. Activity-specific choices remain available through each member's row.
- A8: A persistent, horizontally swipeable squad condition strip remains on
  the shared site/combat page. Tap a member to open squad inventory and records.
- A14/A17: Polling displays its actual noisy survey, unknown figures, approval
  and concern. Month-end accounts pause before the ledger resets; copied
  income/expense figures remain readable in history after acknowledgement.
- A15: Map opens the known current floor, with a draggable detail view and a
  fitted overview. Both maps show siege units/heavy units/traps; the full map
  also exposes the underfoot description on phones. Viewing it spends no turn.
- A16: Dating retains the existing random draws and now carries their results
  into the three original disaster scenes and seven humiliation endings.
- A18: Contextual music and a persisted Music switch are present. Recordings
  come from the committed original assets with attribution. The five recordings
  excluded by LICENSING-NOTES are not shipped in Godot: trial uses defense,
  sleepers use recruiting, victory uses conquer, and news uses base music.
- A3 follow-up: A cancelled conversation or blocked wall does not advance
  bodies. Approaching a door advances reactions/bodies before its question;
  declining it does not add a second body tick. Finished dialogue advances once.

Evidence: nine focused audit-completion tests pass, covering copied reports,
all 21 date-scene combinations, actual phone clicks for bulk assignment and map
inspection, unavailable-member handling, cancellation/door timing, and loading
contextual music without RNG draws, plus toggling music through rebuilt controls.
The original activation/polling and dating comparisons pass, as does the
year-long UI playthrough with monthly acknowledgements. The click regressions
pass. Rendered CI
fixtures now include the bulk picker, full map, polling and financial reports.
These are bounded checks of the audited repairs, not proof that every original
combination of game states is equivalent.
