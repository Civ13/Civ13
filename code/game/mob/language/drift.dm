// Language drift (docs/language-drift.md).
//
// A speech community is one nation's native speakers of one language. When
// they mostly talk among themselves, their way of speaking drifts away from
// everyone else's; when they talk with speakers of the same language from
// outside the nation, the drift is pulled back.
//
// Only heard speech counts, and only for a listener who belongs to a nation
// and whose mother tongue is the language heard. A line from a member of the
// same nation is use; a line from a Conversational speaker of another nation,
// or of none, is contact. Every LANGUAGE_DRIFT_TICK the lines heard since the
// last tick move each community's drift, from 0 to 100:
//   drift += LANGUAGE_DRIFT_GAIN * (1 - 2 * contact share)
// so a community that hears outsiders in a quarter of its lines still drifts
// at half speed, and one that hears them in more than half drifts back.
// A community with fewer than LANGUAGE_DRIFT_MIN_LINES lines in a tick is left
// as it is: a language does not change while nobody speaks it.
//
// Drift is saved with the durable world metadata in the map field
// language_lineage_state (field version 6), as
//   list("drift" = list("Nation|Language" = drift), "daughters" = list())
// Heard lines are not saved. What a community does once its drift is high is
// in the era check (language_era_advanced, daughter.dm).

/obj/map_metadata/var/list/language_lineage_state = list()

var/global/list/language_drift_use = list()
var/global/list/language_drift_contact = list()
var/global/next_language_drift_tick = 0

/mob/living/human/var/next_language_drift_heard = -1

/proc/language_community_key(faction, datum/language/L)
	if (!istext(faction) || !length(faction) || faction == "none" || !istype(L))
		return null
	return "[faction]|[L.name]"

// list(nation, language name) for a key, or null.
/proc/language_community_parts(key)
	if (!istext(key))
		return null
	var/at = findlasttext(key, "|")
	if (at <= 1 || at >= length(key))
		return null
	return list(copytext(key, 1, at), copytext(key, at + 1))

// The saved drift table, repaired in place if a restore left it malformed.
/proc/language_drift_table()
	if (!map)
		return list()
	var/list/state = map.language_lineage_state
	if (!islist(state))
		state = list()
		map.language_lineage_state = state
	var/list/drift = state["drift"]
	if (!islist(drift))
		drift = list()
		state["drift"] = drift
	if (!islist(state["daughters"]))
		state["daughters"] = list()
	return drift

/proc/language_drift(key)
	var/list/drift = language_drift_table()
	var/value = drift[key]
	return isnum(value) ? value : 0

/proc/set_language_drift(key, value)
	if (!istext(key))
		return
	var/list/drift = language_drift_table()
	value = clamp(isnum(value) ? value : 0, 0, 100)
	if (value <= 0)
		drift -= key
	else
		drift[key] = round(value, 0.01)

// Called for every line a human hears in a language (hear_say.dm).
/mob/living/human/proc/language_drift_heard(datum/language/L, mob/speaker)
	if (civilization == "none" || !ishuman(speaker) || speaker == src || world.time < next_language_drift_heard)
		return
	L = canonical_language(L)
	if (!language_learnable(L) || mother_tongue() != L)
		return
	var/key = language_community_key(civilization, L)
	if (!key)
		return
	var/mob/living/human/S = speaker
	if (S.civilization == civilization)
		language_drift_use[key] += 1
	else if (S.language_score(L) >= LANGUAGE_CONVERSATIONAL)
		language_drift_contact[key] += 1
	else
		return
	next_language_drift_heard = world.time + LANGUAGE_DRIFT_HEAR_COOLDOWN
	if (world.time >= next_language_drift_tick)
		language_drift_tick()

// Moves every community that spoke enough since the last tick.
/proc/language_drift_tick()
	next_language_drift_tick = world.time + LANGUAGE_DRIFT_TICK
	var/list/keys = language_drift_use | language_drift_contact
	for (var/key in keys)
		var/use = language_drift_use[key]
		var/contact = language_drift_contact[key]
		var/total = use + contact
		if (total < LANGUAGE_DRIFT_MIN_LINES)
			continue
		set_language_drift(key, language_drift(key) + language_drift_step(use, contact))
	language_drift_use = list()
	language_drift_contact = list()

// How far one tick moves a community that heard `use` lines from its own
// nation and `contact` lines from outside.
/proc/language_drift_step(use, contact)
	var/total = use + contact
	if (total <= 0)
		return 0
	return LANGUAGE_DRIFT_GAIN * (1 - 2 * contact / total)

// Living native speakers of L in a nation.
/proc/language_community_natives(faction, datum/language/L)
	. = 0
	L = canonical_language(L)
	if (!L)
		return
	for (var/mob/living/human/H in living_mob_list)
		if (H.civilization == faction && H.mother_tongue() == L)
			.++

// One line per community with any drift, highest first, for admins.
/proc/language_drift_report()
	var/list/drift = language_drift_table()
	var/list/sorted = list()
	for (var/key in drift)
		var/at = 1
		while (at <= sorted.len && drift[sorted[at]] >= drift[key])
			at++
		sorted.Insert(at, key)
	var/list/lines = list("<b>Language drift</b> (a nation's native speakers drifting from other speakers of their language; [LANGUAGE_SPLIT_DRIFT]% and [LANGUAGE_SPLIT_MIN_NATIVES] living natives can split off at the next era)")
	if (!sorted.len)
		lines += "No community has drifted yet."
		return lines
	for (var/key in sorted)
		var/list/parts = language_community_parts(key)
		if (!parts)
			continue
		var/datum/language/L = all_languages[parts[2]]
		var/natives = L ? language_community_natives(parts[1], L) : 0
		var/value = drift[key]
		var/line = "[parts[1]], [parts[2]]: [round(value)]% drift, [natives] living native\s"
		if (key in language_lineage_part("pending"))
			line += " - <b>waiting for its leader to name it</b>"
		else if (value >= LANGUAGE_SPLIT_DRIFT && natives >= LANGUAGE_SPLIT_MIN_NATIVES)
			line += " - <b>ready to split</b>"
		var/heard = language_drift_use[key] + language_drift_contact[key]
		if (heard)
			line += " (this half hour: [language_drift_use[key]] own, [language_drift_contact[key]] outside)"
		lines += line
	return lines
