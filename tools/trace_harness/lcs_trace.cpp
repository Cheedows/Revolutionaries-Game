// See lcs_trace.h. Liberal Crime Squad is GPL-2.0-or-later; so is this file.
#include "lcs_trace.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
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

void lcs_trace_swap()
{
   if (!g_active) return;
   g_swaps++;
}

int lcs_trace_next_key(const char *kind)
{
   initialise();
   if (!g_active) return -1;

   std::string text = normalise(g_screen);
   g_screen.clear();

   bool exhausted = g_script_pos >= g_script.size()
                    || (g_max_keys >= 0 && g_frame >= g_max_keys);
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
