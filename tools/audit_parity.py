#!/usr/bin/env python3
"""Maps every function in the original onto what became of it in the port.

Gate J of docs/ROADMAP_PORT_COMPLETION.md asks for every meaningful legacy
function to be accounted for as one of:

  ported                  a system in game/ names it and does what it did
  presentation-replaced   it drew a terminal, and the port draws its own
  obsolete                nothing can reach it, or it exists for a dead build
  deferred                deliberately left for after parity

The port writes "Ports foo() from src/..." in the class comment of whatever
ported it, so most of this answers itself: the tool reads the sources for
function definitions, reads game/ for those names, and reports what is left.
What is left is classified in CLASSIFIED below, with a reason, so the residue
of the audit is a fact in the tree rather than a claim in a document.

    python3 tools/audit_parity.py           # summary, and anything unaccounted
    python3 tools/audit_parity.py --list    # every function and its verdict
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
GAME = ROOT / "game"

# Vendored or build-only trees: not the original's game logic.
VENDORED = {"pdcurses", "sdl", "cmarkup", "sandbox", "log"}
VENDORED_FILES = {
    "dumpcaps.cpp",       # a one-off tool for dumping the art files
    "cursesgraphics.cpp", # the terminal itself
    "cursesmovie.cpp",    # the .cmv player, which does not survive 64 bits
    "lcsio.cpp",          # file paths for a DOS-era install layout
    "configfile.cpp",     # the init file the port replaces with its own
}

# A definition looks like `type name(args)` at the start of a line, or a
# method as `Type::name(`.
DEFINITION = re.compile(
    r"^[A-Za-z_][\w:<>,\s\*&]*?[\s\*&]([A-Za-z_]\w*)\s*\([^;]*$", re.MULTILINE)
METHOD = re.compile(r"^\s*\w[\w:<>,\s\*&]*?([A-Za-z_]\w*)::([A-Za-z_]\w*)\s*\(")

# Names that are not worth auditing: C++ plumbing, and the handful of helpers
# whose whole body is a switch over strings.
IGNORED_NAMES = {
    "if", "for", "while", "switch", "return", "else", "do", "catch",
    "main", "operator", "sizeof",
}

# What became of everything the port does not name. Each entry is a reason,
# and the reason is the audit.
CLASSIFIED = {
    # --- The terminal itself -------------------------------------------
    "addstr": "presentation-replaced: writing to a curses window",
    "addstr_f": "presentation-replaced: writing to a curses window",
    "addstr_fl": "presentation-replaced: writing to a curses window",
    "addchar": "presentation-replaced: writing to a curses window",
    "mvaddstr": "presentation-replaced: writing to a curses window",
    "mvaddchar": "presentation-replaced: writing to a curses window",
    "mvaddch": "presentation-replaced: writing to a curses window",
    "set_color": "presentation-replaced: a sixteen-colour palette",
    "set_alignment_color": "presentation-replaced: a sixteen-colour palette",
    "translateGraphicsColor": "presentation-replaced: DOS colour codes",
    "translateGraphicsChar": "presentation-replaced: codepage 437 glyphs",
    "erase": "presentation-replaced: clearing a terminal",
    "refresh": "presentation-replaced: flushing a terminal",
    "move": "presentation-replaced: moving a terminal cursor",
    "clearmessagearea": "presentation-replaced: a fixed message area",
    "clearcommandarea": "presentation-replaced: a fixed command area",
    "printparty": "presentation-replaced: the squad drawn across the top",
    "printfunds": "presentation-replaced: a line of the status bar",
    "printnews": "presentation-replaced: a line of the status bar",
    "addoptions": "presentation-replaced: a menu of single letters",
    "addnextpagestr": "presentation-replaced: paging a terminal list",
    "addprevpagestr": "presentation-replaced: paging a terminal list",
    "displaycenterednewsfont": "presentation-replaced: HeadlineText",
    "displaycenteredsmallnews": "presentation-replaced: MajorEventPageText",
    "displaynewsstory": "presentation-replaced: NewspaperPanel",
    "displaynewspicture": "presentation-replaced: MajorEventPageText",
    "displaystory": "presentation-replaced: NewsReading and NewspaperPanel",
    "displaystoryheader": "ported as HeadlineRules; the lettering is replaced",
    "displayads": "ported as NewsAds; the boxes are replaced",
    "displaysinglead": "ported as NewsAds; the boxes are replaced",
    "preparepage": "ported as NewsReading._page; the masthead art is replaced",
    "display_newspaper": "ported as NewsReading",
    "displaymajoreventstory": "ported as MajorEventStory",
    "constructeventstory": "ported as MajorEventGood/Bad/Industry",
    "squadstory_text_opening": "ported as SquadStory.opening",
    "squadstory_text_location": "presentation-replaced: NewspaperPanel",
    "generatefiller": "ported as StoryFiller",
    "getLastNameForHeadline": "obsolete: the president headlines are unreachable",
    "run_television_news_stories": "ported as NewsBroadcast",
    "loadgraphics": "obsolete: the .cpc art does not survive 64 bits",
    "title": "presentation-replaced: TitleScreen and TitleQuotes",
    # --- Input ---------------------------------------------------------
    "getkey": "presentation-replaced: the Intent/Command seam",
    "getkey_cap": "presentation-replaced: the Intent/Command seam",
    "prompt_amount": "presentation-replaced: the stores panel's counts",
    "keypress": "presentation-replaced: the Intent/Command seam",
    # --- Dead or build-only ---------------------------------------------
    "arttest": "obsolete: a startup check for the art files",
    "sortbyhire": "presentation-replaced: the roster's own ordering",
    "printname": "presentation-replaced: a row of the roster",
    "adjustblogpower": "obsolete: declared and defined, never called",
    "plate": "obsolete: a licence plate generator with no callers",
    "help": "obsolete: an empty stub beside the help text",
    "end_game": "obsolete: exit(), and the flushing that has to happen first",
    "Johnson": "obsolete: a name in the file header, not a function",
    # --- The terminal, part two -----------------------------------------
    "addch_unicode": "presentation-replaced: a curses glyph",
    "lookup_unicode_hack": "presentation-replaced: codepage 437 glyphs",
    "setup_unicode": "presentation-replaced: a terminal's encoding",
    "init_console": "presentation-replaced: opening a terminal",
    "set_title": "presentation-replaced: a terminal's window title",
    "begin_cleartype_fix": "presentation-replaced: a Windows font workaround",
    "end_cleartype_fix": "presentation-replaced: a Windows font workaround",
    "translategetch": "presentation-replaced: the Intent/Command seam",
    "translategetch_cap": "presentation-replaced: the Intent/Command seam",
    "checkkey": "presentation-replaced: the Intent/Command seam",
    "checkkey_cap": "presentation-replaced: the Intent/Command seam",
    "addpagestr": "presentation-replaced: paging a terminal list",
    "mvaddstr_f": "presentation-replaced: writing to a curses window",
    "mvaddstr_fl": "presentation-replaced: writing to a curses window",
    "set_activity_color": "presentation-replaced: the roster's own colours",
    "locheader": "presentation-replaced: a fixed header row",
    "fullstatus": "presentation-replaced: Dossier",
    "printcreatureinfo": "presentation-replaced: Dossier",
    "printhealthstat": "presentation-replaced: DossierText.record",
    "printwoundstat": "presentation-replaced: DossierText.record",
    "printliberalstats": "presentation-replaced: DossierText.record",
    "printliberalskills": "presentation-replaced: DossierText.record",
    "printliberalcrimes": "presentation-replaced: DossierText.record",
    "printlocation": "presentation-replaced: the safehouse panel",
    "printblock": "presentation-replaced: SiteMapView",
    "printwall": "presentation-replaced: SiteMapView",
    "printsitemap": "presentation-replaced: SiteMapView",
    "clearmaparea": "presentation-replaced: SiteMapView",
    "refreshmaparea": "presentation-replaced: SiteMapView",
    "LineOfSight": "presentation-replaced: what SiteMapView draws is not a "
                   "flashlight beam across a character grid",
    "printchaseencounter": "presentation-replaced: ChaseText",
    "show_interrogation_sidebar": "presentation-replaced: the interrogation "
                                  "panel, which is not a sidebar",
    "clear_interrogation_sidebar": "presentation-replaced: as above",
    "show_victim_status": "presentation-replaced: FightText.condition",
    "guardianupdate": "presentation-replaced: how the Guardian was received, "
                      "from the power SpecialEditionRun already returns",
    "conquertext": "presentation-replaced: the siege demands, in SafehouseText",
    "conquertextccs": "presentation-replaced: as above, for the CCS",
    "statebrokenlaws": "presentation-replaced: what the police are shouting "
                       "through the door; the crimes are JusticePanel's",
    "amendmentheading": "presentation-replaced: a banner over the amendment",
    "HelpActivities": "presentation-replaced: the roster's own tooltips",
    "mode_title": "presentation-replaced: TitleScreen",
    # --- Prompts: the Intent/Command seam -------------------------------
    "buyprompt": "presentation-replaced: StoresPanel's counts",
    "choiceprompt": "presentation-replaced: an Intent with options",
    "choose_one": "presentation-replaced: an Intent with options",
    "chooseLetterOrNumber": "obsolete: a helper for the unreachable plate()",
    "enter_name": "presentation-replaced: a LineEdit",
    "choose_savefile_name": "presentation-replaced: SettingsPanel's slots",
    "sorting_prompt": "presentation-replaced: the roster's own ordering",
    "sortliberals": "presentation-replaced: the roster's own ordering",
    "sort_none": "presentation-replaced: the roster's own ordering",
    "sort_squadorname": "presentation-replaced: the roster's own ordering",
    "sort_locationandname": "presentation-replaced: the roster's own ordering",
    "reviewmodeenum_to_sortingchoiceenum":
        "presentation-replaced: which list remembers which ordering",
    # --- Screens whose decisions the port makes elsewhere ----------------
    "review": "presentation-replaced: Roster and Dossier",
    "activatable_liberals": "presentation-replaced: GameState.members()",
    "activatebulk": "presentation-replaced: the roster assigns one at a time",
    "listclasses": "presentation-replaced: the roster's activity picker, "
                   "which does not need the original's four pages",
    "updateclasschoice": "presentation-replaced: as above",
    "assemblesquad": "presentation-replaced: SquadPanel and MarshallingPanel",
    "equipmentbaseassign": "presentation-replaced: Dossier hands out the kit",
    "scheduleddates": "presentation-replaced: a line of the status bar",
    "scheduledmeetings": "presentation-replaced: a line of the status bar",
    "stopevil": "presentation-replaced: Destination and CHOOSE_DESTINATION",
    "choose_buyer": "presentation-replaced: who owns a new car is the "
                    "marshalling panel's, and can be changed after the sale",
    "armsdealer": "presentation-replaced: three lines opening ShopVisit",
    "deptstore": "presentation-replaced: three lines opening ShopVisit",
    "pawnshop": "presentation-replaced: three lines opening ShopVisit",
    "halloweenstore": "presentation-replaced: three lines opening ShopVisit",
    "select_view": "obsolete: asks which issue a Guardian essay is about, and "
                   "the essay then rolls its own issue and never reads it",
    "select_troublefundinglevel": "obsolete: the answer is never read",
    "select_hostagefundinglevel": "obsolete: the answer is never read",
    "recruitName": "presentation-replaced: a label on the activation screen",
    "split_string": "obsolete: C++ has no split; GDScript does",
    "locatesquad": "presentation-replaced: moving the squad is Destination's",
    "squadhasitem": "presentation-replaced: the stores panel reads the haul",
    "getactivity": "presentation-replaced: ActivityText",
    "getalign": "presentation-replaced: Alignment and the palette",
    "getlaw": "presentation-replaced: LawList",
    "getlawflag": "presentation-replaced: JusticeText",
    "getmonth": "presentation-replaced: the status bar's date",
    "romannumeral": "presentation-replaced: the amendment number",
    # --- Lookups the port does with a Dictionary ------------------------
    "find_site_by_id": "presentation-replaced: state.locations is keyed by id",
    "find_site_in_city": "presentation-replaced: a filter over state.locations",
    "findlocation": "presentation-replaced: a filter over state.locations",
    "findlocation_id": "presentation-replaced: a filter over state.locations",
    "id_getcar": "presentation-replaced: state.vehicles is keyed by id",
    # --- Save, score and configuration ----------------------------------
    "savegame": "presentation-replaced: Serializer and SaveGame, which write "
                "the port's own format rather than the original's",
    "create_item": "presentation-replaced: ItemCodec",
    "loadhighscores": "presentation-replaced: ScoreFile",
    "viewhighscores": "presentation-replaced: the endings screen",
    "loadinitfile": "presentation-replaced: Godot's own settings",
    "setconfigoption": "presentation-replaced: Godot's own settings",
    "populate_from_xml": "presentation-replaced: Catalog loads Resources",
    "populate_masks_from_xml": "presentation-replaced: Catalog loads Resources",
    "assign_interval": "presentation-replaced: an exported Vector2i",
    "attribute_string_to_enum": "presentation-replaced: idnames, not enums",
    "attribute_enum_to_string": "presentation-replaced: idnames, not enums",
    "augment_string_to_enum": "presentation-replaced: idnames, not enums",
    "gender_string_to_enum": "presentation-replaced: idnames, not enums",
    "skill_string_to_enum": "presentation-replaced: idnames, not enums",
    "tostring": "presentation-replaced: GDScript's own str()",
    # --- The C runtime and the platform ---------------------------------
    "alarmHandler": "obsolete: a SIGALRM handler for the DOS-era timer",
    "alarmset": "obsolete: as above",
    "initalarm": "obsolete: as above",
    "setTimeval": "obsolete: as above",
    "msToItimerval": "obsolete: as above",
    "pause_ms": "obsolete: the port never blocks the frame",
    "fnvHash": "obsolete: a string hash; GDScript hashes its own",
    "stricmp": "obsolete: a case-insensitive compare MSVC did not ship",
}


def sources() -> list[Path]:
    found = []
    for path in sorted(SRC.rglob("*.cpp")):
        parts = set(path.relative_to(SRC).parts)
        if parts & VENDORED or path.name in VENDORED_FILES:
            continue
        found.append(path)
    return found


def functions() -> dict[str, str]:
    """Every function name in the original, and the file it lives in."""
    found: dict[str, str] = {}
    for path in sources():
        text = path.read_bytes().decode("cp437")
        for match in METHOD.finditer(text):
            found.setdefault(match.group(2), str(path.relative_to(ROOT)))
        for match in DEFINITION.finditer(text):
            name = match.group(1)
            if name in IGNORED_NAMES:
                continue
            found.setdefault(name, str(path.relative_to(ROOT)))
    return found


def port_text() -> str:
    """Everything the port and its documentation say, as one string."""
    parts = []
    for path in list(GAME.rglob("*.gd")) + list((ROOT / "docs").rglob("*.md")) \
            + list((ROOT / "tools").rglob("*.py")) \
            + list((ROOT / "tools").rglob("*.cpp")):
        if path.name == "audit_parity.py":
            continue
        parts.append(path.read_text(errors="replace"))
    return "\n".join(parts)


def named_in_the_port(text: str) -> set[str]:
    """Every legacy function name the port mentions, in a comment or a test."""
    return {name for name in functions() if "%s(" % name in text}


def main() -> int:
    every = functions()
    mentioned = named_in_the_port(port_text())
    ported, classified, unaccounted = [], [], []
    for name in sorted(every):
        if name in mentioned:
            ported.append(name)
        elif name in CLASSIFIED:
            classified.append(name)
        else:
            unaccounted.append(name)

    if "--list" in sys.argv:
        for name in sorted(every):
            verdict = "ported" if name in mentioned \
                else CLASSIFIED.get(name, "UNACCOUNTED")
            print("%-40s %-28s %s" % (name, every[name], verdict))

    print("%d functions in the original's own sources." % len(every))
    print("  %d are named by the port." % len(ported))
    print("  %d are classified in this tool." % len(classified))
    print("  %d are unaccounted for." % len(unaccounted))
    if unaccounted:
        for name in unaccounted:
            print("    %-36s %s" % (name, every[name]))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
