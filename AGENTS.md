# AGENTS.md

These rules apply to Codex and any other coding agent working in this repository.

## Read first

Use these as the authoritative project documents:

1. `docs/ROADMAP_PORT_COMPLETION.md` — current goal and remaining conversion work.
2. `docs/port/ARCHITECTURE.md` — binding code/layer contract.
3. `docs/ROADMAP_FUTURE.md` — post-parity ideas only.
4. `docs/port/LICENSING-NOTES.md` — licensing constraints/reference.
5. `CLAUDE.md` — repository operating rules; follow its documentation-discipline rules even if you are not Claude.

## Current objective

Complete the remaining LCS → Godot 4.6 parity port. `src/` is a behavioral reference; `game/` is the production implementation.

Work directly from the unchecked items in `docs/ROADMAP_PORT_COMPLETION.md`. Finish, test, mark progress there, then continue. Do not create a parallel plan.

## Documentation rule

Planning/documentation sprawl is prohibited.

- The repository has exactly two active roadmaps: `docs/ROADMAP_PORT_COMPLETION.md` and `docs/ROADMAP_FUTURE.md`.
- Do not create new roadmap, plan, phase, status, handoff, TODO, progress, notes, session-summary or completion-report files unless the user explicitly asks for a new standalone document.
- Required port discoveries and blockers go into the existing port roadmap.
- Non-parity ideas go into the future roadmap.
- Architecture changes go into `docs/port/ARCHITECTURE.md`.
- Implementation history belongs in commits, tests and code—not accumulating markdown files.
- Delete/consolidate superseded planning docs when replacing them.

## Engineering constraints

- Respect `data/ -> core/ -> app/ -> ui/` dependency direction.
- Keep `core/` deterministic/headless and independent of scenes, Nodes, UI/input, wall-clock time and arbitrary engine RNG.
- UI submits Commands/Intents and renders state/Events; it does not mutate simulation state directly.
- Preserve deterministic RNG consumption and side-stream swaps while establishing parity.
- Prefer focused systems and data-driven Resources over recreating large legacy switch statements/monoliths.
- A port task is not complete until its strongest practical parity/unit/probe coverage is green.
- When scripted legacy traces cannot reliably reach a path, construct deterministic fixtures rather than accepting an untested gap.

## Mainline

The repository currently uses `master` as its default/canonical branch. There is no `main` branch; treat `master` as mainline unless that is deliberately changed later.
