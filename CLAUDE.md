# CLAUDE.md

## Current project goal

The Liberal Crime Squad → Godot 4.6 conversion is finished: `game/` is the
whole playable implementation and every gate in the port roadmap is green. The
goal now is to expand and modernize Revolutionaries from that baseline, which
means deciding what to build rather than what to port.

- `docs/ROADMAP_FUTURE.md` — **the active roadmap.** Nothing in it is approved;
  ask before starting any of it.
- `docs/ROADMAP_PORT_COMPLETION.md` — the record of the conversion. Read it to
  find out *why* something is the way it is; do not work from it.
- `docs/port/ARCHITECTURE.md` — binding architecture and layer rules.
- `docs/port/LICENSING-NOTES.md` — licensing constraints/reference.

Do not treat old C++ code as the future architecture. `src/` is a test fixture:
four of the five audits CI runs read it to ask whether the port still accounts
for everything the original does, and the trace harness compiles it into the
build the golden traces come from. Nothing under `game/` may depend on it.

**Parity is still enforced, not merely achieved.** `tools/audit_parity.py`,
`tools/audit_state.py`, `tools/audit_choices.py` and `tools/audit_content.py`
fail the build when the port stops accounting for something the original does;
`tools/audit_voice.py` fails it when the port paraphrases a label the original
had words for, and `tools/audit_reach.py` when something in the port can be
reached by nothing; 71 probes and 12 golden
traces diff it against the original draw for draw. A deliberate departure means
updating those and saying so. An accidental one means a red build.

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
