// See lcs_trace.h. Liberal Crime Squad is GPL-2.0-or-later; so is this file.
#include "lcs_trace.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <deque>
#include <vector>

namespace {

bool g_initialised = false;
bool g_active = false;
FILE *g_out = NULL;
unsigned long g_seed = 0;
bool g_seed_forced = false;
long g_max_keys = -1;

std::vector<int> g_script;   // keystrokes to feed, in order
size_t g_script_pos = 0;
long g_frame = 0;
long long g_draws = 0;
long long g_draws_at_last_frame = 0;
long long g_swaps = 0;
long long g_swaps_at_last_frame = 0;
std::string g_screen;        // text drawn since the last frame

// Reads the keystroke script. One key per line: a single character, or a
// bracketed name for the keys that have no printable form.
void load_script(const char *path)
{
   FILE *file = fopen(path, "r");
   if (!file)
   {
      fprintf(stderr, "lcs_trace: cannot open script %s\n", path);
      exit(2);
   }
   char line[256];
   while (fgets(line, sizeof(line), file))
   {
      size_t length = strlen(line);
      while (length && (line[length - 1] == '\n' || line[length - 1] == '\r'))
         line[--length] = '\0';
      if (length == 0) continue;
      if (line[0] == '#') continue;                 // comment
      if (!strcmp(line, "[enter]")) g_script.push_back('\n');
      else if (!strcmp(line, "[space]")) g_script.push_back(' ');
      else if (!strcmp(line, "[esc]")) g_script.push_back(27);
      else if (!strcmp(line, "[up]")) g_script.push_back('8');
      else if (!strcmp(line, "[down]")) g_script.push_back('2');
      else if (!strcmp(line, "[left]")) g_script.push_back('4');
      else if (!strcmp(line, "[right]")) g_script.push_back('6');
      else g_script.push_back((unsigned char)line[0]);
   }
   fclose(file);
}

void initialise()
{
   if (g_initialised) return;
   g_initialised = true;

   const char *script = getenv("LCS_TRACE_SCRIPT");
   if (!script) return;
   g_active = true;
   load_script(script);

   const char *seed = getenv("LCS_TRACE_SEED");
   g_seed = seed ? strtoul(seed, NULL, 10) : 1;

   const char *max_keys = getenv("LCS_TRACE_MAXKEYS");
   if (max_keys) g_max_keys = strtol(max_keys, NULL, 10);

   const char *out = getenv("LCS_TRACE_OUT");
   g_out = out ? fopen(out, "w") : stdout;
   if (!g_out)
   {
      fprintf(stderr, "lcs_trace: cannot open output %s\n", out);
      exit(2);
   }
}

// Screen text is compared literally, so it is normalised: runs of spaces
// collapse and leading/trailing space is dropped. Cursor position is not
// recorded — what the game *says* is the logic signal, not where it puts it.
std::string normalise(const std::string &text)
{
   std::string out;
   bool space = false;
   for (size_t i = 0; i < text.size(); i++)
   {
      char ch = text[i];
      if (ch == ' ' || ch == '\t' || ch == '\n')
      {
         space = !out.empty();
         continue;
      }
      if ((unsigned char)ch < 32) continue;
      if (space) { out += ' '; space = false; }
      out += ch;
   }
   return out;
}

void write_json_string(FILE *file, const std::string &text)
{
   fputc('"', file);
   for (size_t i = 0; i < text.size(); i++)
   {
      char ch = text[i];
      if (ch == '"' || ch == '\\') { fputc('\\', file); fputc(ch, file); }
      // Traces stay pure ASCII: the game draws extended characters, and the
      // comparator must not depend on anyone's encoding guess.
      else if ((unsigned char)ch < 32 || (unsigned char)ch > 126)
         fprintf(file, "\\u%04x", (unsigned char)ch);
      else fputc(ch, file);
   }
   fputc('"', file);
}

} // namespace

bool lcs_trace_active()
{
   initialise();
   return g_active;
}

unsigned long lcs_trace_seed()
{
   initialise();
   return g_seed;
}

bool lcs_trace_has_seed()
{
   initialise();
   return g_active || g_seed_forced;
}

void lcs_trace_set_seed(unsigned long value)
{
   initialise();
   g_seed = value;
   g_seed_forced = true;
}

void lcs_trace_char(char ch)
{
   if (!g_active) return;
   g_screen += ch;
}

void lcs_trace_draw()
{
   if (!g_active) return;
   g_draws++;
}

long long lcs_trace_draw_count()
{
   return g_draws;
}

void lcs_trace_swap()
{
   if (!g_active) return;
   g_swaps++;
}

// Keys a probe has queued up, answered before the script is consulted. A probe
// that needs a particular answer to a particular prompt cannot get it out of a
// looping keystroke file, so it pushes the answer instead.
static std::deque<int> g_pushed;

void lcs_trace_push_key(int key)
{
   g_pushed.push_back(key);
}

void lcs_trace_clear_keys()
{
   g_pushed.clear();
}

// Draws made on a side stream, which a probe subtracts from its own count.
static long long g_side_draws = 0;
static long long g_side_at = 0;

void lcs_trace_side_begin()
{
   g_side_at = g_draws;
}

void lcs_trace_side_end()
{
   g_side_draws += g_draws - g_side_at;
}

long long lcs_trace_side_draws()
{
   long long total = g_side_draws;
   g_side_draws = 0;
   return total;
}

int lcs_trace_next_key(const char *kind)
{
   initialise();
   if (!g_active) return -1;

   if (!g_pushed.empty())
   {
      int pushed = g_pushed.front();
      g_pushed.pop_front();
      g_screen.clear();
      g_frame++;
      return pushed;
   }

   std::string text = normalise(g_screen);
   g_screen.clear();

   bool exhausted = g_script_pos >= g_script.size()
                    || (g_max_keys >= 0 && g_frame >= g_max_keys);
   // A probe drives thousands of prompts and does not care what the screen
   // says, so it loops the script rather than running out and quitting. A
   // recorded playthrough still ends when its script does.
   if (exhausted && getenv("LCS_PROBE") && !g_script.empty()
       && !(g_max_keys >= 0 && g_frame >= g_max_keys))
   {
      g_script_pos = 0;
      exhausted = false;
   }
   int key = exhausted ? -1 : g_script[g_script_pos++];

   std::string state;
   lcs_trace_state(state);

   fprintf(g_out, "{\"frame\":%ld,\"kind\":\"%s\",\"draws\":%lld,\"swaps\":%lld,\"text\":",
           g_frame, kind, g_draws - g_draws_at_last_frame, g_swaps - g_swaps_at_last_frame);
   write_json_string(g_out, text);
   if (key >= 0) fprintf(g_out, ",\"key\":%d", key);
   fprintf(g_out, ",\"state\":%s}\n", state.c_str());
   fflush(g_out);

   g_frame++;
   g_draws_at_last_frame = g_draws;
   g_swaps_at_last_frame = g_swaps;
   return key;
}


// --- The last poll survey ---------------------------------------------------
//
// survey() builds its figures in a local array and then prints them. A probe
// wants the numbers, not the screen, so survey() hands them here on the way
// past and the probe picks them up afterwards.

static int survey_figures[64];
static int survey_count = 0;
static int survey_approval = 0;

void lcs_trace_survey(const int *figures, int count, int approval)
{
   if (count > (int)(sizeof(survey_figures) / sizeof(survey_figures[0])))
      count = (int)(sizeof(survey_figures) / sizeof(survey_figures[0]));
   for (int i = 0; i < count; i++) survey_figures[i] = figures[i];
   survey_count = count;
   survey_approval = approval;
}

const int *lcs_trace_survey_figures(int *count, int *approval)
{
   if (count) *count = survey_count;
   if (approval) *approval = survey_approval;
   return survey_figures;
}


// --- The numbers a trial turned on -----------------------------------------

static int g_trial[4] = {0, 0, 0, 0};

void lcs_trace_trial(int jury, int prosecution, int defensepower, int lenient)
{
   g_trial[0] = jury;
   g_trial[1] = prosecution;
   g_trial[2] = defensepower;
   g_trial[3] = lenient;
}

void lcs_trace_trial_read(int *jury, int *prosecution, int *defensepower,
                          int *lenient)
{
   if (jury) *jury = g_trial[0];
   if (prosecution) *prosecution = g_trial[1];
   if (defensepower) *defensepower = g_trial[2];
   if (lenient) *lenient = g_trial[3];
   g_trial[0] = g_trial[1] = g_trial[2] = g_trial[3] = -12345;
}


static int g_charges[3] = {0, 0, 0};

void lcs_trace_trial_charges(int scarefactor, int typenum, int confessions)
{
   g_charges[0] = scarefactor;
   g_charges[1] = typenum;
   g_charges[2] = confessions;
}

void lcs_trace_trial_charges_read(int *scarefactor, int *typenum,
                                  int *confessions)
{
   if (scarefactor) *scarefactor = g_charges[0];
   if (typenum) *typenum = g_charges[1];
   if (confessions) *confessions = g_charges[2];
}
