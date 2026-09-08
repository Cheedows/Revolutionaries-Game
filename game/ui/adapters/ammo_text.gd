class_name AmmoText
extends RefCounted
## Loaded rounds and compatible spare magazines, including an empty weapon.
static func of(person: Creature, catalog: Catalog = null, compact: bool = false) -> String:
	if person.weapon == null: return "Unarmed"
	var weapon := person.weapon
	var type: WeaponType
	if catalog != null: type = catalog.get_entry(&"weapon", weapon.type)
	else:
		var path := "res://data/weapons/%s.tres" % String(weapon.type).trim_prefix("WEAPON_").to_lower()
		if ResourceLoader.exists(path): type = load(path) as WeaponType
	var title := type.shortname if type != null and not type.shortname.is_empty() else String(weapon.type).trim_prefix("WEAPON_").replace("_", " ")
	var compatible: Array[StringName] = []
	if type != null:
		for attack: WeaponAttack in type.attacks:
			if attack.uses_ammo and not compatible.has(attack.ammotype): compatible.append(attack.ammotype)
	if compatible.is_empty(): return title
	var spare := 0
	for clip: Clip in person.clips:
		if compatible.has(clip.type): spare += clip.count
	var text := "%s: %d loaded, %d spare clips" % [title, weapon.ammo, spare]
	if compact:
		if weapon.ammo == 0: return ("Reload (%d clips)" % spare) if spare > 0 else "Out of ammo (0 clips)"
		return "%d loaded / %d clips" % [weapon.ammo, spare]
	if weapon.ammo == 0: text += " - Reload" if spare > 0 else " - Out of ammo"
	return text
