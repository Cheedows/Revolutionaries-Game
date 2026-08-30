// Golden-trace instrumentation for the original Liberal Crime Squad build.
//
// Purpose: make the C++ game replayable and observable so the Godot port can be
// diffed against it (docs/port/GODOT-PORT-PLAN.md §5). Everything here is inert
// unless LCS_TRACE_SCRIPT is set in the environment, so the normal game build
// behaves exactly as before.
//
// Environment:
//   LCS_TRACE_SCRIPT  path to a file of keystrokes to feed the game
//   LCS_TRACE_OUT     path to write the JSONL trace to (default: stdout)
//   LCS_TRACE_SEED    integer seed for the RNG, making runs reproducible
//   LCS_TRACE_MAXKEYS stop after this many keys (default: the whole script)
//
// Liberal Crime Squad is GPL-2.0-or-later; so is this file.
#ifndef LCS_TRACE_H
#define LCS_TRACE_H

#include <string>

/* True when the harness is driving this run. */
bool lcs_trace_active();

/* Records one character of screen output. Called from the addchar() wrappers,
   which every addstr()/mvaddstr() in the game funnels through. */
void lcs_trace_char(char ch);

/* Counts an RNG draw, so a trace shows how much randomness each step consumed. */
void lcs_trace_draw();

/* Counts an RNG state swap. The game keeps side streams (per-location map
   seeds, an attorney seed) and splices them into the main generator with
   copyRNG(), so a frame containing a swap is not a continuous draw sequence. */
void lcs_trace_swap();

/* The seed to use, or 0 when the harness is not driving the run. */
unsigned long lcs_trace_seed();

/* True when the RNG should be seeded from lcs_trace_seed() rather than from
   system entropy: either a trace is being recorded or a probe set a seed. */
bool lcs_trace_has_seed();

/* Forces the seed, for probes that reseed between samples. */
void lcs_trace_set_seed(unsigned long value);

/* How many draws have been made since the run started. A probe records this
   either side of a step so a divergence can be located by draw count rather
   than by guessing which roll went missing. */
long long lcs_trace_draw_count();

/* Records the figures survey() came up with, so a probe can compare the poll
   the player reads rather than only the randomness it consumed. Inert unless a
   probe is running. */
void lcs_trace_survey(const int *figures, int count, int approval);

/* The last figures recorded by lcs_trace_survey(). */
const int *lcs_trace_survey_figures(int *count, int *approval);

/* Runs the system probe named by LCS_PROBE and exits, when it is set. Called
   from main() once content is loaded. */
void lcs_probe_run_if_requested();

/* Emits one JSONL record for the screen built since the last call and returns
   the next scripted keystroke. Returns -1 when the script is exhausted, which
   the caller turns into a quit. */
int lcs_trace_next_key(const char *kind);

/* Serializes the whole simulation state as JSON. Defined in lcs_state.cpp,
   which can see the game headers; lcs_trace.cpp deliberately cannot. */
void lcs_trace_state(std::string &out);

#endif // LCS_TRACE_H
