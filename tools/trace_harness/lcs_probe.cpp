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
char wincheck();
void make_world(bool hasmaps);
void makecreature(Creature &cr, short type);
void build_site(std::string name);
void initsite(Location &loc);
void knowmap(int locx, int locy, int locz);
char hasdisguise(const Creature &cr);
void attack(Creature &a, Creature &t, char mistake, char &actual, bool force_melee);
short creaturetype_string_to_enum(const std::string &ctname);
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

// The name generator, which every replay depends on because it consumes
// randomness wherever a person is created.
void probe_names(FILE *out)
{
   for (int sample = 0; sample < 40; sample++)
   {
      unsigned long seed = 275604541UL * (unsigned long)(sample + 1);
      lcs_trace_set_seed(seed);
      initMainRNG();

      int gender = sample % 4;  // neutral, male, female, white male patriarch
      fprintf(out, "{\"kind\":\"names\",\"sample\":%d,\"seed\":%lu,\"gender\":%d",
              sample, seed, gender);

      char first[80], last[80], middle[80];
      fputs(",\"full\":[", out);
      for (int i = 0; i < 12; i++)
      {
         generate_name(first, (char)gender);
         fputs(i ? "," : "", out);
         write_string(out, first);
      }
      fputs("],\"first\":[", out);
      for (int i = 0; i < 12; i++)
      {
         firstname(first, (char)gender);
         fputs(i ? "," : "", out);
         write_string(out, first);
      }
      fputs("],\"last\":[", out);
      for (int i = 0; i < 12; i++)
      {
         lastname(last, gender == GENDER_WHITEMALEPATRIARCH);
         fputs(i ? "," : "", out);
         write_string(out, last);
      }
      fputs("],\"long\":[", out);
      for (int i = 0; i < 8; i++)
      {
         generate_long_name(first, middle, last, (char)gender);
         fprintf(out, "%s[", i ? "," : "");
         write_string(out, first);
         fputc(',', out);
         write_string(out, middle);
         fputc(',', out);
         write_string(out, last);
         fputc(']', out);
      }
      fputs("]}\n", out);
   }
}

// Moving public opinion: the function nearly everything funnels through.
void probe_opinion_change(FILE *out)
{
   for (int scenario = 0; scenario < 12; scenario++)
   {
      unsigned long seed = 141650939UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(seed);
      initMainRNG();

      for (int v = 0; v < VIEWNUM; v++)
      {
         attitude[v] = (v * 23 + scenario * 7) % 101;
         public_interest[v] = (v * 11 + scenario * 5) % 60;
         background_liberal_influence[v] = 0;
      }

      fprintf(out, "{\"kind\":\"opinion\",\"scenario\":%d,\"seed\":%lu",
              scenario, seed);
      fputs(",\"attitude_before\":[", out);
      for (int v = 0; v < VIEWNUM; v++)
         fprintf(out, "%s%d", v ? "," : "", attitude[v]);
      fputs("],\"interest_before\":[", out);
      for (int v = 0; v < VIEWNUM; v++)
         fprintf(out, "%s%d", v ? "," : "", public_interest[v]);

      // Every view, every attribution, positive and negative, capped and not.
      fputs("],\"changes\":[", out);
      bool first = true;
      for (int v = 0; v < VIEWNUM; v++)
         for (int affect = -1; affect <= 1; affect++)
            for (int power = -12; power <= 12; power += 8)
            {
               int cap = (power > 0 && (v % 2)) ? 70 : 100;
               change_public_opinion(v, power, (char)affect, (char)cap);
               fprintf(out, "%s[%d,%d]", first ? "" : ",",
                       attitude[v], public_interest[v]);
               first = false;
            }
      fputs("],\"influence\":[", out);
      for (int v = 0; v < VIEWNUM; v++)
         fprintf(out, "%s%d", v ? "," : "", background_liberal_influence[v]);
      fputs("]}\n", out);
   }
}

// The win condition, across governments from hostile to fully converted.
void probe_wincheck(FILE *out)
{
   for (int scenario = 0; scenario < 40; scenario++)
   {
      // Sweep from an Arch-Conservative government to an Elite Liberal one,
      // so the boundary of every threshold is crossed.
      int tilt = scenario % 10;
      wincondition = (scenario / 10) % 2 ? WINCONDITION_ELITE : WINCONDITION_EASY;

      for (int e = 0; e < EXECNUM; e++) exec[e] = tilt >= 8 ? 2 : (tilt / 3) - 2;
      for (int l = 0; l < LAWNUM; l++)
         law[l] = tilt >= 9 ? 2 : ((l + tilt) % 5) - 2;
      for (int h = 0; h < HOUSENUM; h++)
         house[h] = (h % 10) < tilt ? 2 : ((h % 3) - 1);
      for (int s = 0; s < SENATENUM; s++)
         senate[s] = (s % 10) < tilt ? 2 : ((s % 3) - 1);
      for (int j = 0; j < COURTNUM; j++)
         court[j] = (j % 10) < tilt ? 2 : ((j % 3) - 1);

      fprintf(out, "{\"kind\":\"wincheck\",\"scenario\":%d,\"elite\":%d",
              scenario, wincondition == WINCONDITION_ELITE ? 1 : 0);
      fputs(",\"exec\":[", out);
      for (int e = 0; e < EXECNUM; e++)
         fprintf(out, "%s%d", e ? "," : "", exec[e]);
      fputs("],\"law\":[", out);
      for (int l = 0; l < LAWNUM; l++)
         fprintf(out, "%s%d", l ? "," : "", law[l]);
      fputs("],\"house\":[", out);
      for (int h = 0; h < HOUSENUM; h++)
         fprintf(out, "%s%d", h ? "," : "", house[h]);
      fputs("],\"senate\":[", out);
      for (int s = 0; s < SENATENUM; s++)
         fprintf(out, "%s%d", s ? "," : "", senate[s]);
      fputs("],\"court\":[", out);
      for (int j = 0; j < COURTNUM; j++)
         fprintf(out, "%s%d", j ? "," : "", court[j]);
      fprintf(out, "],\"won\":%d}\n", wincheck() ? 1 : 0);
   }
}

// Building the world: the structure of the city and the RNG each location
// takes for its own floor plan.
void probe_world(FILE *out)
{
   for (int scenario = 0; scenario < 6; scenario++)
   {
      unsigned long seed = 122949823UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(seed);
      initMainRNG();

      for (int l = 0; l < LAWNUM; l++)
         law[l] = ((l + scenario) % 5) - 2;
      delete_and_clear(location);

      fprintf(out, "{\"kind\":\"world\",\"scenario\":%d,\"seed\":%lu",
              scenario, seed);
      fputs(",\"law\":[", out);
      for (int l = 0; l < LAWNUM; l++)
         fprintf(out, "%s%d", l ? "," : "", law[l]);

      make_world(scenario % 2 == 1);

      fputs("],\"locations\":[", out);
      for (int l = 0; l < len(location); l++)
      {
         fprintf(out, "%s{\"id\":%d,\"type\":%d,\"parent\":%d,\"area\":%d",
                 l ? "," : "", location[l]->id, location[l]->type,
                 location[l]->parent, location[l]->area);
         fprintf(out, ",\"renting\":%d,\"hidden\":%d,\"mapped\":%d,\"upgradable\":%d",
                 location[l]->renting, location[l]->hidden ? 1 : 0,
                 location[l]->mapped ? 1 : 0, location[l]->upgradable ? 1 : 0);
         fputs(",\"name\":", out);
         write_string(out, location[l]->name);
         fputs(",\"shortname\":", out);
         write_string(out, location[l]->shortname);
         fputs(",\"mapseed\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%d", i ? "," : "", (int)location[l]->mapseed[i]);
         fputs("]}", out);
      }
      fputs("]}\n", out);
   }
}

// The three skills the dice alone do not decide: stealth reads what you are
// wearing, disguise reads whether it belongs where you are standing, and
// driving reads the car.
void probe_context_checks(FILE *out)
{
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 100003UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();

      for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
      delete_and_clear(location);
      make_world(false);

      squadst squad;
      for (int p = 0; p < 6; p++) squad.squad[p] = NULL;
      activesquad = &squad;
      mode = GAMEMODE_SITE;

      // Whether an outfit passes, everywhere it might be worn. No randomness
      // is involved, so this is a table rather than a sample.
      for (int l = 0; l < len(location); l++)
      {
         int type = location[l]->type;
         if (type < 0 || type >= SITENUM) continue;
         cursite = l;
         locx = MAPX >> 1, locy = 5, locz = 0;
         for (int x = 0; x < MAPX; x++)
         for (int y = 0; y < MAPY; y++)
         for (int z = 0; z < MAPZ; z++)
         {
            levelmap[x][y][z].flag = 0;
            levelmap[x][y][z].special = SPECIAL_NONE;
            levelmap[x][y][z].siegeflag = 0;
         }

         for (int secure = 0; secure < 2; secure++)
         {
            levelmap[locx][locy][locz].flag =
               secure ? SITEBLOCK_RESTRICTED : 0;
            for (int high = 0; high < 2; high++)
            {
               location[l]->highsecurity = high;
               fprintf(out, "{\"kind\":\"disguise\",\"scenario\":%d,\"site\":%d",
                       scenario, type);
               fprintf(out, ",\"restricted\":%d,\"highsecurity\":%d", secure, high);
               fputs(",\"armors\":[", out);
               for (int a = 0; a < len(armortype); a++)
               {
                  if (a) fputc(',', out);
                  write_string(out, armortype[a]->get_idname().c_str());
               }
               fputs("],\"ratings\":[", out);
               for (int a = 0; a < len(armortype); a++)
               {
                  Creature cr;
                  cr.give_armor(*armortype[a], NULL);
                  fprintf(out, "%s%d", a ? "," : "", (int)hasdisguise(cr));
               }
               // And with nothing on at all, which several sites care about.
               Creature bare;
               fprintf(out, ",%d]}\n", (int)hasdisguise(bare));
            }
            location[l]->highsecurity = 0;
         }
      }

      // Stealth and disguise rolls, which start from the dice and then get
      // cut down by the clothes.
      cursite = 1;
      locx = MAPX >> 1, locy = 5, locz = 0;
      levelmap[locx][locy][locz].flag = 0;
      for (int a = 0; a < len(armortype); a++)
      for (int wear = 1; wear <= 3; wear++)
      {
         unsigned long seed_used = 100019UL * (unsigned long)(a * 4 + wear + scenario);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         Creature cr;
         cr.set_skill(SKILL_STEALTH, (a + wear) % 9);
         cr.set_skill(SKILL_DISGUISE, (a + wear * 2) % 9);
         cr.give_armor(*armortype[a], NULL);
         for (int step = 1; step < wear; step++) cr.get_armor().decrease_quality(1);
         if (wear == 3) cr.get_armor().set_damaged(true);

         fprintf(out, "{\"kind\":\"cover\",\"scenario\":%d,\"seed\":%lu,\"armor\":",
                 scenario, seed_used);
         write_string(out, armortype[a]->get_idname().c_str());
         fprintf(out, ",\"wear\":%d,\"quality\":%d,\"damaged\":%d",
                 wear, cr.get_armor().get_quality(),
                 cr.get_armor().is_damaged() ? 1 : 0);
         fprintf(out, ",\"stealth_skill\":%d,\"disguise_skill\":%d,\"uniformed\":%d",
                 cr.get_skill(SKILL_STEALTH), cr.get_skill(SKILL_DISGUISE),
                 (int)hasdisguise(cr));
         fputs(",\"stealth\":[", out);
         for (int i = 0; i < 8; i++)
            fprintf(out, "%s%d", i ? "," : "", cr.skill_roll(SKILL_STEALTH));
         fputs("],\"disguise\":[", out);
         for (int i = 0; i < 8; i++)
            fprintf(out, "%s%d", i ? "," : "", cr.skill_roll(SKILL_DISGUISE));
         fputs("]}\n", out);
      }

      // Driving, which is the car's ability more than the driver's.
      mode = GAMEMODE_CHASECAR;
      for (int v = 0; v < len(vehicletype); v++)
      for (int level = 0; level < 3; level++)
      {
         unsigned long seed_used = 100043UL * (unsigned long)(v * 4 + level + scenario);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         Creature cr;
         cr.set_skill(SKILL_DRIVING, level * 4);
         Vehicle car(*vehicletype[v], vehicletype[v]->color()[0], 2000);
         chaseseq.clean();
         chaseseq.friendcar.push_back(&car);
         cr.carid = car.id();

         fprintf(out, "{\"kind\":\"drive\",\"scenario\":%d,\"seed\":%lu,\"vehicle\":",
                 scenario, seed_used);
         write_string(out, vehicletype[v]->idname().c_str());
         fprintf(out, ",\"skill\":%d,\"escape\":[", cr.get_skill(SKILL_DRIVING));
         for (int i = 0; i < 8; i++)
            fprintf(out, "%s%d", i ? "," : "", cr.skill_roll(PSEUDOSKILL_ESCAPEDRIVE));
         fputs("],\"dodge\":[", out);
         for (int i = 0; i < 8; i++)
            fprintf(out, "%s%d", i ? "," : "", cr.skill_roll(PSEUDOSKILL_DODGEDRIVE));
         fputs("]}\n", out);
         chaseseq.friendcar.clear();
      }
      mode = GAMEMODE_SITE;
      activesquad = NULL;
   }
}

// One creature attacking another: the rolls, the burst, where it lands, what
// gets through the armor, and what a death costs everybody.
//
// Fought inside a real site, because attack() reads the floor it is standing
// on and the squad the attacker belongs to.
void probe_combat(FILE *out)
{
   // Seeds shared with the site probe: some worlds overflow a name buffer in
   // initlocation() and abort the original outright, so the seeds that are
   // known to build are the ones used.
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 122949823UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();

      for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      mode = GAMEMODE_SITE;
      cursite = 1;
      sitealarm = scenario % 2;
      sitecrime = 0;
      locx = MAPX >> 1, locy = 5, locz = 0;
      for (int x = 0; x < MAPX; x++)
      for (int y = 0; y < MAPY; y++)
      for (int z = 0; z < MAPZ; z++)
      {
         levelmap[x][y][z].flag = 0;
         levelmap[x][y][z].special = SPECIAL_NONE;
         levelmap[x][y][z].siegeflag = 0;
      }
      newsstoryst *ns = new newsstoryst;
      ns->loc = cursite;
      newsstory.push_back(ns);
      sitestory = ns;

      // Nothing has cleared the encounter slots, and a blood spray rolls for
      // everybody standing in one.
      for (int e = 0; e < ENCMAX; e++) encounter[e].exists = 0;

      // The CEO and the President are built the first time anything asks for
      // them, and dying asks. Building them here, before the samples reseed,
      // keeps a whole creature's worth of draws out of the first fight that
      // kills somebody.
      uniqueCreatures.initialize();

      // A squad the attacker belongs to, so the founder rules are reachable.
      squadst squad;
      for (int p = 0; p < 6; p++) squad.squad[p] = NULL;
      activesquad = &squad;

      // Every weapon in the game, against three states of defence.
      for (int w = 0; w < len(weapontype); w++)
      for (int defence = 0; defence < 3; defence++)
      {
         unsigned long seed_used =
            3000037UL * (unsigned long)(w * 4 + defence + scenario);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         Creature a;
         a.id = 900000;
         a.set_skill(SKILL_CLUB, (w + scenario) % 9);
         a.set_skill(SKILL_PISTOL, (w + scenario) % 9);
         a.set_skill(SKILL_RIFLE, (w + scenario) % 9);
         a.set_skill(SKILL_SHOTGUN, (w + scenario) % 9);
         a.set_skill(SKILL_SMG, (w + scenario) % 9);
         a.set_skill(SKILL_HEAVYWEAPONS, (w + scenario) % 9);
         a.set_skill(SKILL_KNIFE, (w + scenario) % 9);
         a.set_skill(SKILL_AXE, (w + scenario) % 9);
         a.set_skill(SKILL_SWORD, (w + scenario) % 9);
         a.set_skill(SKILL_THROWING, (w + scenario) % 9);
         a.set_skill(SKILL_HANDTOHAND, (w + scenario * 2) % 9);
         a.set_skill(SKILL_STEALTH, (w + scenario) % 7);
         a.align = ALIGN_LIBERAL;
         a.give_weapon(*weapontype[w], NULL);
         if (weapontype[w]->get_attacks().size() &&
             weapontype[w]->get_attacks()[0]->uses_ammo)
         {
            std::string ct = weapontype[w]->get_attacks()[0]->ammotype;
            if (getcliptype(ct) != -1)
            {
               a.take_clips(*cliptype[getcliptype(ct)], 4);
               a.reload(false);
            }
         }

         Creature t;
         // Well clear of the CEO and the President: killing either of those
         // spawns a replacement, and a whole creature's worth of draws would
         // swamp the fight this is trying to record.
         t.id = 900001;
         t.align = ALIGN_CONSERVATIVE;
         t.set_skill(SKILL_DODGE, defence * 4);
         if (defence > 0)
            t.give_armor(*armortype[getarmortype(
               defence == 1 ? "ARMOR_CLOTHES" : "ARMOR_ARMYARMOR")], NULL);
         squad.squad[0] = &a;
         a.squadid = squad.id = 1;
         a.hireid = 0; // Not the founder; the founder rules get their own pass.

         fprintf(out, "{\"kind\":\"attack\",\"scenario\":%d,\"seed\":%lu,\"weapon\":",
                 scenario, seed_used);
         write_string(out, weapontype[w]->get_idname().c_str());
         fprintf(out, ",\"defence\":%d,\"alarm\":%d", defence, sitealarm);
         fputs(",\"attacker_skills\":[", out);
         for (int i = 0; i < SKILLNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", a.get_skill(i));
         fputs("],\"attacker_attributes\":[", out);
         for (int i = 0; i < ATTNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", a.attribute_raw_probe(i));
         fputs("],\"target_attributes\":[", out);
         for (int i = 0; i < ATTNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", t.attribute_raw_probe(i));
         fprintf(out, "],\"target_dodge\":%d,\"ammo_before\":%d",
                 t.get_skill(SKILL_DODGE), a.get_weapon().get_ammoamount());

         fputs(",\"rounds\":[", out);
         for (int round = 0; round < 4; round++)
         {
            char actual = 0;
            long long draws_before = lcs_trace_draw_count();
            attack(a, t, 0, actual, false);
            fputs(round ? ",{" : "{", out);
            fprintf(out, "\"draws\":%lld,",
                    lcs_trace_draw_count() - draws_before);
            fprintf(out, "\"blood\":%d,\"alive\":%d,\"ammo\":%d",
                    t.blood, t.alive ? 1 : 0, a.get_weapon().get_ammoamount());
            fprintf(out, ",\"juice\":%d,\"sitecrime\":%d,\"alarm\":%d",
                    a.juice, sitecrime, sitealarm);
            fputs(",\"wounds\":[", out);
            for (int i = 0; i < BODYPARTNUM; i++)
               fprintf(out, "%s%d", i ? "," : "", (int)t.wound[i]);
            fputs("],\"special\":[", out);
            for (int i = 0; i < SPECIALWOUNDNUM; i++)
               fprintf(out, "%s%d", i ? "," : "", (int)t.special[i]);
            fputs("],\"attacker_skills\":[", out);
            for (int i = 0; i < SKILLNUM; i++)
               fprintf(out, "%s%d", i ? "," : "", a.get_skill(i));
            fputs("]}", out);
         }
         fputs("]}\n", out);
         squad.squad[0] = NULL;
      }
      activesquad = NULL;
   }
}

// Spawning people into a built world: the path a site population, a
// recruitment meeting and a squad of enemies all come through.
//
// Every creature type, under eight legal and political climates, half of them
// mid-infiltration so the branches that only fire inside a site — the CCS
// naming, a firefighter turning out in bunker gear, a bouncer with a cover
// story — are reached too.
void probe_spawn(FILE *out)
{
   for (int scenario = 0; scenario < 8; scenario++)
   {
      unsigned long seed = 217645177UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(seed);
      initMainRNG();

      for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
      for (int v = 0; v < VIEWNUM; v++)
      {
         attitude[v] = (v * 13 + scenario * 5) % 101;
         public_interest[v] = 5;
      }
      delete_and_clear(location);
      make_world(false);

      bool inside = scenario >= 4;
      mode = inside ? GAMEMODE_SITE : GAMEMODE_BASE;
      sitealienate = 0;
      sitealarm = inside ? 1 : 0;
      endgamestate = inside ? (scenario - 4) : ENDGAME_NONE;
      ccs_kills = (char)(scenario % 3);

      fprintf(out, "{\"kind\":\"spawn\",\"scenario\":%d,\"seed\":%lu",
              scenario, seed);
      fprintf(out, ",\"insite\":%d,\"alarm\":%d,\"endgame\":%d,\"ccskills\":%d",
              inside ? 1 : 0, sitealarm, endgamestate, ccs_kills);
      fputs(",\"law\":[", out);
      for (int l = 0; l < LAWNUM; l++)
         fprintf(out, "%s%d", l ? "," : "", law[l]);
      fputs("],\"attitude\":[", out);
      for (int v = 0; v < VIEWNUM; v++)
         fprintf(out, "%s%d", v ? "," : "", attitude[v]);

      // One creature, reused — which is how the game does it, since the
      // encounter slots are constructed once and refilled. Constructing a
      // fresh one per spawn would run creatureinit() twice each time.
      Creature cr;
      fputs("],\"people\":[", out);
      // Indexed by the enum, not by the order the XML happened to load in:
      // makecreature() takes the enum and the two are not the same list.
      for (int t = 0; t < CREATURENUM; t++)
      {
         cursite = 1 + (t % (len(location) - 1));
         makecreature(cr, t);

         fprintf(out, "%s{\"type\":", t ? "," : "");
         write_string(out, getcreaturetype(t)->get_idname().c_str());
         fprintf(out, ",\"site\":%d,\"worklocation\":%d,\"align\":%d,\"age\":%d",
                 cursite, cr.worklocation, cr.align, cr.age);
         fprintf(out, ",\"money\":%d,\"juice\":%d,\"gender\":%d",
                 cr.money, cr.juice, cr.gender_liberal);
         fprintf(out, ",\"infiltration\":%lld",
                 (long long)(cr.infiltration * 1000000.0f));
         // The type can change under the spawner's feet: a prisoner is built
         // as somebody else and only dressed as a prisoner.
         fputs(",\"became\":", out);
         write_string(out, getcreaturetype(cr.type)->get_idname().c_str());
         fputs(",\"name\":", out);
         write_string(out, cr.name);
         fputs(",\"weapon\":", out);
         write_string(out, cr.is_armed() ? cr.get_weapon().get_itemtypename().c_str() : "");
         fprintf(out, ",\"clips\":%d", cr.count_clips());
         fputs(",\"armor\":", out);
         write_string(out, cr.is_naked() ? "" : cr.get_armor().get_itemtypename().c_str());
         fputs(",\"attributes\":[", out);
         for (int i = 0; i < ATTNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", cr.get_attribute(i, false));
         fputs("],\"raw\":[", out);
         for (int i = 0; i < ATTNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", cr.attribute_raw_probe(i));
         fputs("],\"skills\":[", out);
         for (int i = 0; i < SKILLNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", cr.get_skill(i));
         fputs("],\"suspected\":[", out);
         for (int i = 0; i < LAWFLAGNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", cr.crimes_suspected[i]);
         fputs("]}", out);
      }
      fputs("]}\n", out);
   }
}

// Building floor plans from art/sitemaps.txt.
// Rebuilding a whole site from its own seed: the drawn maps, the generated
// plans, the repair passes and the loot scattered on top.
void probe_sites(FILE *out)
{
   for (int scenario = 0; scenario < 2; scenario++)
   {
      unsigned long run_seed = 122949823UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();

      for (int l = 0; l < LAWNUM; l++)
         law[l] = ((l + scenario) % 5) - 2;
      delete_and_clear(location);
      make_world(false);

      // initsite() wants a squad on the map; an empty one is enough, since
      // nothing it does reads the members.
      squadst squad;
      for (int p = 0; p < 6; p++) squad.squad[p] = NULL;
      activesquad = &squad;

      bool seen[SITENUM];
      for (int s = 0; s < SITENUM; s++) seen[s] = false;

      for (int l = 0; l < len(location); l++)
      {
         int type = location[l]->type;
         if (type < 0 || type >= SITENUM || seen[type]) continue;
         seen[type] = true;

         unsigned long before[RNG_SIZE];
         for (int i = 0; i < RNG_SIZE; i++) before[i] = ::seed[i];
         initsite(*location[l]);

         fprintf(out, "{\"kind\":\"site\",\"scenario\":%d,\"seed\":%lu",
                 scenario, run_seed);
         fprintf(out, ",\"location\":%d,\"type\":%d,\"renting\":%d",
                 l, type, location[l]->renting);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("]", out);
         fputs(",\"mapseed\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", location[l]->mapseed[i]);
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", before[i]);
         fputs("],\"flags\":[", out);
         bool first = true;
         for (int z = 0; z < 7; z++)
         for (int y = 0; y < MAPY; y++)
         for (int x = 0; x < MAPX; x++)
         {
            fprintf(out, "%s%d", first ? "" : ",", levelmap[x][y][z].flag);
            first = false;
         }
         fputs("],\"specials\":[", out);
         first = true;
         for (int z = 0; z < 7; z++)
         for (int y = 0; y < MAPY; y++)
         for (int x = 0; x < MAPX; x++)
         {
            fprintf(out, "%s%d", first ? "" : ",", levelmap[x][y][z].special);
            first = false;
         }
         fputs("]}\n", out);

         // Take the squad on a fixed tour of the building, so the rule
         // that stops it at a wall and the way the map fills in around it
         // are pinned down together.
         //
         // It starts on the first open square inside rather than on the
         // doorstep, and treats doors and exits as walls: opening a door and
         // walking out of one both ask the player questions, and both are
         // probed on their own.
         locz = 0;
         locx = MAPX >> 1, locy = 1;
         for (int y = 2; y < MAPY; y++)
         for (int x = 2; x < MAPX - 2; x++)
            if (!(levelmap[x][y][0].flag & (SITEBLOCK_BLOCK | SITEBLOCK_DOOR |
                                            SITEBLOCK_EXIT | SITEBLOCK_OUTDOOR)))
            {  locx = x, locy = y, y = MAPY, x = MAPX; }
         knowmap(locx, locy, locz);

         static const int STEPS[][2] = {
            {0,1},{0,1},{0,1},{1,0},{1,0},{0,1},{0,1},{-1,0},{-1,0},{-1,0},
            {0,1},{0,1},{1,0},{0,1},{0,1},{1,0},{1,0},{1,0},{0,-1},{0,-1},
            {-1,0},{0,1},{0,1},{0,1},{1,0},{1,0},{0,1},{-1,0},{-1,0},{0,1},
         };
         const int STEP_COUNT = (int)(sizeof(STEPS) / sizeof(STEPS[0]));
         fprintf(out, "{\"kind\":\"walk\",\"scenario\":%d,\"seed\":%lu,\"location\":%d",
                 scenario, run_seed, l);
         fprintf(out, ",\"start\":[%d,%d,%d],\"path\":[", locx, locy, locz);
         for (int s = 0; s < STEP_COUNT; s++)
         {
            int nx = locx + STEPS[s][0], ny = locy + STEPS[s][1];
            if (nx >= 0 && nx < MAPX && ny >= 0 && ny < MAPY &&
                !(levelmap[nx][ny][locz].flag & (SITEBLOCK_BLOCK |
                                                 SITEBLOCK_DOOR | SITEBLOCK_EXIT)))
               locx = nx, locy = ny;
            knowmap(locx, locy, locz);
            fprintf(out, "%s[%d,%d,%d]", s ? "," : "", locx, locy, locz);
         }
         fputs("],\"known\":[", out);
         bool seen_first = true;
         for (int y = 0; y < MAPY; y++)
         for (int x = 0; x < MAPX; x++)
         {
            fprintf(out, "%s%d", seen_first ? "" : ",",
                    (levelmap[x][y][locz].flag & SITEBLOCK_KNOWN) ? 1 : 0);
            seen_first = false;
         }
         fputs("]}\n", out);
      }
      activesquad = NULL;
   }
}

void probe_sitemaps(FILE *out)
{
   // Every plan in art/sitemaps.txt, in file order.
   static const char *PLANS[] = {
      "GENERIC_FRONTDOOR", "GENERIC_UNSECURE", "GENERIC_SECURE",
      "GENERIC_ONEROOM", "BUSINESS_CAFE", "BUSINESS_INTERNETCAFE",
      "BUSINESS_RESTRICTEDCAFE", "INDUSTRY_SWEATSHOP", "INDUSTRY_POLLUTER",
      "INDUSTRY_NUCLEAR", "GOVERNMENT_INTELLIGENCEHQ",
      "CORPORATE_HEADQUARTERS", "CORPORATE_HOUSE", "GOVERNMENT_ARMYBASE",
      "LABORATORY_GENETICS", "LABORATORY_COSMETICS", "GENERIC_LOBBY",
      "GOVERNMENT_POLICESTATION", "GOVERNMENT_COURTHOUSE", "GOVERNMENT_PRISON",
      "MEDIA_AMRADIO", "MEDIA_CABLENEWS", "RESIDENTIAL_APARTMENT",
      "OUTDOOR_OPEN", "OUTDOOR_PUBLICPARK", "OUTDOOR_LATTESTAND",
   };
   const int PLAN_COUNT = (int)(sizeof(PLANS) / sizeof(PLANS[0]));

   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long seed = 512927377UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(seed);
      initMainRNG();

      for (int p = 0; p < PLAN_COUNT; p++)
      {
         // Solid rock, as initsite() starts from: a plan carves rooms out of
         // it rather than building walls on empty ground.
         for (int x = 0; x < MAPX; x++)
         for (int y = 0; y < MAPY; y++)
         for (int z = 0; z < MAPZ; z++)
         {
            levelmap[x][y][z].flag = SITEBLOCK_BLOCK;
            levelmap[x][y][z].special = SPECIAL_NONE;
            levelmap[x][y][z].siegeflag = 0;
         }

         build_site(PLANS[p]);

         fprintf(out, "{\"kind\":\"sitemap\",\"scenario\":%d,\"seed\":%lu,\"plan\":",
                 scenario, seed);
         write_string(out, PLANS[p]);
         // The tallest plan is seven floors; the three above that are empty
         // in every plan, so recording them would be all zeroes.
         fputs(",\"flags\":[", out);
         bool first = true;
         for (int z = 0; z < 7; z++)
         for (int y = 0; y < MAPY; y++)
         for (int x = 0; x < MAPX; x++)
         {
            fprintf(out, "%s%d", first ? "" : ",", levelmap[x][y][z].flag);
            first = false;
         }
         fputs("],\"specials\":[", out);
         first = true;
         for (int z = 0; z < 7; z++)
         for (int y = 0; y < MAPY; y++)
         for (int x = 0; x < MAPX; x++)
         {
            fprintf(out, "%s%d", first ? "" : ",", levelmap[x][y][z].special);
            first = false;
         }
         fputs("]}\n", out);
      }
   }
}

} // namespace

// Building a squad of Liberals with a fixed spread of ability, so a chase can
// be run over and over with the same people in it.
static void chase_build_squad(squadst &squad, int scenario, int size,
                              int wounded)
{
   for (int p = 0; p < 6; p++) squad.squad[p] = NULL;
   // Registered globally, because removesquadinfo() looks the squad up there:
   // a Liberal who breaks away from an unregistered squad is never taken out
   // of it, and would keep being rolled for round after round.
   squad.id = 1;
   for (int i = len(::squad) - 1; i >= 0; i--) ::squad.erase(::squad.begin() + i);
   ::squad.push_back(&squad);
   for (int p = 0; p < size; p++)
   {
      Creature *cr = new Creature;
      cr->id = 800000 + p;
      cr->align = ALIGN_LIBERAL;
      cr->squadid = squad.id = 1;
      cr->hireid = p;
      cr->set_skill(SKILL_DRIVING, (p + scenario) % 9);
      cr->set_attribute(ATTRIBUTE_AGILITY, 2 + (p * 2 + scenario) % 8);
      cr->set_attribute(ATTRIBUTE_HEALTH, 2 + (p * 3 + scenario) % 8);
      cr->set_attribute(ATTRIBUTE_STRENGTH, 2 + (p + scenario) % 8);
      cr->blood = 100 - (p * 13 + scenario * 7) % 60;
      // A spread of conditions the driving rules read: a lost leg, a broken
      // spine, and a wheelchair all change what somebody can do.
      if (wounded && p == 0)
      {  // The driver: both legs off, so the car needs a new one.
         cr->wound[BODYPART_LEG_RIGHT] |= WOUND_CLEANOFF;
         cr->wound[BODYPART_LEG_LEFT] |= WOUND_NASTYOFF;
      }
      if (wounded && p == 1) cr->wound[BODYPART_ARM_RIGHT] |= WOUND_CLEANOFF;
      if (wounded && p == 2) cr->special[SPECIALWOUND_LOWERSPINE] = 0;
      if (wounded && p == 3) cr->flag |= CREATUREFLAG_WHEELCHAIR;
      squad.squad[p] = cr;
   }
}

static void chase_free_squad(squadst &squad)
{
   for (int i = len(::squad) - 1; i >= 0; i--)
      if (::squad[i] == &squad) ::squad.erase(::squad.begin() + i);
   for (int p = 0; p < 6; p++)
   {
      if (squad.squad[p]) delete squad.squad[p];
      squad.squad[p] = NULL;
   }
}

// Writes one creature in full: everything a chase rolls against, so the port
// can rebuild the same person without rebuilding the world that made them.
static void chase_write_creature(FILE *out, Creature &cr, bool first)
{
   fprintf(out, "%s{\"id\":%d,\"type\":", first ? "" : ",", (int)cr.id);
   write_string(out, getcreaturetype(cr.type)->get_idname().c_str());
   fprintf(out, ",\"align\":%d,\"blood\":%d,"
                "\"alive\":%d,\"car\":%d,\"driver\":%d,\"squadid\":%d,"
                "\"location\":%d,\"wheelchair\":%d,\"animalgloss\":%d",
           cr.align, cr.blood,
           cr.alive ? 1 : 0, (int)cr.carid, cr.is_driver ? 1 : 0,
           (int)cr.squadid, cr.location,
           (cr.flag & CREATUREFLAG_WHEELCHAIR) ? 1 : 0, cr.animalgloss);
   fprintf(out, ",\"meetings\":%d,\"base\":%d", cr.meetings, cr.base);
   fprintf(out, ",\"age\":%d,\"juice\":%d,\"hireid\":%d,\"stunned\":%d,"
                "\"cantbluff\":%d,\"forceinc\":%d,\"converted\":%d",
           cr.age, cr.juice, (int)cr.hireid, (int)cr.stunned,
           (int)cr.cantbluff, cr.forceinc ? 1 : 0,
           (cr.flag & CREATUREFLAG_CONVERTED) ? 1 : 0);
   fputs(",\"attributes\":[", out);
   for (int i = 0; i < ATTNUM; i++)
      fprintf(out, "%s%d", i ? "," : "", cr.attribute_raw_probe(i));
   fputs("],\"effective\":[", out);
   for (int i = 0; i < ATTNUM; i++)
      fprintf(out, "%s%d", i ? "," : "", cr.get_attribute(i, true));
   fputs("],\"skills\":[", out);
   for (int i = 0; i < SKILLNUM; i++)
      fprintf(out, "%s%d", i ? "," : "", cr.get_skill(i));
   fputs("],\"wounds\":[", out);
   for (int i = 0; i < BODYPARTNUM; i++)
      fprintf(out, "%s%d", i ? "," : "", (int)cr.wound[i]);
   fputs("],\"special\":[", out);
   for (int i = 0; i < SPECIALWOUNDNUM; i++)
      fprintf(out, "%s%d", i ? "," : "", (int)cr.special[i]);

   // What they are carrying, which decides what they can do with it.
   fputs("],\"weapon\":", out);
   write_string(out, cr.is_armed() ? cr.get_weapon().get_itemtypename().c_str() : "");
   fprintf(out, ",\"ammo\":%d",
           cr.is_armed() ? cr.get_weapon().get_ammoamount() : 0);
   fputs(",\"loaded\":", out);
   write_string(out, cr.is_armed()
                     ? cr.get_weapon().get_loaded_cliptypename().c_str() : "");
   fputs(",\"clips\":[", out);
   for (int i = 0; i < len(cr.clips); i++)
      fprintf(out, "%s{\"type\":\"%s\",\"count\":%ld}", i ? "," : "",
              cr.clips[i]->get_itemtypename().c_str(), cr.clips[i]->get_number());
   // is_naked(), not get_armor().empty(): a creature with no armor at all
   // still answers get_armor() with a placeholder garment, and recording that
   // would dress the port's copy in something the original is not wearing.
   fputs("],\"armor\":", out);
   write_string(out, cr.is_naked()
                     ? "" : cr.get_armor().get_itemtypename().c_str());
   fprintf(out, ",\"armor_quality\":%d,\"armor_damaged\":%d,"
                "\"armor_bloody\":%d}",
           cr.is_naked() ? 1 : cr.get_armor().get_quality(),
           cr.get_armor().is_damaged() ? 1 : 0,
           cr.get_armor().is_bloody() ? 1 : 0);
}

// Writes every car on the road, with the type the driving rules read off it.
static void chase_write_cars(FILE *out, const char *key,
                             vector<Vehicle *> &cars)
{
   fprintf(out, ",\"%s\":[", key);
   for (int v = 0; v < len(cars); v++)
   {
      fprintf(out, "%s{\"id\":%ld,\"type\":", v ? "," : "", cars[v]->id());
      write_string(out, cars[v]->vtypeidname().c_str());
      fputs("}", out);
   }
   fputs("]", out);
}

// Writes the state a chase turn can be judged by: who is left on each side,
// what they are riding in and how badly hurt they are. Written twice per
// sample, before and after, so the port starts from the same people.
static void chase_write_state(FILE *out, const char *key, squadst &squad)
{
   fprintf(out, ",\"%s_squad\":[", key);
   bool first = true;
   for (int p = 0; p < 6; p++)
   {
      if (!squad.squad[p]) continue;
      chase_write_creature(out, *squad.squad[p], first);
      first = false;
   }
   fprintf(out, "],\"%s_encounter\":[", key);
   first = true;
   for (int e = 0; e < ENCMAX; e++)
   {
      if (!encounter[e].exists) continue;
      chase_write_creature(out, encounter[e], first);
      first = false;
   }
   fputs("]", out);

   char name[64];
   snprintf(name, sizeof name, "%s_friendcars", key);
   chase_write_cars(out, name, chaseseq.friendcar);
   snprintf(name, sizeof name, "%s_enemycars", key);
   chase_write_cars(out, name, chaseseq.enemycar);
}

// Puts the squad into cars of its own, one driver per car.
static void chase_give_cars(squadst &squad, const char *type, int cars)
{
   delete_and_clear(chaseseq.friendcar, vehicle);
   for (int c = 0; c < cars; c++)
   {
      Vehicle *v = new Vehicle(*vehicletype[getvehicletype(type)]);
      vehicle.push_back(v);
      chaseseq.friendcar.push_back(v);
   }
   for (int p = 0, c = 0; p < 6; p++)
   {
      if (!squad.squad[p]) continue;
      squad.squad[p]->carid = chaseseq.friendcar[c % cars]->id();
      squad.squad[p]->is_driver = (p == c && c < cars);
      if (p == c && c < cars) c++;
   }
}

// Chases: who turns up, who drives, who crashes and who gets away.
//
// Every step is measured by draw count as well as by outcome, because a chase
// is a long sequence of small rolls and a missing one shows up as nothing more
// than a fight that went slightly differently three rounds later.
void probe_chase(FILE *out)
{
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 122949823UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();

      for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
      for (int v = 0; v < VIEWNUM; v++)
      {
         attitude[v] = (v * 7 + scenario * 13) % 101;
         public_interest[v] = (v * 3 + scenario * 5) % 40;
      }
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = scenario == 2 ? ENDGAME_CCS_ATTACKS : ENDGAME_NONE;

      newsstoryst *ns = new newsstoryst;
      ns->loc = 1;
      newsstory.push_back(ns);
      sitestory = ns;
      cursite = 1;
      mode = GAMEMODE_CHASECAR;

      // Who responds, for every site type and a spread of how bad the visit
      // was. makechasers() fills the encounter array and builds their cars.
      for (int type = 0; type < SITENUM; type++)
      for (int crime = 0; crime < 3; crime++)
      {
         unsigned long seed_used =
            3000037UL * (unsigned long)(type * 4 + crime + scenario * 61 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();
         delete_and_clear(chaseseq.enemycar);
         chaseseq.location = 1;

         long long before = lcs_trace_draw_count();
         makechasers(type, crime * 17 + 1);
         fprintf(out, "{\"kind\":\"chasers\",\"scenario\":%d,\"seed\":%lu,"
                      "\"type\":%d,\"crime\":%d,\"endgame\":%d,\"draws\":%lld,"
                      "\"canpullover\":%d",
                 scenario, seed_used, type, crime * 17 + 1, endgamestate,
                 lcs_trace_draw_count() - before, chaseseq.canpullover ? 1 : 0);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("]", out);
         fprintf(out, ",\"world_seed\":%lu", run_seed);
         squadst empty;
         for (int p = 0; p < 6; p++) empty.squad[p] = NULL;
         chase_write_state(out, "after", empty);
         fputs("}\n", out);
      }

      // A full turn of a car chase: reseating drivers, running for it, and
      // swerving around whatever is in the road.
      static const char *TURNS[] = {"update", "evade", "dodge",
                                    "crashfriend", "crashenemy"};
      for (int turn = 0; turn < 5; turn++)
      for (int wounded = 0; wounded < 2; wounded++)
      for (int cars = 1; cars <= 2; cars++)
      {
         unsigned long seed_used = 5000011UL *
            (unsigned long)(turn * 8 + wounded * 3 + cars + scenario * 97);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         squadst squad;
         squad.id = 1;
         chase_build_squad(squad, scenario, 5, wounded);
         activesquad = &squad;
         chaseseq.location = 1;
         delete_and_clear(chaseseq.enemycar);
         makechasers(SITE_GOVERNMENT_POLICESTATION, 40);
         chase_give_cars(squad, "STATIONWAGON", cars);

         fprintf(out, "{\"kind\":\"turn\",\"scenario\":%d,\"seed\":%lu,"
                      "\"turn\":\"%s\",\"wounded\":%d,\"cars\":%d,"
                      "\"endgame\":%d,\"world_seed\":%lu",
                 scenario, seed_used, TURNS[turn], wounded, cars,
                 endgamestate, run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("]", out);
         chase_write_state(out, "before", squad);
         fputs(",\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         short obstacle = -1;
         long long before = lcs_trace_draw_count();
         int ended = 0;
         if (!strcmp(TURNS[turn], "update")) ended = drivingupdate(obstacle);
         else if (!strcmp(TURNS[turn], "evade")) evasivedrive();
         else if (!strcmp(TURNS[turn], "dodge")) ended = dodgedrive();
         else if (!strcmp(TURNS[turn], "crashfriend")) crashfriendlycar(0);
         else if (len(chaseseq.enemycar)) crashenemycar(0);

         fprintf(out, ",\"draws\":%lld,\"ended\":%d,\"obstacle\":%d",
                 lcs_trace_draw_count() - before, ended, obstacle);
         chase_write_state(out, "after", squad);
         fputs("}\n", out);

         delete_and_clear(chaseseq.friendcar, vehicle);
         delete_and_clear(chaseseq.enemycar);
         chase_free_squad(squad);
         activesquad = NULL;
      }

      // The same again on foot, where agility and health decide it instead.
      for (int wounded = 0; wounded < 2; wounded++)
      for (int round = 0; round < 3; round++)
      {
         unsigned long seed_used =
            7000003UL * (unsigned long)(wounded * 5 + round + scenario * 31 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         squadst squad;
         squad.id = 1;
         chase_build_squad(squad, scenario, 5, wounded);
         activesquad = &squad;
         chaseseq.location = 1;
         delete_and_clear(chaseseq.enemycar);
         makechasers(SITE_GOVERNMENT_POLICESTATION, 40);
         delete_and_clear(chaseseq.enemycar);
         for (int e = 0; e < ENCMAX; e++) encounter[e].carid = -1;
         for (int p = 0; p < 6; p++)
            if (squad.squad[p]) squad.squad[p]->carid = -1;
         mode = GAMEMODE_CHASEFOOT;

         fprintf(out, "{\"kind\":\"foot\",\"scenario\":%d,\"seed\":%lu,"
                      "\"wounded\":%d,\"rounds\":%d,\"endgame\":%d,"
                      "\"world_seed\":%lu",
                 scenario, seed_used, wounded, round + 1, endgamestate,
                 run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("]", out);
         chase_write_state(out, "before", squad);
         fputs(",\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         long long before = lcs_trace_draw_count();
         for (int r = 0; r <= round; r++) evasiverun();

         fprintf(out, ",\"draws\":%lld", lcs_trace_draw_count() - before);
         chase_write_state(out, "after", squad);
         fputs("}\n", out);

         mode = GAMEMODE_CHASECAR;
         chase_free_squad(squad);
         activesquad = NULL;
      }
   }
}

// A whole round of combat: the squad swings, the other side swings back, and
// everybody bleeds.
//
// Probed as three separate calls per sample rather than one loop, because
// youattack(), enemyattack() and creatureadvance() each decide a great deal on
// their own and a divergence in one would otherwise be blamed on another.
void probe_fight(FILE *out)
{
   static const char *ROUNDS[] = {"you", "enemy", "advance", "full"};

   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 122949823UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();

      for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
      for (int v = 0; v < VIEWNUM; v++)
      {
         attitude[v] = (v * 7 + scenario * 13) % 101;
         public_interest[v] = (v * 3 + scenario * 5) % 40;
      }
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = ENDGAME_NONE;

      newsstoryst *ns = new newsstoryst;
      ns->loc = 1;
      newsstory.push_back(ns);
      sitestory = ns;

      for (int round = 0; round < 4; round++)
      for (int alarm = 0; alarm < 2; alarm++)
      for (int crowd = 1; crowd <= 3; crowd++)
      {
         unsigned long seed_used = 4000037UL *
            (unsigned long)(round * 12 + alarm * 5 + crowd + scenario * 89 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         mode = GAMEMODE_SITE;
         cursite = 1;
         sitetype = location[cursite]->type;
         sitealarm = alarm;
         sitealienate = 0;
         sitecrime = 0;
         sitealarmtimer = -1;
         postalarmtimer = 0;
         siteonfire = 0;
         sitestory->crime.clear();
         locx = MAPX >> 1, locy = 5, locz = 0;
         for (int x = 0; x < MAPX; x++)
         for (int y = 0; y < MAPY; y++)
         for (int z = 0; z < MAPZ; z++)
         {
            levelmap[x][y][z].flag = 0;
            levelmap[x][y][z].special = SPECIAL_NONE;
            levelmap[x][y][z].siegeflag = 0;
         }
         // A fire under the squad's feet, so the burning and the spreading are
         // both reached.
         if (crowd == 3)
            levelmap[locx][locy][locz].flag |= SITEBLOCK_FIRE_PEAK;

         squadst squad;
         squad.id = 1;
         chase_build_squad(squad, scenario, 4, crowd % 2);
         activesquad = &squad;
         for (int p = 0; p < 6; p++)
            if (squad.squad[p]) squad.squad[p]->carid = -1;

         // A mixed room: enemies who will fight, and bystanders who will not.
         for (int e = 0; e < ENCMAX; e++) encounter[e].exists = 0;
         int slot = 0;
         for (int n = 0; n < crowd * 2; n++)
         {
            makecreature(encounter[slot], n % 2 ? CREATURE_COP
                                                : CREATURE_WORKER_SECRETARY);
            if (n % 2) conservatise(encounter[slot]);
            encounter[slot].carid = -1;
            slot++;
         }
         // Somebody armed, so the squad has a dangerous target to prefer.
         makecreature(encounter[slot], CREATURE_SECURITYGUARD);
         conservatise(encounter[slot]);
         encounter[slot].carid = -1;
         slot++;

         fprintf(out, "{\"kind\":\"fight\",\"scenario\":%d,\"seed\":%lu,"
                      "\"round\":\"%s\",\"alarm\":%d,\"crowd\":%d,"
                      "\"endgame\":%d,\"world_seed\":%lu",
                 scenario, seed_used, ROUNDS[round], alarm, crowd,
                 endgamestate, run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("]", out);
         fprintf(out, ",\"fire\":%d", crowd == 3 ? 1 : 0);
         chase_write_state(out, "before", squad);
         fputs(",\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         long long before = lcs_trace_draw_count();
         if (!strcmp(ROUNDS[round], "you")) youattack();
         else if (!strcmp(ROUNDS[round], "enemy")) enemyattack();
         else if (!strcmp(ROUNDS[round], "advance")) creatureadvance();
         else { youattack(); enemyattack(); creatureadvance(); }

         fprintf(out, ",\"draws\":%lld,\"alarm_after\":%d,\"crime\":%d,"
                      "\"alienate\":%d,\"onfire\":%d,\"postalarm\":%d",
                 lcs_trace_draw_count() - before, sitealarm, sitecrime,
                 sitealienate, siteonfire, postalarmtimer);
         fputs(",\"crimes\":[", out);
         for (int i = 0; i < len(sitestory->crime); i++)
            fprintf(out, "%s%d", i ? "," : "", sitestory->crime[i]);
         fputs("],\"fireflags\":[", out);
         {
            bool first = true;
            for (int y = 0; y < MAPY; y++)
            for (int x = 0; x < MAPX; x++)
            {
               fprintf(out, "%s%d", first ? "" : ",",
                       levelmap[x][y][0].flag & (SITEBLOCK_FIRE_START |
                          SITEBLOCK_FIRE_PEAK | SITEBLOCK_FIRE_END |
                          SITEBLOCK_DEBRIS));
               first = false;
            }
         }
         fputs("]", out);
         chase_write_state(out, "after", squad);
         fputs("}\n", out);

         chase_free_squad(squad);
         activesquad = NULL;
      }
   }
}

// Who is in a building when the squad walks in, and who arrives afterwards.
//
// Every site type, with and without the squad standing somewhere restricted,
// with and without the alarm up long enough to have brought a response, and
// then the siege waves for each kind of attacker.
void probe_encounters(FILE *out)
{
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 122949823UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();

      for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
      for (int v = 0; v < VIEWNUM; v++)
      {
         attitude[v] = (v * 7 + scenario * 13) % 101;
         public_interest[v] = (v * 3 + scenario * 5) % 40;
      }
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = scenario % ENDGAMENUM;
      for (int e = 0; e < EXECNUM; e++) exec[e] = (e + scenario) % 3 - 1;

      newsstoryst *ns = new newsstoryst;
      ns->loc = 1;
      newsstory.push_back(ns);
      sitestory = ns;
      mode = GAMEMODE_SITE;

      squadst squad;
      squad.id = 1;
      for (int p = 0; p < 6; p++) squad.squad[p] = NULL;
      activesquad = &squad;

      for (int type = 0; type < SITENUM; type++)
      for (int sec = 0; sec < 2; sec++)
      for (int variant = 0; variant < 3; variant++)
      {
         unsigned long seed_used = 6000011UL * (unsigned long)
            (type * 8 + sec * 4 + variant + scenario * 457 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         cursite = 1;
         sitetype = location[cursite]->type;
         sitealarm = variant == 1;
         siteonfire = variant == 2;
         postalarmtimer = variant == 2 ? 100 : 0;
         locx = MAPX >> 1, locy = 5, locz = 0;
         for (int x = 0; x < MAPX; x++)
         for (int y = 0; y < MAPY; y++)
         for (int z = 0; z < MAPZ; z++)
         {
            levelmap[x][y][z].flag = 0;
            levelmap[x][y][z].special = SPECIAL_NONE;
         }
         if (sec) levelmap[locx][locy][locz].flag |= SITEBLOCK_RESTRICTED;

         long long before = lcs_trace_draw_count();
         prepareencounter(type, sec);

         fprintf(out, "{\"kind\":\"prepare\",\"scenario\":%d,\"seed\":%lu,"
                      "\"type\":%d,\"sec\":%d,\"variant\":%d,\"sitetype\":%d,"
                      "\"endgame\":%d,\"world_seed\":%lu,\"draws\":%lld",
                 scenario, seed_used, type, sec, variant, sitetype,
                 endgamestate, run_seed, lcs_trace_draw_count() - before);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("],\"exec\":[", out);
         for (int i = 0; i < EXECNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", exec[i]);
         fputs("]", out);
         chase_write_state(out, "after", squad);
         fputs("}\n", out);
      }

      // Siege waves: each kind of attacker, and the building's own
      // reinforcements when no siege is on.
      for (int besieged = 0; besieged < 2; besieged++)
      for (int kind = 0; kind < SIEGENUM; kind++)
      for (int heavy = 0; heavy < 2; heavy++)
      {
         // SIEGE_ORG falls through addsiegeencounter()'s switch without
         // making anybody, so the slots keep whoever was in them from the
         // last wave and are simply re-marked as present. That is leftover
         // state rather than a rule, and the original never reaches it: an
         // organisation siege does not put attackers through the door.
         if (besieged && kind == SIEGE_ORG) continue;
         unsigned long seed_used = 8000009UL * (unsigned long)
            (besieged * 40 + kind * 4 + heavy + scenario * 211 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         cursite = 1;
         sitetype = location[cursite]->type;
         for (int e = 0; e < ENCMAX; e++) encounter[e].exists = 0;
         location[cursite]->siege.siege = besieged != 0;
         location[cursite]->siege.siegetype = kind;
         location[cursite]->siege.escalationstate = kind % 4;

         long long before = lcs_trace_draw_count();
         int came = addsiegeencounter(heavy ? SIEGEFLAG_HEAVYUNIT
                                            : SIEGEFLAG_UNIT_DAMAGED);

         fprintf(out, "{\"kind\":\"siege\",\"scenario\":%d,\"seed\":%lu,"
                      "\"besieged\":%d,\"attacker\":%d,\"heavy\":%d,"
                      "\"escalation\":%d,\"sitetype\":%d,\"endgame\":%d,"
                      "\"world_seed\":%lu,\"draws\":%lld,\"came\":%d",
                 scenario, seed_used, besieged, kind, heavy, kind % 4,
                 sitetype, endgamestate, run_seed,
                 lcs_trace_draw_count() - before, came);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("]", out);
         chase_write_state(out, "after", squad);
         fputs("}\n", out);
      }
      location[1]->siege.siege = false;
      activesquad = NULL;
   }
}

// Getting through a building unnoticed: the per-turn disguise check, and the
// check made when the squad does something it should not have.
//
// The room is filled by prepareencounter() so the watchers are the ones the
// site would really hold, and the squad is dressed and armed across the range
// that matters — nothing, a concealed weapon, and something obvious.
void probe_stealth(FILE *out)
{
   static const char *KITS[] = {"none", "casual", "uniform", "obvious"};

   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 122949823UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();

      for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
      for (int v = 0; v < VIEWNUM; v++)
      {
         attitude[v] = (v * 7 + scenario * 13) % 101;
         public_interest[v] = (v * 3 + scenario * 5) % 40;
      }
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = ENDGAME_NONE;
      fieldskillrate = scenario % 3;

      newsstoryst *ns = new newsstoryst;
      ns->loc = 1;
      newsstory.push_back(ns);
      sitestory = ns;
      mode = GAMEMODE_SITE;

      for (int kit = 0; kit < 4; kit++)
      for (int restricted = 0; restricted < 2; restricted++)
      for (int timer = 0; timer < 3; timer++)
      {
         unsigned long seed_used = 9000011UL * (unsigned long)
            (kit * 8 + restricted * 4 + timer + scenario * 137 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         cursite = 1;
         sitetype = location[cursite]->type;
         sitealarm = 0;
         sitealarmtimer = timer == 0 ? -1 : timer;
         sitecrime = 0;
         locx = MAPX >> 1, locy = 5, locz = 0;
         for (int x = 0; x < MAPX; x++)
         for (int y = 0; y < MAPY; y++)
         for (int z = 0; z < MAPZ; z++)
         {
            levelmap[x][y][z].flag = 0;
            levelmap[x][y][z].special = SPECIAL_NONE;
         }
         if (restricted) levelmap[locx][locy][locz].flag |= SITEBLOCK_RESTRICTED;

         squadst squad;
         squad.id = 1;
         chase_build_squad(squad, scenario, 4, 0);
         activesquad = &squad;
         for (int p = 0; p < 6; p++)
         {
            if (!squad.squad[p]) continue;
            squad.squad[p]->carid = -1;
            squad.squad[p]->set_skill(SKILL_STEALTH, (p + scenario) % 8);
            squad.squad[p]->set_skill(SKILL_DISGUISE, (p * 2 + scenario) % 8);
            if (kit >= 1)
               squad.squad[p]->give_armor(*armortype[getarmortype(
                  kit == 1 ? "ARMOR_CLOTHES" : "ARMOR_POLICEUNIFORM")], NULL);
            if (kit == 2)
               squad.squad[p]->give_weapon(*weapontype[getweapontype(
                  "WEAPON_SEMIPISTOL_9MM")], NULL);
            if (kit == 3)
               squad.squad[p]->give_weapon(*weapontype[getweapontype(
                  "WEAPON_AUTORIFLE_M16")], NULL);
         }

         prepareencounter(sitetype, restricted);

         fprintf(out, "{\"kind\":\"blend\",\"scenario\":%d,\"seed\":%lu,"
                      "\"kit\":\"%s\",\"restricted\":%d,\"timer\":%d,"
                      "\"sitetype\":%d,\"endgame\":%d,\"rate\":%d,"
                      "\"world_seed\":%lu",
                 scenario, seed_used, KITS[kit], restricted, sitealarmtimer,
                 sitetype, endgamestate, fieldskillrate, run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("]", out);
         chase_write_state(out, "before", squad);
         fputs(",\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         long long before = lcs_trace_draw_count();
         disguisecheck(sitealarmtimer < 0 ? 1 : sitealarmtimer);
         fprintf(out, ",\"draws\":%lld,\"alarm\":%d,\"alarmtimer\":%d",
                 lcs_trace_draw_count() - before, sitealarm, sitealarmtimer);
         chase_write_state(out, "after", squad);
         fputs("}\n", out);

         // And then the check the squad triggers by acting.
         lcs_trace_set_seed(seed_used + 1);
         initMainRNG();
         sitealarm = 0;
         fprintf(out, "{\"kind\":\"notice\",\"scenario\":%d,\"seed\":%lu,"
                      "\"kit\":\"%s\",\"restricted\":%d,\"timer\":%d,"
                      "\"sitetype\":%d,\"endgame\":%d,\"rate\":%d,"
                      "\"world_seed\":%lu",
                 scenario, seed_used + 1, KITS[kit], restricted, sitealarmtimer,
                 sitetype, endgamestate, fieldskillrate, run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("]", out);
         chase_write_state(out, "before", squad);
         fputs(",\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fprintf(out, "],\"difficulty\":%d", DIFFICULTY_AVERAGE);

         before = lcs_trace_draw_count();
         noticecheck(-1, DIFFICULTY_AVERAGE);
         fprintf(out, ",\"draws\":%lld,\"alarm\":%d",
                 lcs_trace_draw_count() - before, sitealarm);
         chase_write_state(out, "after", squad);
         fputs("}\n", out);

         chase_free_squad(squad);
         activesquad = NULL;
      }
   }
}

// Recruitment: a day's asking around, and then the meetings that follow.
//
// The meetings are driven directly rather than through
// completerecruitmeeting(), which is a keystroke loop — but every roll that
// function makes is made here in the same order, so the draw counts and the
// outcomes are the ones the real meeting would have produced. The parts that
// only ask the player a question are the parts left out.
void probe_recruit(FILE *out)
{
   static const int TYPES[] = {
      CREATURE_COLLEGESTUDENT, CREATURE_HIPPIE, CREATURE_GANGMEMBER,
      CREATURE_PROSTITUTE, CREATURE_VETERAN, CREATURE_DOCTOR,
      CREATURE_JUDGE_LIBERAL, CREATURE_LOCKSMITH, CREATURE_MUTANT,
      CREATURE_TEACHER,
   };
   const int TYPE_COUNT = (int)(sizeof(TYPES) / sizeof(TYPES[0]));

   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 122949823UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();

      for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
      for (int v = 0; v < VIEWNUM; v++)
      {
         attitude[v] = (v * 7 + scenario * 13) % 101;
         public_interest[v] = (v * 3 + scenario * 5) % 40;
      }
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = ENDGAME_NONE;
      mode = GAMEMODE_BASE;
      cursite = 1;

      // Asking around: every recruitable type, at a spread of street sense.
      for (int t = 0; t < TYPE_COUNT; t++)
      for (int sense = 0; sense < 3; sense++)
      {
         unsigned long seed_used = 1200007UL * (unsigned long)
            (t * 4 + sense + scenario * 61 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();
         for (int e = 0; e < ENCMAX; e++) encounter[e].exists = 0;

         Creature cr;
         cr.id = 700000;
         cr.align = ALIGN_LIBERAL;
         cr.location = 1;
         cr.set_skill(SKILL_STREETSENSE, sense * 4);
         cr.set_attribute(ATTRIBUTE_INTELLIGENCE, 3 + sense * 3);

         // Recorded before the search, since finding people changes nothing
         // about the searcher but the skill it teaches.
         char before_json[8192];
         FILE *hold = tmpfile();
         chase_write_creature(hold, cr, true);
         long held = ftell(hold);
         rewind(hold);
         size_t got = fread(before_json, 1, sizeof(before_json) - 1, hold);
         before_json[got] = 0;
         fclose(hold);
         (void)held;

         // The generator is not at the start of its stream here: reseeding and
         // then building the searcher has already drawn.
         unsigned long rng_at[RNG_SIZE];
         for (int i = 0; i < RNG_SIZE; i++) rng_at[i] = ::seed[i];

         long long before = lcs_trace_draw_count();

         int difficulty = recruitFindDifficulty(TYPES[t]);
         int found = 0;
         long long steps[6];
         for (int i = 0; i < 6; i++) steps[i] = 0;
         long long split_make = 0, split_name = 0;
         if (difficulty < 10)
            for (found = 0; found < 5; found++)
            {
               long long at = lcs_trace_draw_count();
               if (found == 0 ||
                   cr.skill_roll(SKILL_STREETSENSE) > (difficulty + found * 2))
               {
                  makecreature(encounter[found], TYPES[t]);
                  long long made = lcs_trace_draw_count();
                  encounter[found].namecreature();
                  if (found == 0)
                  {
                     split_make = made - at;
                     split_name = lcs_trace_draw_count() - made;
                  }
                  steps[found] = lcs_trace_draw_count() - at;
               }
               else { steps[found] = lcs_trace_draw_count() - at; break; }
            }

         fprintf(out, "{\"kind\":\"ask\",\"scenario\":%d,\"seed\":%lu,"
                      "\"type\":\"%s\",\"sense\":%d,\"difficulty\":%d,"
                      "\"found\":%d,\"draws\":%lld,\"world_seed\":%lu",
                 scenario, seed_used,
                 getcreaturetype(TYPES[t])->get_idname().c_str(), sense * 4,
                 difficulty, found, lcs_trace_draw_count() - before, run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("],\"streetsense_after\":", out);
         fprintf(out, "%d", cr.get_skill(SKILL_STREETSENSE));
         fputs(",\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", rng_at[i]);
         fprintf(out, "],\"split_make\":%lld,\"split_name\":%lld",
                 split_make, split_name);
         fprintf(out, ",\"recruiter\":[%s],\"steps\":[", before_json);
         for (int i = 0; i < 6; i++)
            fprintf(out, "%s%lld", i ? "," : "", steps[i]);
         fputs("]", out);
         squadst empty;
         for (int p = 0; p < 6; p++) empty.squad[p] = NULL;
         chase_write_state(out, "after", empty);
         fputs("}\n", out);
      }

      // The meetings. Every approach against a spread of recruits.
      for (int t = 0; t < TYPE_COUNT; t++)
      for (int approach = 0; approach < 2; approach++)
      for (int standing = 0; standing < 3; standing++)
      {
         unsigned long seed_used = 1300021UL * (unsigned long)
            (t * 8 + approach * 4 + standing + scenario * 97 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();
         for (int e = 0; e < ENCMAX; e++) encounter[e].exists = 0;

         Creature recruiter;
         recruiter.id = 700001;
         recruiter.align = ALIGN_LIBERAL;
         recruiter.location = 1;
         recruiter.hireid = -1;
         recruiter.juice = 100 * standing;
         recruiter.meetings = standing * 3;
         recruiter.set_skill(SKILL_PERSUASION, 2 + standing * 3);
         recruiter.set_skill(SKILL_BUSINESS, standing);
         recruiter.set_skill(SKILL_SCIENCE, standing * 2);
         recruiter.set_skill(SKILL_RELIGION, standing);
         recruiter.set_skill(SKILL_LAW, standing);
         recruiter.set_attribute(ATTRIBUTE_INTELLIGENCE, 4 + standing * 2);

         makecreature(encounter[0], TYPES[t]);
         encounter[0].namecreature();
         encounter[0].juice = standing * 250;
         Creature &recruit = encounter[0];

         ledger.force_funds(approach ? 500 : 10);

         // recruitst's constructor decides how eager they are before anybody
         // has met them; it draws, so it is built inside the measured window.
         unsigned long rng_at[RNG_SIZE];
         for (int i = 0; i < RNG_SIZE; i++) rng_at[i] = ::seed[i];

         long long before = lcs_trace_draw_count();
         recruitst meeting;
         int eagerness_raw = meeting.eagerness1;

         fprintf(out, "{\"kind\":\"meet\",\"scenario\":%d,\"seed\":%lu,"
                      "\"type\":\"%s\",\"approach\":%d,\"standing\":%d,"
                      "\"world_seed\":%lu,\"eagerness\":%d,\"funds\":%d",
                 scenario, seed_used,
                 getcreaturetype(TYPES[t])->get_idname().c_str(), approach,
                 standing, run_seed, eagerness_raw, ledger.get_funds());
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("]", out);
         fputs(",\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", rng_at[i]);
         fputs("],\"recruiter\":[", out);
         chase_write_creature(out, recruiter, true);
         fputs("],\"recruit\":[", out);
         chase_write_creature(out, recruit, true);
         fputs("]", out);

         // The meeting itself, roll for roll.
         int missed = 0;
         int outcome = 0;   // 0 continues, 1 over
         if (recruiter.meetings++ > 5 &&
             LCSrandom(recruiter.meetings - 5))
         {
            missed = 1;
         }
         else
         {
            if (approach) ledger.subtract_funds(50, EXPENSE_RECRUITMENT);
            recruiter.train(SKILL_PERSUASION,
               max(12 - recruiter.get_skill(SKILL_PERSUASION), 5));
            recruiter.train(SKILL_SCIENCE,
               max(recruit.get_skill(SKILL_SCIENCE) - recruiter.get_skill(SKILL_SCIENCE), 0));
            recruiter.train(SKILL_RELIGION,
               max(recruit.get_skill(SKILL_RELIGION) - recruiter.get_skill(SKILL_RELIGION), 0));
            recruiter.train(SKILL_LAW,
               max(recruit.get_skill(SKILL_LAW) - recruiter.get_skill(SKILL_LAW), 0));
            recruiter.train(SKILL_BUSINESS,
               max(recruit.get_skill(SKILL_BUSINESS) - recruiter.get_skill(SKILL_BUSINESS), 0));

            int lib = recruiter.get_skill(SKILL_BUSINESS) +
                      recruiter.get_skill(SKILL_SCIENCE) +
                      recruiter.get_skill(SKILL_RELIGION) +
                      recruiter.get_skill(SKILL_LAW) +
                      recruiter.get_attribute(ATTRIBUTE_INTELLIGENCE, true);
            int reluctance = 5 + recruit.get_skill(SKILL_BUSINESS) +
                             recruit.get_skill(SKILL_SCIENCE) +
                             recruit.get_skill(SKILL_RELIGION) +
                             recruit.get_skill(SKILL_LAW) +
                             recruit.get_attribute(ATTRIBUTE_WISDOM, true) +
                             recruit.get_attribute(ATTRIBUTE_INTELLIGENCE, true);
            if (lib > reluctance) reluctance = 0; else reluctance -= lib;
            int difficulty = reluctance;

            // Both approaches roll for which issue came up: the props branch
            // through getissueeventstring(), the other through getview().
            // Only the draw matters here.
            if (approach) difficulty -= 5;
            LCSrandom(VIEWNUM - 3);

            if (recruit.juice >= 10)
            {
               if (recruit.juice < 50) difficulty += 1;
               else if (recruit.juice < 100)
                  difficulty += (int)(2 + 0.1 * recruit.get_attribute(ATTRIBUTE_WISDOM, false));
               else if (recruit.juice < 200)
                  difficulty += (int)(3 + 0.2 * recruit.get_attribute(ATTRIBUTE_WISDOM, false));
               else if (recruit.juice < 500)
                  difficulty += (int)(4 + 0.3 * recruit.get_attribute(ATTRIBUTE_WISDOM, false));
               else if (recruit.juice < 1000)
                  difficulty += (int)(5 + 0.4 * recruit.get_attribute(ATTRIBUTE_WISDOM, false));
               else
                  difficulty += (int)(6 + 0.5 * recruit.get_attribute(ATTRIBUTE_WISDOM, false));
            }
            if (difficulty > 18) difficulty = 18;

            if (recruiter.skill_check(SKILL_PERSUASION, difficulty))
            {
               if (meeting.level < 127) meeting.level++;
               if (meeting.eagerness1 < 127) meeting.eagerness1++;
            }
            else if (recruiter.skill_check(SKILL_PERSUASION, difficulty))
            {
               if (meeting.level < 127) meeting.level++;
               if (meeting.eagerness1 > -128) meeting.eagerness1--;
            }
            else outcome = 1;
         }

         fprintf(out, ",\"draws\":%lld,\"missed\":%d,\"outcome\":%d,"
                      "\"level\":%d,\"eagerness_after\":%d,\"funds_after\":%d,"
                      "\"subordinates\":%d",
                 lcs_trace_draw_count() - before, missed, outcome,
                 (int)meeting.level, (int)meeting.eagerness1,
                 ledger.get_funds(), subordinatesleft(recruiter));
         fputs(",\"recruiter_after\":[", out);
         chase_write_creature(out, recruiter, true);
         fputs("]}\n", out);

         meeting.recruit = NULL;
      }
   }
}

// Not in includes.h, but not static either: declared here so the probe can
// time each activity group separately.
void doActivityHacking(vector<Creature *> &hack, char &clearformess);
void doActivityGraffiti(vector<Creature *> &graffiti, char &clearformess);
void doActivityProstitution(vector<Creature *> &prostitutes, char &clearformess);
void doActivityLearn(vector<Creature *> &students, char &clearformess);
void doActivityTrouble(vector<Creature *> &trouble, char &clearformess);
void doActivityTeach(vector<Creature *> &teachers, char &clearformess);
void doActivityBury(vector<Creature *> &bury, char &clearformess);

// The pile on the floor, which the tailoring jobs both read and rewrite.
static void activation_write_loot(FILE *out, vector<Item *> &pile)
{
   for (int i = 0; i < len(pile); i++)
   {
      fprintf(out, "%s{\"type\":", i ? "," : "");
      write_string(out, pile[i]->get_itemtypename().c_str());
      fprintf(out, ",\"number\":%ld", pile[i]->get_number());
      if (pile[i]->is_armor())
      {
         Armor *a = static_cast<Armor *>(pile[i]);
         fprintf(out, ",\"quality\":%d,\"bloody\":%d,\"damaged\":%d",
                 a->get_quality(), a->is_bloody() ? 1 : 0,
                 a->is_damaged() ? 1 : 0);
      }
      fputs("}", out);
   }
}


// The dispersal statuses, as daily.cpp declares them privately.
enum ProbeDispersalTypes
{
   DISPERSAL_SAFE=-1,
   DISPERSAL_BOSSSAFE,
   DISPERSAL_NOCONTACT,
   DISPERSAL_BOSSINPRISON,
   DISPERSAL_HIDING,
   DISPERSAL_BOSSINHIDING,
   DISPERSAL_ABANDONLCS
};

// A transcription of dispersalcheck() from src/daily/daily.cpp, with the
// end-of-game check and the empty-squad sweep taken off the end: both belong
// to the day around it rather than to the check, and the first of them ends
// the run when a sample deliberately kills the last Liberal.
static void dispersal_block(char &clearformess)
{
   int p = 0;
   //NUKE DISPERSED SQUAD MEMBERS WHOSE MASTERS ARE NOT AVAILABLE
   if(len(pool))
   {
      // *JDS* I'm documenting this algorithm carefully because it
      // took me awhile to figure out what exactly was going on here.
      //
      // dispersal_status tracks whether each person has a secure chain of command.
      //
      // if dispersal_status == NOCONTACT, no confirmation of contact has been made
      // if dispersal_status == BOSSSAFE, confirmation that THEY are safe is given,
      //    but it is still needed to check whether their subordinates
      //    can reach them.
      // if dispersal_status == SAFE, confirmation has been made that this squad
      //    member is safe, and their immediate subordinates have also
      //    checked.
      //
      // The way the algorithm works, everyone starts at dispersal_status = NOCONTACT.
      // Then we start at the top of the chain of command and walk
      // down it slowly, marking people BOSSSAFE and then SAFE as we sweep
      // down the chain. If someone is dead or in an unreachable state,
      // they block progression down the chain to their subordinates,
      // preventing everyone who requires contact with that person
      // from being marked safe. After everyone reachable has been
      // reached and marked safe, all remaining squad members are nuked.
      vector<int> dispersal_status;
      dispersal_status.resize(len(pool));

      bool promotion;
      do
      {
         promotion=0;
         for(p=0;p<len(pool);p++)
         {
            // Default: members are marked dispersal_status = NOCONTACT
            //(no contact verified)
            dispersal_status[p]=DISPERSAL_NOCONTACT;
            // If member has no boss (founder level), mark
            // them dispersal_status = BOSSSAFE, using them as a starting point
            // at the top of the chain.
            if(pool[p]->hireid==-1)
            {
               if(!disbanding)
               {
                  dispersal_status[p]=DISPERSAL_BOSSSAFE;
                  if(pool[p]->hiding==-1)
                     pool[p]->hiding=LCSrandom(10)+5;
               }
               else dispersal_status[p]=DISPERSAL_BOSSINHIDING;
            }
            // If they're dead, mark them dispersal_status = SAFE, so they
            // don't ever have their subordinates checked
            // and aren't lost themselves (they're a corpse,
            // corpses don't lose contact)
            if(!pool[p]->alive&&!disbanding)
            {
               dispersal_status[p]=DISPERSAL_SAFE;
               //Attempt to promote their subordinates
               if(promotesubordinates(*pool[p],clearformess)) promotion=1;

               if(pool[p]->location==-1||location[pool[p]->location]->renting==RENTING_NOCONTROL)
                  delete_and_remove(pool,p--);
            }
         }
      } while(promotion);

      char changed;

      do // while(changed)
      {
         changed=0;

         char inprison;

         // Go through the entire pool to locate people at dispersal_status = BOSSSAFE,
         // so we can verify that their subordinates can reach them.
         for(p=len(pool)-1;p>=0;p--)
         {
            if(!pool[p]->alive) continue;
            if(pool[p]->location!=-1&&
               location[pool[p]->location]->type==SITE_GOVERNMENT_PRISON&&
             !(pool[p]->flag & CREATUREFLAG_SLEEPER))
            {
               inprison=1;
            }
            else inprison=0;

            // If your boss is in hiding
            if(dispersal_status[p]==DISPERSAL_BOSSINHIDING)
            {
               dispersal_status[p]=DISPERSAL_HIDING;
               for(int p2=len(pool)-1;p2>=0;p2--)
               {
                  if(pool[p2]->hireid==pool[p]->id && pool[p2]->alive)
                  {
                     dispersal_status[p2]=DISPERSAL_BOSSINHIDING; // Mark them as unreachable
                     changed=1; // Need another iteration
                  }
               }
            }

            // If in prison or unreachable due to a member of the command structure
            // above being in prison
            else if((dispersal_status[p]==DISPERSAL_BOSSSAFE&&inprison)||dispersal_status[p]==DISPERSAL_BOSSINPRISON)
            {
               int dispersalval=DISPERSAL_SAFE;
               if(pool[p]->flag&CREATUREFLAG_LOVESLAVE)
               {
                  if((dispersal_status[p]==DISPERSAL_BOSSINPRISON&&!inprison) ||
                     (dispersal_status[p]==DISPERSAL_BOSSSAFE    && inprison))
                  {
                     pool[p]->juice--; // Love slaves bleed juice when not in prison with their lover
                     if(pool[p]->juice<-50) dispersalval=DISPERSAL_ABANDONLCS;
                  }
               }
               dispersal_status[p]=dispersalval; // Guaranteed contactable in prison

               // Find all subordinates
               for(int p2=len(pool)-1;p2>=0;p2--)
               {
                  if(pool[p2]->hireid==pool[p]->id && pool[p2]->alive)
                  {
                     if(inprison) dispersal_status[p2]=DISPERSAL_BOSSINPRISON;
                     else dispersal_status[p2]=DISPERSAL_BOSSSAFE;
                     changed=1; // Need another iteration
                  }
               }
            }
            // Otherwise, if they're reachable
            else if(dispersal_status[p]==DISPERSAL_BOSSSAFE&&!inprison)
            {
               // Start looking through the pool again.
               for(int p2=len(pool)-1;p2>=0;p2--)
               {
                  // Locate each of this person's subordinates.
                  if(pool[p2]->hireid==pool[p]->id)
                  {
                     // Protect them from being dispersed -- their boss is
                     // safe. Their own subordinates will then be considered
                     // in the next loop iteration.
                     dispersal_status[p2]=DISPERSAL_BOSSSAFE;
                     // If they're hiding indefinitely and their boss isn't
                     // hiding at all, then have them discreetly return in a
                     // couple of weeks
                     if(pool[p2]->hiding==-1&&!pool[p]->hiding)
                        pool[p2]->hiding=LCSrandom(10)+3;
                     changed=1; // Take note that another iteration is needed.
                  }
               }
               // Now that we've dealt with this person's subordinates, mark
               // them so that we don't look at them again in this loop.
               dispersal_status[p]=DISPERSAL_SAFE;
            }
         }
      } while(changed); // If another iteration is needed, continue the loop.

      // After checking through the entire command structure, proceed
      // to nuke all squad members who are unable to make contact with
      // the LCS.
      for(p=len(pool)-1;p>=0;p--)
      {
         if(dispersal_status[p]==DISPERSAL_NOCONTACT||dispersal_status[p]==DISPERSAL_HIDING||dispersal_status[p]==DISPERSAL_ABANDONLCS)
         {
            if(clearformess) erase();
            else makedelimiter();

            if(!disbanding)
            {
               if(!pool[p]->hiding&&dispersal_status[p]==DISPERSAL_HIDING)
               {
                  set_color(COLOR_WHITE,COLOR_BLACK,1);
                  move(8,1);
                  addstr(pool[p]->name, gamelog);
                  addstr(" has lost touch with the Liberal Crime Squad.", gamelog);
                  gamelog.nextMessage();

                  getkey();

                  set_color(COLOR_GREEN,COLOR_BLACK,1);
                  move(9,1);
                  addstr("The Liberal has gone into hiding...", gamelog);
                  gamelog.nextMessage();

                  getkey();
               }
               else if(dispersal_status[p]==DISPERSAL_ABANDONLCS)
               {
                  set_color(COLOR_WHITE,COLOR_BLACK,1);
                  move(8,1);
                  addstr(pool[p]->name, gamelog);
                  addstr(" has abandoned the LCS.", gamelog);
                  gamelog.nextMessage();

                  getkey();
               }
               else if(dispersal_status[p]==DISPERSAL_NOCONTACT)
               {
                  set_color(COLOR_WHITE,COLOR_BLACK,1);
                  move(8,1);
                  addstr(pool[p]->name, gamelog);
                  addstr(" has lost touch with the Liberal Crime Squad.", gamelog);
                  gamelog.nextMessage();

                  getkey();
               }
            }

            removesquadinfo(*pool[p]);
            if(dispersal_status[p]==DISPERSAL_NOCONTACT||dispersal_status[p]==DISPERSAL_ABANDONLCS)
               delete_and_remove(pool,p);
            else
            {
               pool[p]->location=-1;
               if(!(pool[p]->flag & CREATUREFLAG_SLEEPER)) //Sleepers end up in shelter otherwise.
                  pool[p]->base=find_homeless_shelter(*pool[p]);
               pool[p]->activity.type=ACTIVITY_NONE;
               pool[p]->hiding=-1; // Hide indefinitely
            }
         }
      }
   }

}





// The first clinic in the world, for the samples that want real medics.
static int find_clinic_index_probe()
{
   for (int l = 0; l < len(location); l++)
      if (location[l]->type == SITE_HOSPITAL_CLINIC) return l;
   return 1;
}

// A transcription of the graffiti, natural-opinion-drift and seduction-stipend
// blocks of passmonth(), which are inline in a function that also runs
// elections, Congress and the whole justice system.
static void monthly_drift_block(int *libpower)
{
   int v;
   int conspower=200-attitude[VIEW_AMRADIO]-attitude[VIEW_CABLENEWS];

   for(int l=0;l<len(location);l++)
   {
      for(int c=len(location[l]->changes)-1;c>=0;c--)
      {
         if(location[l]->changes[c].flag==SITEBLOCK_GRAFFITI||
            location[l]->changes[c].flag==SITEBLOCK_GRAFFITI_CCS||
            location[l]->changes[c].flag==SITEBLOCK_GRAFFITI_OTHER)
         {
            int power=0,align=0;
            if(location[l]->changes[c].flag==SITEBLOCK_GRAFFITI) align=1;
            if(location[l]->changes[c].flag==SITEBLOCK_GRAFFITI_CCS) align=-1;
            if(securityable(location[l]->type))
            {
               location[l]->changes.erase(location[l]->changes.begin()+c);
               power=5;
            }
            else
            {
               if(location[l]->renting==RENTING_CCS)
                  location[l]->changes[c].flag=SITEBLOCK_GRAFFITI_CCS;
               else if(location[l]->renting==RENTING_PERMANENT)
                  location[l]->changes[c].flag=SITEBLOCK_GRAFFITI;
               else
               {
                  power=1;
                  if(!LCSrandom(10))
                     location[l]->changes[c].flag=SITEBLOCK_GRAFFITI_OTHER;
                  if(!LCSrandom(10)&&endgamestate<ENDGAME_CCS_DEFEATED&&endgamestate>0)
                     location[l]->changes[c].flag=SITEBLOCK_GRAFFITI_CCS;
                  if(!LCSrandom(30))
                     location[l]->changes.erase(location[l]->changes.begin()+c);
               }
            }
            if(align==1)
            {
               background_liberal_influence[VIEW_LIBERALCRIMESQUAD]+=power;
               background_liberal_influence[VIEW_CONSERVATIVECRIMESQUAD]+=power;
            }
            else if(align==-1)
            {
               background_liberal_influence[VIEW_LIBERALCRIMESQUAD]-=power;
               background_liberal_influence[VIEW_CONSERVATIVECRIMESQUAD]-=power;
            }
         }
      }
   }

   int mediabalance=0;
   int issuebalance[VIEWNUM-5];
   for(v=0;v<VIEWNUM;v++)
   {
      libpower[v]+=background_liberal_influence[v];
      background_liberal_influence[v]=static_cast<short>(background_liberal_influence[v]*0.66);

      if(v==VIEW_LIBERALCRIMESQUADPOS) continue;
      if(v==VIEW_LIBERALCRIMESQUAD) continue;
      if(v==VIEW_CONSERVATIVECRIMESQUAD) continue;
      if(v!=VIEW_AMRADIO&&v!=VIEW_CABLENEWS)
      {
         issuebalance[v] = libpower[v] - conspower;
         mediabalance += issuebalance[v];
         int roll = issuebalance[v] + LCSrandom(400)-200;
         if(roll < -50) change_public_opinion(v,-1,0);
         else if(roll > 50) change_public_opinion(v,1,0);
         else change_public_opinion(v,LCSrandom(2)*2-1,0);
      }
      else if(v==VIEW_AMRADIO||v==VIEW_CABLENEWS)
      {
         if(publicmood(-1)<attitude[v])change_public_opinion(v,-1);
         else change_public_opinion(v,1);
      }
   }

   for(int s=0;s<len(pool);s++)
   {
      pool[s]->train(SKILL_SEDUCTION,loveslaves(*pool[s])*5);
      if(pool[s]->flag & CREATUREFLAG_LOVESLAVE)
         pool[s]->train(SKILL_SEDUCTION,5);
   }
}

// One person's turn through the system, lifted out of the pool loop in
// passmonth() so a probe can drive a single stage at a time.
static void justice_stage(Creature &g, char &clearformess)
{
   if (!g.alive) return;
   if (g.flag & CREATUREFLAG_SLEEPER) return;
   if (g.location == -1) return;

   if (location[g.location]->type == SITE_GOVERNMENT_POLICESTATION)
   {
      if (g.flag & CREATUREFLAG_MISSING)
      {
         removesquadinfo(g);
         g.exists = false;
         return;
      }
      else if (g.flag & CREATUREFLAG_ILLEGALALIEN && law[LAW_IMMIGRATION] != 2)
      {
         removesquadinfo(g);
         g.exists = false;
         return;
      }
      else
      {
         int copstrength = 100;
         if (law[LAW_POLICEBEHAVIOR] == -2) copstrength = 200;
         if (law[LAW_POLICEBEHAVIOR] == -1) copstrength = 150;
         if (law[LAW_POLICEBEHAVIOR] == 1) copstrength = 75;
         if (law[LAW_POLICEBEHAVIOR] == 2) copstrength = 50;
         copstrength = (copstrength * g.heat) / 4;
         if (copstrength > 200) copstrength = 200;

         if (LCSrandom(copstrength) > g.juice + g.get_attribute(ATTRIBUTE_HEART, true) * 5 -
                                      g.get_attribute(ATTRIBUTE_WISDOM, true) * 5 +
                                      g.get_skill(SKILL_PSYCHOLOGY) * 5 &&
             g.hireid != -1)
         {
            int p2 = getpoolcreature(g.hireid);
            if (p2 != -1 && pool[p2]->alive &&
                (pool[p2]->location == -1 ||
                 location[pool[p2]->location]->type != SITE_GOVERNMENT_PRISON))
            {
               criminalize(*pool[p2], LAWFLAG_RACKETEERING);
               pool[p2]->confessions++;
            }
            if (g.base >= 0) location[g.base]->heat += 300;
            removesquadinfo(g);
            g.exists = false;
            return;
         }
         g.location = find_courthouse(g);
         Armor prisoner(*armortype[getarmortype("ARMOR_PRISONER")]);
         g.give_armor(prisoner, NULL);
      }
   }
   else if (location[g.location]->type == SITE_GOVERNMENT_COURTHOUSE)
      trial(g);
   else if (location[g.location]->type == SITE_GOVERNMENT_PRISON)
      prison(g);
}

// A transcription of giveup() from src/daily/siege.cpp with the end-of-game
// check taken out: it belongs to the day around the surrender, and it ends
// the run whenever a sample deliberately wipes out the last Liberal.
static void giveup_block()
{
   int loc=-1;
   if(selectedsiege!=-1)loc=selectedsiege;
   if(activesquad!=NULL)loc=activesquad->squad[0]->location;
   if(loc==-1)return;

   if(location[loc]->renting>1)location[loc]->renting=RENTING_NOCONTROL;

   //IF POLICE, END SIEGE
   if(location[loc]->siege.siegetype==SIEGE_POLICE ||
      location[loc]->siege.siegetype==SIEGE_FIREMEN)
   {
      music.play(MUSIC_SIEGE);
      int polsta=find_police_station(loc);

      //END SIEGE
      erase();
      set_color(COLOR_WHITE,COLOR_BLACK,1);
      move(1,1);
      if(location[loc]->siege.siegetype==SIEGE_POLICE && location[loc]->siege.escalationstate == 0)
         addstr("The police", gamelog);
      else if(location[loc]->siege.siegetype==SIEGE_POLICE && location[loc]->siege.escalationstate >= 1)
         addstr("The soldiers", gamelog);
      else addstr("The firemen", gamelog);
      addstr(" confiscate everything, including Squad weapons.", gamelog);
      gamelog.newline();

      int kcount=0,pcount=0,icount=0,p;
      char kname[100],pname[100],pcname[100];
      for(p=len(pool)-1;p>=0;p--)
      {
         if(pool[p]->location!=loc||!pool[p]->alive) continue;

         if(pool[p]->flag&CREATUREFLAG_ILLEGALALIEN) icount++;

         if(pool[p]->flag&CREATUREFLAG_MISSING&&pool[p]->align==-1)
         {
            kcount++;
            strcpy(kname,pool[p]->propername);
            if(pool[p]->type==CREATURE_RADIOPERSONALITY) offended_amradio=1;
            if(pool[p]->type==CREATURE_NEWSANCHOR) offended_cablenews=1;
            //clear interrogation data if deleted
            delete pool[p]->activity.intr();
         }
      }

      //CRIMINALIZE POOL IF FOUND WITH KIDNAP VICTIM OR ALIEN
      if(kcount) criminalizepool(LAWFLAG_KIDNAPPING,-1,loc);
      if(icount) criminalizepool(LAWFLAG_HIREILLEGAL,-1,loc);

      if(location[loc]->siege.siegetype==SIEGE_FIREMEN&&location[loc]->compound_walls&COMPOUND_PRINTINGPRESS)
         criminalizepool(LAWFLAG_SPEECH,-1,loc); // Criminalize pool for unacceptable speech

      //LOOK FOR PRISONERS (MUST BE AFTER CRIMINALIZATION ABOVE)
      for(p=len(pool)-1;p>=0;p--)
      {
         if(pool[p]->location!=loc||!pool[p]->alive) continue;

         if(iscriminal(*pool[p])&&!(pool[p]->flag&CREATUREFLAG_MISSING&&pool[p]->align==-1))
         {
            pcount++;
            strcpy(pname,pool[p]->propername);
            strcpy(pcname,pool[p]->name);
         }
      }

      if(kcount==1)
      {
         move(3,1);
         addstr(kname);
         addstr(" is rehabilitated and freed.", gamelog);
         gamelog.newline();
      }
      if(kcount>1)
      {
         move(3,1);
         addstr("The kidnap victims are rehabilitated and freed.", gamelog);
         gamelog.newline();
      }
      if(pcount==1)
      {
         move(5,1);
         addstr(pname, gamelog);
         if(strcmp(pname,pcname))
         {
            addstr(", aka ", gamelog);
            addstr(pcname, gamelog);
            addstr(",", gamelog);
         }
         move(6,1);
         addstr("is taken to the police station.", gamelog);
         gamelog.newline();
      }
      if(pcount>1)
      {
         move(5,1);
         addstr(pcount, gamelog);
         addstr(" Liberals are taken to the police station.", gamelog);
         gamelog.newline();
      }
      if(ledger.get_funds()>0)
      {
         if(ledger.get_funds()<=2000 || location[loc]->siege.siegetype==SIEGE_FIREMEN)
         {
            move(8,1);
            addstr("Fortunately, your funds remain intact.", gamelog);
            gamelog.newline();
         }
         else
         {
            move(8,1);
            int confiscated = LCSrandom(LCSrandom(ledger.get_funds()-2000)+1)+1000;
            if(ledger.get_funds()-confiscated > 50000)
               confiscated += ledger.get_funds() - 30000 - LCSrandom(20000) - confiscated;
            addstr_fl(gamelog,"Law enforcement has confiscated $%d in LCS funds.",confiscated);
            gamelog.newline();
            ledger.subtract_funds(confiscated,EXPENSE_CONFISCATED);
         }
      }
      if(location[loc]->siege.siegetype==SIEGE_FIREMEN)
      {
         if(location[loc]->compound_walls & COMPOUND_PRINTINGPRESS)
         {
            move(10,1);
            addstr("The printing press is dismantled and burned.", gamelog);
            gamelog.newline();
            location[loc]->compound_walls &= ~COMPOUND_PRINTINGPRESS;
         }
      }
      else
      {
         if(location[loc]->compound_walls)
         {
            move(10,1);
            addstr("The compound is dismantled.", gamelog);
            gamelog.newline();
            location[loc]->compound_walls=0;
         }
      }
      if(location[loc]->front_business!=-1)
      {
         move(12,1);
         addstr("Materials relating to the business front have been taken.", gamelog);
         gamelog.newline();
         location[loc]->front_business=-1;
      }

      getkey();

      if(location[loc]->siege.siegetype==SIEGE_FIREMEN)
         offended_firemen=0; // Firemen do not hold grudges

      for(p=len(pool)-1;p>=0;p--)
      {
         if(pool[p]->location!=loc) continue;

         //ALL KIDNAP VICTIMS FREED REGARDLESS OF CRIMES
         if((pool[p]->flag & CREATUREFLAG_MISSING)||
            !pool[p]->alive)
         {
            // Clear actions for anybody who was tending to this person
            for(int i=0;i<len(pool);i++)
               if(pool[i]->alive&&pool[i]->activity.type==ACTIVITY_HOSTAGETENDING&&pool[i]->activity.arg==pool[p]->id)
                  pool[i]->activity.type=ACTIVITY_NONE;

            removesquadinfo(*pool[p]);
            delete_and_remove(pool,p);
            continue;
         }

         //TAKE SQUAD EQUIPMENT
         if(pool[p]->squadid!=-1)
         {
            int sq=getsquad(pool[p]->squadid);
            if(sq!=-1)delete_and_clear(squad[sq]->loot);
         }

         pool[p]->drop_weapons_and_clips(NULL);

         if(iscriminal(*pool[p]))
         {
            removesquadinfo(*pool[p]);
            pool[p]->location=polsta;
            pool[p]->activity.type=ACTIVITY_NONE;
         }
      }

      location[loc]->siege.siege=0;
   }
   else
   {
      //OTHERWISE IT IS SUICIDE
      int killnumber=0;
      for(int p=len(pool)-1;p>=0;p--)
      {
         if(pool[p]->location!=loc) continue;

         if(pool[p]->alive&&pool[p]->align==1) stat_dead++;

         killnumber++;
         removesquadinfo(*pool[p]);
         pool[p]->die();
         pool[p]->location=-1;
      }

      if(location[loc]->siege.siegetype==SIEGE_CCS&&location[loc]->type==SITE_INDUSTRY_WAREHOUSE)
         location[loc]->renting=RENTING_CCS; // CCS Captures warehouse

      erase();
      set_color(COLOR_WHITE,COLOR_BLACK,1);
      move(1,1);
      addstr("Everyone in the ", gamelog);
      addstr(location[loc]->getname(), gamelog);
      addstr(" is slain.", gamelog);
      gamelog.newline();

      getkey();

      newsstoryst *ns=new newsstoryst;
      ns->type=NEWSSTORY_MASSACRE;
      ns->loc=loc;
      ns->crime.push_back(location[loc]->siege.siegetype);
      ns->crime.push_back(killnumber);
      newsstory.push_back(ns);

      //MUST SET cursite TO SATISFY endcheck() CODE

      location[loc]->siege.siege=0;
   }

   //CONFISCATE MATERIAL
   delete_and_clear(location[loc]->loot);
   for(int v=len(vehicle)-1;v>=0;v--)
      if(vehicle[v]->get_location()==loc)
         delete_and_remove(vehicle,v);

   gamelog.newline();

}





// A transcription of majornewspaper() from src/news/news.cpp with the display
// passes taken out: those are presentation, and the port replaces them.
static void newspaper_block()
{
   generate_random_event_news_stories();
   clean_up_empty_news_stories();
   assign_page_numbers_to_newspaper_stories();
   for (int n = 0; n < len(newsstory); n++)
      handle_public_opinion_impact(*newsstory[n]);
}

// Tomorrow's paper: what happened overnight, how prominently each story runs,
// and what that does to the country.
void probe_newspaper(FILE *out)
{
   // Enough story types to reach every branch of the scoring.
   static const int TYPES[] = {
      NEWSSTORY_SQUAD_SITE, NEWSSTORY_SQUAD_ESCAPED, NEWSSTORY_SQUAD_DEFENDED,
      NEWSSTORY_SQUAD_BROKESIEGE, NEWSSTORY_SQUAD_KILLED_SITE,
      NEWSSTORY_CCS_SITE, NEWSSTORY_CCS_DEFENDED, NEWSSTORY_MASSACRE,
      NEWSSTORY_KIDNAPREPORT, NEWSSTORY_GRAFFITIARREST,
      NEWSSTORY_CARTHEFT, NEWSSTORY_MAJOREVENT,
   };
   const int TYPE_COUNT = (int)(sizeof(TYPES) / sizeof(TYPES[0]));

   static const int SITES[] = {
      SITE_INDUSTRY_NUCLEAR, SITE_RESIDENTIAL_TENEMENT,
      SITE_BUSINESS_CRACKHOUSE, SITE_CORPORATE_HEADQUARTERS,
      SITE_GOVERNMENT_COURTHOUSE, SITE_LABORATORY_GENETIC,
   };
   const int SITE_COUNT = (int)(sizeof(SITES) / sizeof(SITES[0]));

   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 91827431UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      mode = GAMEMODE_BASE;
      cursite = 1;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      for (int endgame = 0; endgame < 4; endgame++)
      for (int type = 0; type < TYPE_COUNT; type++)
      for (int place = 0; place < SITE_COUNT; place++)
      for (int shape = 0; shape < 4; shape++)
      {
         unsigned long seed_used = 1500023UL * (unsigned long)
            (endgame * 4096 + type * 128 + place * 8 + shape
             + scenario * 383 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         delete_and_clear(pool);
         delete_and_clear(newsstory);
         endgamestate = endgame;
         ccsexposure = (shape % 3 == 2) ? CCSEXPOSURE_EXPOSED
                                        : CCSEXPOSURE_NONE;
         for (int v = 0; v < VIEWNUM; v++)
         {
            attitude[v] = (v * 11 + scenario * 17 + shape * 5) % 101;
            public_interest[v] = (v * 3 + scenario * 7) % 40;
            background_liberal_influence[v] = 0;
         }
         for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
         // A legislature with a mix of alignments, so the mass arrests in the
         // exposure story have somebody to arrest.
         for (int i = 0; i < SENATENUM; i++)
            senate[i] = ((i + scenario + shape) % 5) - 2;
         for (int i = 0; i < HOUSENUM; i++)
            house[i] = ((i * 3 + endgame + type) % 5) - 2;

         int loc = -1;
         for (int l = 0; l < len(location); l++)
            if (location[l]->type == SITES[place]) { loc = l; break; }
         if (loc != -1)
            location[loc]->renting = (shape == 3) ? RENTING_CCS
                                                  : RENTING_NOCONTROL;

         // A victim for the kidnap story to be about.
         Creature *victim = new Creature;
         makecreature(*victim, (shape % 2) ? CREATURE_CORPORATE_CEO
                                           : CREATURE_WORKER_JANITOR);
         victim->id = 910000;
         victim->align = ALIGN_CONSERVATIVE;
         victim->location = loc;
         pool.push_back(victim);

         newsstoryst *ns = new newsstoryst;
         ns->type = TYPES[type];
         ns->loc = loc;
         ns->cr = victim;
         ns->claimed = shape % 3;
         ns->positive = shape % 3;
         ns->siegetype = SIEGE_POLICE;
         // A crime sheet that grows with the sample's shape, with repeats so
         // the caps are exercised.
         for (int c = 0; c < CRIMENUM; c++)
            for (int r = 0; r <= (c + shape) % 4; r++)
               if ((c + shape) % 3 == 0) ns->crime.push_back(c);
         if (TYPES[type] == NEWSSTORY_MASSACRE)
         {
            ns->crime.clear();
            ns->crime.push_back(SIEGE_POLICE);
            ns->crime.push_back(shape * 3);
         }
         newsstory.push_back(ns);

         fprintf(out, "{\"kind\":\"newspaper\",\"scenario\":%d,\"seed\":%lu,"
                      "\"endgame\":%d,\"type\":%d,\"place\":%d,\"shape\":%d,"
                      "\"loc\":%d,\"exposure\":%d,\"claimed\":%d,"
                      "\"positive\":%d,\"world_seed\":%lu",
                 scenario, seed_used, endgame, ns->type, place, shape, loc,
                 ccsexposure, (int)ns->claimed, (int)ns->positive, run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"senate\":[", out);
         for (int i = 0; i < SENATENUM; i++)
            fprintf(out, "%s%d", i ? "," : "", senate[i]);
         fputs("],\"house\":[", out);
         for (int i = 0; i < HOUSENUM; i++)
            fprintf(out, "%s%d", i ? "," : "", house[i]);
         // The world is built once per scenario and each sample leaves its
         // mark on it, so who holds what goes into the record rather than
         // being assumed.
         fputs("],\"renting\":[", out);
         for (int l = 0; l < len(location); l++)
            fprintf(out, "%s%d", l ? "," : "", location[l]->renting);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("],\"crimes\":[", out);
         for (int c = 0; c < len(ns->crime); c++)
            fprintf(out, "%s%d", c ? "," : "", ns->crime[c]);
         fputs("],\"victim\":", out);
         write_string(out, getcreaturetype(victim->type)->get_idname().c_str());
         fputs(",\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         long long before = lcs_trace_draw_count();
         newspaper_block();

         fprintf(out, ",\"draws\":%lld", lcs_trace_draw_count() - before);
         fputs(",\"attitude_after\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"senate_after\":[", out);
         for (int i = 0; i < SENATENUM; i++)
            fprintf(out, "%s%d", i ? "," : "", senate[i]);
         fputs("],\"house_after\":[", out);
         for (int i = 0; i < HOUSENUM; i++)
            fprintf(out, "%s%d", i ? "," : "", house[i]);
         fprintf(out, "],\"exposure_after\":%d,\"endgame_after\":%d",
                 ccsexposure, endgamestate);
         fputs(",\"influence_after\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", background_liberal_influence[i]);
         fputs("],\"stories\":[", out);
         for (int n = 0; n < len(newsstory); n++)
         {
            fprintf(out, "%s{\"type\":%d,\"priority\":%ld,\"page\":%ld,"
                         "\"guardian\":%ld,\"politics\":%d,\"violence\":%d,"
                         "\"loc\":%d,\"positive\":%d,\"crimes\":[",
                    n ? "," : "", newsstory[n]->type, newsstory[n]->priority,
                    newsstory[n]->page, newsstory[n]->guardianpage,
                    (int)newsstory[n]->politics_level,
                    (int)newsstory[n]->violence_level, newsstory[n]->loc,
                    (int)newsstory[n]->positive);
            for (int c = 0; c < len(newsstory[n]->crime); c++)
               fprintf(out, "%s%d", c ? "," : "", newsstory[n]->crime[c]);
            fputs("]}", out);
         }
         fputs("]}\n", out);

         delete_and_clear(newsstory);
         delete_and_clear(pool);
      }
   }
}


// How a siege ends once the fighting is over: winning buys a few weeks before
// the police come back angrier, and losing costs the house and everything in
// it.
void probe_siege_outcome(FILE *out)
{
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 74310937UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = ENDGAME_NONE;
      mode = GAMEMODE_SITE;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      int shelter = -1, house = -1;
      for (int l = 0; l < len(location); l++)
      {
         if (shelter == -1 && location[l]->type == SITE_RESIDENTIAL_SHELTER)
            shelter = l;
         // A real rentable safehouse: escapesiege() re-seeds and renames the
         // site it lost, and only a proper site has a name to rebuild.
         if (house == -1 && location[l]->type == SITE_RESIDENTIAL_TENEMENT)
            house = l;
      }
      if (house == -1) house = 1;

      for (int won = 0; won < 2; won++)
      for (int attacker = 0; attacker < 3; attacker++)
      for (int rented = 0; rented < 2; rented++)
      for (int crowd = 1; crowd <= 4; crowd++)
      for (int heat = 0; heat < 5; heat++)
      {
         unsigned long seed_used = 1400031UL * (unsigned long)
            (won * 2048 + attacker * 512 + rented * 128 + crowd * 8 + heat
             + scenario * 359 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         delete_and_clear(pool);
         delete_and_clear(squad);
         activesquad = NULL;
         police_heat = heat;
         for (int l = 0; l < len(location); l++)
         {
            location[l]->siege = siegest();
            location[l]->siege.lights_off = 0;
            location[l]->siege.cameras_off = 0;
            location[l]->siege.kills = 0;
            location[l]->siege.tanks = 0;
            location[l]->siege.attacktime = 0;
            location[l]->compound_walls = 0;
            location[l]->compound_stores = 0;
            location[l]->front_business = -1;
            delete_and_clear(location[l]->loot);
         }
         cursite = house;
         location[house]->renting = rented ? 400 : RENTING_PERMANENT;
         location[house]->siege.siege = 1;
         location[house]->siege.siegetype = (attacker == 0) ? SIEGE_POLICE
                                      : (attacker == 1) ? SIEGE_CCS
                                                        : SIEGE_CORPORATE;
         location[house]->siege.escalationstate = attacker;
         location[house]->compound_walls = COMPOUND_BASIC | COMPOUND_GENERATOR;
         location[house]->compound_stores = 20;
         location[house]->front_business = 0;
         location[house]->loot.push_back(
            new Loot(*loottype[getloottype("LOOT_COMPUTER")]));

         squad.push_back(new squadst);
         squad.back()->id = cursquadid++;
         strcpy(squad.back()->name, "Defense");
         activesquad = squad.back();
         activesquad->loot.push_back(
            new Loot(*loottype[getloottype("LOOT_CELLPHONE")]));

         for (int n = 0; n < crowd; n++)
         {
            Creature *cr = new Creature;
            makecreature(*cr, CREATURE_POLITICALACTIVIST);
            cr->id = 920000 + n;
            cr->align = (n == 2) ? ALIGN_CONSERVATIVE : ALIGN_LIBERAL;
            if (n == 2) cr->flag |= CREATUREFLAG_MISSING;
            cr->location = house;
            cr->base = house;
            cr->hireid = n ? 920000 : -1;
            if (n == 3) cr->alive = false;
            if (n < 6)
            {
               activesquad->squad[n] = cr;
               cr->squadid = activesquad->id;
            }
            pool.push_back(cr);
         }

         fprintf(out, "{\"kind\":\"siege_outcome\",\"scenario\":%d,\"seed\":%lu,"
                      "\"won\":%d,\"attacker\":%d,\"rented\":%d,\"crowd\":%d,"
                      "\"heat\":%d,\"shelter\":%d,\"house\":%d,\"renting\":%d,"
                      "\"world_seed\":%lu",
                 scenario, seed_used, won, location[house]->siege.siegetype, rented,
                 crowd, heat, shelter, house, location[house]->renting, run_seed);
         fputs(",\"pool\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"missing\":%d,\"person\":", p ? "," : "",
                    (pool[p]->flag & CREATUREFLAG_MISSING) ? 1 : 0);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         long long before = lcs_trace_draw_count();
         escapesiege(won ? 1 : 0);

         fprintf(out, ",\"draws\":%lld,\"renting_after\":%d,\"compound\":%d,"
                      "\"stores\":%d,\"front\":%d,\"siege\":%d,\"located\":%d,"
                      "\"escalation\":%d,\"police_heat\":%d,\"loot\":%d,"
                      "\"shelter_loot\":%d",
                 lcs_trace_draw_count() - before, location[house]->renting,
                 location[house]->compound_walls, location[house]->compound_stores,
                 location[house]->front_business,
                 location[house]->siege.siege ? 1 : 0,
                 (int)location[house]->siege.timeuntillocated,
                 (int)location[house]->siege.escalationstate, police_heat,
                 len(location[house]->loot),
                 shelter == -1 ? 0 : len(location[shelter]->loot));
         fputs(",\"pool_after\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"hiding\":%d,\"person\":", p ? "," : "",
                    (int)pool[p]->hiding);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("]}\n", out);

         delete_and_clear(pool);
         delete_and_clear(squad);
         activesquad = NULL;
         delete_and_clear(location[house]->loot);
         if (shelter != -1) delete_and_clear(location[shelter]->loot);
      }
   }
}


// Giving up a besieged safehouse. Who is outside decides everything: the
// police and the fire brigade take prisoners and money and leave, and
// everybody else simply kills whoever is inside.
void probe_siege_surrender(FILE *out)
{
   static const int ATTACKERS[] = {
      SIEGE_POLICE, SIEGE_FIREMEN, SIEGE_CORPORATE, SIEGE_CCS, SIEGE_HICKS,
   };
   const int ATTACKER_COUNT = (int)(sizeof(ATTACKERS) / sizeof(ATTACKERS[0]));

   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 66129041UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = ENDGAME_NONE;
      mode = GAMEMODE_BASE;
      cursite = 1;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      int station = -1, warehouse = -1;
      for (int l = 0; l < len(location); l++)
      {
         if (station == -1 && location[l]->type == SITE_GOVERNMENT_POLICESTATION)
            station = l;
         if (warehouse == -1 && location[l]->type == SITE_INDUSTRY_WAREHOUSE)
            warehouse = l;
      }

      for (int attacker = 0; attacker < ATTACKER_COUNT; attacker++)
      for (int money = 0; money < 4; money++)
      for (int crowd = 1; crowd <= 4; crowd++)
      for (int walls = 0; walls < 3; walls++)
      {
         unsigned long seed_used = 1300021UL * (unsigned long)
            (attacker * 1024 + money * 128 + crowd * 8 + walls
             + scenario * 331 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         delete_and_clear(pool);
         delete_and_clear(newsstory);
         static const int PURSE[] = {0, 1500, 9000, 120000};
         ledger.force_funds(PURSE[money]);
         for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
         for (int l = 0; l < len(location); l++)
         {
            location[l]->siege = siegest();
            location[l]->siege.lights_off = 0;
            location[l]->siege.cameras_off = 0;
            location[l]->siege.kills = 0;
            location[l]->siege.tanks = 0;
            location[l]->siege.attacktime = 0;
            location[l]->compound_walls = 0;
            location[l]->compound_stores = 0;
            location[l]->front_business = -1;
            delete_and_clear(location[l]->loot);
         }
         // Half the samples give up a warehouse, so the Conservative Crime
         // Squad's capture of one is covered.
         int site = (walls == 2 && warehouse != -1) ? warehouse : 1;
         location[site]->renting = (money % 2) ? 400 : RENTING_PERMANENT;
         location[site]->siege.siege = 1;
         location[site]->siege.siegetype = ATTACKERS[attacker];
         location[site]->siege.escalationstate = walls;
         location[site]->front_business = walls ? 0 : -1;
         if (walls) location[site]->compound_walls |= COMPOUND_BASIC;
         if (walls) location[site]->compound_walls |= COMPOUND_PRINTINGPRESS;
         location[site]->loot.push_back(
            new Loot(*loottype[getloottype("LOOT_COMPUTER")]));
         selectedsiege = site;
         activesquad = NULL;

         for (int n = 0; n < crowd; n++)
         {
            Creature *cr = new Creature;
            makecreature(*cr, CREATURE_POLITICALACTIVIST);
            cr->id = 930000 + n;
            cr->align = ALIGN_LIBERAL;
            cr->location = site;
            cr->base = site;
            cr->hireid = n ? 930000 : -1;
            cr->juice = 20 * n;
            for (int f = 0; f < LAWFLAGNUM; f++)
               cr->crimes_suspected[f] = ((f + n) % 6 == 0) ? 1 : 0;
            if (n == 1) cr->flag |= CREATUREFLAG_ILLEGALALIEN;
            if (n == 3) cr->alive = false;
            pool.push_back(cr);
         }
         // A hostage taken off the airwaves, so the grudges are covered.
         if (crowd >= 2)
         {
            Creature *hostage = new Creature;
            makecreature(*hostage, CREATURE_RADIOPERSONALITY);
            hostage->id = 931000;
            hostage->align = ALIGN_CONSERVATIVE;
            hostage->location = site;
            hostage->base = site;
            hostage->flag |= CREATUREFLAG_MISSING;
            pool.push_back(hostage);
         }
         offended_amradio = 0;
         offended_cablenews = 0;
         offended_firemen = 1;

         fprintf(out, "{\"kind\":\"surrender\",\"scenario\":%d,\"seed\":%lu,"
                      "\"attacker\":%d,\"money\":%d,\"crowd\":%d,\"walls\":%d,"
                      "\"site\":%d,\"station\":%d,\"funds\":%d,\"renting\":%d,"
                      "\"compound\":%d,\"world_seed\":%lu",
                 scenario, seed_used, ATTACKERS[attacker], money, crowd, walls,
                 site, station, ledger.get_funds(), location[site]->renting,
                 location[site]->compound_walls, run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"pool\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"missing\":%d,\"alien\":%d,\"crimes\":[",
                    p ? "," : "",
                    (pool[p]->flag & CREATUREFLAG_MISSING) ? 1 : 0,
                    (pool[p]->flag & CREATUREFLAG_ILLEGALALIEN) ? 1 : 0);
            for (int f = 0; f < LAWFLAGNUM; f++)
               fprintf(out, "%s%d", f ? "," : "",
                       (int)pool[p]->crimes_suspected[f]);
            fputs("],\"person\":", out);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         long long before = lcs_trace_draw_count();
         giveup_block();

         fprintf(out, ",\"draws\":%lld,\"funds_after\":%d,\"renting_after\":%d,"
                      "\"compound_after\":%d,\"front_after\":%d,\"siege\":%d,"
                      "\"loot\":%d,\"amradio\":%d,\"cablenews\":%d,"
                      "\"firemen\":%d,\"stories\":%d",
                 lcs_trace_draw_count() - before, ledger.get_funds(),
                 location[site]->renting, location[site]->compound_walls,
                 location[site]->front_business,
                 location[site]->siege.siege ? 1 : 0,
                 len(location[site]->loot), offended_amradio ? 1 : 0,
                 offended_cablenews ? 1 : 0, offended_firemen ? 1 : 0,
                 len(newsstory));
         fputs(",\"pool_after\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"crimes\":[", p ? "," : "");
            for (int f = 0; f < LAWFLAGNUM; f++)
               fprintf(out, "%s%d", f ? "," : "",
                       (int)pool[p]->crimes_suspected[f]);
            fputs("],\"person\":", out);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("]}\n", out);

         delete_and_clear(pool);
         delete_and_clear(location[site]->loot);
         selectedsiege = -1;
      }
   }
}


// A day of being under siege: eating the stores, starving without them, the
// power going, snipers, helicopters, and the reporter who occasionally gets in.
void probe_siege_turn(FILE *out)
{
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 51823607UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = ENDGAME_NONE;
      mode = GAMEMODE_BASE;
      cursite = 1;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      for (int walls = 0; walls < 8; walls++)
      for (int escalation = 0; escalation < 4; escalation++)
      for (int stores = 0; stores < 3; stores++)
      for (int crowd = 0; crowd <= 3; crowd++)
      {
         unsigned long seed_used = 1200013UL * (unsigned long)
            (walls * 512 + escalation * 64 + stores * 8 + crowd
             + scenario * 307 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         delete_and_clear(pool);
         for (int v = 0; v < VIEWNUM; v++)
         {
            attitude[v] = (v * 7 + scenario * 13) % 101;
            public_interest[v] = (v * 3 + scenario * 5) % 40;
            background_liberal_influence[v] = 0;
         }
         for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
         for (int l = 0; l < len(location); l++)
         {
            location[l]->siege = siegest();
            // siegest()'s constructor leaves these uninitialised, and a
            // garbage lights_off silently skips the blackout roll.
            location[l]->siege.lights_off = 0;
            location[l]->siege.cameras_off = 0;
            location[l]->siege.kills = 0;
            location[l]->siege.tanks = 0;
            location[l]->siege.attacktime = 0;
            location[l]->compound_walls = 0;
            location[l]->compound_stores = 0;
            delete_and_clear(location[l]->loot);
         }
         location[1]->renting = RENTING_PERMANENT;
         location[1]->siege.siege = 1;
         location[1]->siege.siegetype = SIEGE_POLICE;
         location[1]->siege.underattack = 0;
         location[1]->siege.escalationstate = escalation;
         location[1]->compound_stores = stores * 3;
         // Every combination of the four things a compound can have that the
         // day's rules read.
         if (walls & 1) location[1]->compound_walls |= COMPOUND_BASIC;
         if (walls & 2) location[1]->compound_walls |= COMPOUND_GENERATOR;
         if (walls & 4) location[1]->compound_walls |= COMPOUND_AAGUN;
         if (escalation == 3) location[1]->compound_walls |= COMPOUND_TANKTRAPS;
         location[1]->loot.push_back(
            new Loot(*loottype[getloottype("LOOT_COMPUTER")]));

         for (int n = 0; n < crowd; n++)
         {
            Creature *cr = new Creature;
            makecreature(*cr, CREATURE_POLITICALACTIVIST);
            cr->id = 940000 + n;
            cr->align = ALIGN_LIBERAL;
            cr->location = 1;
            cr->base = 1;
            cr->hireid = n ? 940000 : -1;
            cr->juice = 10 + n * 40;
            cr->blood = 30 + n * 20;
            cr->set_skill(SKILL_PERSUASION, 2 + n * 3);
            pool.push_back(cr);
         }

         fprintf(out, "{\"kind\":\"siege_turn\",\"scenario\":%d,\"seed\":%lu,"
                      "\"walls\":%d,\"escalation\":%d,\"stores\":%d,"
                      "\"crowd\":%d,\"compound\":%d,\"world_seed\":%lu",
                 scenario, seed_used, walls, escalation, stores, crowd,
                 location[1]->compound_walls, run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("],\"pool\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s", p ? "," : "");
            chase_write_creature(out, *pool[p], true);
         }
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         char clearformess = 0;
         long long before = lcs_trace_draw_count();
         siegeturn(clearformess);

         fprintf(out, ",\"draws\":%lld,\"stores_after\":%d,\"walls_after\":%d,"
                      "\"siege\":%d,\"underattack\":%d,\"lights\":%d,"
                      "\"renting\":%d,\"loot\":%d",
                 lcs_trace_draw_count() - before, location[1]->compound_stores,
                 location[1]->compound_walls, location[1]->siege.siege ? 1 : 0,
                 location[1]->siege.underattack ? 1 : 0,
                 location[1]->siege.lights_off ? 1 : 0,
                 location[1]->renting, len(location[1]->loot));
         fputs(",\"attitude_after\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"pool_after\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s", p ? "," : "");
            chase_write_creature(out, *pool[p], true);
         }
         fputs("]}\n", out);

         delete_and_clear(pool);
         delete_and_clear(location[1]->loot);
      }
   }
}


// The nightly siege watch: how close the police are to each safehouse, and
// whether anybody else has decided to pay a visit.
void probe_siege_watch(FILE *out)
{
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 39187457UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      mode = GAMEMODE_BASE;
      cursite = 1;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      for (int endgame = 0; endgame < 3; endgame++)
      for (int heat = 0; heat < 5; heat++)
      for (int crowd = 0; crowd <= 3; crowd++)
      for (int counted = 0; counted < 4; counted++)
      {
         unsigned long seed_used = 1100019UL * (unsigned long)
            (endgame * 512 + heat * 64 + crowd * 8 + counted
             + scenario * 277 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         delete_and_clear(pool);
         endgamestate = (endgame == 0) ? ENDGAME_NONE
                      : (endgame == 1) ? ENDGAME_CCS_APPEARANCE
                                       : ENDGAME_CCS_SIEGES;
         for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
         offended_corps = (counted % 2) ? 1 : 0;
         offended_firemen = 1;

         // Every safehouse starts quiet except the one being watched.
         for (int l = 0; l < len(location); l++)
         {
            location[l]->siege = siegest();
            location[l]->heat = 0;
            location[l]->compound_walls = 0;
            location[l]->front_business = -1;
            location[l]->haveflag = false;
            delete_and_clear(location[l]->loot);
         }
         location[1]->renting = RENTING_PERMANENT;
         location[1]->heat = heat * 60;
         location[1]->haveflag = (counted % 3 == 1);
         location[1]->front_business = (counted % 3 == 2) ? 0 : -1;
         if (counted >= 2)
            location[1]->compound_walls |= COMPOUND_PRINTINGPRESS;
         location[1]->siege.timeuntillocated = (counted == 3) ? 1 : -1;

         for (int n = 0; n < crowd; n++)
         {
            Creature *cr = new Creature;
            makecreature(*cr, CREATURE_POLITICALACTIVIST);
            cr->id = 960000 + n;
            cr->align = ALIGN_LIBERAL;
            cr->location = 1;
            cr->base = 1;
            cr->hireid = n ? 960000 : -1;
            cr->heat = 20 * n + heat * 10;
            cr->joindays = 5;
            cr->activity.type = (n % 2) ? ACTIVITY_NONE : ACTIVITY_DONATIONS;
            if (n == 2) cr->alive = false;
            for (int f = 0; f < LAWFLAGNUM; f++)
               cr->crimes_suspected[f] = ((f + n) % 5 == 0) ? 2 : 0;
            pool.push_back(cr);
         }
         // A sleeper at the police station, so the warning path is reached.
         if (counted == 3)
         {
            Creature *spy = new Creature;
            makecreature(*spy, CREATURE_COP);
            spy->id = 961000;
            spy->align = ALIGN_LIBERAL;
            int station = find_police_station(1);
            spy->location = station;
            spy->base = station;
            spy->hireid = 960000;
            spy->flag |= CREATUREFLAG_SLEEPER;
            pool.push_back(spy);
         }

         fprintf(out, "{\"kind\":\"siege_watch\",\"scenario\":%d,\"seed\":%lu,"
                      "\"endgame\":%d,\"heat\":%d,\"crowd\":%d,\"counted\":%d,"
                      "\"corps\":%d,\"world_seed\":%lu",
                 scenario, seed_used, endgame, heat, crowd, counted,
                 offended_corps ? 1 : 0, run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"site\":{", out);
         fprintf(out, "\"heat\":%d,\"walls\":%d,\"front\":%d,\"flag\":%d,"
                      "\"located\":%d}",
                 location[1]->heat, location[1]->compound_walls,
                 location[1]->front_business, location[1]->haveflag ? 1 : 0,
                 (int)location[1]->siege.timeuntillocated);
         fputs(",\"pool\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"sleeper\":%d,\"heat\":%d,\"activity\":%d,"
                         "\"joindays\":%d,\"crimes\":[",
                    p ? "," : "", (pool[p]->flag & CREATUREFLAG_SLEEPER) ? 1 : 0,
                    (int)pool[p]->heat, pool[p]->activity.type,
                    (int)pool[p]->joindays);
            for (int f = 0; f < LAWFLAGNUM; f++)
               fprintf(out, "%s%d", f ? "," : "",
                       (int)pool[p]->crimes_suspected[f]);
            fputs("],\"person\":", out);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         long long before = lcs_trace_draw_count();
         siegecheck(1);

         fprintf(out, ",\"draws\":%lld,\"pool_size\":%d",
                 lcs_trace_draw_count() - before, len(pool));
         fputs(",\"sites_after\":[", out);
         for (int l = 0; l < len(location); l++)
            fprintf(out, "%s{\"loc\":%d,\"heat\":%d,\"protection\":%d,"
                         "\"siege\":%d,\"type\":%d,\"located\":%d,"
                         "\"corps\":%d,\"ccs\":%d,\"loot\":%d}",
                    l ? "," : "", l, location[l]->heat,
                    location[l]->heat_protection,
                    location[l]->siege.siege ? 1 : 0,
                    (int)location[l]->siege.siegetype,
                    (int)location[l]->siege.timeuntillocated,
                    (int)location[l]->siege.timeuntilcorps,
                    (int)location[l]->siege.timeuntilccs,
                    len(location[l]->loot));
         fputs("],\"pool_after\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"heat\":%d,\"alien\":%d,\"crimes\":[",
                    p ? "," : "", (int)pool[p]->heat,
                    (pool[p]->flag & CREATUREFLAG_ILLEGALALIEN) ? 1 : 0);
            for (int f = 0; f < LAWFLAGNUM; f++)
               fprintf(out, "%s%d", f ? "," : "",
                       (int)pool[p]->crimes_suspected[f]);
            fputs("],\"person\":", out);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("]}\n", out);

         delete_and_clear(pool);
      }
   }
}


// The justice system: a month in the cells, a trial, sentencing, and a month
// inside. Driven one stage at a time, because the original's own loop over the
// pool interleaves them and a divergence would name the month rather than the
// stage.
void probe_justice(FILE *out)
{
   // 0 police station, 1 courthouse, 2 prison.
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 27718493UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = ENDGAME_NONE;
      mode = GAMEMODE_BASE;
      cursite = 1;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      int station = -1, courthouse = -1, jail = -1, shelter = -1;
      for (int l = 0; l < len(location); l++)
      {
         if (station == -1 && location[l]->type == SITE_GOVERNMENT_POLICESTATION)
            station = l;
         if (courthouse == -1 && location[l]->type == SITE_GOVERNMENT_COURTHOUSE)
            courthouse = l;
         if (jail == -1 && location[l]->type == SITE_GOVERNMENT_PRISON)
            jail = l;
         if (shelter == -1 && location[l]->type == SITE_RESIDENTIAL_SHELTER)
            shelter = l;
      }

      // Stage 3 runs sentencing on its own: a trial that diverges is far
      // easier to read once the sentence it hands down is known to be right.
      for (int stage = 0; stage < 4; stage++)
      for (int record = 0; record < 6; record++)
      for (int severity = 0; severity < 4; severity++)
      for (int defense = 0; defense < 5; defense++)
      {
         if (stage != 1 && stage != 3 && defense) continue;  // only these vary
         if (stage == 3 && defense > 1) continue;   // lenient, or not
         // The sleeper attorney is only on the menu when one is in the city,
         // and the prompt loops forever on a key it does not recognise.
         if (defense == 4 && record % 2 == 0) continue;
         unsigned long seed_used = 9900017UL * (unsigned long)
            (stage * 2048 + record * 128 + severity * 8 + defense
             + scenario * 251 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         delete_and_clear(pool);
         ledger.force_funds(20000);
         for (int v = 0; v < VIEWNUM; v++)
         {
            attitude[v] = (v * 17 + scenario * 29 + severity * 11) % 101;
            public_interest[v] = (v * 3 + scenario * 5) % 40;
         }
         for (int l = 0; l < LAWNUM; l++)
            law[l] = ((l + scenario + severity) % 5) - 2;

         // The defendant, and a boss for them to name.
         Creature *boss = new Creature;
         makecreature(*boss, CREATURE_POLITICALACTIVIST);
         boss->id = 980000;
         boss->align = ALIGN_LIBERAL;
         boss->location = 1;
         boss->base = 1;
         boss->hireid = -1;
         boss->juice = 120;
         pool.push_back(boss);

         Creature *cr = new Creature;
         makecreature(*cr, CREATURE_POLITICALACTIVIST);
         cr->id = 980001;
         cr->align = ALIGN_LIBERAL;
         cr->location = (stage == 0) ? station
                      : (stage == 1 || stage == 3) ? courthouse : jail;
         cr->base = 1;
         cr->hireid = (record % 3 == 2) ? -1 : 980000;
         cr->juice = 40 + record * 140;
         cr->heat = 10 + record * 30;
         cr->confessions = record % 3;
         cr->sentence = (stage == 2) ? (1 + record % 5)
                      : ((record % 4 == 3) ? -1 : 0);
         cr->deathpenalty = (stage == 2 && record % 5 == 4) ? 1 : 0;
         if (record % 4 == 1) cr->flag |= CREATUREFLAG_MISSING;
         if (record % 4 == 2) cr->flag |= CREATUREFLAG_ILLEGALALIEN;
         cr->set_skill(SKILL_PERSUASION, 3 + severity * 2);
         cr->set_skill(SKILL_LAW, severity * 3);
         cr->set_skill(SKILL_COMPUTERS, severity * 3);
         cr->set_skill(SKILL_DISGUISE, severity * 3);
         cr->set_skill(SKILL_SECURITY, severity * 3);
         cr->set_skill(SKILL_STEALTH, severity * 3);
         cr->set_skill(SKILL_SCIENCE, severity * 3);
         cr->set_skill(SKILL_HANDTOHAND, severity * 3);
         cr->set_skill(SKILL_PSYCHOLOGY, severity);
         // A charge sheet that grows with severity, so sentencing sees every
         // rule it has.
         for (int f = 0; f < LAWFLAGNUM; f++)
            cr->crimes_suspected[f] = ((f + severity) % (4 - severity + 1) == 0)
                                    ? (1 + (f + severity) % 3) : 0;
         pool.push_back(cr);

         // A sleeper judge and a sleeper lawyer, sometimes.
         if (record % 2)
         {
            Creature *sj = new Creature;
            makecreature(*sj, CREATURE_JUDGE_CONSERVATIVE);
            sj->id = 980002;
            sj->align = ALIGN_LIBERAL;
            sj->location = courthouse;
            sj->base = courthouse;
            sj->hireid = 980000;
            sj->flag |= CREATUREFLAG_SLEEPER;
            sj->infiltration = 0.2f + severity * 0.25f;
            pool.push_back(sj);

            Creature *sl = new Creature;
            makecreature(*sl, CREATURE_LAWYER);
            sl->id = 980003;
            sl->align = ALIGN_LIBERAL;
            sl->location = courthouse;
            sl->base = courthouse;
            sl->hireid = 980000;
            sl->flag |= CREATUREFLAG_SLEEPER;
            sl->set_skill(SKILL_LAW, 5 + severity * 3);
            sl->set_skill(SKILL_PERSUASION, 4 + severity * 2);
            pool.push_back(sl);
         }

         fprintf(out, "{\"kind\":\"justice\",\"scenario\":%d,\"seed\":%lu,"
                      "\"stage\":%d,\"record\":%d,\"severity\":%d,"
                      "\"defense\":%d,\"station\":%d,\"courthouse\":%d,"
                      "\"jail\":%d,\"shelter\":%d,\"world_seed\":%lu",
                 scenario, seed_used, stage, record, severity, defense,
                 station, courthouse, jail, shelter, run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("],\"pool\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"sleeper\":%d,\"missing\":%d,\"alien\":%d,"
                         "\"sentence\":%d,\"death\":%d,\"confessions\":%d,"
                         "\"heat\":%d,\"infiltration\":%.9g,\"crimes\":[",
                    p ? "," : "", (pool[p]->flag & CREATUREFLAG_SLEEPER) ? 1 : 0,
                    (pool[p]->flag & CREATUREFLAG_MISSING) ? 1 : 0,
                    (pool[p]->flag & CREATUREFLAG_ILLEGALALIEN) ? 1 : 0,
                    (int)pool[p]->sentence, (int)pool[p]->deathpenalty,
                    (int)pool[p]->confessions, (int)pool[p]->heat,
                    (double)pool[p]->infiltration);
            for (int f = 0; f < LAWFLAGNUM; f++)
               fprintf(out, "%s%d", f ? "," : "",
                       (int)pool[p]->crimes_suspected[f]);
            fputs("],\"person\":", out);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         // The trial asks how the defense is conducted; the script answers.
         static const char DEFENSE_KEYS[] = { 'a', 'b', 'c', 'd', 'e' };
         // A trial asks a great many "press any key" questions before it asks
         // the one that matters, and the prompt that matters is a loop that
         // ignores anything it does not recognise. Queuing the answer many
         // times over gets it through both.
         lcs_trace_clear_keys();
         if (stage == 1)
            for (int k = 0; k < 400; k++)
               lcs_trace_push_key(DEFENSE_KEYS[defense]);

         char clearformess = 0;
         long long before = lcs_trace_draw_count();
         if (stage == 3) penalize(*cr, defense ? 1 : 0);
         else justice_stage(*cr, clearformess);

         // The attorney's name is drawn from a side stream the port keeps
         // separate, so those draws come off the main count.
         long long side = lcs_trace_side_draws();
         int t_jury = 0, t_pros = 0, t_def = 0, t_len = 0;
         lcs_trace_trial_read(&t_jury, &t_pros, &t_def, &t_len);
         int t_scare = 0, t_types = 0, t_conf = 0;
         lcs_trace_trial_charges_read(&t_scare, &t_types, &t_conf);
         fprintf(out, ",\"scare\":%d,\"charges\":%d,\"testimony\":%d",
                 t_scare, t_types, t_conf);
         fprintf(out, ",\"jury\":%d,\"prosecution\":%d,\"defensepower\":%d,"
                      "\"lenient\":%d", t_jury, t_pros, t_def, t_len);
         fprintf(out, ",\"draws\":%lld,\"side\":%lld,\"funds\":%d,"
                      "\"pool_size\":%d",
                 lcs_trace_draw_count() - before - side, side,
                 ledger.get_funds(), len(pool));
         fputs(",\"pool_after\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"sentence\":%d,\"death\":%d,\"confessions\":%d,"
                         "\"heat\":%d,\"crimes\":[",
                    p ? "," : "", (int)pool[p]->sentence,
                    (int)pool[p]->deathpenalty, (int)pool[p]->confessions,
                    (int)pool[p]->heat);
            for (int f = 0; f < LAWFLAGNUM; f++)
               fprintf(out, "%s%d", f ? "," : "",
                       (int)pool[p]->crimes_suspected[f]);
            fputs("],\"person\":", out);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("]}\n", out);

         delete_and_clear(pool);
      }
   }
}


// A month for the people the squad has left in place: influencing the room,
// snooping through filing cabinets, skimming the accounts, taking things home
// and quietly recruiting the next one.
void probe_sleepers(FILE *out)
{
   // Enough professions to reach every block of the influence table, both
   // broadcasters, the politician who picks three issues at random, the
   // firefighter with an opinion only under censorship, and the ones with
   // nothing to offer at all.
   static const int WHO[] = {
      CREATURE_CORPORATE_CEO, CREATURE_POLITICIAN, CREATURE_SCIENTIST_EMINENT,
      CREATURE_RADIOPERSONALITY, CREATURE_NEWSANCHOR, CREATURE_FIREFIGHTER,
      CREATURE_JUDGE_CONSERVATIVE, CREATURE_LAWYER, CREATURE_COP,
      CREATURE_DEATHSQUAD, CREATURE_AGENT, CREATURE_PRISONGUARD,
      CREATURE_SOLDIER, CREATURE_WORKER_SWEATSHOP, CREATURE_PRIEST,
      CREATURE_NUN, CREATURE_HIPPIE, CREATURE_BANK_MANAGER,
      CREATURE_CORPORATE_MANAGER, CREATURE_SCIENTIST_LABTECH,
      CREATURE_SECRET_SERVICE, CREATURE_MERC,
   };
   const int WHO_COUNT = (int)(sizeof(WHO) / sizeof(WHO[0]));

   static const int JOBS[] = {
      ACTIVITY_SLEEPER_LIBERAL, ACTIVITY_SLEEPER_SPY,
      ACTIVITY_SLEEPER_EMBEZZLE, ACTIVITY_SLEEPER_STEAL,
      ACTIVITY_SLEEPER_SCANDAL, ACTIVITY_SLEEPER_RECRUIT,
   };
   const int JOB_COUNT = (int)(sizeof(JOBS) / sizeof(JOBS[0]));

   for (int scenario = 0; scenario < 2; scenario++)
   {
      unsigned long run_seed = 44017231UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = ENDGAME_NONE;
      mode = GAMEMODE_BASE;
      cursite = 1;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      int shelter = -1;
      for (int l = 0; l < len(location); l++)
         if (shelter == -1 && location[l]->type == SITE_RESIDENTIAL_SHELTER)
            shelter = l;

      for (int job = 0; job < JOB_COUNT; job++)
      for (int who = 0; who < WHO_COUNT; who++)
      for (int depth = 0; depth < 3; depth++)
      {
         unsigned long seed_used = 8800021UL * (unsigned long)
            (job * 1024 + who * 8 + depth + scenario * 211 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         delete_and_clear(pool);
         delete_and_clear(location[shelter]->loot);
         ledger.force_funds(1000);
         for (int v = 0; v < VIEWNUM; v++)
         {
            attitude[v] = (v * 9 + scenario * 23) % 101;
            public_interest[v] = (v * 5 + scenario * 7) % 40;
            background_liberal_influence[v] = 0;
         }
         for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario + depth) % 5) - 2;
         ccsexposure = CCSEXPOSURE_NONE;

         // Where a thief works decides what they bring home, so the sleeper
         // is put somewhere different each time round.
         static const int WORKPLACES[] = {
            SITE_GOVERNMENT_POLICESTATION, SITE_CORPORATE_HOUSE,
            SITE_RESIDENTIAL_APARTMENT_UPSCALE,
         };
         int workplace = 1;
         for (int l = 0; l < len(location); l++)
            if (location[l]->type == WORKPLACES[depth]) { workplace = l; break; }

         Creature *cr = new Creature;
         makecreature(*cr, WHO[who]);
         cr->id = 990000;
         cr->align = ALIGN_LIBERAL;
         cr->location = workplace;
         cr->base = workplace;
         cr->worklocation = workplace;
         cr->hireid = -1;
         cr->juice = depth == 0 ? -2 : 40;
         cr->infiltration = 0.15f + depth * 0.4f;
         cr->flag |= CREATUREFLAG_SLEEPER;
         cr->activity.type = JOBS[job];
         pool.push_back(cr);

         fprintf(out, "{\"kind\":\"sleeper\",\"scenario\":%d,\"seed\":%lu,"
                      "\"job\":%d,\"who\":%d,\"depth\":%d,\"workplace\":%d,"
                      "\"shelter\":%d,\"activity\":%d,\"infiltration\":%.9g,"
                      "\"world_seed\":%lu",
                 scenario, seed_used, job, who, depth, workplace, shelter,
                 cr->activity.type, (double)cr->infiltration, run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("],\"person\":", out);
         chase_write_creature(out, *cr, true);
         fputs(",\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         char clearformess = 0;
         int libpower[VIEWNUM] = {0};
         long long before = lcs_trace_draw_count();
         sleepereffect(*cr, clearformess, 1, libpower);

         fprintf(out, ",\"draws\":%lld,\"funds\":%d,\"exposure\":%d,"
                      "\"infiltration_after\":%.9g,\"sleeper_after\":%d,"
                      "\"activity_after\":%d,\"pool_size\":%d",
                 lcs_trace_draw_count() - before, ledger.get_funds(),
                 ccsexposure, (double)cr->infiltration,
                 (cr->flag & CREATUREFLAG_SLEEPER) ? 1 : 0,
                 cr->activity.type, len(pool));
         fputs(",\"libpower\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", libpower[i]);
         fputs("],\"attitude_after\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"stash\":[", out);
         for (int i = 0; i < len(location[shelter]->loot); i++)
            fprintf(out, "%s\"%s\"", i ? "," : "",
                    location[shelter]->loot[i]->get_itemtypename().c_str());
         fputs("],\"person_after\":", out);
         chase_write_creature(out, *cr, true);
         fputs(",\"encounters\":[", out);
         for (int e = 0; e < ENCMAX; e++)
         {
            if (!encounter[e].exists) break;
            fprintf(out, "%s\"%s\"", e ? "," : "",
                    getcreaturetype(encounter[e].type)->get_idname().c_str());
         }
         fputs("],\"recruits\":[", out);
         for (int p = 1; p < len(pool); p++)
         {
            fprintf(out, "%s{\"align\":%d,\"sleeper\":%d,\"work\":%d,"
                         "\"infiltration\":%.9g,\"person\":",
                    p > 1 ? "," : "", pool[p]->align,
                    (pool[p]->flag & CREATUREFLAG_SLEEPER) ? 1 : 0,
                    pool[p]->worklocation, (double)pool[p]->infiltration);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("]}\n", out);

         delete_and_clear(pool);
         delete_and_clear(location[shelter]->loot);
      }
   }
}


// A month of tags on walls and opinion drifting on its own.
void probe_monthly_drift(FILE *out)
{
   static const int TAGS[] = {
      SITEBLOCK_GRAFFITI, SITEBLOCK_GRAFFITI_CCS, SITEBLOCK_GRAFFITI_OTHER,
   };

   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 83719913UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      mode = GAMEMODE_BASE;
      cursite = 1;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      for (int endgame = 0; endgame < 3; endgame++)
      for (int tagged = 0; tagged < 3; tagged++)
      for (int slaves = 0; slaves < 3; slaves++)
      {
         unsigned long seed_used = 7700019UL * (unsigned long)
            (endgame * 64 + tagged * 8 + slaves + scenario * 173 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         delete_and_clear(pool);
         endgamestate = (endgame == 0) ? ENDGAME_NONE
                      : (endgame == 1) ? ENDGAME_CCS_APPEARANCE
                                       : ENDGAME_CCS_DEFEATED;
         for (int l = 0; l < len(location); l++)
         {
            location[l]->changes.clear();
            // Tags on the first several sites of every kind, so the secure,
            // the squad's own, the enemy's and the ownerless are all covered.
            if (l % (tagged + 2) == 0)
               for (int t = 0; t <= tagged; t++)
               {
                  sitechangest change;
                  change.x = t; change.y = l % 5; change.z = 0;
                  change.flag = TAGS[(l + t) % 3];
                  location[l]->changes.push_back(change);
               }
         }
         location[1]->renting = RENTING_PERMANENT;
         if (len(location) > 3) location[3]->renting = RENTING_CCS;

         for (int v = 0; v < VIEWNUM; v++)
         {
            attitude[v] = (v * 13 + scenario * 19) % 101;
            public_interest[v] = (v * 7 + scenario * 11) % 40;
            background_liberal_influence[v] = (v * 3 - 20 + scenario * 4);
         }

         for (int n = 0; n < 3; n++)
         {
            Creature *cr = new Creature;
            cr->id = 970000 + n;
            cr->align = ALIGN_LIBERAL;
            cr->location = 1;
            cr->base = 1;
            cr->hireid = n ? 970000 : -1;
            if (slaves && n) cr->flag |= CREATUREFLAG_LOVESLAVE;
            if (slaves == 2 && n == 2) cr->alive = false;
            cr->set_skill(SKILL_SEDUCTION, n);
            pool.push_back(cr);
         }

         fprintf(out, "{\"kind\":\"drift\",\"scenario\":%d,\"seed\":%lu,"
                      "\"endgame\":%d,\"tagged\":%d,\"slaves\":%d,"
                      "\"world_seed\":%lu",
                 scenario, seed_used, endgame, tagged, slaves, run_seed);
         fputs(",\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("],\"influence\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", background_liberal_influence[i]);
         fputs("],\"renting\":[", out);
         for (int l = 0; l < len(location); l++)
            fprintf(out, "%s%d", l ? "," : "", location[l]->renting);
         fputs("],\"tags\":[", out);
         {
            bool first = true;
            for (int l = 0; l < len(location); l++)
               for (int c = 0; c < len(location[l]->changes); c++)
               {
                  fprintf(out, "%s{\"loc\":%d,\"x\":%d,\"y\":%d,\"z\":%d,"
                               "\"flag\":%d}",
                          first ? "" : ",", l, location[l]->changes[c].x,
                          location[l]->changes[c].y, location[l]->changes[c].z,
                          location[l]->changes[c].flag);
                  first = false;
               }
         }
         fputs("],\"pool\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"loveslave\":%d,\"person\":", p ? "," : "",
                    (pool[p]->flag & CREATUREFLAG_LOVESLAVE) ? 1 : 0);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         int libpower[VIEWNUM] = {0};
         long long before = lcs_trace_draw_count();
         monthly_drift_block(libpower);

         fprintf(out, ",\"draws\":%lld", lcs_trace_draw_count() - before);
         fputs(",\"attitude_after\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"influence_after\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", background_liberal_influence[i]);
         fputs("],\"tags_after\":[", out);
         {
            bool first = true;
            for (int l = 0; l < len(location); l++)
               for (int c = 0; c < len(location[l]->changes); c++)
               {
                  fprintf(out, "%s{\"loc\":%d,\"x\":%d,\"y\":%d,\"z\":%d,"
                               "\"flag\":%d}",
                          first ? "" : ",", l, location[l]->changes[c].x,
                          location[l]->changes[c].y, location[l]->changes[c].z,
                          location[l]->changes[c].flag);
                  first = false;
               }
         }
         fputs("],\"pool_after\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"person\":", p ? "," : "");
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("]}\n", out);

         delete_and_clear(pool);
      }
   }
}


// A transcription of the "AGE THINGS" pass of advanceday() and the "HEAL
// CLINIC PEOPLE" pass of passmonth(), both of which are inline in functions
// that do far more than the probe wants to measure.
static void ageing_block(char &clearformess)
{
   int pday=day,pmonth=month;
   if(pday>monthday()) pday=1,pmonth=(pmonth%12)+1;

   for(int p=0;p<len(pool);p++)
   {
      pool[p]->stunned=0;
      pool[p]->joindays++;
      if(!pool[p]->alive) { pool[p]->deathdays++; continue; }
      if(!pool[p]->animalgloss)
      {
         if(pool[p]->age>60)
         {
            int decrement=0;
            while(pool[p]->age-decrement>60)
            {
               if(LCSrandom(365*10)==0)
               {
                  pool[p]->adjust_attribute(ATTRIBUTE_HEALTH,-1);
                  if(pool[p]->get_attribute(ATTRIBUTE_HEALTH,false)<=0 &&
                     pool[p]->get_attribute(ATTRIBUTE_HEALTH,true)<=1)
                  {
                     pool[p]->die();
                     break;
                  }
               }
               decrement+=10;
            }
            if(!pool[p]->alive)continue;
         }
         if(pmonth==pool[p]->birthday_month&&pday==pool[p]->birthday_day)
         {
            pool[p]->age++;
            switch(pool[p]->age)
            {
            case 13:
               pool[p]->type=CREATURE_TEENAGER;
               pool[p]->type_idname="CREATURE_TEENAGER";
               break;
            case 18:
               pool[p]->type=CREATURE_POLITICALACTIVIST;
               pool[p]->type_idname="CREATURE_POLITICALACTIVIST";
               break;
            }
         }
      }
      if(pool[p]->blood<100) pool[p]->blood++;
      if(pool[p]->hiding>0)
      {
         if((--pool[p]->hiding)==0)
         {
            if(location[pool[p]->base]->siege.siege) pool[p]->hiding=1;
            else pool[p]->location=pool[p]->base;
         }
      }
      if((pool[p]->flag&CREATUREFLAG_MISSING)&&!(pool[p]->flag&CREATUREFLAG_KIDNAPPED))
      {
         if(LCSrandom(14)+5<pool[p]->joindays)
         {
            pool[p]->flag|=CREATUREFLAG_KIDNAPPED;
            newsstoryst *ns=new newsstoryst;
            ns->type=NEWSSTORY_KIDNAPREPORT;
            ns->loc=pool[p]->location;
            ns->cr=pool[p];
            newsstory.push_back(ns);
         }
      }
      pool[p]->skill_up();
   }
}

static void clinic_block(char &clearformess)
{
   for(int p=0;p<len(pool);p++)
   {
      if(!(pool[p]->alive)) continue;
      if(pool[p]->clinic>0)
      {
         pool[p]->clinic--;
         for(int w=0;w<BODYPARTNUM;w++)
         {
            if((pool[p]->wound[w]&WOUND_NASTYOFF)||(pool[p]->wound[w]&WOUND_CLEANOFF))
               pool[p]->wound[w]=(char)WOUND_CLEANOFF;
            else pool[p]->wound[w]=0;
         }
         int healthdamage = 0;
         if(pool[p]->special[SPECIALWOUND_RIGHTLUNG]!=1)
         {
            pool[p]->special[SPECIALWOUND_RIGHTLUNG]=1;
            if(LCSrandom(2)) healthdamage++;
         }
         if(pool[p]->special[SPECIALWOUND_LEFTLUNG]!=1)
         {
            pool[p]->special[SPECIALWOUND_LEFTLUNG]=1;
            if(LCSrandom(2)) healthdamage++;
         }
         if(pool[p]->special[SPECIALWOUND_HEART]!=1)
         {
            pool[p]->special[SPECIALWOUND_HEART]=1;
            if(LCSrandom(3)) healthdamage++;
         }
         pool[p]->special[SPECIALWOUND_LIVER]=1;
         pool[p]->special[SPECIALWOUND_STOMACH]=1;
         pool[p]->special[SPECIALWOUND_RIGHTKIDNEY]=1;
         pool[p]->special[SPECIALWOUND_LEFTKIDNEY]=1;
         pool[p]->special[SPECIALWOUND_SPLEEN]=1;
         pool[p]->special[SPECIALWOUND_RIBS]=RIBNUM;
         if(!pool[p]->special[SPECIALWOUND_NECK])
            pool[p]->special[SPECIALWOUND_NECK]=2;
         if(!pool[p]->special[SPECIALWOUND_UPPERSPINE])
            pool[p]->special[SPECIALWOUND_UPPERSPINE]=2;
         if(!pool[p]->special[SPECIALWOUND_LOWERSPINE])
            pool[p]->special[SPECIALWOUND_LOWERSPINE]=2;
         pool[p]->set_attribute(ATTRIBUTE_HEALTH,pool[p]->get_attribute(ATTRIBUTE_HEALTH,0)-healthdamage);
         if(pool[p]->get_attribute(ATTRIBUTE_HEALTH,0)<=0)
            pool[p]->set_attribute(ATTRIBUTE_HEALTH,1);
         if(pool[p]->blood<=20&&pool[p]->clinic<=2)pool[p]->blood=50;
         if(pool[p]->blood<=50&&pool[p]->clinic<=1)pool[p]->blood=75;
         if(pool[p]->clinic > 2 && pool[p]->location > -1 &&
            location[pool[p]->location]->type==SITE_HOSPITAL_CLINIC)
         {
            int hospital=find_hospital(*pool[p]);
            if(hospital!=-1) pool[p]->location=hospital;
         }
         if(pool[p]->clinic==0)
         {
            pool[p]->blood=100;
            int hs=find_homeless_shelter(*pool[p]);
            if(hs==-1) hs=0;
            if(location[pool[p]->base]->siege.siege||
               location[pool[p]->base]->renting==RENTING_NOCONTROL)
               pool[p]->base=hs;
            pool[p]->location=pool[p]->base;
         }
      }
   }
}

// A day passing for everybody, and a month passing for anybody in a clinic.
void probe_ageing(FILE *out)
{
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 61207793UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = ENDGAME_NONE;
      mode = GAMEMODE_BASE;
      cursite = 1;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      int clinicloc = find_clinic_index_probe();

      // stage 0 is the day's ageing pass, stage 1 the month at a clinic.
      for (int stage = 0; stage < 2; stage++)
      for (int start = 0; start < 6; start++)
      for (int crowd = 1; crowd <= 3; crowd++)
      for (int besieged = 0; besieged < 2; besieged++)
      {
         unsigned long seed_used = 6600011UL * (unsigned long)
            (stage * 512 + start * 32 + crowd * 4 + besieged + scenario * 149 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         delete_and_clear(pool);
         delete_and_clear(newsstory);
         day = 1 + start * 5;
         month = 1 + start;
         location[1]->siege.siege = besieged ? 1 : 0;

         for (int n = 0; n < crowd; n++)
         {
            Creature *cr = new Creature;
            cr->id = 950000 + n;
            cr->align = ALIGN_LIBERAL;
            cr->location = stage ? clinicloc : 1;
            cr->base = 1;
            cr->hireid = n ? 0 : -1;
            cr->joindays = 3 + n * 6 + start;
            // Old enough to be declining, young enough to have a birthday.
            cr->age = (n == 0) ? 72 + start : 12 + n + start;
            cr->birthday_month = month;
            cr->birthday_day = day + 1 > monthday() ? 1 : day + 1;
            cr->blood = 15 + n * 30;
            cr->hiding = (n == 1) ? 1 : 0;
            cr->clinic = stage ? (1 + (n + start) % 4) : 0;
            cr->set_attribute(ATTRIBUTE_HEALTH, 2 + n);
            cr->wound[BODYPART_ARM_RIGHT] |= (n % 2) ? WOUND_NASTYOFF : WOUND_CUT;
            cr->wound[BODYPART_BODY] |= WOUND_SHOT | WOUND_BLEEDING;
            cr->special[SPECIALWOUND_LEFTLUNG] = 0;
            if (n % 2) cr->special[SPECIALWOUND_HEART] = 0;
            cr->special[SPECIALWOUND_RIBS] = RIBNUM - 2;
            if (n % 3 == 1) cr->special[SPECIALWOUND_LOWERSPINE] = 0;
            if (n == 2) cr->flag |= CREATUREFLAG_MISSING;
            cr->set_skill(SKILL_STREETSENSE, 2);
            cr->train(SKILL_STREETSENSE, 200 + n * 60);
            pool.push_back(cr);
         }

         fprintf(out, "{\"kind\":\"ageing\",\"scenario\":%d,\"seed\":%lu,"
                      "\"stage\":%d,\"start\":%d,\"crowd\":%d,\"besieged\":%d,"
                      "\"day\":%d,\"month\":%d,\"world_seed\":%lu",
                 scenario, seed_used, stage, start, crowd, besieged, day, month,
                 run_seed);
         fputs(",\"pool\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"hiding\":%d,\"clinic\":%d,\"joindays\":%d,"
                         "\"bmonth\":%d,\"bday\":%d,\"missing\":%d,"
                         "\"kidnapped\":%d,\"experience\":[",
                    p ? "," : "", (int)pool[p]->hiding, (int)pool[p]->clinic,
                    (int)pool[p]->joindays, (int)pool[p]->birthday_month,
                    (int)pool[p]->birthday_day,
                    (pool[p]->flag & CREATUREFLAG_MISSING) ? 1 : 0,
                    (pool[p]->flag & CREATUREFLAG_KIDNAPPED) ? 1 : 0);
            for (int sk = 0; sk < SKILLNUM; sk++)
               fprintf(out, "%s%d", sk ? "," : "",
                       (int)pool[p]->get_skill_ip(sk));
            fputs("],\"person\":", out);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         char clearformess = 0;
         long long before = lcs_trace_draw_count();
         if (stage) clinic_block(clearformess);
         else { day++; ageing_block(clearformess); }

         fprintf(out, ",\"draws\":%lld,\"stories\":%d",
                 lcs_trace_draw_count() - before, len(newsstory));
         fputs(",\"pool_after\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"hiding\":%d,\"clinic\":%d,\"joindays\":%d,"
                         "\"kidnapped\":%d,\"type\":",
                    p ? "," : "", (int)pool[p]->hiding, (int)pool[p]->clinic,
                    (int)pool[p]->joindays,
                    (pool[p]->flag & CREATUREFLAG_KIDNAPPED) ? 1 : 0);
            write_string(out, getcreaturetype(pool[p]->type)->get_idname().c_str());
            fputs(",\"person\":", out);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("]}\n", out);

         delete_and_clear(pool);
         location[1]->siege.siege = 0;
      }
   }
}


// The nightly dispersal check: who can still be reached down the chain of
// command, who is promoted when a link in it dies, and who quietly loses touch
// with the organisation for good.
void probe_dispersal(FILE *out)
{
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 71830271UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = ENDGAME_NONE;
      mode = GAMEMODE_BASE;
      cursite = 1;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      int prison = -1, shelter = -1;
      for (int l = 0; l < len(location); l++)
      {
         if (prison == -1 && location[l]->type == SITE_GOVERNMENT_PRISON)
            prison = l;
         if (shelter == -1 && location[l]->type == SITE_RESIDENTIAL_SHELTER)
            shelter = l;
      }

      // depth  how long the chain of command is
      // dead   which rung of it has just died (-1: nobody)
      // jailed which rung is behind bars (-1: nobody)
      // quirk  love slaves, brainwashing and indefinite hiding
      for (int depth = 1; depth <= 4; depth++)
      for (int dead = -1; dead < depth; dead++)
      for (int jailed = -1; jailed < depth; jailed++)
      for (int quirk = 0; quirk < 3; quirk++)
      {
         unsigned long seed_used = 5500013UL * (unsigned long)
            ((depth * 256) + (dead + 1) * 32 + (jailed + 1) * 4 + quirk
             + scenario * 131 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         delete_and_clear(pool);

         // A straight chain: each Liberal recruited by the one above, plus a
         // second recruit at the bottom rung so a promotion has to choose.
         int previous = -1;
         for (int d = 0; d < depth; d++)
         {
            for (int twin = 0; twin < (d == depth - 1 ? 2 : 1); twin++)
            {
               Creature *cr = new Creature;
               cr->id = 900000 + d * 10 + twin;
               cr->align = ALIGN_LIBERAL;
               cr->location = 1;
               cr->base = 1;
               cr->hireid = previous;
               cr->juice = 30 * (d + 1) + twin * 17 + scenario * 5;
               cr->activity.type = ACTIVITY_NONE;
               if (d == dead) cr->alive = false;
               if (d == jailed) cr->location = prison;
               if (quirk == 1 && d == depth - 1 && twin == 0)
                  cr->flag |= CREATUREFLAG_LOVESLAVE;
               if (quirk == 2 && d == depth - 1 && twin == 0)
                  cr->flag |= CREATUREFLAG_BRAINWASHED;
               if (quirk == 2 && d == depth - 1 && twin == 1)
                  cr->hiding = -1;
               pool.push_back(cr);
            }
            previous = 900000 + d * 10;
         }
         // The founder sometimes starts hiding indefinitely, which is the one
         // place the check rolls for the top of the chain.
         if (quirk == 1 && len(pool)) pool[0]->hiding = -1;

         fprintf(out, "{\"kind\":\"dispersal\",\"scenario\":%d,\"seed\":%lu,"
                      "\"depth\":%d,\"dead\":%d,\"jailed\":%d,\"quirk\":%d,"
                      "\"prison\":%d,\"shelter\":%d,\"world_seed\":%lu",
                 scenario, seed_used, depth, dead, jailed, quirk, prison,
                 shelter, run_seed);
         fputs(",\"pool\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"hiding\":%d,\"loveslave\":%d,"
                         "\"brainwashed\":%d,\"person\":",
                    p ? "," : "", (int)pool[p]->hiding,
                    (pool[p]->flag & CREATUREFLAG_LOVESLAVE) ? 1 : 0,
                    (pool[p]->flag & CREATUREFLAG_BRAINWASHED) ? 1 : 0);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         char clearformess = 0;
         long long before = lcs_trace_draw_count();
         dispersal_block(clearformess);

         fprintf(out, ",\"draws\":%lld", lcs_trace_draw_count() - before);
         fputs(",\"pool_after\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"hiding\":%d,\"loveslave\":%d,"
                         "\"brainwashed\":%d,\"person\":",
                    p ? "," : "", (int)pool[p]->hiding,
                    (pool[p]->flag & CREATUREFLAG_LOVESLAVE) ? 1 : 0,
                    (pool[p]->flag & CREATUREFLAG_BRAINWASHED) ? 1 : 0);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("]}\n", out);

         delete_and_clear(pool);
      }
   }
}


// A transcription of the healing block of advanceday(), which is inline there
// and cannot be called on its own. Kept line-for-line so the probe measures the
// original and not a paraphrase of it.
static void recovery_block(char &clearformess)
{
   int p;
   int *healing = new int[len(location)];
   int *healing2 = new int[len(location)];
   for (p = 0; p < len(location); p++)
   {
      if (location[p]->type == SITE_HOSPITAL_CLINIC) healing[p] = 6;
      else if (location[p]->type == SITE_HOSPITAL_UNIVERSITY) healing[p] = 12;
      else healing[p] = 0;
      healing2[p] = 0;
   }
   for (p = 0; p < len(pool); p++)
   {
      if (!pool[p]->alive) continue;
      if (pool[p]->hiding) continue;
      if (pool[p]->flag & CREATUREFLAG_SLEEPER) continue;
      if (pool[p]->activity.type == ACTIVITY_HEAL ||
          pool[p]->activity.type == ACTIVITY_NONE)
         if (pool[p]->location > -1 &&
             healing[pool[p]->location] < pool[p]->get_skill(SKILL_FIRSTAID))
         {
            healing[pool[p]->location] = pool[p]->get_skill(SKILL_FIRSTAID);
            pool[p]->activity.type = ACTIVITY_HEAL;
         }
   }
   for (p = 0; p < len(location); p++)
      if (location[p]->type != SITE_HOSPITAL_CLINIC &&
          location[p]->type != SITE_HOSPITAL_UNIVERSITY)
         if (!fooddaysleft(p))
            if (location[p]->siege.siege)
               healing[p] = 0;

   for (p = 0; p < len(pool); p++)
   {
      if (!(pool[p]->alive)) continue;
      if (clinictime(*pool[p]))
      {
         if (pool[p]->clinic == false)
         {
            int damage = 0;
            int transfer = 0;
            if (pool[p]->location > -1)
               healing2[pool[p]->location] += 100 - pool[p]->blood;
            if (pool[p]->blood < 100 - (clinictime(*pool[p]) - 1) * 20)
            {
               if (pool[p]->location > -1)
                  pool[p]->blood += 1 + healing[pool[p]->location] / 3;
               if (pool[p]->blood > 100 - (clinictime(*pool[p]) - 1) * 20)
                  pool[p]->blood = 100 - (clinictime(*pool[p]) - 1) * 20;
               if (pool[p]->blood > 100) pool[p]->blood = 100;
            }
            if (pool[p]->alive && pool[p]->blood < 0) pool[p]->die();
            for (int w = 0; w < BODYPARTNUM; w++)
            {
               if (pool[p]->wound[w] & WOUND_NASTYOFF)
               {
                  if (pool[p]->location > -1 &&
                      healing[pool[p]->location] + LCSrandom(10) > 12)
                     pool[p]->wound[w] = WOUND_CLEANOFF;
                  else
                  {
                     damage += 4;
                     if (pool[p]->location > -1 &&
                         healing[pool[p]->location] + 9 <= 12) transfer = 1;
                  }
               }
               else if (pool[p]->wound[w] & WOUND_BLEEDING)
               {
                  if (pool[p]->location > -1 &&
                      healing[pool[p]->location] + LCSrandom(10) > 8)
                     pool[p]->wound[w] &= ~WOUND_BLEEDING;
                  else damage += 1;
               }
               else
               {
                  if (pool[p]->blood >= 95) pool[p]->wound[w] &= WOUND_CLEANOFF;
               }
            }
            for (int i = SPECIALWOUND_RIGHTLUNG; i < SPECIALWOUNDNUM; ++i)
            {
               int healdiff = 14, permdamage = 0, bleed = 0, healed = 0;
               switch (i)
               {
               case SPECIALWOUND_HEART:
                  healdiff = 16;
                  bleed = 8;
               case SPECIALWOUND_RIGHTLUNG:
               case SPECIALWOUND_LEFTLUNG:
                  permdamage = 1;
               case SPECIALWOUND_LIVER:
               case SPECIALWOUND_STOMACH:
               case SPECIALWOUND_RIGHTKIDNEY:
               case SPECIALWOUND_LEFTKIDNEY:
               case SPECIALWOUND_SPLEEN:
                  healed = 1;
                  bleed++;
                  break;
               case SPECIALWOUND_RIBS:
                  healed = RIBNUM;
                  break;
               case SPECIALWOUND_NECK:
               case SPECIALWOUND_UPPERSPINE:
               case SPECIALWOUND_LOWERSPINE:
                  healed = 2;
                  break;
               }
               if (pool[p]->special[i] != healed &&
                   (i == SPECIALWOUND_RIBS || pool[p]->special[i] != 1))
               {
                  if (pool[p]->location > -1 &&
                      healing[pool[p]->location] + LCSrandom(10) > healdiff)
                  {
                     pool[p]->special[i] = healed;
                     if (permdamage)
                     {
                        if (LCSrandom(20) > healing[pool[p]->location])
                        {
                           pool[p]->adjust_attribute(ATTRIBUTE_HEALTH, -1);
                           if (pool[p]->get_attribute(ATTRIBUTE_HEALTH, false) <= 0)
                              pool[p]->set_attribute(ATTRIBUTE_HEALTH, 1);
                        }
                     }
                  }
                  else
                  {
                     damage += bleed;
                     if (healing[pool[p]->location] + 9 <= healdiff) transfer = 1;
                  }
               }
            }
            pool[p]->blood -= damage;
            if (transfer && pool[p]->location > -1 && pool[p]->alive == 1 &&
                pool[p]->align == 1 &&
                location[pool[p]->location]->renting != RENTING_NOCONTROL &&
                location[pool[p]->location]->type != SITE_HOSPITAL_UNIVERSITY)
               pool[p]->activity.type = ACTIVITY_CLINIC;
         }
      }
   }
   for (p = 0; p < len(pool); p++)
   {
      if (pool[p]->location >= 0 && pool[p]->activity.type == ACTIVITY_HEAL)
      {
         if (healing2[pool[p]->location] == 0)
            pool[p]->activity.type = ACTIVITY_NONE;
         else
            pool[p]->train(SKILL_FIRSTAID,
                           MAX(0, healing2[pool[p]->location] / 5 -
                                  pool[p]->get_skill(SKILL_FIRSTAID) * 2));
      }
   }
   delete[] healing;
   delete[] healing2;
}


// The night's nursing: the healing block of advanceday(). Anybody hurt enough
// to need a clinic but not in one is patched up where they are, by whoever at
// that safehouse has the steadiest hands.
//
// Driven straight out of daily.cpp, because the block is inline there and the
// point is to measure exactly what it does.
void probe_recovery(FILE *out)
{
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 55501913UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = ENDGAME_NONE;
      mode = GAMEMODE_BASE;
      cursite = 1;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      // Somewhere with real medics on hand, and somewhere without.
      int clinicloc = find_clinic_index_probe();

      for (int hurt = 1; hurt <= 4; hurt++)
      for (int medics = 0; medics < 3; medics++)
      for (int where = 0; where < 2; where++)
      for (int besieged = 0; besieged < 2; besieged++)
      {
         unsigned long seed_used = 4400021UL * (unsigned long)
            (hurt * 64 + medics * 16 + where * 4 + besieged + scenario * 97 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         delete_and_clear(pool);
         int site = where ? clinicloc : 1;
         location[1]->siege.siege = besieged ? 1 : 0;
         location[1]->compound_stores = besieged ? 0 : 100;

         // The patients, hurt in every way the block has a rule for.
         for (int n = 0; n < hurt; n++)
         {
            Creature *cr = new Creature;
            cr->id = 800000 + n;
            cr->align = ALIGN_LIBERAL;
            cr->location = site;
            cr->base = site;
            cr->hireid = n ? 0 : -1;
            cr->blood = 20 + n * 20 - (scenario * 7);
            cr->activity.type = ACTIVITY_NONE;
            cr->set_skill(SKILL_FIRSTAID, 0);
            cr->wound[BODYPART_ARM_RIGHT] |=
               (n % 2) ? WOUND_NASTYOFF : WOUND_BLEEDING;
            cr->wound[BODYPART_BODY] |= WOUND_SHOT | WOUND_BLEEDING;
            cr->wound[BODYPART_HEAD] |= WOUND_CUT;
            cr->special[SPECIALWOUND_LEFTLUNG] = 0;
            if (n % 2) cr->special[SPECIALWOUND_HEART] = 0;
            if (n % 3 == 0) cr->special[SPECIALWOUND_LIVER] = 0;
            cr->special[SPECIALWOUND_RIBS] = RIBNUM - 1 - n % 4;
            if (n % 3 == 1) cr->special[SPECIALWOUND_LOWERSPINE] = 0;
            cr->set_attribute(ATTRIBUTE_HEALTH, 4 + n);
            pool.push_back(cr);
         }
         // The people looking after them, at whatever standard.
         for (int m = 0; m < medics; m++)
         {
            Creature *cr = new Creature;
            cr->id = 810000 + m;
            cr->align = ALIGN_LIBERAL;
            cr->location = site;
            cr->base = site;
            cr->hireid = 0;
            cr->activity.type = m ? ACTIVITY_NONE : ACTIVITY_HEAL;
            cr->set_skill(SKILL_FIRSTAID, (m + scenario) * 4 + 1);
            pool.push_back(cr);
         }

         fprintf(out, "{\"kind\":\"recovery\",\"scenario\":%d,\"seed\":%lu,"
                      "\"hurt\":%d,\"medics\":%d,\"where\":%d,\"besieged\":%d,"
                      "\"site\":%d,\"stores\":%d,\"world_seed\":%lu",
                 scenario, seed_used, hurt, medics, where, besieged, site,
                 location[1]->compound_stores, run_seed);
         fputs(",\"pool\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"activity\":%d,\"person\":",
                    p ? "," : "", pool[p]->activity.type);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         char clearformess = 0;
         long long before = lcs_trace_draw_count();
         recovery_block(clearformess);

         fprintf(out, ",\"draws\":%lld", lcs_trace_draw_count() - before);
         fputs(",\"pool_after\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"activity\":%d,\"person\":",
                    p ? "," : "", pool[p]->activity.type);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("]}\n", out);

         delete_and_clear(pool);
         location[1]->siege.siege = 0;
      }
   }
}


// The individual half of a day: the jobs the original runs one Liberal at a
// time, before it sorts anybody into a group. Mending and sewing clothes,
// finding a wheelchair, reading the polls, and the idle Liberal who washes
// their own bloody shirt without being told to.
//
// Recruiting and car theft are left out on purpose: both are menus that need
// the talk system and the theft minigame, neither of which is ported yet.
void probe_activation_day(FILE *out)
{
   static const int JOBS[] = {
      ACTIVITY_REPAIR_ARMOR, ACTIVITY_MAKE_ARMOR, ACTIVITY_WHEELCHAIR,
      ACTIVITY_POLLS, ACTIVITY_VISIT, ACTIVITY_NONE,
   };
   const int JOB_COUNT = (int)(sizeof(JOBS) / sizeof(JOBS[0]));

   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 96431231UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();

      for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = ENDGAME_NONE;
      mode = GAMEMODE_BASE;
      cursite = 1;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      for (int solo = -1; solo < JOB_COUNT; solo++)
      for (int crowd = 1; crowd <= 3; crowd++)
      for (int besieged = 0; besieged < 2; besieged++)
      {
         unsigned long seed_used = 3300017UL * (unsigned long)
            ((solo + 2) * 32 + crowd * 4 + besieged + scenario * 71 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         delete_and_clear(pool);
         delete_and_clear(location[1]->loot);
         ledger.force_funds(1500);
         for (int v = 0; v < VIEWNUM; v++)
         {
            attitude[v] = (v * 11 + scenario * 17) % 101;
            public_interest[v] = (v * 5 + scenario * 3) % 40;
            background_liberal_influence[v] = 0;
         }
         location[1]->siege.siege = besieged ? 1 : 0;

         // A pile on the floor worth working on, and cloth to sew with.
         for (int i = 0; i < 4; i++)
         {
            Armor *lying = new Armor(*armortype[i % len(armortype)], 1 + i % 3);
            lying->set_bloody(i % 2 == 0);
            lying->set_damaged(i % 3 != 2);
            location[1]->loot.push_back(lying);
         }
         for (int i = 0; i < len(loottype); i++)
            if (loottype[i]->is_cloth())
            {
               location[1]->loot.push_back(new Loot(*loottype[i], 2));
               break;
            }

         int made = 0;
         for (int j = 0; j < JOB_COUNT; j++)
         for (int n = 0; n < crowd; n++)
         {
            if (solo >= 0 && j != solo) continue;
            Creature *cr = new Creature;
            cr->id = 700000 + made;
            cr->align = ALIGN_LIBERAL;
            cr->location = 1;
            cr->base = 1;
            cr->hireid = made ? 0 : -1;
            cr->juice = 20 * n;
            cr->set_skill(SKILL_TAILORING, (j + n + scenario) % 10);
            cr->set_skill(SKILL_COMPUTERS, (j * 2 + n + scenario) % 14);
            cr->set_skill(SKILL_STREETSENSE, (j + n) % 6);
            cr->give_armor(*armortype[getarmortype("ARMOR_CLOTHES")], NULL);
            // Half of them are wearing something that needs attention, which
            // is what the idle case reacts to.
            if ((j + n) % 2 == 0)
            {
               cr->get_armor().set_bloody(true);
               if (n) cr->get_armor().set_damaged(true);
            }
            cr->activity.type = JOBS[j];
            if (cr->activity.type == ACTIVITY_MAKE_ARMOR)
               cr->activity.arg = (j + n + scenario) % len(armortype);
            pool.push_back(cr);
            made++;
         }

         fprintf(out, "{\"kind\":\"activation\",\"scenario\":%d,\"seed\":%lu,"
                      "\"crowd\":%d,\"besieged\":%d,\"solo\":%d,"
                      "\"world_seed\":%lu",
                 scenario, seed_used, crowd, besieged, solo, run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("],\"pool\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"activity\":%d,\"makes\":",
                    p ? "," : "", pool[p]->activity.type);
            write_string(out,
                  pool[p]->activity.type == ACTIVITY_MAKE_ARMOR
                  ? armortype[pool[p]->activity.arg]->get_idname().c_str() : "");
            fputs(",\"person\":", out);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("],\"exec\":[", out);
         for (int i = 0; i < EXECNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", exec[i]);
         fprintf(out, "],\"presparty\":%d", presparty);
         fputs(",\"floor\":[", out);
         activation_write_loot(out, location[1]->loot);
         fputs("]", out);
         fputs(",\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         char clearformess = 0;
         long long before = lcs_trace_draw_count();
         // Every poll read today, written as it happens so the array stays in
         // the order the day produced it.
         int polls = 0;
         for (int p = 0; p < len(pool); p++)
         {
            pool[p]->income = 0;
            if (!pool[p]->alive) continue;
            if (pool[p]->clinic) continue;
            if (pool[p]->dating) continue;
            if (pool[p]->hiding) continue;
            if (pool[p]->location == -1) pool[p]->location = pool[p]->base;
            if (location[pool[p]->location]->siege.siege)
            {
               switch (pool[p]->activity.type)
               {
               case ACTIVITY_HOSTAGETENDING:
               case ACTIVITY_TEACH_POLITICS:
               case ACTIVITY_TEACH_FIGHTING:
               case ACTIVITY_TEACH_COVERT:
               case ACTIVITY_HEAL:
               case ACTIVITY_REPAIR_ARMOR:
                  break;
               default:
                  pool[p]->activity.type = ACTIVITY_NONE;
                  break;
               }
            }
            switch (pool[p]->activity.type)
            {
            case ACTIVITY_REPAIR_ARMOR:
               repairarmor(*pool[p], clearformess);
               break;
            case ACTIVITY_MAKE_ARMOR:
               makearmor(*pool[p], clearformess);
               break;
            case ACTIVITY_WHEELCHAIR:
               getwheelchair(*pool[p], clearformess);
               if (pool[p]->flag & CREATUREFLAG_WHEELCHAIR)
                  pool[p]->activity.type = ACTIVITY_NONE;
               break;
            case ACTIVITY_POLLS:
               pool[p]->train(SKILL_COMPUTERS,
                              MAX(3 - pool[p]->get_skill(SKILL_COMPUTERS), 1));
               survey(pool[p]);
               {
                  int count = 0, approval = 0;
                  const int *figures =
                     lcs_trace_survey_figures(&count, &approval);
                  fprintf(out, "%s{\"who\":%d,\"approval\":%d,\"figures\":[",
                          polls ? "," : ",\"polls\":[", (int)pool[p]->id,
                          approval);
                  for (int i = 0; i < count; i++)
                     fprintf(out, "%s%d", i ? "," : "", figures[i]);
                  fputs("]}", out);
                  polls++;
               }
               break;
            case ACTIVITY_VISIT:
               pool[p]->activity.type = ACTIVITY_NONE;
               break;
            case ACTIVITY_NONE:
               if (pool[p]->align == 1 && !pool[p]->is_imprisoned() &&
                   (pool[p]->get_armor().is_bloody() ||
                    pool[p]->get_armor().is_damaged()))
                  repairarmor(*pool[p], clearformess);
               break;
            }
         }

         if (polls) fputs("]", out);
         else fputs(",\"polls\":[]", out);
         fprintf(out, ",\"draws\":%lld,\"funds\":%d",
                 lcs_trace_draw_count() - before, ledger.get_funds());
         fputs(",\"pool_after\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"activity\":%d,\"person\":",
                    p ? "," : "", pool[p]->activity.type);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("],\"floor_after\":[", out);
         activation_write_loot(out, location[1]->loot);
         fputs("]}\n", out);

         delete_and_clear(pool);
         delete_and_clear(location[1]->loot);
         location[1]->siege.siege = 0;
      }
   }
}


// A transcription of stealcar() from src/daily/activities.cpp with the display
// taken out and the menus answered from parameters rather than the keyboard:
// the theft is a minigame of prompts, and a probe cannot press keys for the
// prompts and for the chase it can end in at the same time.
//
// entry_policy: 0 picks the lock every time, 1 breaks the window every time,
// 2 alternates. start_policy: 0 hotwires, 1 searches for keys, 2 alternates.
// Both give up after ROUNDS_CAP rounds, which is what the player would do.
#define STEAL_ROUNDS_CAP 400

static int steal_block(Creature &cr, short cartype, int entry_policy,
                       int start_policy, int *spotted_out, int *window_out,
                       int *rounds_out)
{
   *spotted_out = 0; *window_out = 0; *rounds_out = 0;

   int diff = vehicletype[cartype]->steal_difficultytofind() * 2;
   Vehicle *v = NULL;
   int old = cartype;

   cr.train(SKILL_STREETSENSE, 5);

   //ROUGH DAY
   if(!cr.skill_check(SKILL_STREETSENSE,diff))
      do cartype=LCSrandom(len(vehicletype));
      while(cartype==old||LCSrandom(10)<vehicletype[cartype]->steal_difficultytofind());

   v = new Vehicle(*vehicletype[cartype]);

   //SECURITY?
   bool alarmon=false,sensealarm=LCSrandom(100)<v->sensealarmchance(),
        touchalarm=LCSrandom(100)<v->touchalarmchance();
   char windowdamage=0;

   int round = 0;
   for(bool entered=false;!entered;)
   {
      if(++round > STEAL_ROUNDS_CAP) { delete v; return 0; }
      char method = entry_policy==2 ? (char)((round-1)%2) : (char)entry_policy;

      //PICK LOCK
      if(method==0)
      {
         if(cr.skill_check(SKILL_SECURITY,DIFFICULTY_AVERAGE))
         {
            switch (fieldskillrate)
            {
               case FIELDSKILLRATE_FAST:
                  cr.train(SKILL_SECURITY, 25);break;
               case FIELDSKILLRATE_CLASSIC:
                  cr.train(SKILL_SECURITY, MAX(5 - cr.get_skill(SKILL_SECURITY), 0));break;
               case FIELDSKILLRATE_HARD:
                  cr.train(SKILL_SECURITY, 0);break;
            }
            entered=true;
         }
      }
      //BREAK WINDOW
      if(method==1)
      {
         int difficulty = static_cast<int>(DIFFICULTY_EASY / cr.get_weapon().get_bashstrengthmod()) - windowdamage;

         if(cr.attribute_check(ATTRIBUTE_STRENGTH,difficulty))
         {
            windowdamage=10;
            entered=true;
         }
         else windowdamage++;
      }

      //ALARM CHECK
      if(touchalarm||sensealarm) alarmon=true;

      //NOTICE CHECK
      if(!LCSrandom(50)||(!LCSrandom(5)&&alarmon))
      {
         chaseseq.clean();
         chaseseq.location=location[cr.location]->parent;
         newsstoryst *ns=new newsstoryst;
         ns->type=NEWSSTORY_CARTHEFT;
         newsstory.push_back(ns);
         sitestory=ns;
         makechasers(-1,5);
         *spotted_out = 1; *window_out = windowdamage; *rounds_out = round;
         mode=GAMEMODE_BASE;
         delete v; return 0;
      }
   }

   //START CAR
   char keys_in_car=LCSrandom(5)>0,key_search_total=0;
   int key_location=LCSrandom(5),nervous_counter=0;

   int start_round = 0;
   for(bool started=false;!started;)
   {
      nervous_counter++;
      if(++start_round > STEAL_ROUNDS_CAP) { delete v; return 0; }
      char method = start_policy==2 ? (char)((start_round-1)%2) : (char)start_policy;

      //HOTWIRE CAR
      if(method==0)
      {
         if(cr.skill_check(SKILL_SECURITY,DIFFICULTY_CHALLENGING))
         {
            switch (fieldskillrate)
            {
               case FIELDSKILLRATE_FAST:
                  cr.train(SKILL_SECURITY, 50);break;
               case FIELDSKILLRATE_CLASSIC:
                  cr.train(SKILL_SECURITY, MAX(10 - cr.get_skill(SKILL_SECURITY), 0));break;
               case FIELDSKILLRATE_HARD:
                  cr.train(SKILL_SECURITY, 0);break;
            }
            started=true;
         }
         else
         {
            // The flavour line is rolled for even though nothing reads it.
            if(cr.get_skill(SKILL_SECURITY) < 4) LCSrandom(3);
            else LCSrandom(5);
         }
      }
      //KEYS
      if(method==1)
      {
         int difficulty;

         if(!keys_in_car) difficulty = DIFFICULTY_IMPOSSIBLE;
         else switch(key_location)
         {
         case 0: default: difficulty = DIFFICULTY_AUTOMATIC; break;
         case 1: difficulty = DIFFICULTY_EASY; break;
         case 2: difficulty = DIFFICULTY_EASY; break;
         case 3: difficulty = DIFFICULTY_AVERAGE; break;
         case 4: difficulty = DIFFICULTY_HARD; break;
         }
         if(cr.attribute_check(ATTRIBUTE_INTELLIGENCE,difficulty)) started=true;
         else
         {
            key_search_total++;
            // The three milestone lines are fixed; every other round rolls.
            if(key_search_total==5) ;
            else if(key_search_total==10) ;
            else if(key_search_total==15) ;
            else LCSrandom(5);
         }
      }

      //NOTICE CHECK
      if(!started&&(!LCSrandom(50)||(!LCSrandom(5)&&alarmon)))
      {
         chaseseq.clean();
         chaseseq.location=location[cr.location]->parent;
         newsstoryst *ns=new newsstoryst;
         ns->type=NEWSSTORY_CARTHEFT;
         newsstory.push_back(ns);
         sitestory=ns;
         makechasers(-1,5);
         *spotted_out = 2; *window_out = windowdamage; *rounds_out = start_round;
         mode=GAMEMODE_BASE;
         delete v; return 0;
      }
      else if (!started&&(LCSrandom(7)+5)<nervous_counter)
      {
         nervous_counter=0;
      }
   }

   //CHASE SEQUENCE
   addjuice(cr,v->steal_juice(),100);

   vehicle.push_back(v);
   v->add_heat(14+v->steal_extraheat());
   v->set_location(cr.base);
   if(cr.pref_carid==-1)
   {
      cr.pref_carid = v->id();
      cr.pref_is_driver = true;
   }

   chaseseq.clean();
   chaseseq.location=location[cr.location]->parent;
   int chaselev=!LCSrandom(13-windowdamage);
   *window_out = windowdamage; *rounds_out = start_round;
   if(chaselev>0||(v->vtypeidname()=="POLICECAR"&&LCSrandom(2)))
   {
      v->add_heat(10);
      chaselev=1;
      newsstoryst *ns=new newsstoryst;
      ns->type=NEWSSTORY_CARTHEFT;
      newsstory.push_back(ns);
      sitestory=ns;
      makechasers(-1,chaselev);
      *spotted_out = 3;
      return 1;
   }

   return 1;
}



// Transcriptions of dateresult(), completevacation() and completedate() from
// src/daily/date.cpp with the display taken out and the evening's menu
// answered from a parameter rather than the keyboard. The two prompts that
// have no rolls in them — naming a new love slave, and choosing whether they
// come home or stay where they work — are answered the way the probe's
// counterpart in the port answers them: come home, keep the name.

enum ProbeDateResults
{
   PROBE_DATE_MEETTOMORROW,
   PROBE_DATE_BREAKUP,
   PROBE_DATE_JOINED,
   PROBE_DATE_ARRESTED
};

static int dateresult_block(int aroll, int troll, datest &d, int e, int p)
{
   if(aroll>troll)
   {
      if(loveslavesleft(*pool[p]) <= 0)
      {
         delete_and_remove(d.date,e);
         return PROBE_DATE_BREAKUP;
      }

      if(LCSrandom((aroll-troll)/2)>d.date[e]->get_attribute(ATTRIBUTE_WISDOM,true))
      {
         location[d.date[e]->worklocation]->mapped=1;
         location[d.date[e]->worklocation]->hidden=0;

         d.date[e]->flag|=CREATUREFLAG_LOVESLAVE;
         d.date[e]->hireid=pool[p]->id;

         // sleeperize_prompt(), answered "come home as a regular member".
         d.date[e]->location=pool[p]->location;
         d.date[e]->base=pool[p]->base;
         liberalize(*d.date[e],false);

         pool.push_back(d.date[e]);
         stat_recruits++;
         d.date.erase(d.date.begin() + e);

         return PROBE_DATE_JOINED;
      }
      else
      {
         if(d.date[e]->align == ALIGN_CONSERVATIVE && d.date[e]->get_attribute(ATTRIBUTE_WISDOM,false)>3)
         {
            d.date[e]->adjust_attribute(ATTRIBUTE_WISDOM,-1);
            d.date[e]->adjust_attribute(ATTRIBUTE_HEART,+1);
         }
         else if(d.date[e]->get_attribute(ATTRIBUTE_WISDOM,false)>3)
         {
            d.date[e]->adjust_attribute(ATTRIBUTE_WISDOM,-1);
         }
         else if(location[d.date[e]->worklocation]->mapped==0 && !LCSrandom(d.date[e]->get_attribute(ATTRIBUTE_WISDOM,false)))
         {
            location[d.date[e]->worklocation]->mapped=1;
            location[d.date[e]->worklocation]->hidden=0;
         }
         return PROBE_DATE_MEETTOMORROW;
      }
   }
   else if(aroll==troll)
   {
      // The excuse for leaving early, which is rolled for and then read out.
      switch(LCSrandom(4))
      {
      case 4:
         LCSrandom(3+(law[LAW_ANIMALRESEARCH]==-2));
         break;
      }
      return PROBE_DATE_MEETTOMORROW;
   }
   else
   {
      //WISDOM POSSIBLE INCREASE
      if(d.date[e]->align==-1&&aroll<troll/2)
      {
         pool[p]->adjust_attribute(ATTRIBUTE_WISDOM,+1);

         if(d.date[e]->get_skill(SKILL_RELIGION)>pool[p]->get_skill(SKILL_RELIGION))
            pool[p]->train(SKILL_RELIGION,20*(d.date[e]->get_skill(SKILL_RELIGION)-pool[p]->get_skill(SKILL_RELIGION)));
         if(d.date[e]->get_skill(SKILL_SCIENCE)>pool[p]->get_skill(SKILL_SCIENCE))
            pool[p]->train(SKILL_SCIENCE,20*(d.date[e]->get_skill(SKILL_SCIENCE)-pool[p]->get_skill(SKILL_SCIENCE)));
         if(d.date[e]->get_skill(SKILL_BUSINESS)>pool[p]->get_skill(SKILL_BUSINESS))
            pool[p]->train(SKILL_BUSINESS,20*(d.date[e]->get_skill(SKILL_BUSINESS)-pool[p]->get_skill(SKILL_BUSINESS)));
      }

      //BREAK UP
      if((iscriminal(*pool[p])) &&
         (!LCSrandom(50) ||(LCSrandom(2) && (d.date[e]->kidnap_resistant()))))
      {
         if((pool[p]->juice<50 && LCSrandom(2)) || LCSrandom(2))
         {
            long ps=find_police_station(*pool[p]);
            removesquadinfo(*pool[p]);
            pool[p]->carid=-1;
            pool[p]->location=ps;
            pool[p]->drop_weapons_and_clips(NULL);
            pool[p]->activity.type=ACTIVITY_NONE;
            delete_and_remove(d.date,e);
            return PROBE_DATE_ARRESTED;
         }
      }
      else
      {
         int ls = loveslaves(*pool[p]);
         if (ls > 0 && LCSrandom(2)) { /* the scheduling disaster, all prose */ }
      }

      delete_and_remove(d.date,e);
      return PROBE_DATE_BREAKUP;
   }
}

static char vacation_block(datest &d, int p)
{
   int e=0;

   int datealignment=d.date[e]->align;
   d.date[e]->align=-1;

   short aroll=pool[p]->skill_roll(SKILL_SEDUCTION)*2;
   short troll=d.date[e]->attribute_roll(ATTRIBUTE_WISDOM);

   d.date[e]->align=datealignment;

   pool[p]->train(SKILL_SEDUCTION,LCSrandom(11)+15);

   int thingsincommon=0;
   for(int s=0;s<SKILLNUM;s++)
      if(d.date[e]->get_skill(s)>=1 && pool[p]->get_skill(s)>=1)
         if (d.date[e]->get_skill(s)<=pool[p]->get_skill(s)*2)
            thingsincommon++;
   aroll += thingsincommon*3;

   pool[p]->train(SKILL_SCIENCE,
      max(d.date[e]->get_skill(SKILL_SCIENCE)-pool[p]->get_skill(SKILL_SCIENCE),0));
   pool[p]->train(SKILL_RELIGION,
      max(d.date[e]->get_skill(SKILL_RELIGION)-pool[p]->get_skill(SKILL_RELIGION),0));
   pool[p]->train(SKILL_BUSINESS,
      max(d.date[e]->get_skill(SKILL_BUSINESS)-pool[p]->get_skill(SKILL_BUSINESS),0));

   if(d.date[e]->skill_roll(SKILL_BUSINESS))
   {
      troll+=d.date[e]->skill_roll(SKILL_BUSINESS);
      aroll+=pool[p]->skill_roll(SKILL_BUSINESS);
   }
   if(d.date[e]->skill_roll(SKILL_RELIGION))
   {
      troll+=d.date[e]->skill_roll(SKILL_RELIGION);
      aroll+=pool[p]->skill_roll(SKILL_RELIGION);
   }
   if(d.date[e]->skill_roll(SKILL_SCIENCE))
   {
      troll+=d.date[e]->skill_roll(SKILL_SCIENCE);
      aroll+=pool[p]->skill_roll(SKILL_SCIENCE);
   }

   switch(dateresult_block(aroll,troll,d,e,p))
   {
   default:
   case PROBE_DATE_MEETTOMORROW:return 0;
   case PROBE_DATE_BREAKUP:     return 1;
   case PROBE_DATE_JOINED:      return 1;
   case PROBE_DATE_ARRESTED:    return 1;
   }
}

// choice: 0 spends money, 1 spends nothing, 2 takes a vacation, 3 breaks it
// off, 4 kidnaps. A choice the evening does not allow falls back to spending
// nothing, which is what the original's menu does with a key it will not take.
static char date_block(datest &d, int p, int choice)
{
   int e;

   if(len(d.date)>1&&!LCSrandom(len(d.date)>2?4:6))
   {
      LCSrandom(3);        // which disaster it was
      // pickrandom() over the ways it ends. The list looks like eight, but
      // its first two entries are missing a comma between them and the
      // compiler joins them into one, so there are seven.
      LCSrandom(7);
      addjuice(*pool[p],-5,-50);
      return 1;
   }

   for(e=len(d.date)-1;e>=0;e--)
   {
      // Others come to dates unarmed and in ordinary clothes, and are given
      // their things back the moment the screen is drawn.
      vector<Item*> temp;
      d.date[e]->drop_weapons_and_clips(&temp);
      Armor atmp(*armortype[getarmortype("ARMOR_CLOTHES")]);
      d.date[e]->give_armor(atmp,&temp);
      while(len(temp))
      {
         if(temp.back()->is_weapon())
            d.date[e]->give_weapon(*(static_cast<Weapon*>(temp.back())),NULL);
         else if(temp.back()->is_armor())
            d.date[e]->give_armor(*(static_cast<Armor*>(temp.back())),NULL);
         else if(temp.back()->is_clip())
            d.date[e]->take_clips(*(static_cast<Clip*>(temp.back())),temp.back()->get_number());
         delete_and_remove(temp,len(temp)-1);
      }

      int thingsincommon = 0;
      for(int s=0;s<SKILLNUM;s++)
         if(d.date[e]->get_skill(s)>=1 && pool[p]->get_skill(s)>=1)
            if (d.date[e]->get_skill(s)<=pool[p]->get_skill(s)*2)
               thingsincommon++;

      short aroll=pool[p]->skill_roll(SKILL_SEDUCTION);
      short troll=d.date[e]->attribute_roll(ATTRIBUTE_WISDOM);
      if(d.date[e]->align==ALIGN_CONSERVATIVE)
         troll+=troll*(d.date[e]->juice/100);
      else if(d.date[e]->align==ALIGN_MODERATE)
         troll+=troll*(d.date[e]->juice/150);
      else troll+=troll*(d.date[e]->juice/200);

      int c = choice;
      if(c==0 && (ledger.get_funds()<100 || pool[p]->clinic)) c=1;
      if(c==2 && (pool[p]->clinic || pool[p]->blood!=100)) c=1;
      if(c==4 && (d.date[e]->align!=-1 || pool[p]->clinic)) c=1;

      char test=0;
      aroll += thingsincommon * 3;
      if(c==0)
      {
         ledger.subtract_funds(100,EXPENSE_DATING);
         aroll+=LCSrandom(10);
         test=true;
      }
      else if(c==1) test=true;

      if(test)
      {
         pool[p]->train(SKILL_SEDUCTION,LCSrandom(4)+5);
         pool[p]->train(SKILL_SCIENCE,
            max(d.date[e]->get_skill(SKILL_SCIENCE)-pool[p]->get_skill(SKILL_SCIENCE),0));
         pool[p]->train(SKILL_RELIGION,
            max(d.date[e]->get_skill(SKILL_RELIGION)-pool[p]->get_skill(SKILL_RELIGION),0));
         pool[p]->train(SKILL_BUSINESS,
            max(d.date[e]->get_skill(SKILL_BUSINESS)-pool[p]->get_skill(SKILL_BUSINESS),0));

         if(d.date[e]->get_skill(SKILL_BUSINESS))
         {
            troll+=d.date[e]->skill_roll(SKILL_BUSINESS);
            aroll+=pool[p]->skill_roll(SKILL_BUSINESS);
         }
         if(d.date[e]->get_skill(SKILL_RELIGION))
         {
            troll+=d.date[e]->skill_roll(SKILL_RELIGION);
            aroll+=pool[p]->skill_roll(SKILL_RELIGION);
         }
         if(d.date[e]->get_skill(SKILL_SCIENCE))
         {
            troll+=d.date[e]->skill_roll(SKILL_SCIENCE);
            aroll+=pool[p]->skill_roll(SKILL_SCIENCE);
         }

         if(dateresult_block(aroll,troll,d,e,p)==PROBE_DATE_ARRESTED) return 1;
         continue;
      }

      if(c==2)
      {
         for(int e2=len(d.date)-1;e2>=0;e2--)
         {
            if(e2==e) continue;
            delete_and_remove(d.date,e2);
            e=0;
         }
         d.timeleft=7;
         pool[p]->train(SKILL_SEDUCTION,LCSrandom(40)+15);
         pool[p]->train(SKILL_SCIENCE,
            max((d.date[e]->get_skill(SKILL_SCIENCE)-pool[p]->get_skill(SKILL_SCIENCE))*4,0));
         pool[p]->train(SKILL_RELIGION,
            max((d.date[e]->get_skill(SKILL_RELIGION)-pool[p]->get_skill(SKILL_RELIGION))*4,0));
         pool[p]->train(SKILL_BUSINESS,
            max((d.date[e]->get_skill(SKILL_BUSINESS)-pool[p]->get_skill(SKILL_BUSINESS))*4,0));
         return 0;
      }
      if(c==3)
      {
         delete_and_remove(d.date,e);
         continue;
      }
      if(c==4)
      {
         int bonus=0;
         if(pool[p]->get_weapon().is_ranged()) bonus=5;
         else if(pool[p]->is_armed())
         {
            if(pool[p]->get_weapon().can_take_hostages()) bonus=5;
            else bonus=-1;
         }
         else bonus+=pool[p]->get_skill(SKILL_HANDTOHAND)-1;

         if((!d.date[e]->kidnap_resistant()&&
             LCSrandom(15))||
             LCSrandom(2+bonus))
         {
            d.date[e]->namecreature();
            strcpy(d.date[e]->propername,d.date[e]->name);

            d.date[e]->location=pool[p]->location;
            d.date[e]->base=pool[p]->base;
            d.date[e]->flag|=CREATUREFLAG_MISSING;

            d.date[e]->drop_weapons_and_clips(NULL);
            Armor clothes(*armortype[getarmortype("ARMOR_CLOTHES")]);
            d.date[e]->give_armor(clothes,NULL);

            d.date[e]->activity.intr()=new interrogation;

            pool.push_back(d.date[e]);
            stat_kidnappings++;
            d.date.erase(d.date.begin()+e);
            continue;
         }
         else
         {
            if(LCSrandom(2))
            {
               criminalize(*pool[p],LAWFLAG_KIDNAPPING);
               delete_and_remove(d.date,e);
               continue;
            }
            else
            {
               int ps=find_police_station(*pool[p]);
               removesquadinfo(*pool[p]);
               pool[p]->carid=-1;
               pool[p]->location=ps;
               pool[p]->drop_weapons_and_clips(NULL);
               pool[p]->activity.type=ACTIVITY_NONE;
               criminalize(*pool[p],LAWFLAG_KIDNAPPING);
               delete_and_remove(d.date,e);
               return 1;
            }
         }
      }
   }

   if(len(d.date))
   {
      d.timeleft=0;
      return 0;
   }
   else return 1;
}



// The technique enum lives inside src/daily/interrogation.cpp rather than a
// header, so it is repeated here.
enum ProbeInterrogationTechniques
{
   TECHNIQUE_TALK,
   TECHNIQUE_RESTRAIN,
   TECHNIQUE_BEAT,
   TECHNIQUE_PROPS,
   TECHNIQUE_DRUGS,
   TECHNIQUE_KILL
};

// A transcription of tendhostage() from src/daily/interrogation.cpp with the
// display taken out and the plan supplied as a parameter rather than typed at
// the menu. Every roll is kept, including the ones that only pick a line of
// prose: they move the generator, so they are part of the behaviour.
//
// `plan` is a bitmask over the six techniques, applied before the menu would
// have been drawn. Returns 0 normally, 1 if the hostage escaped, 2 if they
// were converted, 3 if they died.
static int tend_block(Creature *cr, int plan, int *escaped_out)
{
   vector<Creature *> temppool;
   int p;
   Creature *a=NULL;
   *escaped_out = 0;

   interrogation* &intr=cr->activity.intr();
   bool (&techniques)[6]=intr->techniques;
   int& druguse = intr->druguse;
   map<long,struct float_zero>& rapport = intr->rapport;

   for(p=0;p<len(pool);p++)
   {
      if(!pool[p]->alive) continue;
      if(pool[p]->activity.type==ACTIVITY_HOSTAGETENDING&&pool[p]->activity.arg==cr->id)
      {
         if(pool[p]->location==cr->location&&pool[p]->location!=-1)
            temppool.push_back(pool[p]);
         else pool[p]->activity.type=ACTIVITY_NONE;
      }
   }

   if(cr->location==-1) return 0;

   // The plan is chosen before the escape check, as the menu is not reached
   // until afterwards; the restraint setting the check reads is yesterday's.
   bool wanted[6];
   for(int t=0;t<6;t++) wanted[t]=(plan>>t)&1;

   if(!len(temppool)||!techniques[TECHNIQUE_RESTRAIN])
   {
      if(LCSrandom(200)+25*len(temppool)<
         cr->get_attribute(ATTRIBUTE_INTELLIGENCE,true)+
         cr->get_attribute(ATTRIBUTE_AGILITY,true)+
         cr->get_attribute(ATTRIBUTE_STRENGTH,true)&&
         cr->joindays>=5)
      {
         for(int q=0;q<len(pool);q++)
            if(pool[q]==cr)
            {
               location[cr->location]->siege.timeuntillocated=3;
               for(int i=0;i<len(pool);i++)
               {
                  if(!pool[i]->alive) continue;
                  if(pool[i]->activity.type==ACTIVITY_HOSTAGETENDING&&pool[i]->activity.arg==cr->id)
                     pool[i]->activity.type=ACTIVITY_NONE;
               }
               delete intr;
               intr = NULL;
               delete_and_remove(pool,q);
               break;
            }
         *escaped_out = 1;
         return 1;
      }

      if(!len(temppool)) return 0;
   }

   char turned=0;
   int business=0,religion=0,science=0,attack=0;
   int* _attack = new int[len(temppool)];

   for(p=0;p<len(temppool);p++)
   {
      _attack[p] = 0;
      if(temppool[p] && temppool[p]->alive)
      {
         if(temppool[p]->get_skill(SKILL_BUSINESS)>business)
            business=temppool[p]->get_skill(SKILL_BUSINESS);
         if(temppool[p]->get_skill(SKILL_RELIGION)>religion)
            religion=temppool[p]->get_skill(SKILL_RELIGION);
         if(temppool[p]->get_skill(SKILL_SCIENCE)>science)
            science=temppool[p]->get_skill(SKILL_SCIENCE);

         _attack[p] = (temppool[p]->get_attribute(ATTRIBUTE_HEART,true)-
                       temppool[p]->get_attribute(ATTRIBUTE_WISDOM,true)+
                       temppool[p]->get_skill(SKILL_PSYCHOLOGY)*2);
         _attack[p] += temppool[p]->get_armor().get_interrogation_basepower();
         if(_attack[p]<0) _attack[p]=0;
         if(_attack[p]>attack) attack=_attack[p];
      }
   }

   vector<int> goodp;
   for(p=0;p<len(temppool);p++)
      if(temppool[p] && temppool[p]->alive && _attack[p]==attack)
         goodp.push_back(p);
   a=temppool[pickrandom(goodp)];

   attack+=len(temppool);
   attack+=cr->joindays;
   attack+=business-cr->get_skill(SKILL_BUSINESS);
   attack+=religion-cr->get_skill(SKILL_RELIGION);
   attack+=science-cr->get_skill(SKILL_SCIENCE);
   attack+=a->skill_roll(SKILL_PSYCHOLOGY)-cr->skill_roll(SKILL_PSYCHOLOGY);
   attack+=cr->attribute_roll(ATTRIBUTE_HEART);
   attack-=cr->attribute_roll(ATTRIBUTE_WISDOM)*2;

   // The menu, answered from the plan.
   for(int t=0;t<6;t++) techniques[t]=wanted[t];

   if(techniques[TECHNIQUE_PROPS]&&ledger.get_funds()>=250)
      ledger.subtract_funds(250,EXPENSE_HOSTAGE);
   else techniques[TECHNIQUE_PROPS]=0;
   if(techniques[TECHNIQUE_DRUGS]&&ledger.get_funds()>=50)
      ledger.subtract_funds(50,EXPENSE_HOSTAGE);
   else techniques[TECHNIQUE_DRUGS]=0;

   if(techniques[TECHNIQUE_KILL])
   {
      a=NULL;
      for(int i=0;i<len(temppool);i++)
         if(LCSrandom(50)<temppool[i]->juice||
            LCSrandom(9)+1>=temppool[i]->get_attribute(ATTRIBUTE_HEART,0))
         {  a=temppool[i]; break; }

      if(a)
      {
         delete intr;
         intr = NULL;
         cr->die();
         stat_kills++;
         LCSrandom(5);   // how it was done
         if(LCSrandom(a->get_attribute(ATTRIBUTE_HEART,false))>LCSrandom(3))
         {
            a->adjust_attribute(ATTRIBUTE_HEART,-1);
            LCSrandom(4);
         }
         else if(!LCSrandom(3))
            a->adjust_attribute(ATTRIBUTE_WISDOM,+1);
      }
      else
      {
         techniques[TECHNIQUE_TALK]=0;
         techniques[TECHNIQUE_BEAT]=0;
         techniques[TECHNIQUE_DRUGS]=0;
      }

      if(!cr->alive)
      {
         for(int q=0;q<len(pool);q++)
         {
            if(!pool[q]->alive) continue;
            if(pool[q]->activity.type==ACTIVITY_HOSTAGETENDING&&pool[q]->activity.arg==cr->id)
               pool[q]->activity.type=ACTIVITY_NONE;
         }
         delete[] _attack;
         return 3;
      }
   }

   if(techniques[TECHNIQUE_RESTRAIN]) attack+=5;

   if(techniques[TECHNIQUE_DRUGS])
   {
      int drugbonus=10+a->get_armor().get_interrogation_drugbonus();

      if(LCSrandom(50)<++druguse)
      {
         cr->adjust_attribute(ATTRIBUTE_HEALTH,-1);
         Creature* doctor=a;
         int maxskill=doctor->get_skill(SKILL_FIRSTAID);
         for(int i=0;i<len(temppool);i++)
            if(temppool[i]->get_skill(SKILL_FIRSTAID)>maxskill)
               maxskill=(doctor=temppool[i])->get_skill(SKILL_FIRSTAID);

         if(cr->get_attribute(ATTRIBUTE_HEALTH,false)<=0 || !maxskill)
         {
            cr->die();
         }
         else
         {
            if(doctor->skill_check(SKILL_FIRSTAID,DIFFICULTY_CHALLENGING))
            {
               doctor->train(SKILL_FIRSTAID,5*max(10-doctor->get_skill(SKILL_FIRSTAID),0),10);
               cr->adjust_attribute(ATTRIBUTE_HEALTH,+1);
               techniques[TECHNIQUE_DRUGS]=(druguse=drugbonus=0);
            }
            else
            {
               doctor->train(SKILL_FIRSTAID,5*max(5-doctor->get_skill(SKILL_FIRSTAID),0),5);
               drugbonus*=2;
            }
            rapport[doctor->id]+=0.5f;
         }
      }
      attack+=drugbonus;
   }

   if(techniques[TECHNIQUE_BEAT]&&!turned&&cr->alive)
   {
      int forceroll=0;
      bool tortured=0;

      for(int i=0;i<len(temppool);i++)
      {
         forceroll+=temppool[i]->attribute_roll(ATTRIBUTE_STRENGTH);
         rapport[temppool[i]->id]-=0.4f;
      }

      if(!(a->attribute_check(ATTRIBUTE_HEART,DIFFICULTY_EASY))&&techniques[TECHNIQUE_PROPS])
      {
         tortured = true;
         forceroll*=5;
         rapport[a->id]-=3;
         LCSrandom(6);                       // which torture
         for(int i=0;i<2;i++) LCSrandom(10); // what was screamed
         if(cr->get_attribute(ATTRIBUTE_HEART,true)>1) cr->adjust_attribute(ATTRIBUTE_HEART,-1);
         if(cr->get_attribute(ATTRIBUTE_WISDOM,true)>1) cr->adjust_attribute(ATTRIBUTE_WISDOM,-1);
      }
      else
      {
         if(techniques[TECHNIQUE_PROPS]) LCSrandom(6);  // which prop
         LCSrandom(4);                                  // scream/yell/shout
         for(int i=0;i<3;i++) LCSrandom(20);            // what was shouted
      }

      cr->blood-=(5 + LCSrandom(5)) * (1+techniques[TECHNIQUE_PROPS]);

      if(!(cr->attribute_check(ATTRIBUTE_HEALTH,forceroll)))
      {
         if(cr->skill_check(SKILL_RELIGION,forceroll))
         {
            LCSrandom(2);   // which prayer
         }
         else if(forceroll >
                 cr->get_attribute(ATTRIBUTE_WISDOM,true)*3+
                 cr->get_attribute(ATTRIBUTE_HEART,true)*3+
                 cr->get_attribute(ATTRIBUTE_HEALTH,true)*3)
         {
            switch(LCSrandom(4))
            {
            case 2: if(techniques[TECHNIQUE_DRUGS]) LCSrandom(5); break;
            case 3: if(techniques[TECHNIQUE_DRUGS]) LCSrandom(3); break;
            }
            if(cr->get_attribute(ATTRIBUTE_HEART,false)>1) cr->adjust_attribute(ATTRIBUTE_HEART,-1);

            if(LCSrandom(2)&&cr->juice>0) { if((cr->juice-=forceroll)<0) cr->juice=0; }
            else if(cr->get_attribute(ATTRIBUTE_WISDOM,false)>1)
            {
               cr->set_attribute(ATTRIBUTE_WISDOM,cr->get_attribute(ATTRIBUTE_WISDOM,false)-(forceroll/10));
               if(cr->get_attribute(ATTRIBUTE_WISDOM,false)<1) cr->set_attribute(ATTRIBUTE_WISDOM,1);
            }

            if(location[cr->worklocation]->mapped==0 && !LCSrandom(5))
            {
               location[cr->worklocation]->mapped=1;
               location[cr->worklocation]->hidden=0;
            }
         }
         else
         {
            if(cr->juice>0) if((cr->juice-=forceroll)<0) cr->juice=0;
            if(cr->get_attribute(ATTRIBUTE_WISDOM,false)>1)
            {
               cr->set_attribute(ATTRIBUTE_WISDOM,cr->get_attribute(ATTRIBUTE_WISDOM,false)-(forceroll/10+1));
               if(cr->get_attribute(ATTRIBUTE_WISDOM,false)<1) cr->set_attribute(ATTRIBUTE_WISDOM,1);
            }
         }

         if(!(cr->attribute_check(ATTRIBUTE_HEALTH,forceroll/3)))
         {
            if(cr->get_attribute(ATTRIBUTE_HEALTH,false)>1)
               cr->adjust_attribute(ATTRIBUTE_HEALTH,-1);
            else
            {
               cr->set_attribute(ATTRIBUTE_HEALTH,0);
               cr->die();
            }
         }
      }

      if(tortured && cr->alive)
      {
         if(LCSrandom(a->get_attribute(ATTRIBUTE_HEART,false))>LCSrandom(3))
         {
            a->adjust_attribute(ATTRIBUTE_HEART,-1);
            LCSrandom(4);
         }
         else if(!LCSrandom(3))
            a->adjust_attribute(ATTRIBUTE_WISDOM,+1);
      }
   }

   if(techniques[TECHNIQUE_TALK]&&cr->alive)
   {
      float rapport_temp = rapport[a->id];

      if(!techniques[TECHNIQUE_RESTRAIN])attack += 5;
      attack += int(rapport[a->id] * 3);

      if(techniques[TECHNIQUE_PROPS])
      {
         attack += 10;
         LCSrandom(9);   // which prop session
      }
      else
      {
         switch(LCSrandom(4))
         {
         case 0: LCSrandom(VIEWNUM-3); break;
         case 1: LCSrandom(VIEWNUM-3); break;
         }
      }

      if(techniques[TECHNIQUE_DRUGS])
      {
         if(cr->skill_check(SKILL_PSYCHOLOGY,DIFFICULTY_CHALLENGING))
         {
            LCSrandom(4);
         }
         else if((rapport[a->id]>1 && !LCSrandom(3)) || !LCSrandom(10))
         {
            rapport_temp=10;
            LCSrandom(4);
         }
         else if((rapport[a->id]<-1 && LCSrandom(3)) || !LCSrandom(5))
         {
            attack=0;
            LCSrandom(4);
         }
         else
         {
            LCSrandom(4);
         }
      }

      if(cr->get_skill(SKILL_PSYCHOLOGY)>a->get_skill(SKILL_PSYCHOLOGY))
      {
         LCSrandom(4);
      }
      else if(techniques[TECHNIQUE_BEAT] || rapport_temp < -2)
      {
         LCSrandom(7);
         if(a->skill_check(SKILL_SEDUCTION,DIFFICULTY_CHALLENGING))
         {
            LCSrandom(7);
            rapport[a->id]+=0.7f;
            if(rapport[a->id]>3)
            {
               LCSrandom(7);
               if(rapport[a->id]>5) turned=1;
            }
         }
         if(cr->get_attribute(ATTRIBUTE_HEART,false)>1) cr->adjust_attribute(ATTRIBUTE_HEART,-1);
      }
      else if(cr->get_skill(SKILL_RELIGION)>a->get_skill(SKILL_RELIGION)+a->get_skill(SKILL_PSYCHOLOGY) && !techniques[TECHNIQUE_DRUGS])
      {
         LCSrandom(4);
         a->train(SKILL_RELIGION,cr->get_skill(SKILL_RELIGION)*4);
      }
      else if(cr->get_skill(SKILL_BUSINESS)>a->get_skill(SKILL_BUSINESS)+a->get_skill(SKILL_PSYCHOLOGY) && !techniques[TECHNIQUE_DRUGS])
      {
         LCSrandom(4);
         a->train(SKILL_BUSINESS,cr->get_skill(SKILL_BUSINESS)*4);
      }
      else if(cr->get_skill(SKILL_SCIENCE)>a->get_skill(SKILL_SCIENCE)+a->get_skill(SKILL_PSYCHOLOGY) && !techniques[TECHNIQUE_DRUGS])
      {
         LCSrandom(4);
         a->train(SKILL_SCIENCE,cr->get_skill(SKILL_SCIENCE)*4);
      }
      else if(!(cr->attribute_check(ATTRIBUTE_WISDOM,attack/6)))
      {
         if(cr->juice>0)
         {
            cr->juice-=attack;
            if(cr->juice<0) cr->juice=0;
         }
         if(cr->get_attribute(ATTRIBUTE_HEART,false)<10)
            cr->adjust_attribute(ATTRIBUTE_HEART,+1);
         rapport[a->id]+=1.5;

         if(cr->get_attribute(ATTRIBUTE_HEART,true)>cr->get_attribute(ATTRIBUTE_WISDOM,true)+4) turned=1;
         if(rapport[a->id]>4) turned=1;

         LCSrandom(5);
         if(location[cr->worklocation]->mapped==0 && !LCSrandom(5))
         {
            location[cr->worklocation]->mapped=1;
            location[cr->worklocation]->hidden=0;
         }
      }
      else if(!(cr->skill_check(SKILL_PERSUASION,a->get_attribute(ATTRIBUTE_HEART, true))) || techniques[TECHNIQUE_PROPS])
      {
         rapport[a->id]+=0.2f;
      }
      else
      {
         rapport[a->id]+=0.5f;
         a->adjust_attribute(ATTRIBUTE_WISDOM,+1);
      }
   }

   if(!techniques[TECHNIQUE_KILL])
   {
      a->train(SKILL_PSYCHOLOGY,attack/2+1);
      for(int i=0;i<len(temppool);i++) temppool[i]->train(SKILL_PSYCHOLOGY,attack/4+1);
   }

   if(!turned&&cr->alive&&cr->get_attribute(ATTRIBUTE_HEART,false)<=1&&LCSrandom(3)&&cr->joindays>6)
   {
      if(LCSrandom(6)||techniques[TECHNIQUE_RESTRAIN])
      {
         switch(LCSrandom(5-techniques[TECHNIQUE_RESTRAIN]))
         {
         case 4: cr->blood-=LCSrandom(15)+10; break;
         }
      }
      else cr->die();
   }

   int outcome = 0;
   if(cr->alive==0||cr->blood<1)
   {
      delete intr;
      intr = NULL;
      cr->die();
      stat_kills++;
      outcome = 3;
      if(a)
      {
         if(LCSrandom(a->get_attribute(ATTRIBUTE_HEART,false)))
         {
            a->adjust_attribute(ATTRIBUTE_HEART,-1);
            LCSrandom(4);
         }
         else if(!LCSrandom(3))
            a->adjust_attribute(ATTRIBUTE_WISDOM,+1);
      }
   }
   delete[] _attack;

   if(turned&&cr->alive)
   {
      delete intr;
      intr = NULL;
      if(cr->get_attribute(ATTRIBUTE_HEART,true)>7 &&
         cr->get_attribute(ATTRIBUTE_WISDOM,true)>2 &&
        !LCSrandom(4) && (cr->flag & CREATUREFLAG_KIDNAPPED))
      {
         cr->flag&=~CREATUREFLAG_MISSING;
         cr->flag&=~CREATUREFLAG_KIDNAPPED;
      }
      cr->flag|=CREATUREFLAG_BRAINWASHED;

      for(int q=0;q<len(pool);q++)
         if(pool[q]->activity.type==ACTIVITY_HOSTAGETENDING&&pool[q]->activity.arg==cr->id)
            pool[q]->activity.type=ACTIVITY_NONE;

      liberalize(*cr,false);
      cr->hireid=a->id;
      stat_recruits++;

      if(location[cr->worklocation]->mapped==0 || location[cr->worklocation]->hidden==1)
      {
         location[cr->worklocation]->mapped=1;
         location[cr->worklocation]->hidden=0;
      }

      if(cr->flag & CREATUREFLAG_MISSING && !(cr->flag & CREATUREFLAG_KIDNAPPED))
      {
         // sleeperize_prompt(), answered "come home as a regular member".
         cr->location=a->location;
         cr->base=a->base;
         liberalize(*cr,false);
         cr->flag&=~CREATUREFLAG_MISSING;
         return 2;
      }
      return 2;
   }

   if(cr->align==1||!cr->alive) for(int q=0;q<len(pool);q++)
   {
      if(!pool[q]->alive) continue;
      if(pool[q]->activity.type==ACTIVITY_HOSTAGETENDING&&pool[q]->activity.arg==cr->id)
         pool[q]->activity.type=ACTIVITY_NONE;
   }

   return outcome;
}




// The business-front naming from investlocation(), lifted verbatim.
static void business_front_block(int loc)
{
   do
   {
               location[loc]->front_business=LCSrandom(BUSINESSFRONTNUM);
               lastname(location[loc]->front_name,true);
               strcat(location[loc]->front_name," ");
               switch(location[loc]->front_business)
               {
               case BUSINESSFRONT_INSURANCE:
                  switch(LCSrandom(7))
                  {
                  case 0:
                     strcat(location[loc]->front_name,"Auto");
                     strcpy(location[loc]->front_shortname,"Auto");
                     break;
                  case 1:
                     strcat(location[loc]->front_name,"Life");
                     strcpy(location[loc]->front_shortname,"Life");
                     break;
                  case 2:
                     strcat(location[loc]->front_name,"Health");
                     strcpy(location[loc]->front_shortname,"Health");
                     break;
                  case 3:
                     strcat(location[loc]->front_name,"Home");
                     strcpy(location[loc]->front_shortname,"Home");
                     break;
                  case 4:
                     strcat(location[loc]->front_name,"Boat");
                     strcpy(location[loc]->front_shortname,"Boat");
                     break;
                  case 5:
                     strcat(location[loc]->front_name,"Fire");
                     strcpy(location[loc]->front_shortname,"Fire");
                     break;
                  case 6:
                     strcat(location[loc]->front_name,"Flood");
                     strcpy(location[loc]->front_shortname,"Flood");
                     break;
                  }
                  strcat(location[loc]->front_name," Insurance");
                  strcat(location[loc]->front_shortname," Ins.");
                  break;
               case BUSINESSFRONT_TEMPAGENCY:
                  switch(LCSrandom(7))
                  {
                  case 0:
                     strcat(location[loc]->front_name,"Temp Agency");
                     strcpy(location[loc]->front_shortname,"Agency");
                     break;
                  case 1:
                     strcat(location[loc]->front_name,"Manpower, LLC");
                     strcpy(location[loc]->front_shortname,"Manpower");
                     break;
                  case 2:
                     strcat(location[loc]->front_name,"Staffing, Inc");
                     strcpy(location[loc]->front_shortname,"Staff");
                     break;
                  case 3:
                     strcat(location[loc]->front_name,"Labor Ready");
                     strcpy(location[loc]->front_shortname,"Labor");
                     break;
                  case 4:
                     strcat(location[loc]->front_name,"Employment");
                     strcpy(location[loc]->front_shortname,"Employ");
                     break;
                  case 5:
                     strcat(location[loc]->front_name,"Services");
                     strcpy(location[loc]->front_shortname,"Services");
                     break;
                  case 6:
                     strcat(location[loc]->front_name,"Solutions");
                     strcpy(location[loc]->front_shortname,"Solutns");
                     break;
                  }
                  break;
               case BUSINESSFRONT_RESTAURANT:
                  switch(LCSrandom(7))
                  {
                  case 0:
                     strcat(location[loc]->front_name,"Fried Chicken");
                     strcpy(location[loc]->front_shortname,"Chicken");
                     break;
                  case 1:
                     strcat(location[loc]->front_name,"Hamburgers");
                     strcpy(location[loc]->front_shortname,"Burgers");
                     break;
                  case 2:
                     strcat(location[loc]->front_name,"Steakhouse");
                     strcpy(location[loc]->front_shortname,"Steak");
                     break;
                  case 3:
                     strcat(location[loc]->front_name,"Wok Buffet");
                     strcpy(location[loc]->front_shortname,"Wok");
                     break;
                  case 4:
                     strcat(location[loc]->front_name,"Thai Cuisine");
                     strcpy(location[loc]->front_shortname,"Thai");
                     break;
                  case 5:
                     strcat(location[loc]->front_name,"Pizzeria");
                     strcpy(location[loc]->front_shortname,"Pizza");
                     break;
                  case 6:
                     strcat(location[loc]->front_name,"Fine Dining");
                     strcpy(location[loc]->front_shortname,"Diner");
                     break;
                  }
                  break;
               case BUSINESSFRONT_MISCELLANEOUS:
                  switch(LCSrandom(7))
                  {
                  case 0:
                     strcat(location[loc]->front_name,"Real Estate");
                     strcpy(location[loc]->front_shortname,"Realty");
                     break;
                  case 1:
                     strcat(location[loc]->front_name,"Imported Goods");
                     strcpy(location[loc]->front_shortname,"Import");
                     break;
                  case 2:
                     strcat(location[loc]->front_name,"Waste Disposal");
                     strcpy(location[loc]->front_shortname,"Disposal");
                     break;
                  case 3:
                     strcat(location[loc]->front_name,"Liquor Shop");
                     strcpy(location[loc]->front_shortname,"Liquor");
                     break;
                  case 4:
                     strcat(location[loc]->front_name,"Antiques");
                     strcpy(location[loc]->front_shortname,"Antique");
                     break;
                  case 5:
                     strcat(location[loc]->front_name,"Repair, Inc");
                     strcpy(location[loc]->front_shortname,"Repair");
                     break;
                  case 6:
                     strcat(location[loc]->front_name,"Pet Store");
                     strcpy(location[loc]->front_shortname,"Pets");
                     break;
                  }
                  break;
               }
            } while(location[loc]->duplicatelocation());
}






// A transcription of kidnap() from src/combat/haulkidnap.cpp with the screen
// work taken out: clearmessagearea() redraws the site map, and the site map
// rolls for its own animation, which has nothing to do with the grab.
static bool kidnap_block(Creature &a, Creature &t, bool &amateur)
{
   if(!a.get_weapon().can_take_hostages())
   {
      amateur=1;
      int aroll=a.skill_roll(SKILL_HANDTOHAND);
      int droll=t.attribute_check(ATTRIBUTE_AGILITY,true);
      a.train(SKILL_HANDTOHAND,droll);
      if(aroll>droll)
      {
         a.prisoner=new Creature;
         *a.prisoner=t;
         return 1;
      }
      return 0;
   }
   a.prisoner=new Creature;
   *a.prisoner=t;
   return 1;
}




// The prison control panels and the supercomputer.
static void prison_block(int which, int wing, int *freed_out, int *hacked_out)
{
   *freed_out = 0; *hacked_out = 0;
   if(which == 0)
   {
      short prison_control_type = wing == 0 ? SPECIAL_PRISON_CONTROL_LOW
                                : (wing == 1 ? SPECIAL_PRISON_CONTROL_MEDIUM
                                             : SPECIAL_PRISON_CONTROL_HIGH);
      int numleft=LCSrandom(8)+2;
      if(prison_control_type==SPECIAL_PRISON_CONTROL_LOW)
      {
         switch(law[LAW_DEATHPENALTY])
         {
            case -1: numleft=LCSrandom(6)+2;break;
            case -2: numleft=LCSrandom(3)+1;break;
         }
      }
      else if(prison_control_type==SPECIAL_PRISON_CONTROL_MEDIUM)
      {
         switch(law[LAW_DEATHPENALTY])
         {
            case 2: numleft=LCSrandom(4)+1;
            case 1: numleft=LCSrandom(6)+1;
         }
      }
      else if(prison_control_type==SPECIAL_PRISON_CONTROL_HIGH)
      {
         switch(law[LAW_DEATHPENALTY])
         {
            case  2: numleft=0;break;
            case  1: numleft=LCSrandom(4);break;
            case -1: numleft+=LCSrandom(4);break;
            case -2: numleft+=LCSrandom(4)+2;break;
         }
      }
      *freed_out = numleft;

      for(int e=0;e<ENCMAX;e++)
      {
         if(!encounter[e].exists)
         {
            makecreature(encounter[e],CREATURE_PRISONER);
            numleft--;
         }
         if(numleft==0)break;
      }

      int time=20+LCSrandom(10);
      if(time<1)time=1;
      if(sitealarmtimer>time||sitealarmtimer==-1)sitealarmtimer=time;

      partyrescue(prison_control_type);

      alienationcheck(1);
      noticecheck(-1);
      levelmap[locx][locy][locz].special=-1;
      sitecrime+=30;
      juiceparty(50,1000);
      sitestory->crime.push_back(CRIME_PRISON_RELEASE);
      criminalizeparty(LAWFLAG_HELPESCAPE);
      return;
   }

   // special_intel_supercomputer()
   if(sitealarm||sitealienate) return;
   char actual = 0;
   if(hack(HACK_SUPERCOMPUTER,actual))
   {
      if(endgamestate>=ENDGAME_CCS_APPEARANCE && endgamestate < ENDGAME_CCS_DEFEATED && ccsexposure<CCSEXPOSURE_LCSGOTDATA)
      {
         Item *it=new Loot(*loottype[getloottype("LOOT_CCS_BACKERLIST")]);
         activesquad->loot.push_back(it);
         ccsexposure=CCSEXPOSURE_LCSGOTDATA;
      }
      juiceparty(50,1000);
      Item *it=new Loot(*loottype[getloottype("LOOT_INTHQDISK")]);
      activesquad->loot.push_back(it);
      *hacked_out = 1;
   }
   if(actual)
   {
      int time=20+LCSrandom(10);
      if(time<1)time=1;
      if(sitealarmtimer>time||sitealarmtimer==-1)sitealarmtimer=time;
      alienationcheck(1);
      noticecheck(-1,DIFFICULTY_HARD);
      levelmap[locx][locy][locz].special=-1;
      sitecrime+=3;
      sitestory->crime.push_back(CRIME_HACK_INTEL);
      criminalizeparty(LAWFLAG_TREASON);
   }
}

void probe_prison_control(FILE *out)
{
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 86028121UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      make_world(false);
      uniqueCreatures.initialize();
      mode = GAMEMODE_SITE;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      for (int which = 0; which < 2; which++)
      for (int wing = 0; wing < 3; wing++)
      for (int death = -2; death <= 2; death++)
      for (int crowd = 1; crowd <= 3; crowd++)
      for (int grade = 0; grade < 4; grade++)
      for (int endgame = 0; endgame < 3; endgame++)
      {
         if (which == 1 && wing > 0) continue;   // one machine, not three
         unsigned long seed_used = 10500001UL * (unsigned long)
            (((((which * 3 + wing) * 5 + (death + 2)) * 3 + (crowd - 1)) * 4
              + grade) * 3 + endgame + scenario * 151 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
         law[LAW_DEATHPENALTY] = death;
         for (int v = 0; v < VIEWNUM; v++)
         {
            attitude[v] = (v * 13 + scenario * 7) % 101;
            public_interest[v] = (v * 3) % 40;
         }
         endgamestate = endgame == 0 ? ENDGAME_NONE
                      : (endgame == 1 ? ENDGAME_CCS_APPEARANCE
                                      : ENDGAME_CCS_DEFEATED);
         ccsexposure = CCSEXPOSURE_NONE;

         delete_and_clear(pool);
         delete_and_clear(squad);
         delete_and_clear(newsstory);
         for (int e = 0; e < ENCMAX; e++) encounter[e].exists = 0;

         cursite = 1;
         sitealarm = 0; sitealarmtimer = -1; sitecrime = 0; sitealienate = 0;
         locx = 3; locy = 3; locz = 0;
         initsite(*location[cursite]);
         levelmap[locx][locy][locz].flag = 0;
         levelmap[locx][locy][locz].special = 1;

         newsstoryst *ns = new newsstoryst;
         ns->type = NEWSSTORY_SQUAD_SITE;
         ns->loc = cursite;
         newsstory.push_back(ns);
         sitestory = ns;

         squadst *sq = new squadst;
         sq->id = 1;
         for (int i = 0; i < 6; i++) sq->squad[i] = NULL;
         squad.push_back(sq);
         activesquad = sq;

         for (int n = 0; n < crowd; n++)
         {
            Creature *cr = new Creature;
            makecreature(*cr, CREATURE_POLITICALACTIVIST);
            cr->id = 991000 + n;
            cr->align = ALIGN_LIBERAL;
            cr->location = cursite;
            cr->base = 2;
            cr->juice = 20 * (n + grade);
            cr->set_skill(SKILL_COMPUTERS, (grade * 5 + n) % 16);
            cr->set_skill(SKILL_STEALTH, (grade + n) % 8);
            // A blind hacker in one squad in four, so the handicap is real.
            if (grade == 3 && n == 0)
               cr->special[SPECIALWOUND_RIGHTEYE] = cr->special[SPECIALWOUND_LEFTEYE] = 0;
            cr->give_armor(*armortype[getarmortype("ARMOR_CLOTHES")], NULL);
            cr->squadid = sq->id;
            sq->squad[n] = cr;
            pool.push_back(cr);
         }

         // Two Liberals in the cells, one serving time and one condemned.
         for (int n = 0; n < 2; n++)
         {
            Creature *cr = new Creature;
            makecreature(*cr, CREATURE_POLITICALACTIVIST);
            cr->id = 991100 + n;
            cr->align = ALIGN_LIBERAL;
            cr->location = cursite;
            cr->base = cursite;
            cr->squadid = -1;
            cr->sentence = n ? -1 : 5;
            cr->deathpenalty = n;
            pool.push_back(cr);
         }

         fprintf(out, "{\"kind\":\"prison_control\",\"scenario\":%d,"
                      "\"seed\":%lu,\"which\":%d,\"wing\":%d,\"death\":%d,"
                      "\"crowd\":%d,\"grade\":%d,\"endgame\":%d,"
                      "\"world_seed\":%lu,\"site\":%d",
                 scenario, seed_used, which, wing, death, crowd, grade,
                 endgame, run_seed, cursite);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("],\"squad\":[", out);
         for (int n = 0; n < crowd; n++)
         {
            if (n) fputs(",", out);
            chase_write_creature(out, *sq->squad[n], true);
         }
         fputs("],\"prisoners\":[", out);
         for (int n = 0; n < 2; n++)
         {
            if (n) fputs(",", out);
            fprintf(out, "{\"sentence\":%d,\"death\":%d,\"person\":",
                    (int)pool[crowd + n]->sentence,
                    (int)pool[crowd + n]->deathpenalty);
            chase_write_creature(out, *pool[crowd + n], true);
            fputs("}", out);
         }
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         int freed = 0, hacked = 0;
         long long before = lcs_trace_draw_count();
         prison_block(which, wing, &freed, &hacked);

         int encounters = 0;
         for (int e = 0; e < ENCMAX; e++) if (encounter[e].exists) encounters++;
         int insquad = 0;
         for (int p = 0; p < 6; p++) if (sq->squad[p]) insquad++;

         fprintf(out, ",\"draws\":%lld,\"freed\":%d,\"hacked\":%d,"
                      "\"alarm\":%d,\"alarmtimer\":%d,\"crime\":%d,"
                      "\"alienate\":%d,\"encounters\":%d,\"insquad\":%d,"
                      "\"exposure\":%d,\"loot\":%d",
                 lcs_trace_draw_count() - before, freed, hacked,
                 (int)sitealarm, (int)sitealarmtimer, (int)sitecrime,
                 (int)sitealienate, encounters, insquad, ccsexposure,
                 len(sq->loot));
         fputs(",\"crimes\":[", out);
         for (int c = 0; c < len(ns->crime); c++)
            fprintf(out, "%s%d", c ? "," : "", ns->crime[c]);
         fputs("],\"squad_after\":[", out);
         for (int n = 0; n < crowd; n++)
         {
            if (n) fputs(",", out);
            fprintf(out, "{\"juice\":%d,\"computers\":%d}",
                    (int)sq->squad[n]->juice,
                    sq->squad[n]->get_skill(SKILL_COMPUTERS));
         }
         fputs("]}\n", out);

         for (int p = 0; p < 6; p++)
            if (sq->squad[p]) sq->squad[p]->prisoner = NULL;
         delete_and_clear(sq->loot);
         activesquad = NULL;
         delete_and_clear(squad);
         delete_and_clear(pool);
         delete_and_clear(newsstory);
         sitestory = NULL;
      }
   }
}

// The cells: two to nine strangers, and whoever the squad has lost to this
// building.
static void lockup_block(int courthouse, int *opened_out)
{
   *opened_out = 0;
   char actual = 0;
   if(unlock(UNLOCK_CELL,actual))
   {
      int numleft=LCSrandom(8)+2;
      for(int e=0;e<ENCMAX;e++)
      {
         if(!encounter[e].exists)
         {
            makecreature(encounter[e],CREATURE_PRISONER);
            numleft--;
         }
         if(numleft==0)break;
      }
      juiceparty(50,1000);
      sitecrime+=20;
      int time=20+LCSrandom(10);
      if(time<1)time=1;
      if(sitealarmtimer>time||sitealarmtimer==-1)sitealarmtimer=time;
      partyrescue(courthouse?SPECIAL_COURTHOUSE_LOCKUP:SPECIAL_POLICESTATION_LOCKUP);
      *opened_out = 1;
   }
   if(actual)
   {
      alienationcheck(1);
      noticecheck(-1,DIFFICULTY_HARD);
      levelmap[locx][locy][locz].special=-1;
      sitecrime+=courthouse?3:2;
      sitestory->crime.push_back(courthouse?CRIME_COURTHOUSE_LOCKUP:CRIME_POLICE_LOCKUP);
      criminalizeparty(LAWFLAG_HELPESCAPE);
   }
}

void probe_lockup(FILE *out)
{
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 67867967UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      make_world(false);
      uniqueCreatures.initialize();
      mode = GAMEMODE_SITE;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      for (int courthouse = 0; courthouse < 2; courthouse++)
      for (int crowd = 1; crowd <= 4; crowd++)
      for (int grade = 0; grade < 5; grade++)
      for (int held = 0; held < 4; held++)
      for (int room = 0; room < 2; room++)
      {
         unsigned long seed_used = 10000019UL * (unsigned long)
            ((((courthouse * 4 + (crowd - 1)) * 5 + grade) * 4 + held) * 2
             + room + scenario * 163 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
         for (int v = 0; v < VIEWNUM; v++)
         {
            attitude[v] = (v * 13 + scenario * 7) % 101;
            public_interest[v] = (v * 3) % 40;
         }

         delete_and_clear(pool);
         delete_and_clear(squad);
         delete_and_clear(newsstory);
         for (int e = 0; e < ENCMAX; e++) encounter[e].exists = 0;

         cursite = 1;
         sitealarm = 0; sitealarmtimer = -1; sitecrime = 0; sitealienate = 0;
         locx = 3; locy = 3; locz = 0;
         initsite(*location[cursite]);
         levelmap[locx][locy][locz].flag = 0;
         levelmap[locx][locy][locz].special = 1;

         newsstoryst *ns = new newsstoryst;
         ns->type = NEWSSTORY_SQUAD_SITE;
         ns->loc = cursite;
         newsstory.push_back(ns);
         sitestory = ns;

         squadst *sq = new squadst;
         sq->id = 1;
         for (int i = 0; i < 6; i++) sq->squad[i] = NULL;
         squad.push_back(sq);
         activesquad = sq;

         for (int n = 0; n < crowd; n++)
         {
            Creature *cr = new Creature;
            makecreature(*cr, CREATURE_POLITICALACTIVIST);
            cr->id = 990000 + n;
            cr->align = ALIGN_LIBERAL;
            cr->location = cursite;
            cr->base = 2;
            cr->juice = 20 * (n + grade);
            cr->set_skill(SKILL_SECURITY, (grade * 4 + n) % 18);
            cr->set_skill(SKILL_STEALTH, (grade + n) % 8);
            cr->give_armor(*armortype[getarmortype("ARMOR_CLOTHES")], NULL);
            cr->squadid = sq->id;
            sq->squad[n] = cr;
            pool.push_back(cr);
         }

         // Liberals already in this building, waiting to be let out.
         for (int n = 0; n < held; n++)
         {
            Creature *cr = new Creature;
            makecreature(*cr, CREATURE_POLITICALACTIVIST);
            cr->id = 990100 + n;
            cr->align = ALIGN_LIBERAL;
            cr->location = cursite;
            cr->base = cursite;
            cr->squadid = -1;
            cr->sentence = (n % 2) ? 5 : -1;
            cr->deathpenalty = (n == 3) ? 1 : 0;
            pool.push_back(cr);
         }

         for (int n = 0; n < room; n++)
         {
            makecreature(encounter[n], CREATURE_COP);
            encounter[n].exists = 1;
            encounter[n].align = ALIGN_CONSERVATIVE;
            encounter[n].id = 990200 + n;
         }

         fprintf(out, "{\"kind\":\"lockup\",\"scenario\":%d,\"seed\":%lu,"
                      "\"courthouse\":%d,\"crowd\":%d,\"grade\":%d,"
                      "\"held\":%d,\"room_count\":%d,\"world_seed\":%lu,"
                      "\"site\":%d",
                 scenario, seed_used, courthouse, crowd, grade, held, room,
                 run_seed, cursite);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("],\"squad\":[", out);
         for (int n = 0; n < crowd; n++)
         {
            if (n) fputs(",", out);
            chase_write_creature(out, *sq->squad[n], true);
         }
         fputs("],\"prisoners\":[", out);
         for (int n = 0; n < held; n++)
         {
            if (n) fputs(",", out);
            fprintf(out, "{\"sentence\":%d,\"death\":%d,\"person\":",
                    (int)pool[crowd + n]->sentence,
                    (int)pool[crowd + n]->deathpenalty);
            chase_write_creature(out, *pool[crowd + n], true);
            fputs("}", out);
         }
         fputs("],\"room\":[", out);
         for (int n = 0; n < room; n++)
         {
            if (n) fputs(",", out);
            chase_write_creature(out, encounter[n], true);
         }
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         int opened = 0;
         long long before = lcs_trace_draw_count();
         lockup_block(courthouse, &opened);

         int encounters = 0;
         for (int e = 0; e < ENCMAX; e++) if (encounter[e].exists) encounters++;
         int insquad = 0;
         for (int p = 0; p < 6; p++) if (sq->squad[p]) insquad++;

         fprintf(out, ",\"draws\":%lld,\"opened\":%d,\"alarm\":%d,"
                      "\"alarmtimer\":%d,\"crime\":%d,\"alienate\":%d,"
                      "\"encounters\":%d,\"insquad\":%d",
                 lcs_trace_draw_count() - before, opened, (int)sitealarm,
                 (int)sitealarmtimer, (int)sitecrime, (int)sitealienate,
                 encounters, insquad);
         fputs(",\"crimes\":[", out);
         for (int c = 0; c < len(ns->crime); c++)
            fprintf(out, "%s%d", c ? "," : "", ns->crime[c]);
         fputs("],\"freed\":[", out);
         for (int n = 0; n < held; n++)
         {
            Creature *cr = pool[crowd + n];
            int carried = 0;
            for (int p = 0; p < 6; p++)
               if (sq->squad[p] && sq->squad[p]->prisoner == cr) carried = 1;
            fprintf(out, "%s{\"id\":%d,\"squadid\":%d,\"location\":%d,"
                         "\"base\":%d,\"escaped\":%d,\"carried\":%d}",
                    n ? "," : "", (int)cr->id, (int)cr->squadid,
                    (int)cr->location, (int)cr->base,
                    (cr->flag & CREATUREFLAG_JUSTESCAPED) ? 1 : 0, carried);
         }
         fputs("],\"squad_after\":[", out);
         for (int n = 0; n < crowd; n++)
         {
            if (n) fputs(",", out);
            fprintf(out, "{\"juice\":%d,\"security\":%d,\"prisoner\":%d}",
                    (int)sq->squad[n]->juice,
                    sq->squad[n]->get_skill(SKILL_SECURITY),
                    sq->squad[n]->prisoner ? (int)sq->squad[n]->prisoner->id : 0);
         }
         fputs("]}\n", out);

         for (int p = 0; p < 6; p++)
            if (sq->squad[p]) sq->squad[p]->prisoner = NULL;
         activesquad = NULL;
         delete_and_clear(squad);
         delete_and_clear(pool);
         delete_and_clear(newsstory);
         sitestory = NULL;
      }
   }
}

// Breaking the fittings: the machines, the cases, the cages, the walls and the
// reactor. Each is transcribed with the prompt answered yes and the display
// taken out.
static void special_block(int which, int *opened_out)
{
   *opened_out = 0;
   char actual = 0;
   switch(which)
   {
   case 0: // special_sweatshop_equipment()
   {
      int time=20+LCSrandom(10);
      if(time<1)time=1;
      if(sitealarmtimer>time||sitealarmtimer==-1)sitealarmtimer=time;
      alienationcheck(0);
      noticecheck(-1,DIFFICULTY_HEROIC);
      levelmap[locx][locy][locz].special=-1;
      levelmap[locx][locy][locz].flag|=SITEBLOCK_DEBRIS;
      sitecrime++;
      juiceparty(5,100);
      sitestory->crime.push_back(CRIME_BREAK_SWEATSHOP);
      criminalizeparty(LAWFLAG_VANDALISM);
      break;
   }
   case 1: // special_polluter_equipment()
   {
      int time=20+LCSrandom(10);
      if(time<1)time=1;
      if(sitealarmtimer>time||sitealarmtimer==-1)sitealarmtimer=time;
      change_public_opinion(VIEW_POLLUTION,2,1,70);
      alienationcheck(0);
      noticecheck(-1,DIFFICULTY_HEROIC);
      levelmap[locx][locy][locz].special=-1;
      levelmap[locx][locy][locz].flag|=SITEBLOCK_DEBRIS;
      sitecrime+=2;
      juiceparty(5,100);
      sitestory->crime.push_back(CRIME_BREAK_FACTORY);
      criminalizeparty(LAWFLAG_VANDALISM);
      break;
   }
   case 2: // special_display_case()
   {
      int time=20+LCSrandom(10);
      if(time<1)time=1;
      if(sitealarmtimer>time||sitealarmtimer==-1)sitealarmtimer=time;
      alienationcheck(0);
      noticecheck(-1,DIFFICULTY_HEROIC);
      levelmap[locx][locy][locz].special=-1;
      levelmap[locx][locy][locz].flag|=SITEBLOCK_DEBRIS;
      sitecrime++;
      juiceparty(5,100);
      sitestory->crime.push_back(CRIME_VANDALISM);
      criminalizeparty(LAWFLAG_VANDALISM);
      break;
   }
   case 3: // special_graffiti()
   {
      if(!sitestory->claimed) sitestory->claimed=1;
      int time=20+LCSrandom(10);
      if(time<1)time=1;
      if(sitealarmtimer>time||sitealarmtimer==-1)sitealarmtimer=time;
      alienationcheck(0);
      noticecheck(-1,DIFFICULTY_HARD);
      levelmap[locx][locy][locz].flag|=SITEBLOCK_GRAFFITI;
      levelmap[locx][locy][locz].flag&=~(SITEBLOCK_GRAFFITI_CCS|SITEBLOCK_GRAFFITI_OTHER);
      if(!location[cursite]->highsecurity)
      {
         for(int i=0;i<len(location[cursite]->changes);i++)
         {
            if((location[cursite]->changes[i].x == locx) &&
               (location[cursite]->changes[i].y == locy) &&
               (location[cursite]->changes[i].z == locz) &&
               ((location[cursite]->changes[i].flag == SITEBLOCK_GRAFFITI) ||
                (location[cursite]->changes[i].flag == SITEBLOCK_GRAFFITI_CCS) ||
                (location[cursite]->changes[i].flag == SITEBLOCK_GRAFFITI_OTHER)))
            {
               location[cursite]->changes.erase(location[cursite]->changes.begin()+i);
               break;
            }
         }
         struct sitechangest change(locx,locy,locz,SITEBLOCK_GRAFFITI);
         location[cursite]->changes.push_back(change);
      }
      sitecrime++;
      for(int i=0;i<6;i++)
         if(activesquad->squad[i]) addjuice(*(activesquad->squad[i]),1,50);
      criminalizeparty(LAWFLAG_VANDALISM);
      sitestory->crime.push_back(CRIME_TAGGING);
      break;
   }
   case 4: // special_lab_cosmetics_cagedanimals()
   case 5: // special_lab_genetic_cagedanimals()
   {
      if(unlock(which==4?UNLOCK_CAGE:UNLOCK_CAGE_HARD,actual))
      {
         int time=20+LCSrandom(10);
         if(time<1)time=1;
         if(sitealarmtimer>time||sitealarmtimer==-1)sitealarmtimer=time;
         sitecrime++;
         juiceparty(3,100);
         sitestory->crime.push_back(which==4?CRIME_FREE_RABBITS:CRIME_FREE_BEASTS);
         criminalizeparty(LAWFLAG_VANDALISM);
         *opened_out = 1;
      }
      if(actual)
      {
         alienationcheck(0);
         noticecheck(-1);
         levelmap[locx][locy][locz].special=-1;
      }
      break;
   }
   default: // special_nuclear_onoff()
   {
      levelmap[locx][locy][locz].special=-1;
      char max=DIFFICULTY_HARD;
      Creature* maxs=0;
      for(int p=0;p<6;p++)
      {
         if(activesquad->squad[p]!=NULL&&activesquad->squad[p]->alive)
            if(activesquad->squad[p]->skill_check(SKILL_SCIENCE,max))
            {
               maxs=activesquad->squad[p];
               break;
            }
      }
      if(maxs)
      {
         if(law[LAW_NUCLEARPOWER]==2)
         {
            change_public_opinion(VIEW_NUCLEARPOWER,15,0,95);
            change_public_opinion(VIEW_LIBERALCRIMESQUADPOS,-50,0,0);
            juiceparty(40,1000);
            sitecrime+=25;
            sitestory->crime.push_back(CRIME_SHUTDOWNREACTOR);
         }
         else
         {
            change_public_opinion(VIEW_NUCLEARPOWER,15,0,95);
            juiceparty(100,1000);
            sitecrime+=50;
            sitestory->crime.push_back(CRIME_SHUTDOWNREACTOR);
         }
         *opened_out = 1;
      }
      else juiceparty(15,500);
      sitealarm=1;
      alienationcheck(1);
      levelmap[locx][locy][locz].special=-1;
      sitecrime+=5;
      criminalizeparty(LAWFLAG_TERRORISM);
      break;
   }
   }
}

void probe_site_specials(FILE *out)
{
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 49979687UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      make_world(false);
      uniqueCreatures.initialize();
      mode = GAMEMODE_SITE;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      for (int which = 0; which < 7; which++)
      for (int crowd = 1; crowd <= 3; crowd++)
      for (int grade = 0; grade < 4; grade++)
      for (int room = 0; room < 3; room++)
      for (int nuclear = 0; nuclear < 2; nuclear++)
      for (int guarded = 0; guarded < 2; guarded++)
      {
         unsigned long seed_used = 9700079UL * (unsigned long)
            (((((which * 3 + (crowd - 1)) * 4 + grade) * 3 + room) * 2
              + nuclear) * 2 + guarded + scenario * 173 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
         law[LAW_NUCLEARPOWER] = nuclear ? 2 : 0;
         for (int v = 0; v < VIEWNUM; v++)
         {
            attitude[v] = (v * 13 + scenario * 7) % 101;
            public_interest[v] = (v * 3) % 40;
            background_liberal_influence[v] = 0;
         }

         delete_and_clear(pool);
         delete_and_clear(squad);
         delete_and_clear(newsstory);
         for (int e = 0; e < ENCMAX; e++) encounter[e].exists = 0;

         cursite = 1;
         location[cursite]->highsecurity = guarded;
         location[cursite]->changes.clear();
         if (guarded == 0)
         {
            struct sitechangest old(3,3,0,SITEBLOCK_GRAFFITI_CCS);
            location[cursite]->changes.push_back(old);
         }
         sitealarm = 0;
         sitealarmtimer = -1;
         sitecrime = 0;
         sitealienate = 0;
         locx = 3; locy = 3; locz = 0;
         initsite(*location[cursite]);
         levelmap[locx][locy][locz].flag = 0;
         levelmap[locx][locy][locz].special = 1;

         newsstoryst *ns = new newsstoryst;
         ns->type = NEWSSTORY_SQUAD_SITE;
         ns->loc = cursite;
         ns->claimed = 0;
         newsstory.push_back(ns);
         sitestory = ns;

         squadst *sq = new squadst;
         sq->id = 1;
         for (int i = 0; i < 6; i++) sq->squad[i] = NULL;
         squad.push_back(sq);
         activesquad = sq;

         for (int n = 0; n < crowd; n++)
         {
            Creature *cr = new Creature;
            makecreature(*cr, CREATURE_POLITICALACTIVIST);
            cr->id = 980000 + n;
            cr->align = ALIGN_LIBERAL;
            cr->location = cursite;
            cr->base = cursite;
            cr->juice = 20 * (n + grade);
            cr->set_skill(SKILL_SECURITY, (grade * 3 + n) % 12);
            cr->set_skill(SKILL_SCIENCE, (grade * 4 + n) % 14);
            cr->set_skill(SKILL_STEALTH, (grade + n) % 8);
            cr->give_armor(*armortype[getarmortype("ARMOR_CLOTHES")], NULL);
            cr->squadid = sq->id;
            sq->squad[n] = cr;
            pool.push_back(cr);
         }

         // Somebody in the room to notice, sometimes.
         for (int n = 0; n < room; n++)
         {
            makecreature(encounter[n], CREATURE_WORKER_JANITOR);
            encounter[n].exists = 1;
            encounter[n].align = ALIGN_CONSERVATIVE;
            encounter[n].id = 980100 + n;
         }

         fprintf(out, "{\"kind\":\"site_specials\",\"scenario\":%d,"
                      "\"seed\":%lu,\"which\":%d,\"crowd\":%d,\"grade\":%d,"
                      "\"room_count\":%d,\"nuclear\":%d,\"guarded\":%d,"
                      "\"world_seed\":%lu,\"site\":%d",
                 scenario, seed_used, which, crowd, grade, room, nuclear,
                 guarded, run_seed, cursite);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("],\"squad\":[", out);
         for (int n = 0; n < crowd; n++)
         {
            if (n) fputs(",", out);
            chase_write_creature(out, *sq->squad[n], true);
         }
         fputs("],\"room\":[", out);
         for (int n = 0; n < room; n++)
         {
            if (n) fputs(",", out);
            chase_write_creature(out, encounter[n], true);
         }
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         int opened = 0;
         long long before = lcs_trace_draw_count();
         special_block(which, &opened);

         fprintf(out, ",\"draws\":%lld,\"opened\":%d,\"alarm\":%d,"
                      "\"alarmtimer\":%d,\"crime\":%d,\"alienate\":%d,"
                      "\"flag\":%d,\"special\":%d,\"claimed\":%d,"
                      "\"changes\":%d",
                 lcs_trace_draw_count() - before, opened, (int)sitealarm,
                 (int)sitealarmtimer, (int)sitecrime, (int)sitealienate,
                 (int)levelmap[locx][locy][locz].flag,
                 (int)levelmap[locx][locy][locz].special,
                 (int)ns->claimed, len(location[cursite]->changes));
         fputs(",\"crimes\":[", out);
         for (int c = 0; c < len(ns->crime); c++)
            fprintf(out, "%s%d", c ? "," : "", ns->crime[c]);
         fputs("],\"attitude_after\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"squad_after\":[", out);
         for (int n = 0; n < crowd; n++)
         {
            if (n) fputs(",", out);
            fprintf(out, "{\"juice\":%d,\"security\":%d,\"suspected\":[",
                    (int)sq->squad[n]->juice,
                    sq->squad[n]->get_skill(SKILL_SECURITY));
            for (int f = 0; f < LAWFLAGNUM; f++)
               fprintf(out, "%s%d", f ? "," : "",
                       (int)sq->squad[n]->crimes_suspected[f]);
            fputs("]}", out);
         }
         fputs("]}\n", out);

         activesquad = NULL;
         delete_and_clear(squad);
         delete_and_clear(pool);
         delete_and_clear(newsstory);
         sitestory = NULL;
      }
   }
}

// Cash is written by its amount: the original keeps that separate from the
// stack count, and the port keeps it in the count.
static void vault_write_loot(FILE *out, vector<Item *> &pile)
{
   for (int i = 0; i < len(pile); i++)
   {
      fprintf(out, "%s{\"type\":", i ? "," : "");
      write_string(out, pile[i]->get_itemtypename().c_str());
      if (pile[i]->is_money())
         fprintf(out, ",\"money\":1,\"number\":%ld",
                 static_cast<Money *>(pile[i])->get_amount());
      else
         fprintf(out, ",\"money\":0,\"number\":%ld", pile[i]->get_number());
      if (pile[i]->is_weapon())
      {
         Weapon *w = static_cast<Weapon *>(pile[i]);
         fprintf(out, ",\"ammo\":%d", w->get_ammoamount());
      }
      fputs("}", out);
   }
}

// Safes, armouries and juries: the specials that hand out equipment or
// argue with strangers. Each is transcribed from src/sitemode/mapspecials.cpp
// with the prompt answered yes and the display taken out.
static void vault_block(int which, int *opened_out)
{
   *opened_out = 0;
   char actual = 0;
   switch(which)
   {
   case 0: // special_courthouse_jury()
   {
      if(sitealarm||sitealienate) return;
      levelmap[locx][locy][locz].special=-1;
      char succeed=0;
      int maxattack=0;
      int maxp=-1;
      for(int p=0;p<6;p++)
      {
         if(activesquad->squad[p]!=NULL&&activesquad->squad[p]->alive)
         {
            if(activesquad->squad[p]->get_attribute(ATTRIBUTE_CHARISMA,true)+
               activesquad->squad[p]->get_attribute(ATTRIBUTE_INTELLIGENCE,true)+
               activesquad->squad[p]->get_skill(SKILL_PERSUASION)+
               activesquad->squad[p]->get_skill(SKILL_LAW)>maxattack)
            {
               maxattack = activesquad->squad[p]->get_attribute(ATTRIBUTE_CHARISMA,true)+
                           activesquad->squad[p]->get_attribute(ATTRIBUTE_INTELLIGENCE,true)+
                           activesquad->squad[p]->get_skill(SKILL_PERSUASION)+
                           activesquad->squad[p]->get_skill(SKILL_LAW);
               maxp = p;
            }
         }
      }
      if(maxp > -1)
      {
         int p=maxp;
         activesquad->squad[p]->train(SKILL_PERSUASION,20);
         activesquad->squad[p]->train(SKILL_LAW,20);
         if(activesquad->squad[p]->skill_check(SKILL_PERSUASION,DIFFICULTY_HARD) &&
            activesquad->squad[p]->skill_check(SKILL_LAW,DIFFICULTY_CHALLENGING))succeed=1;
         if(succeed)
         {
            LCSrandom(16);
            alienationcheck(0);
            noticecheck(-1);
            addjuice(*(activesquad->squad[p]),25,200);
            *opened_out = 1;
         }
         else
         {
            int numleft=12;
            for(int e=0;e<ENCMAX;e++)
            {
               if(!encounter[e].exists)
               {
                  makecreature(encounter[e],CREATURE_JUROR);
                  numleft--;
               }
               if(numleft==0)break;
            }
            sitealarm=1;
            sitealienate=2;
            sitecrime+=10;
            sitestory->crime.push_back(CRIME_JURYTAMPERING);
            criminalizeparty(LAWFLAG_JURY);
         }
      }
      break;
   }
   case 1: // special_armory()
   {
      sitealarm=1;
      bool empty=true;
      Item *it;
      if(m249==false && location[cursite]->type == SITE_GOVERNMENT_ARMYBASE)
      {
         Weapon* de=new Weapon(*weapontype[getweapontype("WEAPON_M249_MACHINEGUN")]);
         Clip r(*cliptype[getcliptype("CLIP_DRUM")]);
         de->reload(r);
         activesquad->loot.push_back(de);
         it=new Clip(*cliptype[getcliptype("CLIP_DRUM")],9);
         activesquad->loot.push_back(it);
         m249=true;
         empty=false;
      }
      if(LCSrandom(2))
      {
         int num = 0;
         do
         {
            Weapon* de=new Weapon(*weapontype[getweapontype("WEAPON_AUTORIFLE_M16")]);
            Clip r(*cliptype[getcliptype("CLIP_ASSAULT")]);
            de->reload(r);
            activesquad->loot.push_back(de);
            it=new Clip(*cliptype[getcliptype("CLIP_ASSAULT")],5);
            activesquad->loot.push_back(it);
            num++;
         } while(num<2 || (LCSrandom(2) && num<5));
         empty=false;
      }
      if(LCSrandom(2))
      {
         int num = 0;
         do
         {
            Weapon* de=new Weapon(*weapontype[getweapontype("WEAPON_CARBINE_M4")]);
            Clip r(*cliptype[getcliptype("CLIP_ASSAULT")]);
            de->reload(r);
            activesquad->loot.push_back(de);
            it=new Clip(*cliptype[getcliptype("CLIP_ASSAULT")],5);
            activesquad->loot.push_back(it);
            num++;
         } while(num<2 || (LCSrandom(2) && num<5));
         empty=false;
      }
      if(LCSrandom(2))
      {
         int num = 0;
         do
         {
            Armor* de;
            if(location[cursite]->type == SITE_GOVERNMENT_ARMYBASE)
               de=new Armor(*armortype[getarmortype("ARMOR_ARMYARMOR")]);
            else
               de=new Armor(*armortype[getarmortype("ARMOR_CIVILLIANARMOR")]);
            activesquad->loot.push_back(de);
            num++;
         } while(num<2 || (LCSrandom(2) && num<5));
         empty=false;
      }
      if(empty)
      {
         criminalizeparty(LAWFLAG_TREASON);
         int numleft=LCSrandom(8)+2;
         for(int e=0;e<ENCMAX;e++)
         {
            if(!encounter[e].exists)
            {
               if(location[cursite]->type == SITE_GOVERNMENT_ARMYBASE)
                  makecreature(encounter[e],CREATURE_SOLDIER);
               else
                  makecreature(encounter[e],CREATURE_MERC);
               numleft--;
            }
            if(numleft==0)break;
         }
      }
      else
      {
         juiceparty(50,1000);
         sitecrime+=40;
         sitestory->crime.push_back(CRIME_ARMORY);
         criminalizeparty(LAWFLAG_THEFT);
         criminalizeparty(LAWFLAG_TREASON);
         int time=20+LCSrandom(10);
         if(time<1)time=1;
         if(sitealarmtimer>time||sitealarmtimer==-1)sitealarmtimer=time;
         int numleft=LCSrandom(4)+2;
         for(int e=0;e<ENCMAX;e++)
         {
            if(!encounter[e].exists)
            {
               if(location[cursite]->type == SITE_GOVERNMENT_ARMYBASE)
                  makecreature(encounter[e],CREATURE_SOLDIER);
               else
                  makecreature(encounter[e],CREATURE_MERC);
               numleft--;
            }
            if(numleft==0)break;
         }
         *opened_out = 1;
      }
      alienationcheck(0);
      noticecheck(-1);
      levelmap[locx][locy][locz].special=-1;
      break;
   }
   case 2: // special_corporate_files()
   {
      if(unlock(UNLOCK_SAFE,actual))
      {
         Item *it=new Loot(*loottype[getloottype("LOOT_CORPFILES")]);
         activesquad->loot.push_back(it);
         it=new Loot(*loottype[getloottype("LOOT_CORPFILES")]);
         activesquad->loot.push_back(it);
         juiceparty(50,1000);
         sitecrime+=40;
         int time=20+LCSrandom(10);
         if(time<1)time=1;
         if(sitealarmtimer>time||sitealarmtimer==-1)sitealarmtimer=time;
         *opened_out = 1;
      }
      if(actual)
      {
         alienationcheck(0);
         noticecheck(-1);
         levelmap[locx][locy][locz].special=-1;
         sitecrime+=3;
         sitestory->crime.push_back(CRIME_CORP_FILES);
         criminalizeparty(LAWFLAG_THEFT);
      }
      break;
   }
   default: // special_house_photos()
   {
      if(unlock(UNLOCK_SAFE,actual))
      {
         bool empty=true;
         Item *it;
         if(deagle==false)
         {
            Weapon* de=new Weapon(*weapontype[getweapontype("WEAPON_DESERT_EAGLE")]);
            Clip r(*cliptype[getcliptype("CLIP_50AE")]);
            de->reload(r);
            activesquad->loot.push_back(de);
            it=new Clip(*cliptype[getcliptype("CLIP_50AE")],9);
            activesquad->loot.push_back(it);
            deagle=true;
            empty=false;
         }
         if(LCSrandom(2))
         {
            it=new Money(1000*(1+LCSrandom(10)));
            activesquad->loot.push_back(it);
            empty=false;
         }
         if(LCSrandom(2))
         {
            it=new Loot(*loottype[getloottype("LOOT_EXPENSIVEJEWELERY")],3);
            activesquad->loot.push_back(it);
            empty=false;
         }
         if(!LCSrandom(3))
         {
            it=new Loot(*loottype[getloottype("LOOT_CEOPHOTOS")]);
            activesquad->loot.push_back(it);
            empty=false;
         }
         if(!LCSrandom(3)) empty=false;
         if(!LCSrandom(3))
         {
            it=new Loot(*loottype[getloottype("LOOT_CEOLOVELETTERS")]);
            activesquad->loot.push_back(it);
            empty=false;
         }
         if(!LCSrandom(3))
         {
            it=new Loot(*loottype[getloottype("LOOT_CEOTAXPAPERS")]);
            activesquad->loot.push_back(it);
            empty=false;
         }
         if(!empty)
         {
            juiceparty(50,1000);
            sitecrime+=40;
            sitestory->crime.push_back(CRIME_HOUSE_PHOTOS);
            criminalizeparty(LAWFLAG_THEFT);
            int time=20+LCSrandom(10);
            if(time<1)time=1;
            if(sitealarmtimer>time||sitealarmtimer==-1)sitealarmtimer=time;
            *opened_out = 1;
         }
      }
      if(actual)
      {
         alienationcheck(0);
         noticecheck(-1);
         levelmap[locx][locy][locz].special=-1;
      }
      break;
   }
   }
}

void probe_vaults(FILE *out)
{
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 32452843UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      make_world(false);
      uniqueCreatures.initialize();
      mode = GAMEMODE_SITE;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      for (int which = 0; which < 4; which++)
      for (int crowd = 1; crowd <= 3; crowd++)
      for (int grade = 0; grade < 4; grade++)
      for (int room = 0; room < 3; room++)
      for (int army = 0; army < 2; army++)
      for (int taken = 0; taken < 2; taken++)
      for (int noticed = 0; noticed < 2; noticed++)
      {
         unsigned long seed_used = 15485863UL * (unsigned long)
            (((((((which * 3 + (crowd - 1)) * 4 + grade) * 3 + room) * 2
              + army) * 2 + taken) * 2 + noticed) + scenario * 991 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
         for (int v = 0; v < VIEWNUM; v++)
         {
            attitude[v] = (v * 17 + scenario * 5) % 101;
            public_interest[v] = (v * 3) % 40;
            background_liberal_influence[v] = 0;
         }

         delete_and_clear(pool);
         delete_and_clear(squad);
         delete_and_clear(newsstory);
         for (int e = 0; e < ENCMAX; e++) encounter[e].exists = 0;

         deagle = taken ? true : false;
         m249 = taken ? true : false;

         cursite = 1;
         location[cursite]->type = army ? SITE_GOVERNMENT_ARMYBASE
                                        : SITE_CORPORATE_HEADQUARTERS;
         location[cursite]->highsecurity = 0;
         sitealarm = (which == 0 && noticed) ? 1 : 0;
         sitealarmtimer = -1;
         sitecrime = 0;
         sitealienate = 0;
         locx = 3; locy = 3; locz = 0;
         initsite(*location[cursite]);
         levelmap[locx][locy][locz].flag = 0;
         levelmap[locx][locy][locz].special = 1;

         newsstoryst *ns = new newsstoryst;
         ns->type = NEWSSTORY_SQUAD_SITE;
         ns->loc = cursite;
         ns->claimed = 0;
         newsstory.push_back(ns);
         sitestory = ns;

         squadst *sq = new squadst;
         sq->id = 1;
         for (int i = 0; i < 6; i++) sq->squad[i] = NULL;
         squad.push_back(sq);
         activesquad = sq;

         for (int n = 0; n < crowd; n++)
         {
            Creature *cr = new Creature;
            makecreature(*cr, CREATURE_LAWYER);
            cr->id = 970000 + n;
            cr->align = ALIGN_LIBERAL;
            cr->location = cursite;
            cr->base = cursite;
            cr->juice = 20 * (n + grade);
            cr->set_skill(SKILL_SECURITY, (grade * 3 + n) % 12);
            cr->set_skill(SKILL_PERSUASION, (grade * 2 + n) % 10);
            cr->set_skill(SKILL_LAW, (grade * 5 + n) % 13);
            cr->set_skill(SKILL_STEALTH, (grade + n) % 8);
            cr->give_armor(*armortype[getarmortype("ARMOR_CLOTHES")], NULL);
            cr->squadid = sq->id;
            sq->squad[n] = cr;
            pool.push_back(cr);
         }

         for (int n = 0; n < room; n++)
         {
            makecreature(encounter[n], CREATURE_WORKER_SECRETARY);
            encounter[n].exists = 1;
            encounter[n].align = ALIGN_CONSERVATIVE;
            encounter[n].id = 970100 + n;
         }

         fprintf(out, "{\"kind\":\"vaults\",\"scenario\":%d,"
                      "\"seed\":%lu,\"which\":%d,\"crowd\":%d,\"grade\":%d,"
                      "\"room_count\":%d,\"army\":%d,\"taken\":%d,"
                      "\"noticed\":%d,\"world_seed\":%lu,\"site\":%d",
                 scenario, seed_used, which, crowd, grade, room, army, taken,
                 noticed, run_seed, cursite);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("],\"squad\":[", out);
         for (int n = 0; n < crowd; n++)
         {
            if (n) fputs(",", out);
            chase_write_creature(out, *sq->squad[n], true);
         }
         fputs("],\"room\":[", out);
         for (int n = 0; n < room; n++)
         {
            if (n) fputs(",", out);
            chase_write_creature(out, encounter[n], true);
         }
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         int opened = 0;
         long long before = lcs_trace_draw_count();
         vault_block(which, &opened);

         int encount = 0;
         for (int e = 0; e < ENCMAX; e++) if (encounter[e].exists) encount++;

         fprintf(out, ",\"draws\":%lld,\"opened\":%d,\"alarm\":%d,"
                      "\"alarmtimer\":%d,\"crime\":%d,\"alienate\":%d,"
                      "\"special\":%d,\"encounters\":%d,\"deagle\":%d,"
                      "\"m249\":%d",
                 lcs_trace_draw_count() - before, opened, (int)sitealarm,
                 (int)sitealarmtimer, (int)sitecrime, (int)sitealienate,
                 (int)levelmap[locx][locy][locz].special, encount,
                 deagle ? 1 : 0, m249 ? 1 : 0);
         fputs(",\"crimes\":[", out);
         for (int c = 0; c < len(ns->crime); c++)
            fprintf(out, "%s%d", c ? "," : "", ns->crime[c]);
         fputs("],\"loot\":[", out);
         vault_write_loot(out, activesquad->loot);
         fputs("],\"squad_after\":[", out);
         for (int n = 0; n < crowd; n++)
         {
            if (n) fputs(",", out);
            fprintf(out, "{\"juice\":%d,\"security\":%d,\"persuasion\":%d,"
                         "\"law\":%d,\"suspected\":[",
                    (int)sq->squad[n]->juice,
                    sq->squad[n]->get_skill(SKILL_SECURITY),
                    sq->squad[n]->get_skill(SKILL_PERSUASION),
                    sq->squad[n]->get_skill(SKILL_LAW));
            for (int f = 0; f < LAWFLAGNUM; f++)
               fprintf(out, "%s%d", f ? "," : "",
                       (int)sq->squad[n]->crimes_suspected[f]);
            fputs("]}", out);
         }
         fputs("]}\n", out);

         activesquad = NULL;
         delete_and_clear(squad);
         delete_and_clear(pool);
         delete_and_clear(newsstory);
         sitestory = NULL;
      }
   }
}

// Grabbing somebody: a hostage-taking weapon makes it certain, and bare
// hands make it a fight.
void probe_kidnap(FILE *out)
{
   static const char *WEAPONS[] = {
      "WEAPON_NONE", "WEAPON_SEMIPISTOL_9MM", "WEAPON_GAVEL",
      "WEAPON_COMBATKNIFE",
   };
   const int WEAPON_COUNT = (int)(sizeof(WEAPONS) / sizeof(WEAPONS[0]));

   static const int TARGETS[] = {
      CREATURE_CORPORATE_CEO, CREATURE_COP, CREATURE_WORKER_SECRETARY,
      CREATURE_SCIENTIST_LABTECH,
   };
   const int TARGET_COUNT = (int)(sizeof(TARGETS) / sizeof(TARGETS[0]));

   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 32452843UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      make_world(false);
      uniqueCreatures.initialize();
      mode = GAMEMODE_SITE;
      cursite = 1;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      for (int hand = 0; hand < WEAPON_COUNT; hand++)
      for (int who = 0; who < TARGET_COUNT; who++)
      for (int grade = 0; grade < 4; grade++)
      for (int hurt = 0; hurt < 3; hurt++)
      {
         unsigned long seed_used = 9200089UL * (unsigned long)
            ((((hand * TARGET_COUNT + who) * 4 + grade) * 3 + hurt)
             + scenario * 197 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
         delete_and_clear(pool);

         Creature *grabber = new Creature;
         makecreature(*grabber, CREATURE_POLITICALACTIVIST);
         grabber->id = 970000;
         grabber->align = ALIGN_LIBERAL;
         grabber->location = 1;
         grabber->base = 1;
         grabber->set_skill(SKILL_HANDTOHAND, grade * 4);
         grabber->set_attribute(ATTRIBUTE_STRENGTH, 2 + grade * 3);
         grabber->give_armor(*armortype[getarmortype("ARMOR_CLOTHES")], NULL);
         if (strcmp(WEAPONS[hand], "WEAPON_NONE"))
            grabber->give_weapon(*weapontype[getweapontype(WEAPONS[hand])], NULL);
         pool.push_back(grabber);
         // The message area redraws the site map, which reads the active
         // squad, so there has to be one.
         delete_and_clear(squad);
         squadst *sq = new squadst;
         sq->id = 1;
         for (int i = 0; i < 6; i++) sq->squad[i] = NULL;
         sq->squad[0] = grabber;
         grabber->squadid = sq->id;
         squad.push_back(sq);
         activesquad = sq;

         // Left on the heap: Creature's copy assignment shares its owned
         // pointers, so letting two of them go out of scope double-frees.
         Creature *target = new Creature;
         makecreature(*target, TARGETS[who]);
         target->id = 970100;
         target->align = ALIGN_CONSERVATIVE;
         target->location = 1;
         target->set_attribute(ATTRIBUTE_AGILITY, 2 + grade * 2);
         target->blood = 100 - hurt * 30;

         fprintf(out, "{\"kind\":\"kidnap\",\"scenario\":%d,\"seed\":%lu,"
                      "\"hand\":%d,\"who\":%d,\"grade\":%d,\"hurt\":%d,"
                      "\"weapon\":", scenario, seed_used, hand, who, grade, hurt);
         write_string(out, WEAPONS[hand]);
         fputs(",\"grabber\":", out);
         chase_write_creature(out, *grabber, true);
         fputs(",\"target\":", out);
         chase_write_creature(out, *target, true);
         fputs(",\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         bool amateur = 0;
         long long before = lcs_trace_draw_count();
         bool got = kidnap_block(*grabber, *target, amateur);

         fprintf(out, ",\"draws\":%lld,\"got\":%d,\"amateur\":%d",
                 lcs_trace_draw_count() - before, got ? 1 : 0,
                 amateur ? 1 : 0);
         fputs(",\"grabber_after\":", out);
         chase_write_creature(out, *grabber, true);
         fputs("}\n", out);

         grabber->prisoner = NULL;
         activesquad = NULL;
         delete_and_clear(squad);
         delete_and_clear(pool);
      }
   }
}

// The November election: the presidency every fourth year, both chambers
// every second, and the propositions every year.
extern std::vector<int> probe_props, probe_propdirs, probe_priority, probe_moods;

void probe_election_day(FILE *out)
{
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 15485863UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      make_world(false);
      uniqueCreatures.initialize();
      mode = GAMEMODE_BASE;

      for (int years = 0; years < 4; years++)
      for (int temper = 0; temper < 5; temper++)
      for (int term = 1; term <= 2; term++)
      for (int party = 0; party < 3; party++)
      for (int stalin = 0; stalin < 2; stalin++)
      {
         unsigned long seed_used = 8300021UL * (unsigned long)
            ((((years * 5 + temper) * 2 + (term - 1)) * 3 + party) * 2 + stalin
             + scenario * 269 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         year = 2000 + years;
         month = 11; day = 1;
         disbanding = 0;
         stalinmode = stalin ? true : false;
         termlimits = false;
         for (int l = 0; l < LAWNUM; l++) law[l] = ((l + temper) % 5) - 2;
         for (int v = 0; v < VIEWNUM; v++)
         {
            attitude[v] = (temper * 23 + v * 7) % 101;
            public_interest[v] = (v * 5 + temper) % 40;
         }
         for (int h = 0; h < HOUSENUM; h++) house[h] = ((h + temper) % 5) - 2;
         for (int s = 0; s < SENATENUM; s++) senate[s] = ((s + temper) % 5) - 2;
         for (int c = 0; c < COURTNUM; c++) court[c] = ((c + temper) % 5) - 2;
         presparty = party;
         execterm = term;
         for (int e = 0; e < EXECNUM; e++)
         {
            exec[e] = ((e + temper) % 5) - 2;
            snprintf(execname[e], POLITICIAN_NAMELEN, "Exec %d", e);
         }

         fprintf(out, "{\"kind\":\"election_day\",\"scenario\":%d,\"seed\":%lu,"
                      "\"years\":%d,\"temper\":%d,\"term\":%d,\"party\":%d,"
                      "\"stalin\":%d,\"year\":%d",
                 scenario, seed_used, years, temper, term, party, stalin, year);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("],\"house\":[", out);
         for (int i = 0; i < HOUSENUM; i++)
            fprintf(out, "%s%d", i ? "," : "", house[i]);
         fputs("],\"senate\":[", out);
         for (int i = 0; i < SENATENUM; i++)
            fprintf(out, "%s%d", i ? "," : "", senate[i]);
         fputs("],\"exec\":[", out);
         for (int i = 0; i < EXECNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", exec[i]);
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         long long before = lcs_trace_draw_count();
         probe_props.clear();
         probe_propdirs.clear();
         probe_priority.clear();
         probe_moods.clear();
         elections(0, 1);

         fputs(",\"props\":[", out);
         for (int i = 0; i < len(probe_props); i++)
            fprintf(out, "%s[%d,%d]", i ? "," : "", probe_props[i],
                    probe_propdirs[i]);
         fputs("],\"priority\":[", out);
         for (int i = 0; i < len(probe_priority); i++)
            fprintf(out, "%s%d", i ? "," : "", probe_priority[i]);
         fputs("],\"moods\":[", out);
         for (int i = 0; i < len(probe_moods); i++)
            fprintf(out, "%s%d", i ? "," : "", probe_moods[i]);
         fputs("]", out);
         fprintf(out, ",\"draws\":%lld,\"party_after\":%d,\"term_after\":%d",
                 lcs_trace_draw_count() - before, presparty, execterm);
         fputs(",\"law_after\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"house_after\":[", out);
         for (int i = 0; i < HOUSENUM; i++)
            fprintf(out, "%s%d", i ? "," : "", house[i]);
         fputs("],\"senate_after\":[", out);
         for (int i = 0; i < SENATENUM; i++)
            fprintf(out, "%s%d", i ? "," : "", senate[i]);
         fputs("],\"exec_after\":[", out);
         for (int i = 0; i < EXECNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", exec[i]);
         fputs("],\"exec_names\":[", out);
         for (int i = 0; i < EXECNUM; i++)
         {
            if (i) fputs(",", out);
            write_string(out, execname[i]);
         }
         fputs("]}\n", out);
      }
   }
}

// Amending the constitution: both chambers, then thirty-eight states.
static char ratify_block(int level,int lawview,int view,char congress)
{
   int mood=publicmood(lawview);
   if(view>=0) mood=attitude[view];

   bool ratified=false;

   if(congress)
   {
      ratified=true;
      bool yeswin_h=false,yeswin_s=false;
      int yesvotes_h=0,yesvotes_s=0,vote,s=0;

      for(int l=0;l<HOUSENUM;l++)
      {
         vote=house[l];
         if(vote>=-1&&vote<=1) vote+=LCSrandom(3)-1;
         if(level==vote) yesvotes_h++;
         if(l==HOUSENUM-1) if(yesvotes_h>=HOUSESUPERMAJORITY) yeswin_h=true;

         if(l%4==0&&s<SENATENUM)
         {
            vote=senate[s++];
            if(vote>=-1&&vote<=1) vote+=LCSrandom(3)-1;
            if(level==vote) yesvotes_s++;
         }
         if(l==HOUSENUM-1&&yesvotes_s>=SENATESUPERMAJORITY) yeswin_s=true;
      }
      if(!yeswin_h||!yeswin_s) ratified=false;
      if(!ratified) return 0;
   }

   int yesstate=0,vote,smood;
   for(int s=0;s<STATENUM;s++)
   {
      smood=mood;
      int multiplier = 5+LCSrandom(3);
      switch(s)
      {
         case 0:smood-=3*multiplier;break;  case 1:smood-=4*multiplier;break;
         case 2:smood-=1*multiplier;break;  case 3:smood-=2*multiplier;break;
         case 4:smood+=4*multiplier;break;  case 5:break;
         case 6:smood+=3*multiplier;break;  case 7:smood+=3*multiplier;break;
         case 8:break;                      case 9:smood-=2*multiplier;break;
         case 10:smood+=4*multiplier;break; case 11:smood-=5*multiplier;break;
         case 12:smood+=4*multiplier;break; case 13:smood-=1*multiplier;break;
         case 14:smood+=1*multiplier;break; case 15:smood-=3*multiplier;break;
         case 16:smood-=3*multiplier;break; case 17:smood-=1*multiplier;break;
         case 18:smood+=2*multiplier;break; case 19:smood+=3*multiplier;break;
         case 20:smood+=6*multiplier;break; case 21:smood+=2*multiplier;break;
         case 22:smood+=2*multiplier;break; case 23:smood-=4*multiplier;break;
         case 24:smood-=1*multiplier;break; case 25:smood-=2*multiplier;break;
         case 26:smood-=3*multiplier;break; case 27:break;
         case 28:smood+=1*multiplier;break; case 29:smood+=3*multiplier;break;
         case 30:smood+=1*multiplier;break; case 31:smood+=5*multiplier;break;
         case 32:smood-=1*multiplier;break; case 33:smood-=3*multiplier;break;
         case 34:break;                     case 35:smood-=4*multiplier;break;
         case 36:smood+=3*multiplier;break; case 37:smood+=2*multiplier;break;
         case 38:smood+=4*multiplier;break; case 39:smood-=5*multiplier;break;
         case 40:smood-=3*multiplier;break; case 41:smood-=2*multiplier;break;
         case 42:smood-=4*multiplier;break; case 43:smood-=6*multiplier;break;
         case 44:smood+=5*multiplier;break; case 45:break;
         case 46:smood+=3*multiplier;break; case 47:smood-=2*multiplier;break;
         case 48:smood+=2*multiplier;break; case 49:smood-=5*multiplier;break;
      }

      vote=-2;
      if(LCSrandom(100)<smood)vote++;
      if(LCSrandom(100)<smood)vote++;
      if(LCSrandom(100)<smood)vote++;
      if(LCSrandom(100)<smood)vote++;
      if(vote==1&&!LCSrandom(2)) vote=2;
      if(vote==-1&&!LCSrandom(2)) vote=-2;

      if(vote==level) yesstate++;
   }

   if(yesstate>=STATESUPERMAJORITY) ratified=true;
   else ratified=false;
   return ratified;
}

// The four amendments, with the display and the endgame taken out.
static int amendment_block(int which)
{
   switch(which)
   {
   case 0:   // tossjustices()
      if(ratify_block(2,-1,-1,1))
      {
         for(int j=0;j<COURTNUM;j++) if(court[j]!=ALIGN_ELITELIBERAL)
         {
            do generate_name(courtname[j]); while(len(courtname[j])>20);
            court[j]=ALIGN_ELITELIBERAL;
         }
         amendnum++;
         return 1;
      }
      return 0;
   case 1:   // amendment_termlimits(), minus the elections it then holds
      if(termlimits) return 0;
      if(ratify_block(2,-1,-1,0))
      {
         termlimits = true;
         amendnum++;
         return 1;
      }
      return 0;
   case 2:   // reaganify()
      if(ratify_block(-2,-1,-1,1))
      {
         amendnum = 1;
         for(int e=0;e<EXECNUM;e++) exec[e]=ALIGN_ARCHCONSERVATIVE;
         for(int l=0;l<LAWNUM;l++) law[l]=ALIGN_ARCHCONSERVATIVE;
         return 1;
      }
      return 0;
   default:  // stalinize()
      if(ratify_block(3,-2,-2,1))
      {
         amendnum = 1;
         for(int e=0;e<EXECNUM;e++) exec[e]=ALIGN_STALINIST;
         for(int l=0;l<LAWNUM;l++) law[l]=stalinview(l,true)?ALIGN_ELITELIBERAL:ALIGN_ARCHCONSERVATIVE;
         return 1;
      }
      return 0;
   }
}

void probe_amendments(FILE *out)
{
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 27644437UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      make_world(false);
      uniqueCreatures.initialize();
      mode = GAMEMODE_BASE;

      for (int which = 0; which < 4; which++)
      for (int tilt = 0; tilt < 6; tilt++)
      for (int temper = 0; temper < 5; temper++)
      for (int already = 0; already < 2; already++)
      {
         unsigned long seed_used = 7900109UL * (unsigned long)
            ((((which * 6 + tilt) * 5 + temper) * 2 + already)
             + scenario * 251 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
         for (int v = 0; v < VIEWNUM; v++)
         {
            attitude[v] = temper * 25;
            public_interest[v] = (v * 3) % 40;
         }
         // A chamber tilted far enough to pass each of the four.
         for (int h = 0; h < HOUSENUM; h++)
            house[h] = (h % 10 < tilt * 2) ? (which == 2 ? -2
                                          : (which == 3 ? 3 : 2))
                                          : ((h % 3) - 1);
         for (int s = 0; s < SENATENUM; s++)
            senate[s] = (s % 10 < tilt * 2) ? (which == 2 ? -2
                                           : (which == 3 ? 3 : 2))
                                           : ((s % 3) - 1);
         for (int c = 0; c < COURTNUM; c++)
            court[c] = ((c + already) % 4) - 1;
         for (int c = 0; c < COURTNUM; c++)
            snprintf(courtname[c], 20, "Justice %d", c);
         for (int e = 0; e < EXECNUM; e++) exec[e] = (e % 3) - 1;
         termlimits = already ? true : false;
         amendnum = 0;
         stalinmode = true;

         fprintf(out, "{\"kind\":\"amendments\",\"scenario\":%d,\"seed\":%lu,"
                      "\"which\":%d,\"tilt\":%d,\"temper\":%d,\"already\":%d",
                 scenario, seed_used, which, tilt, temper, already);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"house\":[", out);
         for (int i = 0; i < HOUSENUM; i++)
            fprintf(out, "%s%d", i ? "," : "", house[i]);
         fputs("],\"senate\":[", out);
         for (int i = 0; i < SENATENUM; i++)
            fprintf(out, "%s%d", i ? "," : "", senate[i]);
         fputs("],\"court\":[", out);
         for (int i = 0; i < COURTNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", court[i]);
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         long long before = lcs_trace_draw_count();
         int passed = amendment_block(which);

         fprintf(out, ",\"draws\":%lld,\"passed\":%d,\"amendnum\":%d,"
                      "\"termlimits\":%d",
                 lcs_trace_draw_count() - before, passed, amendnum,
                 termlimits ? 1 : 0);
         fputs(",\"law_after\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"court_after\":[", out);
         for (int i = 0; i < COURTNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", court[i]);
         fputs("],\"exec_after\":[", out);
         for (int i = 0; i < EXECNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", exec[i]);
         fputs("],\"court_names\":[", out);
         for (int i = 0; i < COURTNUM; i++)
         {
            if (i) fputs(",", out);
            write_string(out, courtname[i]);
         }
         fputs("]}\n", out);
      }
   }
}

// Buying a compound: what a safehouse can have built into it, and the
// business front's rejection loop.
static void invest_block(int loc, int choice)
{
   if(choice==0)
   {
      if(location[loc]->can_be_fortified()&&ledger.get_funds()>=2000)
      {
         ledger.subtract_funds(2000,EXPENSE_COMPOUND);
         location[loc]->compound_walls|=COMPOUND_BASIC;
      }
   }
   else if(choice==1)
   {
      if(!(location[loc]->compound_walls & COMPOUND_CAMERAS)&&ledger.get_funds()>=2000)
      {
         ledger.subtract_funds(2000,EXPENSE_COMPOUND);
         location[loc]->compound_walls|=COMPOUND_CAMERAS;
      }
   }
   else if(choice==2)
   {
      if(location[loc]->can_be_trapped()&&ledger.get_funds()>=3000)
      {
         ledger.subtract_funds(3000,EXPENSE_COMPOUND);
         location[loc]->compound_walls|=COMPOUND_TRAPS;
      }
   }
   else if(choice==3)
   {
      if(location[loc]->can_install_tanktraps()&&ledger.get_funds()>=3000)
      {
         ledger.subtract_funds(3000,EXPENSE_COMPOUND);
         location[loc]->compound_walls|=COMPOUND_TANKTRAPS;
      }
   }
   else if(choice==4)
   {
      if(!(location[loc]->compound_walls & COMPOUND_GENERATOR)&&ledger.get_funds()>=3000)
      {
         ledger.subtract_funds(3000,EXPENSE_COMPOUND);
         location[loc]->compound_walls|=COMPOUND_GENERATOR;
      }
   }
   else if(choice==5)
   {
      int aagunPrice = 200000;
      if(law[LAW_GUNCONTROL]==ALIGN_ARCHCONSERVATIVE) aagunPrice = 35000;
      if(!(location[loc]->compound_walls & COMPOUND_AAGUN)&&ledger.get_funds()>=aagunPrice)
      {
         ledger.subtract_funds(aagunPrice,EXPENSE_COMPOUND);
         location[loc]->compound_walls|=COMPOUND_AAGUN;
      }
   }
   else if(choice==6)
   {
      if(!(location[loc]->compound_walls & COMPOUND_PRINTINGPRESS)&&ledger.get_funds()>=3000)
      {
         ledger.subtract_funds(3000,EXPENSE_COMPOUND);
         location[loc]->compound_walls|=COMPOUND_PRINTINGPRESS;
      }
   }
   else if(choice==7)
   {
      if(ledger.get_funds()>=150)
      {
         ledger.subtract_funds(150,EXPENSE_COMPOUND);
         location[loc]->compound_stores+=20;
      }
   }
   else if(choice==8)
   {
      if(location[loc]->can_have_businessfront()&&ledger.get_funds()>=3000)
      {
         ledger.subtract_funds(3000,EXPENSE_COMPOUND);
         business_front_block(loc);
      }
   }
}

void probe_safehouse(FILE *out)
{
   static const int SITES[] = {
      SITE_RESIDENTIAL_TENEMENT, SITE_RESIDENTIAL_APARTMENT,
      SITE_OUTDOOR_BUNKER, SITE_RESIDENTIAL_BOMBSHELTER,
      SITE_BUSINESS_BARANDGRILL, SITE_INDUSTRY_WAREHOUSE,
   };
   const int SITE_COUNT = (int)(sizeof(SITES) / sizeof(SITES[0]));

   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 43217791UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();
      delete_and_clear(location);
      make_world(false);
      uniqueCreatures.initialize();
      mode = GAMEMODE_BASE;
      cursite = 1;

      for (int place = 0; place < SITE_COUNT; place++)
      for (int choice = 0; choice < 9; choice++)
      for (int walls = 0; walls < 4; walls++)
      for (int purse = 0; purse < 3; purse++)
      for (int guns = 0; guns < 2; guns++)
      for (int upgradable = 0; upgradable < 2; upgradable++)
      {
         unsigned long seed_used = 6700417UL * (unsigned long)
            (((((place * 9 + choice) * 4 + walls) * 3 + purse) * 2 + guns) * 2
             + upgradable + scenario * 233 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
         law[LAW_GUNCONTROL] = guns ? ALIGN_ARCHCONSERVATIVE : ALIGN_LIBERAL;
         ledger.force_funds(purse == 0 ? 100 : (purse == 1 ? 4000 : 400000));

         int loc = -1;
         for (int l = 0; l < len(location); l++)
            if (location[l]->type == SITES[place]) { loc = l; break; }
         if (loc == -1) continue;
         location[loc]->upgradable = upgradable;
         location[loc]->compound_walls = walls == 0 ? 0
            : (walls == 1 ? COMPOUND_BASIC
            : (walls == 2 ? (COMPOUND_BASIC|COMPOUND_CAMERAS|COMPOUND_TRAPS)
                          : (COMPOUND_TANKTRAPS|COMPOUND_GENERATOR)));
         location[loc]->compound_stores = 5;
         // Fronts opened by earlier samples are still standing in this world,
         // so they are cleared rather than inherited.
         for (int l = 0; l < len(location); l++)
         {
            location[l]->front_business = -1;
            location[l]->front_name[0] = 0;
            location[l]->front_shortname[0] = 0;
         }
         // A front already open elsewhere, so the rejection loop has
         // something to reject.
         int other = (loc + 3) % len(location);
         location[other]->front_business = BUSINESSFRONT_RESTAURANT;
         strcpy(location[other]->front_shortname, "Pizza");
         strcpy(location[other]->front_name, "Smith Pizzeria");

         fprintf(out, "{\"kind\":\"safehouse\",\"scenario\":%d,\"seed\":%lu,"
                      "\"place\":%d,\"choice\":%d,\"walls\":%d,\"purse\":%d,"
                      "\"guns\":%d,\"upgradable\":%d,\"loc\":%d,\"other\":%d,"
                      "\"funds\":%d,\"world_seed\":%lu",
                 scenario, seed_used, place, choice, walls, purse, guns,
                 upgradable, loc, other, ledger.get_funds(), run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         long long before = lcs_trace_draw_count();
         invest_block(loc, choice);

         fprintf(out, ",\"draws\":%lld,\"funds_after\":%d,\"walls_after\":%d,"
                      "\"stores_after\":%d,\"front\":%d",
                 lcs_trace_draw_count() - before, ledger.get_funds(),
                 (int)location[loc]->compound_walls,
                 (int)location[loc]->compound_stores,
                 (int)location[loc]->front_business);
         fputs(",\"front_name\":", out);
         write_string(out, location[loc]->front_name);
         fputs(",\"front_short\":", out);
         write_string(out, location[loc]->front_shortname);
         fputs("}\n", out);
      }
   }
}

// Disbanding: scattering the squad, and the slow forgetting of the years
// afterwards.
static void disband_block()
{
   // pickrandom() over the phrases the player has to type, which is rolled
   // before the typing and so costs a draw.
   LCSrandom(22);

   for(int p=len(pool)-1;p>=0;p--)
   {
      if(!pool[p]->alive || pool[p]->flag&CREATUREFLAG_KIDNAPPED || pool[p]->flag&CREATUREFLAG_MISSING)
         delete_and_remove(pool,p);
      else if(!(pool[p]->flag&CREATUREFLAG_SLEEPER))
      {
         removesquadinfo(*pool[p]);
         pool[p]->hiding=-1;
      }
   }
   cleangonesquads();
   disbandtime=year;
}

// The monthly thinning of a disbanded squad, from show_disbanding_screen().
static void disband_month_block()
{
   for(int p=len(pool)-1;p>=0;p--)
   {
      int targetjuice=LCSrandom(100*(year-disbandtime+1));
      if(targetjuice>1000) targetjuice=1000;
      if(pool[p]->juice<targetjuice&&pool[p]->hireid!=-1&&!(pool[p]->flag&CREATUREFLAG_SLEEPER))
         pool[p]->alive=0;
   }
}

void probe_disband(FILE *out)
{
   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 88113301UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();

      for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
      delete_and_clear(location);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = ENDGAME_NONE;
      mode = GAMEMODE_BASE;
      cursite = 1;

      for (int crowd = 1; crowd <= 6; crowd++)
      for (int shape = 0; shape < 6; shape++)
      for (int years = 0; years < 5; years++)
      for (int monthly = 0; monthly < 2; monthly++)
      {
         unsigned long seed_used = 6100013UL * (unsigned long)
            ((((crowd * 6 + shape) * 5 + years) * 2 + monthly)
             + scenario * 179 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         delete_and_clear(pool);
         delete_and_clear(squad);
         year = 2000 + years * 12;
         disbandtime = 2000;
         month = 1; day = 1;

         squadst *sq = new squadst;
         sq->id = 1;
         for (int i = 0; i < 6; i++) sq->squad[i] = NULL;
         squad.push_back(sq);

         for (int n = 0; n < crowd; n++)
         {
            Creature *cr = new Creature;
            makecreature(*cr, CREATURE_POLITICALACTIVIST);
            cr->id = 950000 + n;
            cr->align = ALIGN_LIBERAL;
            cr->location = 1;
            cr->base = 1;
            cr->juice = (n * 137 + shape * 40) % 1200;
            cr->hireid = n == 0 ? -1 : 950000;
            cr->alive = ((n + shape) % 7 != 3);
            if ((n + shape) % 5 == 1) cr->flag |= CREATUREFLAG_SLEEPER;
            if ((n + shape) % 5 == 2) cr->flag |= CREATUREFLAG_MISSING;
            if ((n + shape) % 5 == 3) cr->flag |= CREATUREFLAG_KIDNAPPED;
            if (n < 6)
            {
               sq->squad[n] = cr;
               cr->squadid = sq->id;
            }
            pool.push_back(cr);
         }

         fprintf(out, "{\"kind\":\"disband\",\"scenario\":%d,\"seed\":%lu,"
                      "\"crowd\":%d,\"shape\":%d,\"years\":%d,\"monthly\":%d,"
                      "\"year\":%d,\"disbandtime\":%d,\"world_seed\":%lu",
                 scenario, seed_used, crowd, shape, years, monthly, year,
                 disbandtime, run_seed);
         fputs(",\"pool\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"id\":%d,\"alive\":%d,\"sleeper\":%d,"
                         "\"missing\":%d,\"kidnapped\":%d,\"person\":",
                    p ? "," : "", (int)pool[p]->id, pool[p]->alive ? 1 : 0,
                    (pool[p]->flag & CREATUREFLAG_SLEEPER) ? 1 : 0,
                    (pool[p]->flag & CREATUREFLAG_MISSING) ? 1 : 0,
                    (pool[p]->flag & CREATUREFLAG_KIDNAPPED) ? 1 : 0);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         long long before = lcs_trace_draw_count();
         if (monthly) disband_month_block();
         else disband_block();

         fprintf(out, ",\"draws\":%lld,\"disbandtime_after\":%d",
                 lcs_trace_draw_count() - before, disbandtime);
         fputs(",\"pool_after\":[", out);
         for (int p = 0; p < len(pool); p++)
            fprintf(out, "%s{\"id\":%d,\"alive\":%d,\"hiding\":%d,"
                         "\"squadid\":%d}", p ? "," : "", (int)pool[p]->id,
                    pool[p]->alive ? 1 : 0, (int)pool[p]->hiding,
                    (int)pool[p]->squadid);
         fprintf(out, "],\"squads\":%d}\n", len(squad));

         delete_and_clear(pool);
         delete_and_clear(squad);
      }
   }
}

// The Education of a Conservative: a day of interrogation, with the plan set
// in advance rather than typed at the menu.
void probe_interrogation(FILE *out)
{
   static const int HOSTAGES[] = {
      CREATURE_CORPORATE_CEO, CREATURE_PRIEST, CREATURE_SCIENTIST_LABTECH,
      CREATURE_COP, CREATURE_WORKER_SECRETARY,
   };
   const int HOSTAGE_COUNT = (int)(sizeof(HOSTAGES) / sizeof(HOSTAGES[0]));

   // Talk, restrain, beat, props, drugs, kill, and the combinations that
   // matter: the plan is a bitmask over the six.
   static const int PLANS[] = {
      0, 1, 2, 3, 7, 11, 19, 27, 31, 32, 47, 63,
   };
   const int PLAN_COUNT = (int)(sizeof(PLANS) / sizeof(PLANS[0]));

   for (int scenario = 0; scenario < 2; scenario++)
   {
      unsigned long run_seed = 61773119UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();

      for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
      delete_and_clear(location);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = ENDGAME_NONE;
      mode = GAMEMODE_BASE;
      cursite = 1;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      for (int who = 0; who < HOSTAGE_COUNT; who++)
      for (int plan = 0; plan < PLAN_COUNT; plan++)
      for (int guards = 0; guards <= 2; guards++)
      for (int grade = 0; grade < 3; grade++)
      for (int held = 0; held < 3; held++)
      for (int yesterday = 0; yesterday < 2; yesterday++)
      for (int warmth = 0; warmth < 2; warmth++)
      {
         unsigned long seed_used = 5300021UL * (unsigned long)
            ((((((who * PLAN_COUNT + plan) * 3 + guards) * 3 + grade) * 3
              + held) * 2 + yesterday) * 2 + warmth + scenario * 307 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         delete_and_clear(pool);
         ledger.force_funds(grade ? 5000 : 100);
         stat_kills = 0;
         stat_recruits = 0;
         for (int n = 0; n < 3; n++)
         {
            location[20 + n]->mapped = 0;
            location[20 + n]->hidden = 1;
         }

         Creature *hostage = new Creature;
         makecreature(*hostage, HOSTAGES[who]);
         hostage->id = 900000;
         hostage->align = ALIGN_CONSERVATIVE;
         hostage->location = 1;
         hostage->base = 1;
         hostage->worklocation = 20 + (who % 3);
         hostage->hireid = -1;
         hostage->joindays = held == 0 ? 1 : (held == 1 ? 6 : 20);
         hostage->juice = 20 * grade;
         hostage->flag |= CREATUREFLAG_MISSING | CREATUREFLAG_KIDNAPPED;
         hostage->set_attribute(ATTRIBUTE_HEART, 1 + grade * 3);
         hostage->set_attribute(ATTRIBUTE_WISDOM, 2 + grade * 2);
         hostage->set_attribute(ATTRIBUTE_HEALTH, 2 + grade * 3);
         hostage->give_armor(*armortype[getarmortype("ARMOR_CLOTHES")], NULL);
         hostage->activity.intr() = new interrogation;
         hostage->activity.intr()->techniques[TECHNIQUE_RESTRAIN] = yesterday;
         hostage->activity.intr()->druguse = held == 2 ? 40 : 0;
         // A hostage who has been talked round already, so the conversion
         // that ends the interrogation is reachable.
         if (warmth)
         {
            hostage->set_attribute(ATTRIBUTE_HEART, 8);
            hostage->set_attribute(ATTRIBUTE_WISDOM, 3);
            hostage->activity.intr()->rapport[900100].n = 4.2f;
            hostage->activity.intr()->rapport[900101].n = 4.2f;
         }
         pool.push_back(hostage);

         for (int n = 0; n < guards; n++)
         {
            Creature *guard = new Creature;
            makecreature(*guard, CREATURE_POLITICALACTIVIST);
            guard->id = 900100 + n;
            guard->align = ALIGN_LIBERAL;
            guard->location = 1;
            guard->base = 1;
            guard->hireid = -1;
            guard->juice = 30 * (n + grade);
            guard->set_skill(SKILL_PSYCHOLOGY, grade * 3 + n);
            guard->set_skill(SKILL_RELIGION, (grade + n) % 4);
            guard->set_skill(SKILL_SCIENCE, (grade + n + 1) % 4);
            guard->set_skill(SKILL_BUSINESS, (grade + n + 2) % 4);
            guard->set_skill(SKILL_SEDUCTION, grade * 2);
            guard->set_skill(SKILL_FIRSTAID, n * 4);
            guard->set_attribute(ATTRIBUTE_HEART, 2 + n * 3);
            guard->set_attribute(ATTRIBUTE_WISDOM, 3 + grade);
            guard->give_armor(*armortype[getarmortype("ARMOR_CLOTHES")], NULL);
            guard->activity.type = ACTIVITY_HOSTAGETENDING;
            guard->activity.arg = hostage->id;
            pool.push_back(guard);
         }

         fprintf(out, "{\"kind\":\"interrogation\",\"scenario\":%d,"
                      "\"seed\":%lu,\"who\":%d,\"plan\":%d,\"guard_count\":%d,"
                      "\"grade\":%d,\"held\":%d,\"yesterday\":%d,\"warmth\":%d,"
                      "\"funds\":%d,\"druguse\":%d,\"world_seed\":%lu",
                 scenario, seed_used, who, PLANS[plan], guards, grade, held,
                 yesterday, warmth, ledger.get_funds(),
                 hostage->activity.intr()->druguse, run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"hostage\":", out);
         chase_write_creature(out, *hostage, true);
         fprintf(out, ",\"worklocation\":%d,\"joindays\":%d",
                 (int)hostage->worklocation, (int)hostage->joindays);
         fputs(",\"guards\":[", out);
         for (int n = 1; n < len(pool); n++)
         {
            if (n > 1) fputs(",", out);
            chase_write_creature(out, *pool[n], true);
         }
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         int escaped = 0;
         long long before = lcs_trace_draw_count();
         int outcome = tend_block(hostage, PLANS[plan], &escaped);

         fprintf(out, ",\"draws\":%lld,\"outcome\":%d,\"escaped\":%d,"
                      "\"funds_after\":%d,\"kills\":%d,\"recruits\":%d",
                 lcs_trace_draw_count() - before, outcome, escaped,
                 ledger.get_funds(), stat_kills, stat_recruits);
         fputs(",\"pool_after\":[", out);
         for (int i = 0; i < len(pool); i++)
         {
            fprintf(out, "%s{\"id\":%d,\"alive\":%d,\"align\":%d,"
                         "\"brainwashed\":%d,\"missing\":%d,\"activity\":%d,"
                         "\"person\":", i ? "," : "", (int)pool[i]->id,
                    pool[i]->alive ? 1 : 0, (int)pool[i]->align,
                    (pool[i]->flag & CREATUREFLAG_BRAINWASHED) ? 1 : 0,
                    (pool[i]->flag & CREATUREFLAG_MISSING) ? 1 : 0,
                    pool[i]->activity.type);
            chase_write_creature(out, *pool[i], true);
            fputs("}", out);
         }
         fputs("],\"mapped\":[", out);
         for (int n = 0; n < 3; n++)
            fprintf(out, "%s%d", n ? "," : "", (int)location[20 + n]->mapped);
         fprintf(out, "],\"druguse_after\":%d",
                 (escaped || outcome == 2 || outcome == 3)
                    ? -1 : pool[0]->activity.intr()->druguse);
         fputs("}\n", out);

         delete_and_clear(pool);
      }
   }
}

// An evening out: one date or three, paid for or not, ending in a love slave,
// a break-up, a police ambush or a kidnapping in the car park.
void probe_dating(FILE *out)
{
   static const int DATES[] = {
      CREATURE_CORPORATE_MANAGER, CREATURE_COP, CREATURE_WORKER_SECRETARY,
      CREATURE_SCIENTIST_LABTECH, CREATURE_PRIEST,
   };
   const int DATE_COUNT = (int)(sizeof(DATES) / sizeof(DATES[0]));

   static const char *WEAPONS[] = {
      "WEAPON_NONE", "WEAPON_SEMIPISTOL_9MM", "WEAPON_GAVEL",
   };
   const int WEAPON_COUNT = (int)(sizeof(WEAPONS) / sizeof(WEAPONS[0]));

   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 33871301UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();

      for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
      delete_and_clear(location);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = ENDGAME_NONE;
      mode = GAMEMODE_BASE;
      cursite = 1;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;

      for (int who = 0; who < DATE_COUNT; who++)
      for (int choice = 0; choice < 5; choice++)
      for (int crowd = 1; crowd <= 3; crowd++)
      for (int grade = 0; grade < 3; grade++)
      for (int hand = 0; hand < WEAPON_COUNT; hand++)
      for (int wanted = 0; wanted < 2; wanted++)
      for (int vacation = 0; vacation < 2; vacation++)
      {
         if (vacation && crowd > 1) continue;   // a vacation stands up the rest
         unsigned long seed_used = 4100011UL * (unsigned long)
            (((((who * 5 + choice) * 3 + (crowd - 1)) * 3 + grade)
              * WEAPON_COUNT + hand) * 4 + wanted * 2 + vacation
             + scenario * 211 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         delete_and_clear(pool);
         ledger.force_funds(grade ? 5000 : 50);
         stat_recruits = 0;
         stat_kidnappings = 0;

         Creature *dater = new Creature;
         makecreature(*dater, CREATURE_POLITICALACTIVIST);
         dater->id = 800000;
         dater->align = ALIGN_LIBERAL;
         dater->location = 1;
         dater->base = 1;
         dater->hireid = -1;
         dater->juice = 30 * grade;
         dater->blood = grade == 2 ? 80 : 100;
         dater->clinic = 0;
         dater->set_skill(SKILL_SEDUCTION, grade * 5);
         dater->set_skill(SKILL_BUSINESS, grade * 2);
         dater->set_skill(SKILL_RELIGION, (grade + 1) % 3);
         dater->set_skill(SKILL_SCIENCE, (grade + 2) % 3);
         dater->set_skill(SKILL_HANDTOHAND, grade * 3);
         dater->give_armor(*armortype[getarmortype("ARMOR_CLOTHES")], NULL);
         if (strcmp(WEAPONS[hand], "WEAPON_NONE"))
            dater->give_weapon(*weapontype[getweapontype(WEAPONS[hand])], NULL);
         if (wanted) criminalize(*dater, LAWFLAG_VANDALISM);
         pool.push_back(dater);

         // Somebody already on the books, so the cap on how many people one
         // Liberal can juggle is exercised.
         if (grade == 0)
         {
            Creature *held = new Creature;
            makecreature(*held, CREATURE_WORKER_SECRETARY);
            held->id = 800100;
            held->align = ALIGN_LIBERAL;
            held->hireid = dater->id;
            held->flag |= CREATUREFLAG_LOVESLAVE;
            held->location = 1;
            held->base = 1;
            pool.push_back(held);
         }

         // The three workplaces a date can have are put back each sample, so
         // a map given away in one is not still given away in the next.
         for (int n = 0; n < 3; n++)
         {
            location[20 + n]->mapped = 0;
            location[20 + n]->hidden = 1;
         }

         datest d;
         d.mac_id = dater->id;
         d.city = 0;
         d.timeleft = 0;
         for (int n = 0; n < crowd; n++)
         {
            Creature *seen = new Creature;
            makecreature(*seen, DATES[(who + n) % DATE_COUNT]);
            seen->id = 800200 + n;
            seen->align = n % 3 == 1 ? ALIGN_MODERATE : ALIGN_CONSERVATIVE;
            seen->juice = 40 * n;
            seen->worklocation = 20 + n;
            seen->location = seen->worklocation;
            seen->base = seen->worklocation;
            d.date.push_back(seen);
         }

         fprintf(out, "{\"kind\":\"dating\",\"scenario\":%d,\"seed\":%lu,"
                      "\"who\":%d,\"choice\":%d,\"crowd\":%d,\"grade\":%d,"
                      "\"hand\":%d,\"wanted\":%d,\"vacation\":%d,"
                      "\"funds\":%d,\"world_seed\":%lu",
                 scenario, seed_used, who, choice, crowd, grade, hand, wanted,
                 vacation, ledger.get_funds(), run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"suspected\":[", out);
         for (int i = 0; i < LAWFLAGNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", dater->crimes_suspected[i]);
         fputs("],\"dater\":", out);
         chase_write_creature(out, *dater, true);
         fputs(",\"held\":[", out);
         {
            int written = 0;
            for (int i = 1; i < len(pool); i++)
            {
               if (written++) fputs(",", out);
               chase_write_creature(out, *pool[i], true);
            }
         }
         fputs("],\"dates\":[", out);
         for (int n = 0; n < len(d.date); n++)
         {
            fprintf(out, "%s{\"worklocation\":%d,\"gender\":%d,"
                         "\"named\":%d,\"type\":", n ? "," : "",
                    (int)d.date[n]->worklocation,
                    (int)d.date[n]->gender_liberal,
                    d.date[n]->dontname ? 1 : 0);
            write_string(out, getcreaturetype(d.date[n]->type)->get_idname().c_str());
            fputs(",\"person\":", out);
            chase_write_creature(out, *d.date[n], true);
            fputs("}", out);
         }
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         long long before = lcs_trace_draw_count();
         char over = vacation ? vacation_block(d, 0) : date_block(d, 0, choice);

         fprintf(out, ",\"draws\":%lld,\"over\":%d,\"timeleft\":%d,"
                      "\"funds_after\":%d,\"recruits\":%d,\"kidnaps\":%d",
                 lcs_trace_draw_count() - before, (int)over, (int)d.timeleft,
                 ledger.get_funds(), stat_recruits, stat_kidnappings);
         fputs(",\"pool_after\":[", out);
         for (int i = 0; i < len(pool); i++)
         {
            fprintf(out, "%s{\"id\":%d,\"loveslave\":%d,\"missing\":%d,"
                         "\"person\":", i ? "," : "", (int)pool[i]->id,
                    (pool[i]->flag & CREATUREFLAG_LOVESLAVE) ? 1 : 0,
                    (pool[i]->flag & CREATUREFLAG_MISSING) ? 1 : 0);
            chase_write_creature(out, *pool[i], true);
            fputs("}", out);
         }
         fputs("],\"still_dating\":[", out);
         for (int n = 0; n < len(d.date); n++)
            fprintf(out, "%s%d", n ? "," : "", (int)d.date[n]->id);
         fputs("],\"mapped\":[", out);
         for (int n = 0; n < 3; n++)
            fprintf(out, "%s%d", n ? "," : "", (int)location[20 + n]->mapped);
         fputs("]}\n", out);

         // The pool owns whoever joined it; the rest go with the date list.
         delete_and_clear(pool);
      }
   }
}

// Adventures in Liberal Car Theft: finding a car, getting into it, getting it
// started, and the two ways a passerby can end the evening.
void probe_cartheft(FILE *out)
{
   // A spread of cars: cheap and easy, alarmed, and the police cruiser the
   // escape treats specially.
   static const char *CARS[] = {
      "STATIONWAGON", "SPORTSCAR", "SUV", "POLICECAR", "PICKUP",
   };
   const int CAR_COUNT = (int)(sizeof(CARS) / sizeof(CARS[0]));

   static const char *WEAPONS[] = {
      "WEAPON_NONE", "WEAPON_CROWBAR", "WEAPON_BASEBALLBAT",
   };
   const int WEAPON_COUNT = (int)(sizeof(WEAPONS) / sizeof(WEAPONS[0]));

   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 55117133UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();

      for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = ENDGAME_NONE;
      mode = GAMEMODE_BASE;
      cursite = 1;
      // Kept off the settings that field a death squad, so a chase can always
      // be given up on and the sample terminates.
      law[LAW_DEATHPENALTY] = 0;
      law[LAW_POLICEBEHAVIOR] = 0;

      for (int car = 0; car < CAR_COUNT; car++)
      for (int entry = 0; entry < 3; entry++)
      for (int start = 0; start < 3; start++)
      for (int hand = 0; hand < WEAPON_COUNT; hand++)
      for (int grade = 0; grade < 3; grade++)
      for (int rate = 0; rate < 3; rate++)
      {
         unsigned long seed_used = 2900011UL * (unsigned long)
            ((((car * 3 + entry) * 3 + start) * WEAPON_COUNT + hand) * 9
             + grade * 3 + rate + scenario * 149 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         delete_and_clear(pool);
         delete_and_clear(newsstory);
         delete_and_clear(vehicle);
         sitestory = NULL;
         // Chasers are left standing in the encounter roster when a sample
         // ends in one, so the roster is cleared rather than inherited.
         for (int e = 0; e < ENCMAX; e++) encounter[e].exists = 0;
         fieldskillrate = rate == 0 ? FIELDSKILLRATE_FAST
                        : rate == 1 ? FIELDSKILLRATE_CLASSIC
                                    : FIELDSKILLRATE_HARD;

         Creature *cr = new Creature;
         makecreature(*cr, CREATURE_POLITICALACTIVIST);
         cr->id = 700000;
         cr->align = ALIGN_LIBERAL;
         cr->location = 1;
         cr->base = 1;
         cr->hireid = -1;
         cr->juice = 20 * grade;
         cr->pref_carid = -1;
         cr->set_skill(SKILL_SECURITY, grade * 4);
         cr->set_skill(SKILL_STREETSENSE, grade * 3 + 1);
         cr->set_attribute(ATTRIBUTE_INTELLIGENCE, 2 + grade * 4);
         cr->set_attribute(ATTRIBUTE_STRENGTH, 2 + grade * 4);
         cr->give_armor(*armortype[getarmortype("ARMOR_CLOTHES")], NULL);
         if (strcmp(WEAPONS[hand], "WEAPON_NONE"))
            cr->give_weapon(*weapontype[getweapontype(WEAPONS[hand])], NULL);
         pool.push_back(cr);

         short cartype = (short)getvehicletype(CARS[car]);

         fprintf(out, "{\"kind\":\"cartheft\",\"scenario\":%d,\"seed\":%lu,"
                      "\"car\":%d,\"entry\":%d,\"start\":%d,\"hand\":%d,"
                      "\"grade\":%d,\"rate\":%d,\"cartype\":", scenario,
                 seed_used, car, entry, start, hand, grade, rate);
         write_string(out, CARS[car]);
         fputs(",\"weapon\":", out);
         write_string(out, WEAPONS[hand]);
         fputs(",\"thief\":", out);
         chase_write_creature(out, *cr, true);
         fputs(",\"world_seed\":", out);
         fprintf(out, "%lu", run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         int spotted = 0, windowdamage = 0, rounds = 0;
         long long before = lcs_trace_draw_count();
         int drove = steal_block(*cr, cartype, entry, start, &spotted,
                                 &windowdamage, &rounds);

         fprintf(out, ",\"draws\":%lld,\"drove\":%d,\"spotted\":%d,"
                      "\"windowdamage\":%d,\"rounds\":%d",
                 lcs_trace_draw_count() - before, drove, spotted,
                 windowdamage, rounds);
         fputs(",\"thief_after\":", out);
         chase_write_creature(out, *cr, true);
         fputs(",\"cars\":[", out);
         for (int i = 0; i < len(vehicle); i++)
            fprintf(out, "%s{\"type\":\"%s\",\"heat\":%d,\"loc\":%d,"
                         "\"year\":%d,\"color\":\"%s\"}",
                    i ? "," : "", vehicle[i]->vtypeidname().c_str(),
                    (int)vehicle[i]->get_heat(), (int)vehicle[i]->get_location(),
                    (int)vehicle[i]->myear(), vehicle[i]->color().c_str());
         fputs("],\"stories\":[", out);
         for (int n = 0; n < len(newsstory); n++)
            fprintf(out, "%s%d", n ? "," : "", newsstory[n]->type);
         fputs("],\"chasers\":[", out);
         {
            int written = 0;
            for (int e = 0; e < ENCMAX; e++)
               if (encounter[e].exists)
               {
                  if (written++) fputs(",", out);
                  chase_write_creature(out, encounter[e], true);
               }
         }
         fputs("]}\n", out);

         delete_and_clear(vehicle);
         delete_and_clear(pool);
         delete_and_clear(newsstory);
         sitestory = NULL;
      }
   }
}


// A day's activities, run the way the original runs them: everybody grouped by
// what they are doing, and the groups worked through in a fixed order.
//
// Hacking and graffiti are the two new ones, but the whole pass is driven so
// the grouping itself is checked — a mixed roster rolls in a different order
// from a roster doing one thing each.
void probe_activities_day(FILE *out)
{
   static const int JOBS[] = {
      ACTIVITY_DONATIONS, ACTIVITY_SELL_TSHIRTS, ACTIVITY_SELL_ART,
      ACTIVITY_SELL_MUSIC, ACTIVITY_SELL_DRUGS, ACTIVITY_CCFRAUD,
      ACTIVITY_DOS_ATTACKS, ACTIVITY_DOS_RACKET, ACTIVITY_HACKING,
      ACTIVITY_GRAFFITI, ACTIVITY_PROSTITUTION, ACTIVITY_TROUBLE,
      ACTIVITY_STUDY_LAW, ACTIVITY_STUDY_MARTIAL_ARTS,
      ACTIVITY_TEACH_POLITICS, ACTIVITY_TEACH_FIGHTING, ACTIVITY_BURY,
      ACTIVITY_WRITE_LETTERS, ACTIVITY_WRITE_GUARDIAN,
      ACTIVITY_COMMUNITYSERVICE, ACTIVITY_CLINIC, ACTIVITY_SLEEPER_JOINLCS,
   };
   const int JOB_COUNT = (int)(sizeof(JOBS) / sizeof(JOBS[0]));

   for (int scenario = 0; scenario < 3; scenario++)
   {
      unsigned long run_seed = 122949823UL * (unsigned long)(scenario + 1);
      lcs_trace_set_seed(run_seed);
      initMainRNG();

      for (int l = 0; l < LAWNUM; l++) law[l] = ((l + scenario) % 5) - 2;
      for (int v = 0; v < VIEWNUM; v++)
      {
         attitude[v] = (v * 7 + scenario * 13) % 101;
         public_interest[v] = (v * 3 + scenario * 5) % 40;
         background_liberal_influence[v] = 0;
      }
      delete_and_clear(location);
      delete_and_clear(newsstory);
      make_world(false);
      uniqueCreatures.initialize();
      endgamestate = ENDGAME_NONE;
      mode = GAMEMODE_BASE;
      cursite = 1;
      fieldskillrate = FIELDSKILLRATE_CLASSIC;
      // Kept off the two settings that field a death squad, so an arrest can
      // always be surrendered to and the chase it starts terminates.
      law[LAW_DEATHPENALTY] = 0;
      law[LAW_POLICEBEHAVIOR] = 0;

      // A mixed roster: several Liberals on each job, so the grouping and the
      // team rules both matter.
      // "solo" runs one job on its own, so a divergence names the activity
      // rather than the day; -1 is the mixed roster the grouping needs.
      for (int solo = -1; solo < JOB_COUNT; solo++)
      for (int crowd = 1; crowd <= 3; crowd++)
      for (int spread = 0; spread < 2; spread++)
      {
         if (solo >= 0 && spread) continue;   // order is meaningless alone
         unsigned long seed_used = 1700009UL * (unsigned long)
            ((solo + 2) * 64 + crowd * 4 + spread + scenario * 53 + 1);
         lcs_trace_set_seed(seed_used);
         initMainRNG();

         delete_and_clear(pool);
         ledger.force_funds(2000);
         for (int v = 0; v < VIEWNUM; v++)
         {
            attitude[v] = (v * 7 + scenario * 13) % 101;
            public_interest[v] = (v * 3 + scenario * 5) % 40;
            background_liberal_influence[v] = 0;
         }

         int made = 0;
         for (int j = 0; j < JOB_COUNT; j++)
         for (int n = 0; n < crowd; n++)
         {
            if (solo >= 0 && j != solo) continue;
            // "spread" alternates the roster order so the grouping is doing
            // real work: without it the roster is already in activity order.
            Creature *cr = new Creature;
            cr->id = 600000 + made;
            cr->align = ALIGN_LIBERAL;
            cr->location = 1;
            cr->base = 1;
            cr->hireid = made ? 0 : -1;
            cr->juice = 50 * n;
            cr->set_skill(SKILL_COMPUTERS, (j + n + scenario) % 12);
            cr->set_skill(SKILL_ART, (j * 2 + n + scenario) % 10);
            cr->set_skill(SKILL_STREETSENSE, (j + n * 2 + scenario) % 8);
            cr->set_skill(SKILL_BUSINESS, (j + n) % 6);
            cr->set_skill(SKILL_MUSIC, (j + n) % 6);
            cr->set_skill(SKILL_PERSUASION, (j + n) % 6);
            // Dressed, because a naked Liberal on the street is arrested
            // half the time and that is a different pass entirely.
            cr->give_armor(*armortype[getarmortype("ARMOR_CLOTHES")], NULL);
            cr->activity.type = JOBS[spread ? (JOB_COUNT - 1 - j) : j];
            if (cr->activity.type == ACTIVITY_GRAFFITI)
            {
               cr->give_weapon(*weapontype[getweapontype("WEAPON_SPRAYCAN")], NULL);
               cr->activity.arg = (n == 2) ? VIEW_TAXES : -1;
            }
            // A trip to the clinic only means anything to somebody hurt, and
            // the length of the stay is read straight off the injuries.
            if (cr->activity.type == ACTIVITY_CLINIC)
            {
               cr->blood = 40 + n * 25;
               cr->wound[BODYPART_ARM_RIGHT] |= WOUND_NASTYOFF;
               cr->special[SPECIALWOUND_LEFTLUNG] = 0;
               if (n) cr->special[SPECIALWOUND_HEART] = 0;
               cr->special[SPECIALWOUND_RIBS] = RIBNUM - n;
            }
            if (cr->activity.type == ACTIVITY_SLEEPER_JOINLCS)
               cr->flag |= CREATUREFLAG_SLEEPER;
            pool.push_back(cr);
            made++;
         }

         // A couple of bodies, so the burial pass has something to do. They
         // are at the end of the pool, which is where the original walks from.
         for (int d = 0; d < 2; d++)
         {
            Creature *dead = new Creature;
            dead->id = 610000 + d;
            dead->align = ALIGN_LIBERAL;
            dead->location = 1;
            dead->base = 1;
            dead->alive = false;
            dead->money = 20 + d * 15;
            dead->activity.type = ACTIVITY_NONE;
            pool.push_back(dead);
         }

         fprintf(out, "{\"kind\":\"day\",\"scenario\":%d,\"seed\":%lu,"
                      "\"crowd\":%d,\"spread\":%d,\"solo\":%d,"
                      "\"world_seed\":%lu",
                 scenario, seed_used, crowd, spread, solo, run_seed);
         fputs(",\"law\":[", out);
         for (int i = 0; i < LAWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", law[i]);
         fputs("],\"attitude\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("],\"pool\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"activity\":%d,\"arg\":%d,\"clinic\":%d,"
                         "\"sleeper\":%d,\"person\":",
                    p ? "," : "", pool[p]->activity.type, (int)pool[p]->activity.arg,
                    (int)pool[p]->clinic,
                    (pool[p]->flag & CREATUREFLAG_SLEEPER) ? 1 : 0);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("]", out);
         fputs(",\"rng\":[", out);
         for (int i = 0; i < RNG_SIZE; i++)
            fprintf(out, "%s%lu", i ? "," : "", ::seed[i]);
         fputs("]", out);

         char clearformess = 0;
         // A clean news queue per sample, so the stories the day files can be
         // read off the end of it. The original never clears `sitestory`, so
         // it is cleared here rather than left pointing at a freed story from
         // the sample before.
         delete_and_clear(newsstory);
         sitestory = NULL;
         long long before = lcs_trace_draw_count();
         // Split by group, so a divergence names the activity rather than the
         // day. Mirrors funds_and_trouble()'s own order.
         long long split[12];
         {
            vector<Creature *> trouble, hack, bury, solicit, tshirts, art,
                               music, graffiti, brownies, prostitutes,
                               teachers, students;
            for (int p = 0; p < len(pool); p++)
            {
               switch (pool[p]->activity.type)
               {
               case ACTIVITY_CCFRAUD: case ACTIVITY_DOS_RACKET:
               case ACTIVITY_DOS_ATTACKS: case ACTIVITY_HACKING:
                  hack.push_back(pool[p]); break;
               case ACTIVITY_GRAFFITI: graffiti.push_back(pool[p]); break;
               case ACTIVITY_DONATIONS: solicit.push_back(pool[p]); break;
               case ACTIVITY_SELL_TSHIRTS: tshirts.push_back(pool[p]); break;
               case ACTIVITY_SELL_ART: art.push_back(pool[p]); break;
               case ACTIVITY_SELL_MUSIC: music.push_back(pool[p]); break;
               case ACTIVITY_SELL_DRUGS: brownies.push_back(pool[p]); break;
               case ACTIVITY_PROSTITUTION: prostitutes.push_back(pool[p]); break;
               case ACTIVITY_TROUBLE: trouble.push_back(pool[p]); break;
               case ACTIVITY_BURY: bury.push_back(pool[p]); break;
               case ACTIVITY_TEACH_POLITICS: case ACTIVITY_TEACH_COVERT:
               case ACTIVITY_TEACH_FIGHTING: teachers.push_back(pool[p]); break;
               case ACTIVITY_STUDY_LAW: case ACTIVITY_STUDY_MARTIAL_ARTS:
                  students.push_back(pool[p]); break;
               case ACTIVITY_COMMUNITYSERVICE:
                  addjuice(*pool[p],1,10);
                  change_public_opinion(VIEW_LIBERALCRIMESQUADPOS,1,0,80);
                  break;
               case ACTIVITY_CLINIC:
                  hospitalize(find_clinic(*pool[p]),*pool[p]);
                  pool[p]->activity.type=ACTIVITY_NONE;
                  break;
               case ACTIVITY_SLEEPER_JOINLCS:
                  if(!location[find_homeless_shelter(*pool[p])]->siege.siege)
                  {
                     pool[p]->activity.type=ACTIVITY_NONE;
                     pool[p]->flag &= ~CREATUREFLAG_SLEEPER;
                     pool[p]->location = pool[p]->base =
                        find_homeless_shelter(*pool[p]);
                  }
                  // No break: the original falls through into the letters.
               case ACTIVITY_WRITE_LETTERS:
                  if(pool[p]->skill_check(SKILL_WRITING,DIFFICULTY_EASY))
                     background_liberal_influence[randomissue()]+=5;
                  pool[p]->train(SKILL_WRITING,LCSrandom(5)+1);
                  break;
               case ACTIVITY_WRITE_GUARDIAN:
                  if(pool[p]->skill_check(SKILL_WRITING,DIFFICULTY_EASY))
                     background_liberal_influence[randomissue()]+=15;
                  else
                     background_liberal_influence[randomissue()]-=15;
                  pool[p]->train(SKILL_WRITING,LCSrandom(5)+1);
                  break;
               }
            }
            long long at = lcs_trace_draw_count();
            doActivitySolicitDonations(solicit, clearformess);
            split[0] = lcs_trace_draw_count() - at; at = lcs_trace_draw_count();
            doActivitySellTshirts(tshirts, clearformess);
            split[1] = lcs_trace_draw_count() - at; at = lcs_trace_draw_count();
            doActivitySellArt(art, clearformess);
            split[2] = lcs_trace_draw_count() - at; at = lcs_trace_draw_count();
            doActivitySellMusic(music, clearformess);
            split[3] = lcs_trace_draw_count() - at; at = lcs_trace_draw_count();
            doActivitySellBrownies(brownies, clearformess);
            split[4] = lcs_trace_draw_count() - at; at = lcs_trace_draw_count();
            doActivityHacking(hack, clearformess);
            split[5] = lcs_trace_draw_count() - at; at = lcs_trace_draw_count();
            doActivityGraffiti(graffiti, clearformess);
            split[6] = lcs_trace_draw_count() - at; at = lcs_trace_draw_count();
            doActivityProstitution(prostitutes, clearformess);
            split[7] = lcs_trace_draw_count() - at; at = lcs_trace_draw_count();
            doActivityLearn(students, clearformess);
            split[8] = lcs_trace_draw_count() - at; at = lcs_trace_draw_count();
            doActivityTrouble(trouble, clearformess);
            split[9] = lcs_trace_draw_count() - at; at = lcs_trace_draw_count();
            doActivityTeach(teachers, clearformess);
            split[10] = lcs_trace_draw_count() - at; at = lcs_trace_draw_count();
            doActivityBury(bury, clearformess);
            split[11] = lcs_trace_draw_count() - at;
         }

         fprintf(out, ",\"draws\":%lld,\"funds\":%d",
                 lcs_trace_draw_count() - before, ledger.get_funds());
         fputs(",\"split\":[", out);
         for (int i = 0; i < 12; i++)
            fprintf(out, "%s%lld", i ? "," : "", split[i]);
         fputs("]", out);
         fputs(",\"attitude_after\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", attitude[i]);
         fputs("],\"interest_after\":[", out);
         for (int i = 0; i < VIEWNUM; i++)
            fprintf(out, "%s%d", i ? "," : "", public_interest[i]);
         fputs("],\"pool_after\":[", out);
         for (int p = 0; p < len(pool); p++)
         {
            fprintf(out, "%s{\"activity\":%d,\"arg\":%d,\"income\":%d,"
                         "\"clinic\":%d,\"sleeper\":%d,\"person\":",
                    p ? "," : "", pool[p]->activity.type, (int)pool[p]->activity.arg,
                    (int)pool[p]->income, (int)pool[p]->clinic,
                    (pool[p]->flag & CREATUREFLAG_SLEEPER) ? 1 : 0);
            chase_write_creature(out, *pool[p], true);
            fputs("}", out);
         }
         fputs("],\"baseloot\":[", out);
         for (int i = 0; i < len(location[1]->loot); i++)
            fprintf(out, "%s\"%s\"", i ? "," : "",
                    location[1]->loot[i]->get_itemtypename().c_str());
         fputs("],\"stories\":[", out);
         for (int n = 0; n < len(newsstory); n++)
         {
            fprintf(out, "%s{\"type\":%d,\"loc\":%d,\"claimed\":%d,"
                         "\"crimes\":[",
                    n ? "," : "", newsstory[n]->type, (int)newsstory[n]->loc,
                    (int)newsstory[n]->claimed);
            for (int c = 0; c < len(newsstory[n]->crime); c++)
               fprintf(out, "%s%d", c ? "," : "", newsstory[n]->crime[c]);
            fputs("]}", out);
         }
         fputs("]}\n", out);

         delete_and_clear(pool);
         delete_and_clear(location[1]->loot);
      }
   }
}

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
   else if (!strcmp(which, "names")) probe_names(out);
   else if (!strcmp(which, "opinion")) probe_opinion_change(out);
   else if (!strcmp(which, "wincheck")) probe_wincheck(out);
   else if (!strcmp(which, "world")) probe_world(out);
   else if (!strcmp(which, "spawn")) probe_spawn(out);
   else if (!strcmp(which, "sitemaps")) probe_sitemaps(out);
   else if (!strcmp(which, "sites")) probe_sites(out);
   else if (!strcmp(which, "context")) probe_context_checks(out);
   else if (!strcmp(which, "combat")) probe_combat(out);
   else if (!strcmp(which, "chase")) probe_chase(out);
   else if (!strcmp(which, "fight")) probe_fight(out);
   else if (!strcmp(which, "encounters")) probe_encounters(out);
   else if (!strcmp(which, "stealth")) probe_stealth(out);
   else if (!strcmp(which, "recruit")) probe_recruit(out);
   else if (!strcmp(which, "activities_day")) probe_activities_day(out);
   else if (!strcmp(which, "activation")) probe_activation_day(out);
   else if (!strcmp(which, "recovery")) probe_recovery(out);
   else if (!strcmp(which, "dispersal")) probe_dispersal(out);
   else if (!strcmp(which, "ageing")) probe_ageing(out);
   else if (!strcmp(which, "drift")) probe_monthly_drift(out);
   else if (!strcmp(which, "sleepers")) probe_sleepers(out);
   else if (!strcmp(which, "justice")) probe_justice(out);
   else if (!strcmp(which, "siege_watch")) probe_siege_watch(out);
   else if (!strcmp(which, "siege_turn")) probe_siege_turn(out);
   else if (!strcmp(which, "surrender")) probe_siege_surrender(out);
   else if (!strcmp(which, "siege_outcome")) probe_siege_outcome(out);
   else if (!strcmp(which, "newspaper")) probe_newspaper(out);
   else if (!strcmp(which, "cartheft")) probe_cartheft(out);
   else if (!strcmp(which, "dating")) probe_dating(out);
   else if (!strcmp(which, "interrogation")) probe_interrogation(out);
   else if (!strcmp(which, "disband")) probe_disband(out);
   else if (!strcmp(which, "safehouse")) probe_safehouse(out);
   else if (!strcmp(which, "amendments")) probe_amendments(out);
   else if (!strcmp(which, "election_day")) probe_election_day(out);
   else if (!strcmp(which, "kidnap")) probe_kidnap(out);
   else if (!strcmp(which, "site_specials")) probe_site_specials(out);
   else if (!strcmp(which, "vaults")) probe_vaults(out);
   else if (!strcmp(which, "lockup")) probe_lockup(out);
   else if (!strcmp(which, "prison_control")) probe_prison_control(out);
   else
   {
      fprintf(stderr, "lcs_probe: unknown probe '%s'\n", which);
      exit(2);
   }

   fclose(out);
   endwin();
   exit(0);
}
