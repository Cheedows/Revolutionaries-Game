# AGENTS.md

These rules apply to Codex and any other coding agent working in this repository.

## Read first

Use these as the authoritative project documents:

1. `docs/ROADMAP_FUTURE.md` — the active roadmap. Nothing in it is approved.
2. `docs/port/ARCHITECTURE.md` — binding code/layer contract.
3. `docs/ROADMAP_PORT_COMPLETION.md` — the record of the finished conversion.
   Read it to find out why something is the way it is; do not work from it.
4. `docs/port/LICENSING-NOTES.md` — licensing constraints/reference.
5. `CLAUDE.md` — repository operating rules; follow its documentation-discipline rules even if you are not Claude.

## Current objective

The LCS → Godot 4.6 parity port is finished. `game/` is the whole playable
implementation; `src/` is a test fixture that three CI checks and the trace
harness read, and nothing under `game/` may depend on it.

There is no conversion work left to pick up. New work is a decision, so ask
before starting anything in `docs/ROADMAP_FUTURE.md`.

Parity is enforced rather than merely achieved: `tools/audit_parity.py`,
`tools/audit_state.py` and `tools/audit_choices.py` fail the build when the
port stops accounting for something the original does, and 71 probes and 12
golden traces diff it against the original draw for draw. A deliberate
departure means updating those and saying so; an accidental one means a red
build.

## Documentation rule

Planning/documentation sprawl is prohibited.

- The repository has exactly two roadmaps: `docs/ROADMAP_FUTURE.md` (active) and `docs/ROADMAP_PORT_COMPLETION.md` (the conversion's record).
- Do not create new roadmap, plan, phase, status, handoff, TODO, progress, notes, session-summary or completion-report files unless the user explicitly asks for a new standalone document.
- Ideas and findings go into the future roadmap.
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
