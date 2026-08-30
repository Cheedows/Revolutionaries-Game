// System probes: run one piece of the original in isolation and dump what it
// produced, so the ported system can be diffed against it directly.
//
// Whole-game traces prove a playthrough matches; a probe pins down a single
// function, which is what makes a divergence point at a line rather than a day.
//
//   LCS_PROBE=creatures LCS_PROBE_OUT=out.jsonl crimesquad
//
// Liberal Crime Squad is GPL-2.0-or-later; so is this file.
#include <externs.h>
#include <includes.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

#include "lcs_trace.h"

namespace {

// Samples per creature type. Enough to exercise every interval and every
// random branch in make_creature() without producing an unreadable file.
const int SAMPLES = 8;

void write_string(FILE *out, const char *text)
{
   fputc('"', out);
   for (const char *p = text; p && *p; p++)
   {
      unsigned char ch = (unsigned char)*p;
      if (ch == '"' || ch == '\\') { fputc('\\', out); fputc((char)ch, out); }
      else if (ch < 32 || ch > 126) fprintf(out, "\\u%04x", ch);
      else fputc((char)ch, out);
   }
   fputc('"', out);
}

// Spawns every creature type from a known seed and records what was rolled.
void probe_creatures(FILE *out)
{
   for (int t = 0; t < len(creaturetype); t++)
   {
      for (int sample = 0; sample < SAMPLES; sample++)
      {
         // Each sample gets its own stream so a divergence stays local.
         unsigned long seed = 1000003UL * (unsigned long)(t + 1)
                              + 7919UL * (unsigned long)(sample + 1);
         lcs_trace_set_seed(seed);
         initMainRNG();

         Creature cr;
         creaturetype[t]->make_creature(cr);

         fputs("{\"type\":", out);
         write_string(out, creaturetype[t]->get_idname().c_str());
         fprintf(out, ",\"sample\":%d,\"seed\":%lu", sample, seed);
         fputs(",\"name\":", out);
         write_string(out, cr.name);
         fprintf(out, ",\"align\":%d,\"age\":%d,\"juice\":%d,\"money\":%d",
                 cr.align, cr.age, cr.juice, cr.money);
         fprintf(out, ",\"gender\":%d,\"mood\":%d", cr.gender_liberal, publicmood(-1));
         // The legal climate the rolls read. Laws are set during startup, so
         // they are not all zero even before a game begins.
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("]", out);
         fprintf(out, ",\"infiltration\":%lld",
                 (long long)(cr.infiltration * 1000000.0f));

         fputs(",\"attributes\":[", out);
         for (int i = 0; i < ATTNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", cr.get_attribute(i, false));
         fputs("],\"skills\":[", out);
         for (int i = 0; i < SKILLNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", cr.get_skill(i));
         fputs("]", out);

         fputs(",\"weapon\":", out);
         write_string(out, cr.is_armed() ? cr.get_weapon().get_itemtypename().c_str() : "");
         fputs(",\"armor\":", out);
         write_string(out, cr.is_naked() ? "" : cr.get_armor().get_itemtypename().c_str());
         fprintf(out, ",\"clips\":%d", cr.count_clips());
         fputs("}\n", out);
      }
   }
}

// Constructs blank creatures, so a divergence in creatureinit() can be told
// apart from one in make_creature().
void probe_blank(FILE *out)
{
   for (int sample = 0; sample < 200; sample++)
   {
      unsigned long seed = 104729UL * (unsigned long)(sample + 1);
      lcs_trace_set_seed(seed);
      initMainRNG();

      Creature cr;
      fprintf(out, "{\"sample\":%d,\"seed\":%lu", sample, seed);
      fprintf(out, ",\"age\":%d,\"gender\":%d,\"birthday_month\":%d,\"birthday_day\":%d",
              cr.age, cr.gender_liberal, cr.birthday_month, cr.birthday_day);
      fprintf(out, ",\"align\":%d", cr.align);
      fputs(",\"attributes\":[", out);
      for (int i = 0; i < ATTNUM; i++)
         fprintf(out, "%s%d", i ? "," : "", cr.get_attribute(i, false));
      fputs("]}\n", out);
   }
}

// Trains creatures and levels them up, so the experience curve can be
// diffed. No randomness is involved beyond creating the creature itself.
void probe_training(FILE *out)
{
   for (int sample = 0; sample < 120; sample++)
   {
      unsigned long seed = 15485863UL * (unsigned long)(sample + 1);
      lcs_trace_set_seed(seed);
      initMainRNG();

      Creature cr;
      // A spread of juice levels, since juice raises the attribute cap.
      cr.juice = (sample % 6) * 40 - 40;
      int skill = sample % SKILLNUM;
      int lesson = 1 + (sample % 17) * 3;
      int upto = (sample % 4 == 0) ? 4 : MAXATTRIBUTE;

      fprintf(out, "{\"sample\":%d,\"seed\":%lu,\"juice\":%d,\"skill\":%d",
              sample, seed, cr.juice, skill);
      fprintf(out, ",\"lesson\":%d,\"upto\":%d,\"steps\":[", lesson, upto);
      for (int step = 0; step < 12; step++)
      {
         cr.train(skill, lesson, upto);
         cr.skill_up();
         fprintf(out, "%s[%d,%d]", step ? "," : "",
                 cr.get_skill(skill), cr.get_skill_ip(skill));
      }
      fputs("]}\n", out);
   }
}

} // namespace

void lcs_probe_run_if_requested()
{
   const char *which = getenv("LCS_PROBE");
   if (!which) return;

   const char *path = getenv("LCS_PROBE_OUT");
   FILE *out = path ? fopen(path, "w") : stdout;
   if (!out)
   {
      fprintf(stderr, "lcs_probe: cannot open %s\n", path);
      exit(2);
   }

   if (!strcmp(which, "creatures")) probe_creatures(out);
   else if (!strcmp(which, "blank")) probe_blank(out);
   else if (!strcmp(which, "training")) probe_training(out);
   else
   {
      fprintf(stderr, "lcs_probe: unknown probe '%s'\n", which);
      exit(2);
   }

   fclose(out);
   endwin();
   exit(0);
}
