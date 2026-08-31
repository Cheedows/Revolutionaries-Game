class_name HospitalVisit
extends RefCounted
## Taking somebody to a hospital.
##
## Ports hospital() from src/daily/shopsnstuff.cpp, minus the ward it draws.
## A clinic and a teaching hospital differ only in how quickly they work, which
## is [Treatment]'s business; what happens here is choosing who to admit.


## Asks who is being left in. Returns a [PendingIntent], or the events of a
## visit nobody needed.
static func open(state: GameState, squad: Squad, site: Location) -> Variant:
	var options: Array[Dictionary] = []
	for member: Creature in state.squad_members(squad):
		if member.clinic > 0 or Treatment.clinic_time(member) <= 0:
			continue
		options.append({"id": member.id, "label": member.name,
				"note": "%d days" % Treatment.clinic_time(member),
				"enabled": true})
	if options.is_empty():
		return [] as Array[Event]

	options.append({"id": 0, "label": "Nobody", "enabled": true})
	return PendingIntent.new(
			Intent.new(Intent.CHOOSE_BASE_ACTION, options,
					{"location": site.id}, false),
			func(answer: Variant) -> Variant:
				return _admit(state, squad, site, int(answer)),
			[] as Array[Event])


## Leaves one of them in, and asks again in case there are more.
static func _admit(state: GameState, squad: Squad, site: Location,
		id: int) -> Variant:
	if id == 0:
		return [] as Array[Event]
	var patient: Creature = state.creatures.get(id)
	if patient == null:
		return [] as Array[Event]
	var events := Treatment.hospitalize(state, patient, site)
	var again: Variant = open(state, squad, site)
	if again is PendingIntent:
		var asked: PendingIntent = again
		return PendingIntent.new(asked.intent, asked.resume,
				events + asked.events)
	return events + (again as Array[Event])
