#!/usr/bin/env python3
"""Maps every global the original mutates onto where the port keeps it.

Gate J of docs/ROADMAP_PORT_COMPLETION.md asks that every state mutation in
the original has an equivalent in the port or a documented exception. The
original keeps its whole world in globals declared in src/externs.h, so the
list of things that can be mutated is that file: anything a function writes,
it writes there or into a Creature, Location, Item or Vehicle that hangs off
there.

This tool reads those declarations and looks each name up in CARRIED below,
which says where in the port that piece of state lives — or why nothing in the
port needs it. Unlike tools/audit_parity.py it does not search the port for the
name: half of these globals are ordinary English words (law, court, mode, pool,
score) that would match by accident, so every one of them is written out.

A global added to the original, or a rename that breaks the map, fails here.

    python3 tools/audit_state.py           # summary, and anything unaccounted
    python3 tools/audit_state.py --list    # every global and its verdict
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXTERNS = ROOT / "src" / "externs.h"

DECLARATION = re.compile(r"^extern\s+(?:const\s+)?[\w:<>,\s]*?[\s\*&]"
                         r"([A-Za-z_]\w*)\s*(?:\[[^\]]*\])*\s*;", re.MULTILINE)

# Where each global that the port does not name by its original spelling went.
CARRIED = {
    # --- The terminal, the art and the platform -------------------------
    "homedir": "obsolete: a DOS-era install layout",
    "artdir": "obsolete: a DOS-era install layout",
    "movie": "obsolete: the .cmv player does not survive 64 bits",
    "bigletters": "presentation-replaced: HeadlineText",
    "newstops": "presentation-replaced: the newspaper's masthead art",
    "newspic": "presentation-replaced: MajorEventPageText",
    "music": "presentation-replaced: the port's own audio, if any",
    "interface_pgup": "presentation-replaced: a scrolling list",
    "interface_pgdn": "presentation-replaced: a scrolling list",
    "fixcleartype": "obsolete: a Windows font workaround",
    "oldMapMode": "presentation-replaced: SiteMapView draws one way",
    "mapshowing": "presentation-replaced: SiteMapView is always up",
    "showcarprefs": "presentation-replaced: MarshallingPanel is a panel",
    "party_status": "presentation-replaced: which squad row is expanded",
    "gamelog": "presentation-replaced: LogView, fed by Events",
    "xmllog": "presentation-replaced: Godot's own import errors",
    "savefile_name": "presentation-replaced: SettingsPanel's slots",
    "autosave": "presentation-replaced: Commands.advance_day's own flag",
    "encounterwarnings": "presentation-replaced: the port always shows them",
    "activesortingchoice": "presentation-replaced: the roster's own ordering",
    # --- Content tables, which are Resources now ------------------------
    "sitemaps": "carried: SiteMaps and SitePlans",
    "cliptype": "carried: Catalog's clip Resources",
    "weapontype": "carried: Catalog's weapon Resources",
    "armortype": "carried: Catalog's armor Resources",
    "loottype": "carried: Catalog's loot Resources",
    "creaturetype": "carried: Catalog's creature Resources",
    "augmenttype": "carried: Catalog's augmentation Resources",
    "vehicletype": "carried: Catalog's vehicle Resources",
    "uniqueCreatures": "carried: GameState.uniques",
    # --- State the port keeps under another name ------------------------
    "seed": "carried: Rng, which is seeded and passed rather than global",
    "levelmap": "carried: GameState.site.map, a SiteMap",
    "cursite": "carried: GameState.site.location",
    "sitetype": "carried: the Location's own type",
    "locx": "carried: GameState.site.x",
    "locy": "carried: GameState.site.y",
    "locz": "carried: GameState.site.z",
    "encounter": "carried: GameState.site.encounter_ids",
    "groundloot": "carried: GameState.site.ground_loot",
    "sitealienate": "carried: GameState.site.alienate",
    "sitealarm": "carried: GameState.site.alarm",
    "sitealarmtimer": "carried: GameState.site.alarm_timer",
    "postalarmtimer": "carried: GameState.site.post_alarm_timer",
    "siteonfire": "carried: GameState.site.on_fire",
    "sitecrime": "carried: GameState.site.crime",
    "sitestory": "carried: GameState.site.story",
    "foughtthisround": "carried: the combat context's own flag",
    "chaseseq": "carried: GameState.chase",
    "curcreatureid": "carried: GameState's own id counter",
    "cursquadid": "carried: GameState's own id counter",
    "cantseereason": "carried: Awareness.reason",
    "lcityname": "carried: GameState.city_name",
    "attorneyseed": "carried: the trial's own draw",
    "loaded": "carried: SaveGame's own result",
    "date": "carried: GameState.calendar",
    "day": "carried: GameState.calendar.day",
    "month": "carried: GameState.calendar.month",
    "year": "carried: GameState.calendar.year",
    "courtname": "carried: the justices' own names in GameState.court",
    "execname": "carried: GameState.executive's own names",
    "oldPresidentName": "carried: GameState.executive's own record",
    "stat_recruits": "carried: GameState.stats",
    "stat_kidnappings": "carried: GameState.stats",
    "stat_dead": "carried: GameState.stats",
    "stat_kills": "carried: GameState.stats",
    "stat_funds": "carried: GameState.stats",
    "stat_spent": "carried: GameState.stats",
    "stat_buys": "carried: GameState.stats",
    "stat_burns": "carried: GameState.stats",
    "ustat_recruits": "carried: GameState.stats, the month's half",
    "ustat_kidnappings": "carried: GameState.stats, the month's half",
    "ustat_dead": "carried: GameState.stats, the month's half",
    "ustat_kills": "carried: GameState.stats, the month's half",
    "ustat_funds": "carried: GameState.stats, the month's half",
    "ustat_spent": "carried: GameState.stats, the month's half",
    "ustat_buys": "carried: GameState.stats, the month's half",
    "ustat_burns": "carried: GameState.stats, the month's half",
    "offended_corps": "carried: GameState.offended",
    "offended_cia": "carried: GameState.offended",
    "offended_amradio": "carried: GameState.offended",
    "offended_cablenews": "carried: GameState.offended",
    "offended_firemen": "carried: GameState.offended",
    "newscherrybusted": "carried: GameState.stats",
    "ccs_kills": "carried: GameState.stats",
    "ccs_siege_kills": "carried: GameState.stats",
    "ccs_boss_kills": "carried: GameState.stats",
    "score": "carried: HighScores",
    "yourscore": "carried: HighScores",
    "deagle": "carried: the unique weapons' own flags in GameState",
    "m249": "carried: the unique weapons' own flags in GameState",
    "multipleCityMode": "carried: WorldLayout builds every city either way",
    "fieldskillrate": "carried: TrainingRules' own rate",
    "activesquad": "carried: GameState.active_squad_id and active_squad()",
    "law": "carried: GameState.law, a Law",
    "house": "carried: GameState.government's House",
    "senate": "carried: GameState.government's Senate",
    "court": "carried: GameState.government's Supreme Court",
    "exec": "carried: GameState.government's executive",
    "execterm": "carried: GameState.government's term counter",
    "presparty": "carried: GameState.government's president's party",
    "termlimits": "carried: GameState.term_limits",
    "amendnum": "carried: GameState.amendments",
    "attitude": "carried: GameState.opinion, a PublicOpinion",
    "public_interest": "carried: PublicOpinion's interest per issue",
    "background_liberal_influence": "carried: PublicOpinion's background",
    "ledger": "carried: GameState.ledger, a Ledger",
    "mode": "carried: GameState.mode",
    "wincondition": "carried: GameState.win_condition",
    "stalinmode": "carried: GameState.stalin_mode",
    "police_heat": "carried: GameState.police_heat",
    "ccsexposure": "carried: GameState.ccs_exposure",
    "endgamestate": "carried: GameState.endgame_state",
    "disbanding": "carried: GameState.disbanded",
    "disbandtime": "carried: GameState.disband_year",
    "slogan": "carried: GameState.slogan",
    "pool": "carried: GameState.creatures",
    "squad": "carried: GameState.squads",
    "location": "carried: GameState.locations",
    "vehicle": "carried: GameState.vehicles",
    "newsstory": "carried: GameState.news",
    "recruit": "carried: GameState.recruit_meetings",
    "notermlimit": "carried: GameState.no_term_limits",
    "nocourtpurge": "carried: GameState.no_court_purge",
    "selectedsiege": "presentation-replaced: which siege the status bar is "
                     "showing; every besieged safehouse is listed at once",
}


def globals_declared() -> list[str]:
    text = EXTERNS.read_bytes().decode("cp437")
    return sorted(set(DECLARATION.findall(text)))


def main() -> int:
    every = globals_declared()
    carried, unaccounted = [], []
    for name in every:
        if name in CARRIED:
            carried.append(name)
        else:
            unaccounted.append(name)

    if "--list" in sys.argv:
        for name in every:
            print("%-30s %s" % (name, CARRIED.get(name, "UNACCOUNTED")))

    print("%d globals in the original's own state." % len(every))
    print("  %d are mapped onto the port." % len(carried))
    print("  %d are unaccounted for." % len(unaccounted))
    for name in unaccounted:
        print("    %s" % name)
    return 1 if unaccounted else 0


if __name__ == "__main__":
    raise SystemExit(main())
