class_name Disguise
extends RefCounted
## Whether the squad passes for people who belong here.
##
## Ports hasdisguise() from src/sitemode/stealth.cpp. The rules themselves —
## which outfit works where — are generated into core/disguise_rules.gd; this
## is what applies them.
##
## The answer is three-valued: nobody is fooled, somebody is dressed for the
## job, or somebody is dressed for a job that is not quite this one. The last
## is what a police uniform gets you in a building the police have no business
## being in, and it halves the roll rather than passing it.

## Not in disguise at all.
const EXPOSED := 0
## Dressed for the job.
const CONVINCING := 1
## Dressed for a job, but the wrong one.
const PARTIAL := 2


## How convincing [param creature] looks where the squad is standing.
static func rating(state: GameState, creature: Creature, catalog: Catalog) -> int:
	var site: Location = state.locations.get(state.site.location)
	if site == null:
		return EXPOSED

	var siege: Siege = state.sieges.get(site.id)
	var uniformed: int
	if siege != null and siege.active:
		uniformed = _apply(state, creature, site,
				DisguiseRules.BY_SIEGE.get(siege.attacker, []), siege)
	else:
		uniformed = _walking_in(state, creature, site)

	if uniformed == EXPOSED:
		uniformed = _last_resorts(state, creature, site)
	return _worn_through(uniformed, creature, catalog)


## The rating for a squad that walked in off the street.
##
## Anyone wearing anything at all starts out unremarkable — clothes are a
## disguise in a building full of people in clothes — and then the site's own
## rules decide whether that is good enough here.
static func _walking_in(state: GameState, creature: Creature,
		site: Location) -> int:
	var uniformed := EXPOSED
	var dressed := creature.armor != null or creature.animal_gloss == &"animal"
	if dressed and (creature.armor == null
			or creature.armor.type != &"ARMOR_HEAVYARMOR"):
		uniformed = CONVINCING
	return _apply(state, creature, site,
			DisguiseRules.BY_SITE.get(site.type, []), null, uniformed)


## Runs a rule list in order; the last rule that matches decides.
static func _apply(state: GameState, creature: Creature, site: Location,
		rules: Array, siege: Siege, start: int = EXPOSED) -> int:
	var uniformed := start
	for rule: Dictionary in rules:
		if not _matches(state, creature, site, siege, rule):
			continue
		var value: Variant = rule[&"value"]
		if value is StringName:
			uniformed = CONVINCING if site.high_security > 0 else PARTIAL
		else:
			uniformed = int(value)
	return uniformed


static func _matches(state: GameState, creature: Creature, site: Location,
		siege: Siege, rule: Dictionary) -> bool:
	if rule.get(&"restricted", false):
		var restricted: int = Tables.SITE_BLOCKS[&"restricted"]
		if not (state.site.map.get_flag(state.site.x, state.site.y, state.site.z)
				& restricted):
			return false
	if rule.get(&"high_security", false) and site.high_security == 0:
		return false
	if rule.get(&"naked", false) and creature.armor != null:
		return false
	if rule.has(&"armor"):
		if creature.armor == null or creature.armor.type != rule[&"armor"]:
			return false
	if rule.has(&"laws") and not _laws_hold(state, rule[&"laws"]):
		return false
	# The original reaches these through an else branch, so what is required is
	# that the laws do not *all* hold.
	if rule.has(&"not_laws") and _laws_hold(state, rule[&"not_laws"]):
		return false
	if rule.has(&"escalation"):
		if siege == null:
			return false
		var test: Array = rule[&"escalation"]
		var level: int = siege.escalation
		if String(test[0]) == "==" and level != int(test[1]):
			return false
		if String(test[0]) == ">" and level <= int(test[1]):
			return false
	return true


static func _laws_hold(state: GameState, laws: Array) -> bool:
	for pair: Array in laws:
		if state.law.get_value(pair[0]) != int(pair[1]):
			return false
	return true


## What a uniform still gets you when the site itself is not fooled.
##
## A police uniform is never quite right anywhere the police do not work, but
## it is enough to make people hesitate. Bunker gear in a burning building is
## the one that actually passes.
static func _last_resorts(state: GameState, creature: Creature,
		site: Location) -> int:
	if creature.armor == null:
		return EXPOSED
	var worn := creature.armor.type
	var uniformed := EXPOSED

	if worn == &"ARMOR_POLICEUNIFORM" or worn == &"ARMOR_POLICEARMOR":
		uniformed = PARTIAL
	if worn == &"ARMOR_DEATHSQUADUNIFORM" \
			and state.law.get_value(&"policebehavior") == -2 \
			and state.law.get_value(&"deathpenalty") == -2:
		uniformed = PARTIAL
	if site.high_security > 0 and worn == &"ARMOR_SWATARMOR":
		uniformed = PARTIAL

	var fire: int = Tables.SITE_BLOCKS[&"fire_start"] \
			| Tables.SITE_BLOCKS[&"fire_end"] | Tables.SITE_BLOCKS[&"fire_peak"]
	if worn == &"ARMOR_BUNKERGEAR" \
			and state.site.map.get_flag(state.site.x, state.site.y, state.site.z) & fire:
		uniformed = CONVINCING
	return uniformed


## A disguise is only as good as the state of the clothes.
##
## Worn clothing makes a worse disguise, and shredded clothing gives the game
## away entirely — which also means a partial disguise in poor condition is no
## disguise at all.
static func _worn_through(uniformed: int, creature: Creature,
		catalog: Catalog) -> int:
	if uniformed == EXPOSED or creature.armor == null:
		return uniformed
	var tiers := EquipmentRules.quality_levels(creature.armor, catalog)
	var wear := creature.armor.quality + (1 if creature.armor.damaged else 0)
	if wear > tiers:
		return EXPOSED
	if (wear - 1) * 2 > tiers:
		uniformed += 1
	return EXPOSED if uniformed > PARTIAL else uniformed
