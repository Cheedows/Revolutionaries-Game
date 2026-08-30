# Revolutionaries — Future Roadmap

**Status:** parking lot for post-parity ideas only.  
**Active conversion work belongs in:** `docs/ROADMAP_PORT_COMPLETION.md`.

This is intentionally the only second roadmap document. An idea that is not necessary to finish the LCS → Godot parity conversion goes here rather than spawning a proposal, phase plan, handoff, TODO, design-roadmap or status file.

Nothing in this document is automatically approved for implementation. The current priority remains completing the parity port.

## 1. Post-parity bug-fix pass

Once deterministic parity gives us a stable baseline, decide deliberately whether to fix original behavior that was reproduced only for compatibility:

- Fix the `roll_gender()` fallthrough bug.
- Correct ignored/misspelled data fields where the intended behavior is clear.
- Revisit `bashstrengthmod` default behavior.
- Clean up `fireprotection` semantics into an explicit typed field.
- Fix the dangling-`else` relaxed win condition.
- Fix `generatestairsrandom()` secure-list indexing instead of preserving defined-safe approximations of the legacy bug.
- Remove any equivalent of the `alarmwait()` race rather than emulating it.
- Audit other quirks discovered during the final parity sweep and classify each as **keep**, **fix**, or **replace**.

## 2. Full UI / UX modernization

After every original mode is functionally accessible in Godot:

- Replace code-built provisional layouts with designed scenes where that improves iteration.
- Establish final typography, iconography, spacing, responsive rules and visual hierarchy.
- Build richer character dossiers, equipment views and contextual tooltips.
- Make political state legible through dashboards/history rather than terminal-style text dumps.
- Give site mode a clear modern tactical presentation while keeping the simulation engine-independent.
- Improve news presentation into an actual newspaper/broadcast experience rather than recreating ASCII assets.
- Add animation/transitions only where they increase clarity; do not make presentation timing part of simulation correctness.
- Accessibility pass: scalable type, keyboard-only navigation, focus visibility, color-independent status indicators and remappable controls.

## 3. Product architecture after the port

Potential improvements once parity constraints no longer dominate:

- Replace remaining generated/hard-coded lookup tables with authored Resources where doing so improves modability.
- Add editor tooling for creature, weapon, armor, activity, site and law content.
- Formalize mod/content-pack loading without allowing mods to bypass save/version safety.
- Add simulation debug inspectors: RNG stream state, event timeline, intent queue, entity/state diff and deterministic replay controls.
- Keep the headless core useful for automated balance simulation and AI-assisted testing.
- Consider snapshot/replay tooling for bug reports so a player can provide a seed + Intent history instead of an opaque save.

## 4. Expansion beyond LCS

The clean core/UI split is specifically intended to make Revolutionaries larger than a literal LCS remake. Candidate directions to evaluate after parity include:

- More factions and organizations with independent goals, resources and relationships.
- Deeper interpersonal relationships, loyalty, rivalries and organizational politics.
- Multiple cities/regions and richer travel/world structure.
- More dynamic safehouses, property ownership and organizational infrastructure.
- Expanded covert operations, surveillance, infiltration and counterintelligence.
- More systemic law/policy interactions instead of only fixed legacy issue tracks.
- Richer NPC schedules, careers and persistent world consequences.
- Expanded tactical/site simulation and more data-driven site types.
- More sophisticated media/public-opinion feedback loops.
- Additional strategic resources, logistics and long-term organizational planning.

Each major expansion should first be expressed as data/state/system seams that fit `docs/port/ARCHITECTURE.md`; do not erode the architecture to reproduce old-style monoliths.

## 5. Quality, performance and release work

- Profiling pass on large populations, long simulations, site maps and event-heavy UI.
- Save migration stress tests across multiple future schema versions.
- Fuzz/property testing for deterministic systems and serializers.
- Long-run soak simulations over many seeds to detect state drift, runaway economies and impossible government states.
- Crash-safe autosave/backup rotation.
- Packaging/export validation on target desktop platforms.
- Replace/remove legacy vendored libraries and obsolete build artifacts from the production distribution once the C++ reference is no longer needed.

## 6. Documentation rule

Do **not** create a new roadmap for any item above. Expand the relevant section here. If an idea eventually becomes active implementation work, move its concrete acceptance criteria into the existing active roadmap rather than creating a third roadmap document.
