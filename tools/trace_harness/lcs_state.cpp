// Serializes the running game's state as JSON, for the golden-trace harness.
//
// This is the signal the Godot port is actually diffed against: what the game
// *says* is a proxy, but what it *is* after the same inputs is the truth. The
// port reproduces this structure from its own GameState.
//
// Liberal Crime Squad is GPL-2.0-or-later; so is this file.
#include <externs.h>
#include <includes.h>

#include <cstdio>
#include <string>

#include "lcs_trace.h"

namespace {

void json_string(std::string &out, const char *text)
{
   out += '"';
   for (const char *p = text; p && *p; p++)
   {
      unsigned char ch = (unsigned char)*p;
      if (ch == '"' || ch == '\\') { out += '\\'; out += (char)ch; }
      else if (ch < 32 || ch > 126)
      {
         char buffer[8];
         snprintf(buffer, sizeof(buffer), "\\u%04x", ch);
         out += buffer;
      }
      else out += (char)ch;
   }
   out += '"';
}

void field(std::string &out, const char *name, long long value, bool first = false)
{
   if (!first) out += ',';
   out += '"'; out += name; out += "\":";
   char buffer[32];
   snprintf(buffer, sizeof(buffer), "%lld", value);
   out += buffer;
}

template <typename T>
void int_array(std::string &out, const char *name, const T *values, int count)
{
   out += ",\""; out += name; out += "\":[";
   for (int i = 0; i < count; i++)
   {
      if (i) out += ',';
      char buffer[32];
      snprintf(buffer, sizeof(buffer), "%d", (int)values[i]);
      out += buffer;
   }
   out += ']';
}

// One creature, flattened. Only fields the simulation can change: cosmetic and
// UI-only members are left out so the comparator does not police presentation.
void creature_json(std::string &out, const Creature &cr)
{
   out += '{';
   field(out, "id", cr.id, true);
   out += ",\"name\":"; json_string(out, cr.name);
   out += ",\"type\":"; json_string(out, cr.type_idname.c_str());
   field(out, "align", cr.align);
   field(out, "alive", cr.alive ? 1 : 0);
   field(out, "exists", cr.exists ? 1 : 0);
   field(out, "squadid", cr.squadid);
   field(out, "age", cr.age);
   field(out, "juice", cr.juice);
   field(out, "money", cr.money);
   field(out, "blood", cr.blood);
   field(out, "heat", cr.heat);
   field(out, "location", cr.location);
   field(out, "base", cr.base);
   field(out, "hiding", cr.hiding);
   field(out, "clinic", cr.clinic);
   field(out, "dating", cr.dating);
   field(out, "sentence", cr.sentence);
   field(out, "joindays", cr.joindays);
   field(out, "stunned", cr.stunned);
   field(out, "infiltration", (long long)(cr.infiltration * 1000000.0f));

   out += ",\"attributes\":[";
   for (int i = 0; i < ATTNUM; i++)
   {
      if (i) out += ',';
      char buffer[32];
      snprintf(buffer, sizeof(buffer), "%d", cr.get_attribute(i, false));
      out += buffer;
   }
   out += "],\"skills\":[";
   for (int i = 0; i < SKILLNUM; i++)
   {
      if (i) out += ',';
      char buffer[32];
      snprintf(buffer, sizeof(buffer), "%d", cr.get_skill(i));
      out += buffer;
   }
   out += ']';
   int_array(out, "special", cr.special, SPECIALWOUNDNUM);
   int_array(out, "crimes_suspected", cr.crimes_suspected, LAWFLAGNUM);
   out += '}';
}

} // namespace

void lcs_trace_state(std::string &out)
{
   out += '{';
   field(out, "day", day, true);
   field(out, "month", month);
   field(out, "year", year);
   field(out, "mode", mode);
   field(out, "funds", ledger.get_funds());
   field(out, "total_income", ledger.total_income);
   field(out, "total_expense", ledger.total_expense);
   field(out, "police_heat", police_heat);
   field(out, "endgamestate", endgamestate);
   field(out, "ccsexposure", ccsexposure);
   field(out, "amendnum", amendnum);
   field(out, "execterm", execterm);
   field(out, "presparty", presparty);
   field(out, "offended_corps", offended_corps);
   field(out, "offended_cia", offended_cia);
   field(out, "offended_amradio", offended_amradio);
   field(out, "offended_cablenews", offended_cablenews);
   field(out, "offended_firemen", offended_firemen);
   field(out, "sitealarm", sitealarm);
   field(out, "sitecrime", sitecrime);
   field(out, "cursite", cursite);
   field(out, "curcreatureid", curcreatureid);
   field(out, "cursquadid", cursquadid);
   field(out, "stat_recruits", stat_recruits);
   field(out, "stat_kills", stat_kills);
   field(out, "stat_dead", stat_dead);
   field(out, "stat_kidnappings", stat_kidnappings);

   int_array(out, "law", law, LAWNUM);
   int_array(out, "attitude", attitude, VIEWNUM);
   int_array(out, "public_interest", public_interest, VIEWNUM);
   int_array(out, "background_liberal_influence", background_liberal_influence, VIEWNUM);
   int_array(out, "exec", exec, EXECNUM);
   int_array(out, "court", court, COURTNUM);
   int_array(out, "senate", senate, SENATENUM);
   int_array(out, "house", house, HOUSENUM);
   int_array(out, "rng", seed, RNG_SIZE);

   out += ",\"pool\":[";
   for (int i = 0; i < len(pool); i++)
   {
      if (i) out += ',';
      creature_json(out, *pool[i]);
   }
   out += "]}";
}
