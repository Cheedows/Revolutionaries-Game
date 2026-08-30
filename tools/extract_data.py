#!/usr/bin/env python3
"""Converts the original art/*.xml content into Godot resources.

Content is data (ARCHITECTURE.md §5): every weapon, creature, vehicle and so on
becomes a .tres under game/data/, generated — never hand-edited.

Two fidelity rules make this safe to trust:

1. The set of XML elements this script understands is checked against the
   element names the C++ readers actually compare on. If upstream recognises a
   field we drop, the run fails.
2. Elements present in the XML that the C++ *ignores* (there are a few, from
   typos upstream) are ignored here too, and reported. Reproducing the original
   behaviour matters more than fixing the data during a parity port.
"""
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from tres import Res, StringName, write  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art"
OUT = ROOT / "game" / "data"

AGE_MACROS = {
    "DOGYEARS": (2, 6), "CHILD": (7, 10), "TEENAGER": (14, 17),
    "YOUNGADULT": (18, 35), "MATURE": (20, 59), "GRADUATE": (26, 59),
    "MIDDLEAGED": (35, 59), "SENIOR": (65, 94),
}
TRUE_WORDS = {"true", "1", "on", "yes"}
FALSE_WORDS = {"false", "0", "off", "no"}


def to_bool(text, default):
    lowered = (text or "").strip().lower()
    if lowered in TRUE_WORDS:
        return True
    if lowered in FALSE_WORDS:
        return False
    return default  # matches stringtobool() returning -1: the field is left alone


def to_int(text, default=0):
    try:
        return int((text or "").strip())
    except ValueError:
        return default


def interval(text, default=(0, 0)):
    """Parses "6" or "6-10" the way Interval::set_interval does."""
    raw = (text or "").strip()
    match = re.fullmatch(r"(-?\d+)\s*-\s*(-?\d+)", raw)
    if match:
        return Res("interval.gd", {"min": int(match.group(1)), "max": int(match.group(2))})
    if re.fullmatch(r"-?\d+", raw):
        return Res("interval.gd", {"min": int(raw), "max": int(raw)})
    return Res("interval.gd", {"min": default[0], "max": default[1]})


def child_text(element, tag, default=""):
    found = element.find(tag)
    return default if found is None or found.text is None else found.text.strip()


def slug(idname: str) -> str:
    return idname.lower().removeprefix("creature_").removeprefix("weapon_") \
        .removeprefix("armor_").removeprefix("clip_").removeprefix("loot_") \
        .removeprefix("vehicle_").removeprefix("augment_") or idname.lower()


class Report:
    """Collects what was written and what was deliberately ignored."""

    def __init__(self):
        self.written = 0
        self.ignored: dict = {}

    def ignore(self, source: str, idname: str, tag: str):
        self.ignored.setdefault(f"{source}:{tag}", []).append(idname)

    def summarise(self):
        if self.ignored:
            print("\nElements present in the XML but ignored by the original parser:")
            for key, owners in sorted(self.ignored.items()):
                print(f"  {key}  ({len(owners)}x, e.g. {owners[0]})")
        print(f"\n{self.written} resource(s) written to {OUT.relative_to(ROOT)}")


def verify_against_cpp(source_file: str, handled: set, extra_ok: set = frozenset()):
    """Fails if the C++ reader recognises an element this script does not."""
    text = (ROOT / source_file).read_text(errors="replace")
    recognised = set(re.findall(r'element(?:_name)?\s*==\s*"([a-z_0-9]+)"', text))
    missing = recognised - handled - extra_ok
    if missing:
        raise SystemExit(
            f"{source_file} recognises elements this extractor drops: {sorted(missing)}"
        )


def extract_weapons(report: Report):
    handled = {
        "name", "name_future", "fencevalue", "shortname", "shortname_future",
        "name_sub_1", "name_sub_2", "name_future_sub_1", "name_future_sub_2",
        "shortname_sub_1", "shortname_sub_2", "shortname_future_sub_1",
        "shortname_future_sub_2", "can_take_hostages", "can_threaten_hostages",
        "protects_against_kidnapping", "threatening", "musical_attack",
        "instrument", "graffiti", "suspicious", "auto_break_locks", "legality",
        "bashstrengthmod", "size", "attack",
    }
    attack_fields = {
        "priority", "ranged", "thrown", "can_backstab", "skill", "ammotype",
        "shoots", "number_attacks", "strength_min", "strength_max",
        "accuracy_bonus", "successive_attacks_difficulty", "fixed_damage",
        "random_damage", "armorpiercing", "no_damage_reduction_for_limbs_chance",
        "bruises", "cuts", "tears", "burns", "bleeding", "fire", "damages_armor",
        "critical", "always_describe_hit", "severtype", "attack_description",
        "hit_description", "hit_punctuation",
    }
    # "chance", "chance_causes_debris" and "hits_required" belong to the site-map
    # destruction block the same reader handles; they are not weapon fields.
    verify_against_cpp("src/items/weapontype.cpp", handled | attack_fields,
                       extra_ok={"chance", "chance_causes_debris", "hits_required"})
    verify_against_cpp("src/items/itemtype.cpp", handled)

    root = ET.parse(ART / "weapons.xml").getroot()
    for entry in root.findall("weapontype"):
        idname = entry.get("idname", "")
        attacks = []
        props = {
            "idname": StringName(idname),
            "name": child_text(entry, "name", "UNDEFINED"),
            "name_future": child_text(entry, "name_future"),
            "fencevalue": to_int(child_text(entry, "fencevalue")),
            "shortname": child_text(entry, "shortname"),
            "shortname_future": child_text(entry, "shortname_future"),
            "name_sub_1": child_text(entry, "name_sub_1"),
            "name_sub_2": child_text(entry, "name_sub_2"),
            "name_future_sub_1": child_text(entry, "name_future_sub_1"),
            "name_future_sub_2": child_text(entry, "name_future_sub_2"),
            "shortname_sub_1": child_text(entry, "shortname_sub_1"),
            "shortname_sub_2": child_text(entry, "shortname_sub_2"),
            "shortname_future_sub_1": child_text(entry, "shortname_future_sub_1"),
            "shortname_future_sub_2": child_text(entry, "shortname_future_sub_2"),
            "can_take_hostages": to_bool(child_text(entry, "can_take_hostages"), False),
            "can_threaten_hostages": to_bool(child_text(entry, "can_threaten_hostages"), True),
            "protects_against_kidnapping": to_bool(child_text(entry, "protects_against_kidnapping"), True),
            "threatening": to_bool(child_text(entry, "threatening"), False),
            "musical_attack": to_bool(child_text(entry, "musical_attack"), False),
            "instrument": to_bool(child_text(entry, "instrument"), False),
            "graffiti": to_bool(child_text(entry, "graffiti"), False),
            "suspicious": to_bool(child_text(entry, "suspicious"), True),
            "auto_break_locks": to_bool(child_text(entry, "auto_break_locks"), False),
            "legality": to_int(child_text(entry, "legality"), 2),
            "bashstrengthmod": to_int(child_text(entry, "bashstrengthmod"), 100),
            "size": to_int(child_text(entry, "size"), 15),
        }
        for tag in {child.tag for child in entry} - handled:
            report.ignore("weapons.xml", idname, tag)

        for attack in entry.findall("attack"):
            for tag in {child.tag for child in attack} - attack_fields:
                report.ignore("weapons.xml/attack", idname, tag)
            attacks.append(Res("weapon_attack.gd", {
                "priority": to_int(child_text(attack, "priority"), 1),
                "ranged": to_bool(child_text(attack, "ranged"), False),
                "thrown": to_bool(child_text(attack, "thrown"), False),
                "can_backstab": to_bool(child_text(attack, "can_backstab"), False),
                "skill": StringName(child_text(attack, "skill")),
                "ammotype": StringName(child_text(attack, "ammotype")),
                "shoots": to_int(child_text(attack, "shoots")),
                "number_attacks": to_int(child_text(attack, "number_attacks"), 1),
                "strength_min": to_int(child_text(attack, "strength_min")),
                "strength_max": to_int(child_text(attack, "strength_max")),
                "accuracy_bonus": to_int(child_text(attack, "accuracy_bonus")),
                "successive_attacks_difficulty": to_int(child_text(attack, "successive_attacks_difficulty")),
                "fixed_damage": to_int(child_text(attack, "fixed_damage"), 1),
                "random_damage": to_int(child_text(attack, "random_damage"), 1),
                "armorpiercing": to_int(child_text(attack, "armorpiercing")),
                "no_damage_reduction_for_limbs_chance": to_int(
                    child_text(attack, "no_damage_reduction_for_limbs_chance")),
                "bruises": to_bool(child_text(attack, "bruises"), False),
                "cuts": to_bool(child_text(attack, "cuts"), False),
                "tears": to_bool(child_text(attack, "tears"), False),
                "burns": to_bool(child_text(attack, "burns"), False),
                "bleeding": to_bool(child_text(attack, "bleeding"), False),
                "fire": to_bool(child_text(attack, "fire"), False),
                "damages_armor": to_bool(child_text(attack, "damages_armor"), False),
                "critical": to_bool(child_text(attack, "critical"), False),
                "always_describe_hit": to_bool(child_text(attack, "always_describe_hit"), False),
                "severtype": to_int(child_text(attack, "severtype")),
                "attack_description": child_text(attack, "attack_description"),
                "hit_description": child_text(attack, "hit_description"),
                "hit_punctuation": child_text(attack, "hit_punctuation", "."),
            }))
        props["attacks"] = attacks
        write(OUT / "weapons" / f"{slug(idname)}.tres", Res("weapon_type.gd", props))
        report.written += 1


ARMOR_HANDLED = {
    "name", "name_future", "fencevalue", "shortname", "description",
    "armor", "body", "head", "limbs", "fireprotection", "body_covering",
    "arms", "legs", "conceals_face", "conceal_weapon_size", "professionalism",
    "stealth_value", "deathsquad_legality", "can_get_bloody", "can_get_damaged",
    "qualitylevels", "durability", "make_difficulty", "make_price",
    "interrogation", "basepower", "assaultbonus", "drugbonus", "mask", "surprise",
}


def _armor_props(entry, idname, is_mask):
    covering = entry.find("body_covering")
    armor = entry.find("armor")
    interrogation = entry.find("interrogation")

    def covering_flag(tag, default):
        return default if covering is None else to_bool(child_text(covering, tag), default)

    def armor_value(tag):
        return 0 if armor is None else to_int(child_text(armor, tag))

    def interrogation_value(tag):
        return 0 if interrogation is None else to_int(child_text(interrogation, tag))

    return {
        "idname": StringName(idname),
        "name": child_text(entry, "name", "UNDEFINED"),
        "name_future": child_text(entry, "name_future"),
        "fencevalue": to_int(child_text(entry, "fencevalue")),
        "shortname": child_text(entry, "shortname"),
        "description": child_text(entry, "description"),
        "armor_body": armor_value("body"),
        "armor_head": armor_value("head"),
        "armor_limbs": armor_value("limbs"),
        "armor_fireprotection": armor_value("fireprotection"),
        "covers_body": covering_flag("body", False),
        "covers_head": covering_flag("head", False),
        "covers_arms": covering_flag("arms", False),
        "covers_legs": covering_flag("legs", False),
        "conceals_face": covering_flag("conceals_face", False),
        "conceal_weapon_size": to_int(child_text(entry, "conceal_weapon_size")),
        "professionalism": to_int(child_text(entry, "professionalism")),
        "stealth_value": to_int(child_text(entry, "stealth_value")),
        "deathsquad_legality": to_bool(child_text(entry, "deathsquad_legality"), False),
        "can_get_bloody": to_bool(child_text(entry, "can_get_bloody"), True),
        "can_get_damaged": to_bool(child_text(entry, "can_get_damaged"), True),
        "qualitylevels": to_int(child_text(entry, "qualitylevels"), 1),
        "durability": to_int(child_text(entry, "durability"), 1),
        "make_difficulty": to_int(child_text(entry, "make_difficulty")),
        "make_price": to_int(child_text(entry, "make_price")),
        "interrogation_basepower": interrogation_value("basepower"),
        "interrogation_assaultbonus": interrogation_value("assaultbonus"),
        "interrogation_drugbonus": interrogation_value("drugbonus"),
        "is_mask": is_mask,
        "surprise": to_int(child_text(entry, "surprise")),
    }


def extract_armors(report: Report):
    verify_against_cpp("src/items/armortype.cpp", ARMOR_HANDLED)
    for source, entry_tag, is_mask, out_dir in (
        ("armors.xml", "armortype", False, "armor"),
        ("masks.xml", "masktype", True, "masks"),
    ):
        root = ET.parse(ART / source).getroot()
        for entry in root.findall(entry_tag):
            idname = entry.get("idname", "")
            for tag in {child.tag for child in entry} - ARMOR_HANDLED:
                report.ignore(source, idname, tag)
            write(OUT / out_dir / f"{slug(idname)}.tres",
                  Res("armor_type.gd", _armor_props(entry, idname, is_mask)))
            report.written += 1


def extract_clips(report: Report):
    handled = {"name", "name_future", "fencevalue", "ammo"}
    verify_against_cpp("src/items/cliptype.cpp", handled)
    root = ET.parse(ART / "clips.xml").getroot()
    for entry in root.findall("cliptype"):
        idname = entry.get("idname", "")
        for tag in {child.tag for child in entry} - handled:
            report.ignore("clips.xml", idname, tag)
        write(OUT / "clips" / f"{slug(idname)}.tres", Res("clip_type.gd", {
            "idname": StringName(idname),
            "name": child_text(entry, "name", "UNDEFINED"),
            "name_future": child_text(entry, "name_future"),
            "fencevalue": to_int(child_text(entry, "fencevalue")),
            "ammo": to_int(child_text(entry, "ammo"), 1),
        }))
        report.written += 1


def extract_loot(report: Report):
    handled = {"name", "name_future", "fencevalue", "cloth", "stackable", "no_quick_fencing"}
    verify_against_cpp("src/items/loottype.cpp", handled)
    root = ET.parse(ART / "loot.xml").getroot()
    for entry in root.findall("loottype"):
        idname = entry.get("idname", "")
        for tag in {child.tag for child in entry} - handled:
            report.ignore("loot.xml", idname, tag)
        write(OUT / "loot" / f"{slug(idname)}.tres", Res("loot_type.gd", {
            "idname": StringName(idname),
            "name": child_text(entry, "name", "UNDEFINED"),
            "name_future": child_text(entry, "name_future"),
            "fencevalue": to_int(child_text(entry, "fencevalue")),
            "cloth": to_bool(child_text(entry, "cloth"), False),
            "stackable": to_bool(child_text(entry, "stackable"), False),
            "no_quick_fencing": to_bool(child_text(entry, "no_quick_fencing"), False),
        }))
        report.written += 1


def extract_augmentations(report: Report):
    handled = {"name", "description", "type", "attribute", "effect", "cost",
               "difficulty", "min_age", "max_age"}
    verify_against_cpp("src/creature/augmenttype.cpp", handled)
    root = ET.parse(ART / "augmentations.xml").getroot()
    for entry in root.findall("augmenttype"):
        idname = entry.get("idname", "")
        for tag in {child.tag for child in entry} - handled:
            report.ignore("augmentations.xml", idname, tag)
        write(OUT / "augments" / f"{slug(idname)}.tres", Res("augment_type.gd", {
            "idname": StringName(idname),
            "name": child_text(entry, "name", "UNDEFINED"),
            "description": child_text(entry, "description"),
            "type": StringName(child_text(entry, "type")),
            "attribute": StringName(child_text(entry, "attribute")),
            "effect": to_int(child_text(entry, "effect")),
            "cost": to_int(child_text(entry, "cost")),
            "difficulty": to_int(child_text(entry, "difficulty")),
            "min_age": to_int(child_text(entry, "min_age"), 0),
            "max_age": to_int(child_text(entry, "max_age"), 999),
        }))
        report.written += 1


def extract_vehicles(report: Report):
    handled = {
        "longname", "shortname", "price", "sleeperprice", "available_at_dealership",
        "size", "year", "colors", "drivebonus", "dodgebonus", "attackbonus",
        "armor", "stealing",
    }
    nested = {
        "start_at_year", "start_at_current_year", "add", "add_random",
        "add_random_up_to_current_year", "color", "display_color", "base",
        "skillfactor", "softlimit", "hardlimit", "driver", "passenger",
        "low_armor_min", "low_armor_max", "high_armor_min", "high_armor_max",
        "armor_midpoint", "difficulty_to_find", "touch_alarm_chance",
        "sense_alarm_chance", "juice", "extra_heat",
    }
    verify_against_cpp("src/vehicle/vehicletype.cpp", handled | nested)

    root = ET.parse(ART / "vehicles.xml").getroot()
    for entry in root.findall("vehicletype"):
        idname = entry.get("idname", "")
        for tag in {child.tag for child in entry} - handled:
            report.ignore("vehicles.xml", idname, tag)

        def block(name, tag, default=0):
            node = entry.find(name)
            return default if node is None else to_int(child_text(node, tag), default)

        def block_bool(name, tag, default=False):
            node = entry.find(name)
            return default if node is None else to_bool(child_text(node, tag), default)

        colors_node = entry.find("colors")
        colors = [] if colors_node is None else [
            StringName(node.text.strip()) for node in colors_node.findall("color")
            if node.text
        ]
        display_colors = [] if colors_node is None else [
            StringName(node.text.strip()) for node in colors_node.findall("display_color")
            if node.text
        ]

        write(OUT / "vehicles" / f"{slug(idname)}.tres", Res("vehicle_type.gd", {
            "idname": StringName(idname),
            "longname": child_text(entry, "longname", "UNDEFINED"),
            "shortname": child_text(entry, "shortname"),
            "price": to_int(child_text(entry, "price")),
            "sleeperprice": to_int(child_text(entry, "sleeperprice")),
            "available_at_dealership": to_bool(child_text(entry, "available_at_dealership"), False),
            "size": to_int(child_text(entry, "size")),
            "year_start_at_year": block("year", "start_at_year"),
            "year_start_at_current_year": block_bool("year", "start_at_current_year"),
            "year_add": block("year", "add"),
            "year_add_random": block("year", "add_random"),
            "year_add_random_up_to_current_year": block_bool("year", "add_random_up_to_current_year"),
            "colors": colors,
            "display_colors": display_colors,
            "drivebonus_base": block("drivebonus", "base"),
            "drivebonus_skillfactor": block("drivebonus", "skillfactor"),
            "drivebonus_softlimit": block("drivebonus", "softlimit"),
            "drivebonus_hardlimit": block("drivebonus", "hardlimit"),
            "dodgebonus_base": block("dodgebonus", "base"),
            "dodgebonus_skillfactor": block("dodgebonus", "skillfactor"),
            "dodgebonus_softlimit": block("dodgebonus", "softlimit"),
            "dodgebonus_hardlimit": block("dodgebonus", "hardlimit"),
            "attackbonus_driver": block("attackbonus", "driver"),
            "attackbonus_passenger": block("attackbonus", "passenger"),
            "armor_low_min": block("armor", "low_armor_min"),
            "armor_low_max": block("armor", "low_armor_max"),
            "armor_high_min": block("armor", "high_armor_min"),
            "armor_high_max": block("armor", "high_armor_max"),
            "armor_midpoint": block("armor", "armor_midpoint"),
            "steal_difficulty_to_find": block("stealing", "difficulty_to_find"),
            "steal_touch_alarm_chance": block("stealing", "touch_alarm_chance"),
            "steal_sense_alarm_chance": block("stealing", "sense_alarm_chance"),
            "steal_juice": block("stealing", "juice"),
            "steal_extra_heat": block("stealing", "extra_heat"),
        }))
        report.written += 1


ALIGNMENTS = {"LIBERAL": "liberal", "MODERATE": "moderate", "CONSERVATIVE": "conservative"}
GENDERS = {
    "MALE": "male", "FEMALE": "female", "NEUTRAL": "neutral",
    "MALE BIAS": "male_bias", "FEMALE BIAS": "female_bias",
}


def extract_creatures(report: Report):
    handled = {
        "type_name", "encounter_name", "alignment", "gender", "age", "juice",
        "money", "infiltration", "attribute_points", "attributes", "skills",
        "armor", "weapon",
    }
    verify_against_cpp("src/creature/creaturetype.cpp", handled,
                       extra_ok={"type", "cliptype", "number_clips", "number_weapons"})

    root = ET.parse(ART / "creatures.xml").getroot()
    for entry in root.findall("creaturetype"):
        idname = entry.get("idname", "")
        for tag in {child.tag for child in entry} - handled:
            report.ignore("creatures.xml", idname, tag)

        age_raw = child_text(entry, "age")
        if age_raw in AGE_MACROS:
            low, high = AGE_MACROS[age_raw]
            age = Res("interval.gd", {"min": low, "max": high})
        else:
            age = interval(age_raw)

        attributes = {}
        node = entry.find("attributes")
        if node is not None:
            for child in node:
                attributes[StringName(child.tag)] = interval(
                    "" if child.text is None else child.text)

        skills = {}
        node = entry.find("skills")
        if node is not None:
            for child in node:
                skills[StringName(child.tag)] = interval(
                    "" if child.text is None else child.text)

        weapons = []
        for weapon in entry.findall("weapon"):
            if len(weapon) == 0:
                weapons.append(Res("creature_weapons.gd", {
                    "type": StringName((weapon.text or "WEAPON_NONE").strip()),
                    "number_weapons": interval("1", (1, 1)),
                    "cliptype": StringName("APPROPRIATE"),
                    "number_clips": interval("4", (4, 4)),
                }))
            else:
                weapons.append(Res("creature_weapons.gd", {
                    "type": StringName(child_text(weapon, "type", "WEAPON_NONE")),
                    "number_weapons": interval(child_text(weapon, "number_weapons"), (1, 1)),
                    "cliptype": StringName(child_text(weapon, "cliptype", "APPROPRIATE")),
                    "number_clips": interval(child_text(weapon, "number_clips"), (4, 4)),
                }))
        if not weapons:
            weapons.append(Res("creature_weapons.gd", {
                "type": StringName("WEAPON_NONE"),
                "number_weapons": interval("1", (1, 1)),
                "cliptype": StringName("NONE"),
                "number_clips": interval("0", (0, 0)),
            }))

        armortypes = [StringName(node.text.strip()) for node in entry.findall("armor")
                      if node.text and node.text.strip()]
        if not armortypes:
            armortypes = [StringName("ARMOR_NONE")]

        alignment_raw = child_text(entry, "alignment")
        write(OUT / "creatures" / f"{slug(idname)}.tres", Res("creature_type.gd", {
            "idname": StringName(idname),
            "type_name": child_text(entry, "type_name", "UNDEFINED"),
            "encounter_name": child_text(entry, "encounter_name"),
            "alignment": StringName(ALIGNMENTS.get(alignment_raw, "public_mood"
                                                   if alignment_raw else "conservative")),
            "gender": StringName(GENDERS.get(child_text(entry, "gender"), "neutral")),
            "age": age,
            "juice": interval(child_text(entry, "juice")),
            "money": interval(child_text(entry, "money")),
            "infiltration": interval(child_text(entry, "infiltration")),
            "attribute_points": interval(child_text(entry, "attribute_points")),
            "attributes": attributes,
            "skills": skills,
            "armortypes": armortypes,
            "weapons": weapons,
        }))
        report.written += 1


def main() -> int:
    report = Report()
    extract_weapons(report)
    extract_armors(report)
    extract_clips(report)
    extract_loot(report)
    extract_augmentations(report)
    extract_vehicles(report)
    extract_creatures(report)
    report.summarise()
    return 0


if __name__ == "__main__":
    sys.exit(main())
