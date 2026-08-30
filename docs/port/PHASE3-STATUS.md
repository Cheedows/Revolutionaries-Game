# Phase 3 status: the interface

The first pass exists and runs. It is not the modernization pass — that comes
once the systems behind it are all green — but it is a real interface rather
than a curses emulator, and it proves the seam works.

## What is there

`ui/screens/base_screen.tscn` is the running game: it owns a [Session], sends it
decisions, and renders the events that come back. It never touches `GameState`
to change anything.

- **`ui/theme/`** — one palette and one theme, built in code so a colour changes
  in a single place. The original is a sixteen-colour terminal that leans on
  that palette for meaning — green for the player's people, red for the
  opposition — and the reading is kept even though nothing here is a terminal.
- **`ui/widgets/`** — a status bar (date, funds, public mood as a bar rather
  than a number), the agenda (every law and where it stands, always visible
  rather than behind a keypress), the roster, and a scrolling log with history.
- **`ui/adapters/event_text.gd`** — the only place that knows both an event's
  shape and English. Systems emit no prose at all, which is what lets the same
  event become a log line here and something else elsewhere.

## What that demonstrates

The layout is the point. The original's base mode is one terminal screen with
the squad at the top, single-letter commands at the bottom, and everything else
reached by pressing a key — because 80x25 forces you to choose what to show.
This shows the agenda, the roster and the log at once, because it does not have
to choose. That is the modernization the port is for, in its smallest form.

## What is not there

- **Every screen but the safehouse.** Site mode, the squad screens, shops,
  news, the review screens and the title sequence are not built. They wait on
  the systems behind them.
- **Intents are not yet rendered.** The seam exists and is tested, but no
  ported system asks a question yet, so nothing puts one to the player.
- **No new-game sequence.** The screen seats a plausible starting country so
  the political systems have something to act on; the original's character
  creation is not ported.
- **Nothing is styled beyond the theme.** No art, no fonts, no layout polish.
- **The screen is built in code**, not laid out in the editor. That is
  deliberate for now: it keeps the palette authoritative and makes the screen
  testable headlessly. A designed layout can replace it once the shape settles.

## How it is checked

`tools/run_tests.sh` instantiates the screen headlessly, runs forty days through
it, and asserts the calendar and city are sane — so a UI that will not build is
a failing test rather than something noticed later.
