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
   fprintf(out, ",\"meetings\":%d", cr.meetings);
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
   else
   {
      fprintf(stderr, "lcs_probe: unknown probe '%s'\n", which);
      exit(2);
   }

   fclose(out);
   endwin();
   exit(0);
}
