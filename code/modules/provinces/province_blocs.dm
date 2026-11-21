// Province blocs (docs/character-slots.md, "Structuring"). A side's province
// cap (province_holding.dm) counts its whole bloc, so one group split into
// several factions cannot hold a whole land:
// - a nation, or a faction outside one, is a group (province_group_of);
// - groups whose factions are led by the same player share a bloc (kin-led);
// - staff can mark groups as one bloc, or freeze a group's claims, from
//   Admin > Province Blocs (province_blocs_admin.dm). Every staff action is
//   logged with its reason.
//
// State in map.faction_recruitment (durable):
//   "province_blocs"  - group -> bloc name (staff marks)
//   "province_frozen" - group -> list(reason, staff ckey, realtime)

/obj/map_metadata/proc/province_bloc_marks()
	var/list/S = recruitment_state()
	if (!islist(S["province_blocs"]))
		S["province_blocs"] = list()
	return S["province_blocs"]

/obj/map_metadata/proc/province_frozen_groups()
	var/list/S = recruitment_state()
	if (!islist(S["province_frozen"]))
		S["province_frozen"] = list()
	return S["province_frozen"]

/proc/province_claims_frozen(group)
	if (!map || !istext(group))
		return FALSE
	var/list/F = map.province_frozen_groups()
	return islist(F[group])

// The player leading each group's factions: group -> list(person).
/proc/province_group_leaders()
	. = list()
	if (!map)
		return
	for (var/faction in map.custom_civs)
		var/list/civ_data = map.faction_leader_record(faction)
		var/mob/living/human/L = civ_data ? civ_data[4] : null
		var/person = istype(L) && !QDELETED(L) ? faction_leader_person(L) : null
		if (!person)
			continue
		var/group = province_group_of(faction)
		var/list/people = .[group]
		if (!islist(people))
			people = list()
			.[group] = people
		people |= person

// Every group sharing a cap with group, group included.
/proc/province_bloc_groups(group)
	. = list(group)
	if (!map || !istext(group))
		return
	var/list/marks = map.province_bloc_marks()
	var/bloc = marks[group]
	if (istext(bloc))
		for (var/other in marks)
			if (marks[other] == bloc)
				. |= other
	var/list/leaders = province_group_leaders()
	var/list/mine = leaders[group]
	if (islist(mine))
		for (var/other in leaders)
			var/list/theirs = leaders[other]
			if (other != group && length(mine & theirs))
				. |= other

// Provinces of this land held by group's bloc.
/proc/province_bloc_holdings(group)
	var/list/bloc = province_bloc_groups(group)
	var/count = 0
	for (var/c in map.province_holders())
		if (province_holder_of(c) in bloc)
			count++
	return count

// Staff: lets go of a held province at once (the next count may give it to the leader).
/proc/province_release(c, reason, staff)
	if (!map || !istext(c))
		return FALSE
	var/list/H = map.province_holders()
	var/list/row = H[c]
	if (!islist(row) || !row[1])
		return FALSE
	var/holder = row[1]
	row[1] = null
	row[2] = 0
	row[3] = 0
	row[4] = null
	row[5] = 0
	var/datum/province_map/P = map.province_map()
	var/name = P ? P.names[c] : c
	province_tell_leaders(holder, "Staff released your hold on the [name]: [reason]")
	log_admin("Provinces: [staff] released province [c] from [holder]: [reason]")
	return TRUE
