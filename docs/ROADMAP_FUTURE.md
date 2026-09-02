# Revolutionaries — Future Roadmap

**Status:** the active roadmap. The parity conversion is finished;
`docs/ROADMAP_PORT_COMPLETION.md` is now the record of how, and why the code
is shaped the way it is, rather than a plan to work from.

This is intentionally the only second roadmap document. An idea goes here
rather than spawning a proposal, phase plan, handoff, TODO, design-roadmap or
status file.

Nothing in this document is approved for implementation. Parity is no longer
an argument against any of it, but which of it to do is a decision, and the
decision has not been made. The main strategic advantage of the migration is
that we no longer have to choose between preserving LCS and evolving it: the
parity baseline is testable, so future changes can be deliberate departures
rather than ambiguous porting mistakes.

What keeps that baseline honest through whatever comes next is in the tree:
the layer, parity, state, decision, content and reachability checks fail the
build when the port stops accounting for the old game or when new code is
unreachable; the probes and golden traces diff against an instrumented build
of the original; and long/full-game tests exercise the Godot version without a
terminal. A deliberate departure from the original means updating those tests
and audits; an accidental one means a red build.

## 0. Playtesting on Android — done

Numbered zero because it came before the rest and is finished; everything
below it is still a decision rather than a plan.

The point was not a phone port. It was to make the game reachable: a build
that can be downloaded and installed from the phone it is going to be played
on, without a PC in the loop, so that the thing being argued about is the game
rather than a description of it.

- **The base viewport is portrait, which is what makes the rest of this work.**
  With `stretch/aspect` set to `expand` the scale is
  `min(screen.x/base.x, screen.y/base.y)` and the viewport is the screen
  divided by it, so the tighter axis decides what the layout is handed. A base
  of `1280x800` gave a 1080x2400 phone a viewport of **1280x2844 at 0.84x** —
  the desktop layout, shrunk below readable, in a viewport three times taller
  than it had anything to put in. `400x800` gives that phone `400x888` at
  2.7x, and leaves desktop identical, because any window wider than 1:2 is
  bound by its height either way; `window_width_override` keeps the desktop
  window opening at 1280x800 rather than at the base size.

  Every mobile test passed throughout that, because each one began by handing
  the layout a 400x800 viewport itself rather than asking what a phone would
  hand it. `test_a_real_phone_screen_hands_the_layout_a_narrow_viewport`
  starts from the screen instead, running the project's own content-scale
  settings through Godot's stretch system, and fails on the old base.
- **One interface, two sizes.** `ui/theme/metrics.gd` answers two questions the
  rest of the interface asks: how much room there is, and whether what is
  hitting the screen is a fingertip or a pointer. They are deliberately
  separate — a tablet is wide and still touched, a desktop window dragged thin
  is narrow and still moused — and neither is answered by asking what platform
  this is. There is no mobile build and no mobile screen: `base_screen.gd`
  re-reads the room on every resize, so a desktop window dragged narrow becomes
  the phone layout and back again.
- **One column, one scroller.** `BaseLayout.reflow()` sets the sizes and
  `BaseLayout.focus()` decides what is on screen at once. A phone reads the
  whole safehouse as a single column top to bottom, with whatever the game is
  asking at the head of it. The law column — always up on a desk — becomes
  another thing to open. The row of panel buttons wraps rather than running
  off the edge, and rows of variable length (the marching order, the cars,
  what somebody is carrying) fold onto a second line rather than being cut
  off.
- **Nothing scrolls inside anything else.** Fifteen widgets own a scroller,
  which is right on a desk — each pane holds its place and the wheel goes to
  whichever one the pointer is over. Stacked in one column on a phone they
  became fifteen little scroll boxes fighting over the same drag, and which
  one moved depended on where the thumb landed. `Metrics.unscroll()` switches
  every one of them off there and lets it grow to fit, and the screen puts one
  bar-less scroller around the lot; the log keeps thirty lines instead of four
  hundred so the page has an end. A test counts the scrollers that can move
  and fails at anything but one.
- **Touch targets.** `Metrics.enlarge()` puts a floor under the height of
  everything that can be pressed, because the theme alone is not enough for a
  control built a moment ago. The floor plan draws its squares at more than
  twice the size and shows less of the building, so a square next to the squad
  can be hit with a thumb.
- **No keyboard and no hover anywhere.** Every question is a list of buttons —
  it always was, which is what made this cheap — and the number-key shortcuts
  are a convenience rather than a route. Text is typed into `LineEdit`s, which
  Android answers with its own keyboard. Nothing is reachable only by hovering.
- **The original's words, where it had words.** The menus had been reworded
  into something flatter — "We Didn't Start The Fire" as "a strong
  Conservative Crime Squad", "Grinding is Conservative!" as "Learn quickly in
  the field", "Procuring a Wheelchair" as "Look after the wheelchairs", which
  is not even the same job. Presentation is the port's to write where the
  original printed nothing; where it printed words, those words are content.
  `tools/audit_voice.py` is the sixth check in CI. It reads every string a
  player can see and looks for it in the original's own code and content; what
  is not there must be explained in `tools/voice_exceptions.json`. The doors and
  the courts are done: the club and the checkpoint say all sixty-odd of the
  original's complaints rather than one summary each, a jury reads five ways
  with four flavours at each end, both sides' performances are graded as the
  original grades them, and a month inside tells one of its thirty stories.

- **The interface has a design system, and twenty files still to move onto it.**
  Reported as three separate complaints about one screen — the Continue button
  drawn off the bottom, six switches with no visible on state, and a focus ring
  on the first row of every list — which turned out to be one cause: nothing
  said what a switch, an action or a gap was, so all forty widgets answered for
  themselves. Across `ui/` that had come to 43 hand-built buttons, 73
  hand-built labels, 155 theme overrides and eight different hand-picked
  separations.

  `ui/theme/atoms.gd` now holds the primitives, `Metrics` holds a four-step
  spacing scale, `Palette` holds the states a control can be in, and
  `ToggleRow`, `OptionRow` and `ActionBar` sit over them. A screen's actions
  live in the bar and the bar never scrolls, which is the rule that fixes the
  cut-off button for good rather than one screen at a time. Switches that
  cancel each other are refused rather than merely ignored: turn Classic Mode
  on and "We Didn't Start The Fire" greys out, which is what the original does
  to it and is honest, because `classicmode` beats `strongccs` in newgame.cpp
  whatever `strongccs` is set to.

  **A rendered check, because the headless one cannot see this.** Three rounds
  of visibly broken layout — rows overlapping, every line cut off, a button
  drawn past the bottom edge — went past a green suite, and the reason is
  structural: a container only lays its children out inside a live tree, and a
  `--script` run has none. So a label never wraps, a row never learns how tall
  it needs to be, and the whole class of bug is invisible to every test in the
  project. `tools/check_layout.sh` renders real frames under `xvfb` at four
  sizes and reads the rectangles back, asking the one question that matters:
  is anything drawn outside the thing meant to contain it? It named all six
  broken rows, by name and by pixel, on the build that shipped them.

  The bug underneath was that a `Button` is not a `Container`, so a face
  anchored to one is never measured — and that overriding `_get_minimum_size()`
  to fix it is silently ignored, because `Button` overrides it in C++ and the
  C++ override wins. `RowButton` pushes the height into `custom_minimum_size`
  instead, which `Button` does respect.

  **All 78 files under `game/ui` are on it now**, and `audit_design.py`'s
  exemption list is empty. A file added back to it is a file exempted from the
  design system, so adding one is a decision rather than a convenience.

  Moving the last twenty over turned up what the system was for. Ten panels had
  written out the same header — a heading and a Close button in a row — and a
  row does not wrap, so on every panel with a long name ("Choosing the Right
  Liberal Vehicle") the Close button was drawn off the side of the phone,
  unreachable. Ten copies of a bug is one bug: `PanelHeader` is a flow, and
  fixing it once fixed all ten. The stores panel's two columns are wider than
  a phone put together and now stack (`Atoms.split`/`Atoms.stack`, because an
  `HBoxContainer` refuses to be laid out vertically). The safehouse page on a
  desk grew past the bottom of a 1280x800 window whenever a panel was open,
  taking the panel buttons with it, because its scroller was switched off
  rather than set to appear when needed. And the two buttons that both said
  "Wait a day" now say "Wait a day" and "Keep waiting".

  The scale learned something too. It was four steps that doubled — 4, 8, 16,
  24 — until that pushed every 12px gap up to 16 and grew the safehouse past
  the bottom of the window. It is five steps of four now. A scale has to fit
  the thing it is describing.

  **The backlog is empty.** Of the 2,331 strings a player can see, 2,072 are
  the original's own words and the remaining 259 are explained one by one in
  `tools/voice_exceptions.json` with what the original does instead. The
  ratchet is now a wall: a line that is neither carried nor explained fails
  the build, and `tools/voice_backlog.json` is `[]` and stays that way.

  Emptying it turned up more than wording. The state's charges were being
  printed as their own enum names — "bankrobbery", "armedassault" — where the
  original reads an indictment ("bank robbery", "felony assault", "3 counts of
  arson", and the two charges whose name depends on the law of the day).
  `printhealthstat()` had never been ported at all, so every screen that shows
  how somebody is holding up said "42% blood" where the original says "Badly
  Wounded"; it is now `ui/adapters/condition_text.gd` and the roster, the
  record and the fight all read from it. The CCS exposure story had been cut
  to a third of its length. The high score screen and the endings said one
  thing where the original has sixteen.

  The tool learned four things in the process, each of which had been hiding
  real matches: the original's content lives in `art/*.xml` as well as `src/`,
  so an item's name is its name; a story is assembled from a run of
  consecutive `strcat()` calls, so a sentence of it has to be looked for in
  the run rather than in one literal; punctuation glued to a format hole
  ("$%d") belongs to the number; and case is presentation, not voice.
- **The back button means back.** Android's back button closes the game unless
  the game says otherwise, which is not what a player who has just opened the
  paper means by it. `quit_on_go_back` is off and `BaseLayout.step_back()`
  shuts the topmost thing that is open — the law column, then a panel — before
  the screen falls back to declining a question that can be declined. At the
  title, where there is nothing to back out of, it still leaves.
- **Builds you can install from a phone.** `.github/workflows/android.yml`
  exports a debug APK on every push and attaches it to the run; a push to
  `master` also rolls the `mobile-latest` prerelease over to it, so the
  Releases page keeps one permanent link to the newest build. No secrets are
  involved: it signs with the debug key checked in at
  `tools/android/debug.keystore`, which is enough to install and deliberately
  not enough to publish. The key is checked in rather than generated because
  Android refuses to install a new version signed by a different key, and the
  uninstall that would otherwise be needed takes the player's saves with it;
  CI fails the build if the signer's fingerprint ever changes.

  Each build now carries a real version — `versionCode` is the workflow's run
  number and `versionName` is `0.1.<run>+<sha>` — because a preset pinned at 1
  made every build look like the same build to Android and to any updater. A
  phone keeps itself current by pointing
  [Obtainium](https://github.com/ImranR98/Obtainium) at this repository with
  *Include prereleases* and *Use release title as version string* turned on. The
  second is needed because `mobile-latest` keeps its tag forever so that the
  download link stays good, and an updater reads the tag for the version unless
  told otherwise — so the release title is the version string and nothing else,
  which is also what the APK reports to Android. Obtainium then installs each
  build over the top without touching the saves, and nothing in the repository
  has to know it is happening.
- **Portrait on a phone, and a way out of a list that is not in the list.**
  The Android build is locked upright: the layout is one narrow column, and
  turned sideways it gets the desktop's two-column form at fingertip size,
  which fits and is unreadable. This took two goes. The setting is an int in
  Godot 4 and the project held a string — `"sensor"`, then `"portrait"` — which
  the exporter casts to 0, which is `SCREEN_LANDSCAPE`. Every APK had shipped
  hard-locked sideways, and a test comparing the setting to `"portrait"`
  passed the whole time. It is `window/handheld/orientation=1` now, the test
  compares against `DisplayServer.SCREEN_PORTRAIT`, and
  `tools/android/check_orientation.py` decodes the built APK's manifest in CI
  so that only the artefact gets to say what the artefact does. `IntentDialog` also grew a
  footer: an option marked `"footer": true` is drawn as a button under the
  list rather than as another numbered row, so the six switches on the
  new-game screen read as six things you flip and Continue reads as the one
  thing that leaves. The original says that with "Press any other key to
  continue...", which is likewise not one of the lettered choices.
- **Tested rather than configured.** `tests/unit/test_mobile_layout.gd` draws
  each screen into a 400x800 viewport — a small phone, upright — and measures
  what comes out: whether anything runs off the side, whether everything
  pressable is 48 pixels tall, whether every panel and somebody's record fit,
  whether a year can be played and a building walked with nothing but taps.
  It found the overflows it was written to find — the kit buttons, the seating
  chart and the status bar were all over the edge — and it sweeps every widget
  in `ui/widgets/` rather than a list, so one added tomorrow is measured
  tomorrow. The workflow builds and signs a real APK rather than only
  declaring how one would be built; the first four attempts failed, and the
  last of them for a reason Godot does not print at all.

What is still awkward on a phone, and is worth doing next:

- Landscape on a phone gets the desktop layout at finger size, which fits but
  is dense. It is the two-column layout that should give way at a height
  threshold, not only a width one.
- Nothing is gesture-driven: no swipe between panels, no pinch on the floor
  plan, no long-press for what is now a tooltip. Tooltips in particular have
  no touch equivalent at all yet.
- The APK is signed with a key published in this repository and is arm64 only.
  That is right for a playtest and wrong for anything else: a release build
  wants a real key kept out of the tree, both architectures and a launcher
  icon. Until it has one there is no icon in the app drawer, only Godot's.
- There is no way to save to or restore from anywhere but the device, which
  makes moving a game between a phone and a desk impossible.

## 1. Post-parity bug-fix pass

Use the deterministic baseline to decide deliberately which inherited LCS
quirks are worth keeping and which should become Revolutionaries behavior.

- Fix the `roll_gender()` fallthrough bug.
- Correct ignored/misspelled data fields where the intended behavior is clear.
- Revisit `bashstrengthmod` default behavior.
- Clean up `fireprotection` semantics into an explicit typed field.
- Fix the dangling-`else` relaxed win condition.
- Fix `generatestairsrandom()` secure-list indexing instead of preserving defined-safe approximations of the legacy bug.
- Remove any equivalent of the `alarmwait()` race rather than emulating it.
- Audit other quirks discovered during the parity sweep and classify each as **keep**, **fix**, or **replace**.

The sweep is done, and the quirks it kept are not duplicated here: each is
written up at the code that reproduces it, marked `Original quirk`. Keep that
code-local inventory as the source of truth so this roadmap does not become a
second stale bug catalogue.

Three things the port already fixed rather than reproduced because the original
behavior was broken rather than meaningfully quirky:

- Newspaper *rendering* draws are separated from mechanical RNG. The old
  eighty-column layout and literal prose no longer get to move the simulation.
- Creatures the game has finished with are actually cleared by `Tombstones`
  rather than leaking forever.
- Membership is explicit through `Creature.enlisted` instead of depending on a
  day counter that reads zero on the day somebody joins.

## 2. Full UI / UX modernization

The simulation is no longer welded to terminal rendering. Exploit that rather
than building a prettier curses emulator.

- Replace provisional code-built layouts with designed Godot scenes where that improves iteration.
- Establish final typography, iconography, spacing, responsive rules and visual hierarchy.
- Use persistent panes where useful: roster, agenda, current operations, alerts, finances, public mood and event history do not need to hide behind single-letter menus.
- Build rich character dossiers with equipment, wounds, criminal history, standing, skills, relationships, recruitment lineage, organizational role and contextual actions.
- Add relationship graphs, organization trees, filters, search, history timelines and tooltips so deep simulation is understandable rather than merely present.
- Make political state legible through dashboards, trends and history rather than terminal-style text dumps.
- Give site mode a clear modern tactical presentation while keeping the simulation engine-independent.
- Improve news into an actual newspaper/broadcast experience with visual hierarchy, archives and links back to the events/people/sites behind a story.
- Let the same Event drive different presentation surfaces: log line, toast, tooltip, dossier history, newspaper story, map marker or animation without changing simulation code.
- Add animation/transitions only where they improve clarity; presentation timing must never become simulation timing.
- Accessibility pass: scalable type, keyboard-only navigation, focus visibility, color-independent status indicators and remappable controls.

The UI should expose the depth LCS already had and make future systems readable.
The goal is not merely that more information fits on screen; the player should
be able to understand *why* the organization, public, government and individual
characters changed.

## 3. Product architecture, modding and development leverage

Use Godot Resources and the headless deterministic core as a product platform,
not just as implementation details of the port.

- Replace remaining generated/hard-coded lookup tables with authored Resources where doing so improves modability and iteration.
- Add editor tooling for creature archetypes, equipment, activities, factions, organizations, sites, laws, events, encounter tables and shops.
- Formalize mod/content-pack loading without allowing mods to bypass save/version safety.
- Make adding ordinary content primarily a data operation rather than a code edit.
- Add simulation debug inspectors: RNG stream state, Event timeline, Intent queue, entity/state diff and deterministic replay controls.
- Keep the headless core useful for automated balance simulation and AI-assisted testing.
- Add snapshot/replay tooling for bug reports so a player can provide a seed + Intent history instead of only an opaque save.
- Use deterministic batch simulation as a design tool: run hundreds or thousands of campaigns under changed rules and inspect survival, income, arrests, recruitment, faction strength, public opinion and government outcomes.
- Build regression scenarios for complex emergent situations instead of relying only on hand-played saves.

Long term, mod support could cover new creature types, laws, equipment, site
types, events, factions, organizations and scenarios while leaving the core
architecture and save/version contract intact.

## 4. Deeper characters and social simulation

The old game already treats people as persistent operatives. Godot makes it
practical to turn them into much richer simulated characters and to expose that
depth through UI.

Candidate directions:

- Persistent loyalties, beliefs, ideology, fears, ambitions, trauma and personality traits.
- Friendships, romances, rivalries, grudges, mentorships and family/social ties that affect decisions rather than existing only as flavor.
- Reputation and history remembered between characters: recruitment, betrayal, rescue, arrest, injury, promotion, abandonment and shared operations.
- Recruitment lineage as a meaningful social/command network rather than only an implementation detail of orders and dispersal.
- More consequential wounds, recovery, disability, addiction, burnout and psychological effects.
- Character roles inside the organization: handler, recruiter, quartermaster, propagandist, strategist, medic, cell leader, treasurer, infiltrator and similar responsibilities.
- More autonomous NPC behavior driven by personality, situation and relationships while preserving player agency over strategic decisions.
- Dossiers that explain these systems clearly rather than burying them in invisible modifiers.

## 5. Organizations, factions and internal politics

Turn the current organization/recruitment structure into a first-class strategy
layer, and allow other organizations to use comparable systemic rules.

- Visible hierarchy: founder, lieutenants, cell leaders, handlers and recruits.
- Semi-independent cells with their own people, safehouses, funds, exposure and operational specialties.
- Regional leadership and delegation once the organization grows beyond one manageable roster.
- Front businesses, safehouses, warehouses, presses and other infrastructure as an organizational network.
- Sleeper networks with handlers, compartmentalization, compromised links and counterintelligence risk.
- Internal politics: competing priorities, factions, succession, dissent, schisms, promotions and leadership crises.
- Rival organizations with their own goals, resources, recruitment, relationships and territorial/political interests instead of being simple encounter tables.
- Alliances, feuds, infiltration, negotiation and covert action between organizations.

A major design opportunity is to let the same clean systems model the player's
movement and at least some opposition groups, so the world becomes a contest
between organizations rather than a collection of bespoke scripts.

## 6. Multiple cities and a richer strategic world

The port already removed many assumptions that made the old single-city
presentation difficult to expand. Make cities meaningful strategic entities
rather than copies of a location list.

Potential city/region differences:

- Laws and enforcement climate.
- Demographics and public opinion.
- Police/Federal pressure and investigative capability.
- Media ecosystem and political importance.
- Faction and organization presence.
- Economy, rents, jobs, black markets and fundraising opportunities.
- Distinct site pools, landmarks and infrastructure.
- Local political offices and institutions.
- Travel time, cost, logistics and risk.

This could support regional campaigns, expansion into new territory, relocating
leadership under pressure, moving people/equipment between cells and political
changes that propagate unevenly across the country.

## 7. Expanded site / tactical simulation

Site mode is now a simulation system rather than an ASCII drawing loop. It can
become substantially richer without moving mechanics into the UI.

Possible directions:

- Modern top-down tactical presentation over the existing deterministic site state.
- Better visibility and information presentation even if the underlying LCS visibility rules remain simple initially.
- Lighting, line of sight, noise and concealment as future systems.
- Guard patrols, civilian movement and schedules.
- Cameras, alarms, locked zones, access credentials and security networks.
- Contextual disguises and social infiltration that react to role, behavior and location.
- More interactive doors, utilities, machinery, evidence, documents and infrastructure.
- Fire, environmental hazards and eventually selective destruction where it adds systemic value.
- Procedural and authored site templates through data rather than giant switches.
- Preparation/intelligence that reveals maps, schedules, security systems or alternative approaches before an operation.
- More objectives than "enter, cause event, leave": surveillance, extraction, sabotage, theft, rescue, recruitment, planting evidence, information gathering and covert access.

Keep the tactical presentation replaceable: improving the map view should not
require rewriting combat, stealth, encounters or consequences.

## 8. Combat and chase presentation / expansion

The deterministic combat/chase systems can support richer presentation without
throwing away their tested mechanics.

- Character portraits/body diagrams showing wounds, equipment, ammunition and incapacitation.
- Clear target selection, attack previews and contextual consequences.
- Visual combat/event sequencing driven by Events rather than animation callbacks driving simulation.
- Better hostage, surrender, morale and rhetorical-combat presentation.
- Tactical overlays for cover/threat/escape information if future mechanics justify them.
- Chase views that expose vehicles, pursuit pressure, obstacles, damage and escape choices instead of reducing the whole sequence to text prompts.
- Future vehicle condition, route choice, traffic, pursuit escalation and support units can be added as isolated systems if desired.

The key freedom is that combat can remain mechanically deterministic while its
presentation ranges from concise dossier/log feedback to a much more visual
tactical scene.

## 9. Media, politics and public opinion

The news system should eventually become a strategic interface rather than only
an output log.

- Distinct media outlets with slant, reach, audience, credibility and relationships.
- Story lifecycles: breaking story, follow-up, counter-narrative, scandal decay and resurfacing history.
- Visual public-opinion history by issue, city, demographic or media audience if those dimensions are added.
- Let players inspect which Events produced a shift and why.
- More strategic propaganda/media activities and counter-messaging.
- Public figures, reporters and outlets as persistent actors rather than only generated prose.
- Richer elections, campaigns, lobbying, institutions and political careers once the baseline laws/politics model is deliberately expanded.
- More systemic law/policy interactions instead of only fixed legacy issue tracks.

The existing Event seam makes it possible for one operation to feed the log,
newspaper, political dashboard, character histories and organization reputation
without duplicating mechanics.

## 10. Economy, logistics and long-term planning

As the organization grows, add strategic pressures that make scale meaningful
rather than only increasing roster size.

- Funding sources with different risk, sustainability and political consequences.
- Equipment procurement, storage and movement between safehouses/cities.
- Safehouse capacity, security, upkeep and specialized facilities.
- Vehicles and transport as an operational network.
- Front businesses and legitimate income with exposure/cover tradeoffs.
- Medical, legal and prisoner-support infrastructure.
- Operational planning costs: intelligence, preparation, travel, specialists and fallback plans.
- Long-term resource allocation between recruitment, propaganda, operations, legal defense, infrastructure and political influence.

## 11. Quality, performance and release work

- Profiling pass on large populations, long simulations, site maps and event-heavy UI.
- Save migration stress tests across multiple future schema versions.
- Fuzz/property testing for deterministic systems and serializers.
- Long-run soak simulations over many seeds to detect state drift, runaway economies and impossible government states.
- Large batch simulation for balance and economy validation.
- Crash-safe autosave/backup rotation.
- Packaging/export validation on target desktop platforms.
- Maintain the legacy C++ oracle and trace harness while they continue to catch regressions; remove them from the production distribution rather than deleting useful test infrastructure.

## 12. Architectural principle for every expansion

The main post-port advantage is the freedom to change one layer without
entangling all the others. Preserve it.

- Content should generally be data.
- Simulation changes belong in focused headless systems.
- Player decisions cross the Intent/Command seam.
- Simulation reports Events; presentation decides how to show them.
- New UI must not mutate `GameState` directly.
- A new feature that requires edits throughout unrelated systems is a warning that its seam is wrong.
- Preserve deterministic seeds/replays wherever possible even after deliberate departures from LCS parity.

This is what makes it possible to evolve Revolutionaries aggressively without
losing the stable LCS baseline underneath it.

## 13. Documentation rule

Do **not** create a new roadmap for any item above. Expand the relevant section
here. If an idea becomes active implementation work, add its concrete
acceptance criteria to this roadmap rather than creating a third roadmap or a
stack of phase/status/handoff documents.
