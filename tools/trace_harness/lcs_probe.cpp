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

// Not declared in includes.h; the probe needs them to diff the political model.
int getsimplevoter(int leaning);
void congress(char clearformess, char canseethings);
void elections_house(char canseethings);
void supremecourt(char clearformess, char canseethings);
void elections_senate(int senmod, char canseethings);
void healthmodroll(int &aroll, Creature &a);
void damagemod(Creature &t, char &damtype, int &damamount, char hitlocation,
               char armorpenetration, int mod, int extraarmor);
void doActivitySolicitDonations(std::vector<Creature *> &solicit, char &clearformess);
void doActivitySellTshirts(std::vector<Creature *> &tshirts, char &clearformess);
void doActivitySellArt(std::vector<Creature *> &art, char &clearformess);
void doActivitySellMusic(std::vector<Creature *> &music, char &clearformess);
void doActivitySellBrownies(std::vector<Creature *> &brownies, char &clearformess);
int presidentapproval();
char determine_politician_vote(char alignment, int law);

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

// Rolls the dice system across a spread of abilities, and runs skill and
// attribute rolls on real creatures.
void probe_checks(FILE *out)
{
   // The raw dice system, ability by ability.
   for (int ability = 0; ability <= 40; ability++)
   {
      unsigned long seed = 32452843UL * (unsigned long)(ability + 1);
      lcs_trace_set_seed(seed);
      initMainRNG();
      fprintf(out, "{\"kind\":\"roll\",\"ability\":%d,\"seed\":%lu,\"rolls\":[",
              ability, seed);
      for (int i = 0; i < 20; i++)
         fprintf(out, "%s%d", i ? "," : "", Creature::roll_check_probe(ability));
      fputs("]}\n", out);
   }

   // Skill and attribute rolls on creatures, which fold in the attribute rules.
   for (int sample = 0; sample < 80; sample++)
   {
      unsigned long seed = 49979687UL * (unsigned long)(sample + 1);
      lcs_trace_set_seed(seed);
      initMainRNG();

      // Stealth, disguise and driving read armor, a disguise and the current
      // vehicle, none of which exist outside a game; they are probed with the
      // site and chase systems instead.
      static const int SAFE_SKILLS[] = {
         SKILL_PSYCHOLOGY, SKILL_LAW, SKILL_SECURITY, SKILL_COMPUTERS,
         SKILL_MUSIC, SKILL_ART, SKILL_RELIGION, SKILL_SCIENCE, SKILL_BUSINESS,
         SKILL_TEACHING, SKILL_FIRSTAID, SKILL_PERSUASION, SKILL_SEDUCTION,
         SKILL_WRITING, SKILL_STREETSENSE, SKILL_TAILORING, SKILL_KNIFE,
         SKILL_PISTOL, SKILL_RIFLE, SKILL_SHOTGUN, SKILL_SMG, SKILL_AXE,
         SKILL_CLUB, SKILL_SWORD, SKILL_HANDTOHAND, SKILL_HEAVYWEAPONS,
         SKILL_THROWING, SKILL_DODGE,
      };
      const int SAFE_COUNT = (int)(sizeof(SAFE_SKILLS) / sizeof(SAFE_SKILLS[0]));

      Creature cr;
      cr.juice = (sample % 5) * 60 - 60;
      int skill = SAFE_SKILLS[sample % SAFE_COUNT];
      cr.set_skill(skill, sample % 12);
      int attribute = sample % ATTNUM;

      fprintf(out, "{\"kind\":\"creature\",\"sample\":%d,\"seed\":%lu",
              sample, seed);
      fprintf(out, ",\"juice\":%d,\"skill\":%d,\"skill_value\":%d,\"attribute\":%d",
              cr.juice, skill, sample % 12, attribute);
      fputs(",\"skill_rolls\":[", out);
      for (int i = 0; i < 10; i++)
         fprintf(out, "%s%d", i ? "," : "", cr.skill_roll(skill));
      fputs("],\"attribute_rolls\":[", out);
      for (int i = 0; i < 10; i++)
         fprintf(out, "%s%d", i ? "," : "", cr.attribute_roll(attribute));
      fputs("]}\n", out);
   }
}

// Wears armor down, values it, checks concealment, and loads weapons, so the
// equipment rules can be diffed. Deterministic: no randomness is involved.
void probe_equipment(FILE *out)
{
   for (int a = 0; a < len(armortype); a++)
   {
      Armor armor(*armortype[a]);
      fputs("{\"kind\":\"armor\",\"type\":", out);
      write_string(out, armortype[a]->get_idname().c_str());
      fprintf(out, ",\"quality_levels\":%d,\"steps\":[",
              armortype[a]->get_quality_levels());
      for (int step = 0; step < 6; step++)
      {
         bool wearable = armor.decrease_quality(1);
         fprintf(out, "%s[%d,%d,%ld]", step ? "," : "",
                 armor.get_quality(), wearable ? 1 : 0, armor.get_fencevalue());
      }
      fputs("],\"conceals\":[", out);
      for (int w = 0; w < len(weapontype); w++)
         fprintf(out, "%s%d", w ? "," : "",
                 armortype[a]->conceals_weapon(*weapontype[w]) ? 1 : 0);
      fputs("]}\n", out);
   }

   // Loading: give a creature each weapon and the clips its type names, then
   // reload until the clips run out.
   for (int w = 0; w < len(weapontype); w++)
   {
      Creature cr;
      cr.give_weapon(*weapontype[w], NULL);
      fputs("{\"kind\":\"reload\",\"weapon\":", out);
      write_string(out, weapontype[w]->get_idname().c_str());

      std::string clipname;
      for (int i = 0; i < weapontype[w]->get_attacks().size(); i++)
         if (!weapontype[w]->get_attacks()[i]->ammotype.empty())
         {
            clipname = weapontype[w]->get_attacks()[i]->ammotype;
            break;
         }
      fputs(",\"clip\":", out);
      write_string(out, clipname.c_str());

      int taken = 0;
      if (!clipname.empty() && getcliptype(clipname) != -1)
         taken = cr.take_clips(*cliptype[getcliptype(clipname)], 12) ? 1 : 0;
      fprintf(out, ",\"taken\":%d,\"clips_after_take\":%d", taken, cr.count_clips());

      fputs(",\"reloads\":[", out);
      for (int i = 0; i < 12; i++)
      {
         bool ok = cr.reload(true);
         fprintf(out, "%s[%d,%d,%d]", i ? "," : "", ok ? 1 : 0,
                 cr.get_weapon().get_ammoamount(), cr.count_clips());
      }
      fputs("]}\n", out);
   }
}

// The political model: public mood per law, Stalinist agreement, weighted
// issue draws, voters, approval ratings and how politicians vote.
void probe_politics(FILE *out)
{
   // Vary the country's opinions so the tables are exercised, not just read.
   for (int scenario = 0; scenario < 6; scenario++)
   {
      unsigned long seed = 86028121UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(seed);
      initMainRNG();

      for (int v = 0; v < VIEWNUM; v++)
      {
         attitude[v] = (v * 7 + scenario * 13) % 101;
         public_interest[v] = (v * 3 + scenario * 5) % 40;
      }
      exec[EXEC_PRESIDENT] = (scenario % 5) - 2;
      presparty = scenario % 2;

      fprintf(out, "{\"kind\":\"politics\",\"scenario\":%d,\"seed\":%lu",
              scenario, seed);
      fputs(",\"attitude\":[", out);
      for (int v = 0; v < VIEWNUM; v++)
         fprintf(out, "%s%d", v ? "," : "", attitude[v]);
      fputs("],\"interest\":[", out);
      for (int v = 0; v < VIEWNUM; v++)
         fprintf(out, "%s%d", v ? "," : "", public_interest[v]);
      fputs("],\"mood\":[", out);
      for (int l = 0; l < LAWNUM; l++)
         fprintf(out, "%s%d", l ? "," : "", publicmood(l));
      fprintf(out, "],\"mood_overall\":%d,\"mood_stalin\":%d",
              publicmood(LAW_MOOD), publicmood(LAW_STALIN));
      fprintf(out, ",\"president\":%d,\"presparty\":%d",
              exec[EXEC_PRESIDENT], presparty);

      fputs(",\"issues\":[", out);
      for (int i = 0; i < 30; i++)
         fprintf(out, "%s%d", i ? "," : "", randomissue(true));
      fputs("],\"swing\":[", out);
      for (int i = 0; i < 20; i++)
         fprintf(out, "%s%d", i ? "," : "", getswingvoter(false));
      fputs("],\"swing_stalin\":[", out);
      for (int i = 0; i < 20; i++)
         fprintf(out, "%s%d", i ? "," : "", getswingvoter(true));
      fputs("],\"simple\":[", out);
      for (int i = 0; i < 20; i++)
         fprintf(out, "%s%d", i ? "," : "", getsimplevoter(i % 3 - 1));
      fputs("],\"politician\":[", out);
      for (int a = -2; a <= 3; a++)
         for (int l = 0; l < LAWNUM; l++)
            fprintf(out, "%s%d", (a == -2 && l == 0) ? "" : ",",
                    determine_politician_vote((char)a, l));
      fprintf(out, "],\"approval\":%d}\n", presidentapproval());
   }
}

// Runs the money-earning street activities. Needs LCS_TRACE_SCRIPT set as
// well, because an arrest reports itself through getkey().
void probe_activities(FILE *out)
{
   for (int scenario = 0; scenario < 8; scenario++)
   {
      unsigned long seed = 122949829UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(seed);
      initMainRNG();

      for (int v = 0; v < VIEWNUM; v++)
      {
         attitude[v] = (v * 11 + scenario * 9) % 101;
         public_interest[v] = (v * 5 + scenario * 3) % 40;
         background_liberal_influence[v] = 0;
      }
      ledger.force_funds(0);

      Creature cr;
      cr.set_skill(SKILL_PERSUASION, scenario % 8);
      cr.set_skill(SKILL_TAILORING, (scenario + 2) % 8);
      cr.set_skill(SKILL_BUSINESS, (scenario + 4) % 8);
      cr.set_skill(SKILL_ART, (scenario + 1) % 8);
      cr.set_skill(SKILL_MUSIC, (scenario + 3) % 8);
      cr.set_skill(SKILL_STREETSENSE, scenario % 4);
      // Heat stays at zero: an arrest reaches criminalize() and the news
      // system, which need a world this probe does not build. The arrest rule
      // itself is simple enough to check without the original.
      cr.heat = 0;
      cr.give_armor(*armortype[getarmortype("ARMOR_CHEAPSUIT")], NULL);
      if (scenario % 2) cr.give_weapon(*weapontype[getweapontype("WEAPON_GUITAR")], NULL);

      fprintf(out, "{\"kind\":\"activities\",\"scenario\":%d,\"seed\":%lu",
              scenario, seed);
      fprintf(out, ",\"heat\":%d,\"instrument\":%d", cr.heat, scenario % 2);
      fputs(",\"skills\":[", out);
      for (int i = 0; i < SKILLNUM; i++)
         fprintf(out, "%s%d", i ? "," : "", cr.get_skill(i));
      fputs("],\"attitude\":[", out);
      for (int v = 0; v < VIEWNUM; v++)
         fprintf(out, "%s%d", v ? "," : "", attitude[v]);
      fputs("],\"interest\":[", out);
      for (int v = 0; v < VIEWNUM; v++)
         fprintf(out, "%s%d", v ? "," : "", public_interest[v]);

      char clearformess = 0;
      std::vector<Creature *> one;
      one.push_back(&cr);

      // Drug laws stay Liberal so a brownie seller is never busted: an arrest
      // reaches criminalize() and the news system, which need a built world.
      law[LAW_DRUGS] = (scenario % 2) + 1;
      fprintf(out, "],\"drug_law\":%d", law[LAW_DRUGS]);

      fputs(",\"runs\":[", out);
      for (int day = 0; day < 4; day++)
      {
         doActivitySolicitDonations(one, clearformess);
         long after_donations = ledger.get_funds();
         doActivitySellTshirts(one, clearformess);
         long after_tshirts = ledger.get_funds();
         doActivitySellArt(one, clearformess);
         long after_art = ledger.get_funds();
         doActivitySellMusic(one, clearformess);
         long after_music = ledger.get_funds();
         doActivitySellBrownies(one, clearformess);
         long after_brownies = ledger.get_funds();
         // Prostitution is not probed: a police sting sends the creature to
         // find_police_station(), which walks a world this probe does not
         // build. See docs/port/PHASE2-STATUS.md.
         fprintf(out, "%s[%ld,%ld,%ld,%ld,%ld]", day ? "," : "",
                 after_donations, after_tshirts, after_art, after_music,
                 after_brownies);
      }
      fputs("],\"influence\":[", out);
      for (int v = 0; v < VIEWNUM; v++)
         fprintf(out, "%s%d", v ? "," : "", background_liberal_influence[v]);
      fprintf(out, "],\"juice_after\":%d", cr.juice);
      fputs(",\"skills_after\":[", out);
      for (int i = 0; i < SKILLNUM; i++)
         fprintf(out, "%s%d", i ? "," : "", cr.get_skill(i));
      fputs("]}\n", out);
   }
}

// The two pieces of combat that decide outcomes: what old injuries cost a
// roll, and what armor takes out of a hit.
void probe_damage(FILE *out)
{
   static const char *ARMORS[] = {
      "ARMOR_NONE", "ARMOR_CLOTHES", "ARMOR_ARMYARMOR", "ARMOR_BUNKERGEAR",
      "ARMOR_HEAVYARMOR", "ARMOR_CHEAPSUIT",
   };
   const int ARMOR_COUNT = (int)(sizeof(ARMORS) / sizeof(ARMORS[0]));

   for (int sample = 0; sample < 60; sample++)
   {
      unsigned long seed = 217645199UL * (unsigned long)(sample + 1);
      lcs_trace_set_seed(seed);
      initMainRNG();

      Creature cr;
      // Knock out a spread of organs so the injury penalties are exercised.
      cr.special[SPECIALWOUND_RIGHTEYE] = (sample % 2) ? 1 : 0;
      cr.special[SPECIALWOUND_LEFTEYE] = (sample % 3) ? 1 : 0;
      cr.special[SPECIALWOUND_RIGHTLUNG] = (sample % 4) ? 1 : 0;
      cr.special[SPECIALWOUND_HEART] = (sample % 5) ? 1 : 0;
      cr.special[SPECIALWOUND_NECK] = (sample % 7) ? 1 : 0;
      cr.special[SPECIALWOUND_LOWERSPINE] = (sample % 6) ? 1 : 0;
      cr.special[SPECIALWOUND_RIBS] = RIBNUM - (sample % 11);

      fprintf(out, "{\"kind\":\"damage\",\"sample\":%d,\"seed\":%lu",
              sample, seed);
      fputs(",\"special\":[", out);
      for (int i = 0; i < SPECIALWOUNDNUM; i++)
         fprintf(out, "%s%d", i ? "," : "", cr.special[i]);

      fputs("],\"health_rolls\":[", out);
      for (int i = 0; i < 8; i++)
      {
         int roll = 20;
         healthmodroll(roll, cr);
         fprintf(out, "%s%d", i ? "," : "", roll);
      }

      // Armor: every combination of garment, body part and attack.
      const char *armorname = ARMORS[sample % ARMOR_COUNT];
      int quality = 1 + (sample % 3);
      bool damaged = (sample % 4) == 0;
      cr.give_armor(*armortype[getarmortype(armorname)], NULL);
      // decrease_quality() is the only way in; quality starts at 1.
      cr.get_armor().decrease_quality(quality - 1);
      if (damaged) cr.get_armor().set_damaged(true);

      fputs("],\"armor\":", out);
      write_string(out, armorname);
      fprintf(out, ",\"quality\":%d,\"damaged\":%d", quality, damaged ? 1 : 0);

      fputs(",\"damage\":[", out);
      bool first = true;
      for (int bp = 0; bp < BODYPARTNUM; bp++)
         for (int piercing = 0; piercing <= 4; piercing += 2)
            for (int mod = -6; mod <= 6; mod += 3)
            {
               char damtype = (mod % 2) ? WOUND_BURNED : WOUND_CUT;
               int amount = 40;
               damagemod(cr, damtype, amount, (char)bp, (char)piercing, mod, 0);
               fprintf(out, "%s%d", first ? "" : ",", amount);
               first = false;
            }
      fputs("]}\n", out);
   }
}

// A session of Congress, with the presentation switched off. Records the
// laws, chambers and public opinion going in, and the laws coming out.
void probe_congress(FILE *out)
{
   for (int scenario = 0; scenario < 10; scenario++)
   {
      unsigned long seed = 433494437UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(seed);
      initMainRNG();

      for (int v = 0; v < VIEWNUM; v++)
      {
         attitude[v] = (v * 13 + scenario * 17) % 101;
         public_interest[v] = (v * 7 + scenario) % 40;
      }
      for (int l = 0; l < LAWNUM; l++)
         law[l] = ((l + scenario) % 5) - 2;
      for (int h = 0; h < HOUSENUM; h++)
         house[h] = ((h + scenario) % 6) - 2;
      for (int s = 0; s < SENATENUM; s++)
         senate[s] = ((s * 3 + scenario) % 6) - 2;
      for (int e = 0; e < EXECNUM; e++)
         exec[e] = ((e + scenario) % 5) - 2;
      presparty = scenario % 2;

      fprintf(out, "{\"kind\":\"congress\",\"scenario\":%d,\"seed\":%lu",
              scenario, seed);
      fputs(",\"attitude\":[", out);
      for (int v = 0; v < VIEWNUM; v++)
         fprintf(out, "%s%d", v ? "," : "", attitude[v]);
      fputs("],\"interest\":[", out);
      for (int v = 0; v < VIEWNUM; v++)
         fprintf(out, "%s%d", v ? "," : "", public_interest[v]);
      fputs("],\"law_before\":[", out);
      for (int l = 0; l < LAWNUM; l++)
         fprintf(out, "%s%d", l ? "," : "", law[l]);
      fputs("],\"house\":[", out);
      for (int h = 0; h < HOUSENUM; h++)
         fprintf(out, "%s%d", h ? "," : "", house[h]);
      fputs("],\"senate\":[", out);
      for (int s = 0; s < SENATENUM; s++)
         fprintf(out, "%s%d", s ? "," : "", senate[s]);
      fputs("],\"exec\":[", out);
      for (int e = 0; e < EXECNUM; e++)
         fprintf(out, "%s%d", e ? "," : "", exec[e]);

      congress(0, 0);

      fputs("],\"law_after\":[", out);
      for (int l = 0; l < LAWNUM; l++)
         fprintf(out, "%s%d", l ? "," : "", law[l]);
      fputs("]}\n", out);
   }
}

// Congressional elections, with the presentation switched off.
void probe_elections(FILE *out)
{
   for (int scenario = 0; scenario < 10; scenario++)
   {
      unsigned long seed = 236887691UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(seed);
      initMainRNG();

      for (int v = 0; v < VIEWNUM; v++)
         attitude[v] = (v * 19 + scenario * 11) % 101;
      for (int l = 0; l < LAWNUM; l++)
         law[l] = ((l + scenario) % 5) - 2;
      law[LAW_ELECTIONS] = (scenario % 5) - 2;
      for (int h = 0; h < HOUSENUM; h++)
         house[h] = ((h * 2 + scenario) % 5) - 2;
      for (int s = 0; s < SENATENUM; s++)
         senate[s] = ((s + scenario) % 5) - 2;
      termlimits = (scenario % 4) == 3;
      stalinmode = (scenario % 3) == 2;

      fprintf(out, "{\"kind\":\"elections\",\"scenario\":%d,\"seed\":%lu",
              scenario, seed);
      fprintf(out, ",\"election_law\":%d,\"termlimits\":%d,\"stalinmode\":%d",
              law[LAW_ELECTIONS], termlimits ? 1 : 0, stalinmode ? 1 : 0);
      fputs(",\"attitude\":[", out);
      for (int v = 0; v < VIEWNUM; v++)
         fprintf(out, "%s%d", v ? "," : "", attitude[v]);
      fputs("],\"law\":[", out);
      for (int l = 0; l < LAWNUM; l++)
         fprintf(out, "%s%d", l ? "," : "", law[l]);
      fputs("],\"house_before\":[", out);
      for (int h = 0; h < HOUSENUM; h++)
         fprintf(out, "%s%d", h ? "," : "", house[h]);
      fputs("],\"senate_before\":[", out);
      for (int s = 0; s < SENATENUM; s++)
         fprintf(out, "%s%d", s ? "," : "", senate[s]);

      elections_house(0);
      elections_senate(scenario % 3, 0);

      fputs("],\"house_after\":[", out);
      for (int h = 0; h < HOUSENUM; h++)
         fprintf(out, "%s%d", h ? "," : "", house[h]);
      fputs("],\"senate_after\":[", out);
      for (int s = 0; s < SENATENUM; s++)
         fprintf(out, "%s%d", s ? "," : "", senate[s]);
      fprintf(out, "],\"senate_class\":%d}\n", scenario % 3);
   }
}

// A Supreme Court session, with the presentation switched off. The court's
// own laws and bench are recorded before and after.
void probe_court(FILE *out)
{
   for (int scenario = 0; scenario < 12; scenario++)
   {
      unsigned long seed = 179424691UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(seed);
      initMainRNG();

      for (int l = 0; l < LAWNUM; l++)
         law[l] = ((l * 2 + scenario) % 5) - 2;
      for (int j = 0; j < COURTNUM; j++)
         court[j] = ((j + scenario) % 5) - 2;
      for (int s = 0; s < SENATENUM; s++)
         senate[s] = ((s + scenario) % 5) - 2;
      exec[EXEC_PRESIDENT] = (scenario % 5) - 2;

      fprintf(out, "{\"kind\":\"court\",\"scenario\":%d,\"seed\":%lu",
              scenario, seed);
      fprintf(out, ",\"president\":%d", exec[EXEC_PRESIDENT]);
      fputs(",\"law_before\":[", out);
      for (int l = 0; l < LAWNUM; l++)
         fprintf(out, "%s%d", l ? "," : "", law[l]);
      fputs("],\"court_before\":[", out);
      for (int j = 0; j < COURTNUM; j++)
         fprintf(out, "%s%d", j ? "," : "", court[j]);
      fputs("],\"senate\":[", out);
      for (int s = 0; s < SENATENUM; s++)
         fprintf(out, "%s%d", s ? "," : "", senate[s]);

      supremecourt(0, 0);

      fputs("],\"law_after\":[", out);
      for (int l = 0; l < LAWNUM; l++)
         fprintf(out, "%s%d", l ? "," : "", law[l]);
      fputs("],\"court_after\":[", out);
      for (int j = 0; j < COURTNUM; j++)
         fprintf(out, "%s%d", j ? "," : "", court[j]);
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
   else if (!strcmp(which, "checks")) probe_checks(out);
   else if (!strcmp(which, "equipment")) probe_equipment(out);
   else if (!strcmp(which, "politics")) probe_politics(out);
   else if (!strcmp(which, "activities")) probe_activities(out);
   else if (!strcmp(which, "damage")) probe_damage(out);
   else if (!strcmp(which, "congress")) probe_congress(out);
   else if (!strcmp(which, "elections")) probe_elections(out);
   else if (!strcmp(which, "court")) probe_court(out);
   else
   {
      fprintf(stderr, "lcs_probe: unknown probe '%s'\n", which);
      exit(2);
   }

   fclose(out);
   endwin();
   exit(0);
}
