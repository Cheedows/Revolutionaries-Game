# Phase 0 status

What the scaffolding actually delivers, and what it does not. Written to be
checked, not believed: every claim below is asserted by `tools/run_tests.sh`
or reproducible with `tools/trace_harness/record_all.sh`.

## Green

| Item | Evidence |
|---|---|
| Godot 4.6 project laid out per ARCHITECTURE.md | `game/`, boots headless and imports clean |
| Layer, file-size and naming rules enforced | `tools/check_layers.py`, run in CI |
| Branding behind one autoload | `game/branding.gd`, tokens resolved on load |
| RNG ported bit-exact | 3 seeds x 10,000 draws x 13 values, 0 divergences |
| RNG tracks the original through real gameplay | every swap-free frame transition in every trace |
| Content extracted from `art/*.xml` | 306 resources, all loading in Godot |
| Identifier lists generated from the C++ enums | lengths asserted against a recorded trace |
| Trace harness: fixed seed, scripted input, JSONL state dump | `tools/trace_harness/` |
| Golden traces for title, base, daily/monthly and site modes | 9 traces, 3 scripts x 3 seeds |
| Dependency-free headless test runner | 15 tests, 0 failures |

## Not green

- **Chases have no trace.** Car and foot chases need a pursuit to start, which a
  fixed keystroke script cannot reliably provoke. `combat/chase.cpp` (1,842
  lines) therefore has no golden reference yet.
- **Activity assignment has no trace.** A first attempt at an `activate.keys`
  script drove the game into a state that never asked for another key. Dropped
  rather than committed as a truncated trace.
- **`site.777` is short.** 35 frames against 247 for the other two seeds: the
  squad leaves the site early on that seed, after which the script's site
  movement keys land in the base menu, and `X` there means "quit and save".
  Scripted input cannot branch. The trace is still deterministic and valid, just
  shallower.
- **`art/sitemaps.txt` is not extracted.** It is a map scripting language
  interpreted by `src/configfile.cpp`, not data. It belongs with the site
  systems in Phase 2.
- **Save games are not addressed.** Deliberate: the new format is written in
  Phase 1 with the state model, and the original's is not ported.

## Harness concessions

The instrumentation is inert unless `LCS_TRACE_SCRIPT` is set, so the ordinary
build is unchanged. Under the harness, four things behave differently, each for
a documented reason and none of them touching game logic:

1. **Recordings run under a throwaway `HOME`.** The game saves to `$HOME/.lcs`
   and loads that save on the next launch, so without this a recording is
   contaminated by the previous one.
2. **`checkkey()` returns ERR.** Polling a non-terminal stdin returns
   unpredictable values.
3. **`pause_ms()` and `alarmwait()` return immediately.** Beyond speed, this
   closes the race the original's own comment describes, where a timer firing
   before `pause()` blocks the process forever.
4. **Cutscenes are not loaded.** `loadmovie()` reads frame timings with
   `sizeof(long)` from files written where `long` was 4 bytes. On 64-bit the
   frame table misaligns, the trailing reads run past end-of-file, and a
   cutscene played to the end — which only a scripted run does, since a human
   presses a key — hangs or reads out of bounds. Cutscenes consume no randomness
   and change no state.

## One thing the port must not miss

The original does not have a single random stream. It keeps side streams — a
per-location map seed, an attorney seed — and splices them into the main
generator with `copyRNG()`, then splices the old state back. The harness counts
those swaps per frame (`"swaps"` in each record) precisely because a frame
containing one is not a continuous draw sequence. In the daily traces 495 of 497
frames are swap-free; the two that are not are world generation at startup and
the monthly justice pass. Any port that assumes one stream will diverge exactly
there.
