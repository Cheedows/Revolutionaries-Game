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

/* Emits one JSONL record for the screen built since the last call and returns
   the next scripted keystroke. Returns -1 when the script is exhausted, which
   the caller turns into a quit. */
int lcs_trace_next_key(const char *kind);

/* Serializes the whole simulation state as JSON. Defined in lcs_state.cpp,
   which can see the game headers; lcs_trace.cpp deliberately cannot. */
void lcs_trace_state(std::string &out);

#endif // LCS_TRACE_H
