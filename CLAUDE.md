# CLAUDE.md

## Current project goal

Finish the Liberal Crime Squad → Godot 4.6 conversion to mechanical parity, then expand and modernize Revolutionaries from that stable baseline.

The active execution plan is:

- `docs/ROADMAP_PORT_COMPLETION.md` — **canonical current roadmap**. Work this top-to-bottom until the port is complete.
- `docs/ROADMAP_FUTURE.md` — post-parity ideas/bug fixes/modernization only.
- `docs/port/ARCHITECTURE.md` — binding architecture and layer rules.
- `docs/port/LICENSING-NOTES.md` — licensing constraints/reference.

Do not treat old C++ code as the future architecture. `src/` is the parity oracle/reference; `game/` is the future game.

## Documentation discipline — mandatory

This repository must not accumulate planning-document bloat.

1. There may be **no more than two active roadmap documents**: the two listed above.
2. Do **not** create new `ROADMAP`, `PLAN`, `PHASE`, `STATUS`, `HANDOFF`, `TODO`, `PROGRESS`, `NOTES`, session-summary, implementation-plan or completion-report documents unless the user explicitly requests a new standalone document.
3. Update `docs/ROADMAP_PORT_COMPLETION.md` for conversion progress, blockers, parity exceptions and newly discovered required work.
4. Put ideas that are not required for parity in `docs/ROADMAP_FUTURE.md`.
5. Change architecture rules in `docs/port/ARCHITECTURE.md`; do not make a competing architecture/design document.
6. Use code comments, tests, commit messages and Git history for implementation detail/history. Git history is the session log.
7. When work completes, update the existing roadmap checkbox/status in the same workstream. Do not write a separate status report.
8. Prefer deleting or consolidating superseded planning docs over leaving stale instructions for future agents.

## Architecture rules

`docs/port/ARCHITECTURE.md` is binding. In particular:

- Pure GDScript target. No C++/GDExtension carried forward as runtime game logic.
- Dependencies flow `data/ -> core/ -> app/ -> ui/` only.
- `core/` is deterministic and headless: no Node/scene/UI/input/OS-time dependencies and no arbitrary engine RNG.
- UI reads state and sends Commands/Intents; it does not directly mutate `GameState`.
- Simulation emits structured Events, not prose/presentation calls.
- Content should be data-driven Resources where practical.
- Keep systems focused and testable; do not recreate legacy monoliths or `misc/common/utils/helpers` dumping grounds.
- Preserve legacy quirks until parity is demonstrated when changing them could alter behavior or RNG consumption.

## How to work the port

- Start by reading the unchecked items in `docs/ROADMAP_PORT_COMPLETION.md`.
- Continue through dependencies rather than inventing a new phase plan.
- Use the original C++ implementation and trace harness as the behavioral oracle.
- Add the strongest practical deterministic probe/golden/unit test with each ported behavior.
- Do not stop at "representative" coverage when the roadmap asks for the full original mode.
- If the original harness cannot reliably reach a behavior, build a deterministic fixture/probe instead of leaving it unverified.
- Do not begin new gameplay features while parity work remains unless the user explicitly changes priority.

## Mainline note

The repository's canonical/default branch is currently named `master`; there is no `main` branch. Treat `master` as mainline unless the repository is deliberately renamed later.
