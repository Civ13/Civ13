// Peoples split after long isolation (docs/peoples.md).
//
// Splits are rare on purpose (Val, 2026-11-21): contact between factions is
// watched, and only a nation that stays out of touch for a long time becomes a
// people of its own. Research eras play no part, since they move with player
// research; time is the world calendar (world_calendar_year, peoples.dm).
//
// A community is one nation's members of one people ("Nation|people id").
// While the drift tick runs (language/drift.dm), it notes which communities
// had a member playing, and which nations had contact with another faction or
// with someone of no faction: hearing their speech (PEOPLE_CONTACT_LINES in a
// year), or standing within PEOPLE_CONTACT_RANGE tiles of them (trade, visits,
// a shared settlement). At each new calendar year, an active community of a
// nation without contact gains one year of isolation; contact halves it. With
// PEOPLE_SPLIT_YEARS years, PEOPLE_SPLIT_MIN living members and at least half
// of the nation's living members, it is ready to split, and the nation's
// Discord-verified leader names the new people (Name Our People). Living
// members of that nation and people join it; nobody else changes.
//
// Saved in map.language_lineage_state:
//   "people_isolation" = list("Nation|id" = years)
//   "people_pending"   = list("Nation|id" = year it became ready)
//   "people_year"      = list("year" = last calendar year processed)
//   "people_active", "people_contact" = this year's flags

/mob/living/human/var/tmp/next_people_contact_heard = -1

/proc/people_community_key(nation, id)
	if (!istext(nation) || !length(nation) || nation == "none" || !istext(id) || !length(id))
		return null
	return "[nation]|[id]"

// list(nation, people id) for a key, or null.
/proc/people_community_parts(key)
	if (!istext(key))
		return null
	var/at = findlasttext(key, "|")
	if (at <= 1 || at >= length(key))
		return null
	return list(copytext(key, 1, at), copytext(key, at + 1))

// Called for every line a human hears (hear_say.dm): speech from another
// faction, or from someone of none, is contact for the listener's nation.
/mob/living/human/proc/people_heard(mob/speaker)
	if (civilization == "none" || !ishuman(speaker) || speaker == src || world.time < next_people_contact_heard)
		return
	var/mob/living/human/S = speaker
	if (S.civilization == civilization || !S.client)
		return
	next_people_contact_heard = world.time + LANGUAGE_DRIFT_HEAR_COOLDOWN
	var/list/heard = language_lineage_part("people_heard")
	heard[civilization] = (heard[civilization] || 0) + 1
	if (heard[civilization] >= PEOPLE_CONTACT_LINES)
		var/list/contact = language_lineage_part("people_contact")
		contact[civilization] = TRUE

// Runs with the drift tick: notes this year's activity and nearness to
// outsiders, and rolls the year over when the calendar has moved on.
/proc/people_isolation_tick()
	if (!map)
		return
	var/list/active = language_lineage_part("people_active")
	var/list/contact = language_lineage_part("people_contact")
	var/list/players = list()
	for (var/mob/living/human/H in human_mob_list)
		if (H.stat != DEAD && H.client && !QDELETED(H))
			players += H
	for (var/mob/living/human/H in players)
		var/key = people_community_key(H.civilization, H.origin_id)
		if (key)
			active[key] = TRUE
		if (H.civilization == "none" || contact[H.civilization])
			continue
		var/turf/T = get_turf(H)
		if (!T)
			continue
		for (var/mob/living/human/other in players)
			if (other.civilization == H.civilization)
				continue
			var/turf/O = get_turf(other)
			if (O && O.z == T.z && max(abs(O.x - T.x), abs(O.y - T.y)) <= PEOPLE_CONTACT_RANGE)
				contact[H.civilization] = TRUE
				if (other.civilization != "none")
					contact[other.civilization] = TRUE
				break
	people_year_check(world_calendar_year())

// Closes every calendar year since the last one processed. Only the year
// just ended carries flags; years nobody played add nothing.
/proc/people_year_check(year)
	var/list/marker = language_lineage_part("people_year")
	if (!isnum(marker["year"]))
		marker["year"] = year
		return 0
	if (year <= marker["year"])
		return 0
	marker["year"] = year
	var/list/active = language_lineage_part("people_active")
	var/list/contact = language_lineage_part("people_contact")
	var/list/isolation = language_lineage_part("people_isolation")
	for (var/key in active)
		var/list/parts = people_community_parts(key)
		if (!parts)
			continue
		if (contact[parts[1]])
			isolation[key] = round((isnum(isolation[key]) ? isolation[key] : 0) / 2)
		else
			isolation[key] = (isnum(isolation[key]) ? isolation[key] : 0) + 1
		if (isolation[key] <= 0)
			isolation -= key
	active.Cut()
	contact.Cut()
	var/list/heard = language_lineage_part("people_heard")
	heard.Cut()
	return people_split_check(year)

// Living members of a nation, and of one people in it.
/proc/people_nation_counts(nation, id)
	var/members = 0
	var/total = 0
	for (var/mob/living/human/H in human_mob_list)
		if (H.stat == DEAD || H.civilization != nation)
			continue
		total++
		if (H.origin_id == id)
			members++
	return list(members, total)

// Marks every community that has been apart long enough as ready to split.
/proc/people_split_check(year)
	var/list/isolation = language_lineage_part("people_isolation")
	var/list/pending = language_lineage_part("people_pending")
	. = 0
	for (var/key in isolation)
		if (key in pending)
			continue
		var/list/parts = people_community_parts(key)
		if (!parts || !isnum(isolation[key]) || isolation[key] < PEOPLE_SPLIT_YEARS || !origin_by_id(parts[2]))
			continue
		var/list/counts = people_nation_counts(parts[1], parts[2])
		if (counts[1] < PEOPLE_SPLIT_MIN || counts[1] * 2 < counts[2])
			continue
		pending[key] = year
		.++
		people_split_ready_notice(parts[1], parts[2])

/proc/people_split_ready_notice(nation, id)
	var/datum/origin/O = origin_by_id(id)
	for (var/mob/living/human/H in living_mob_list)
		if (H.civilization != nation)
			continue
		if (H.origin_id == id)
			to_chat(H, SPAN_NOTICE("Your people have lived apart from the rest of the [O ? O.name : "world"] for so long that they have become a people of their own."))
		if (map.is_faction_leader(H, nation))
			H.offer_people_naming()

/mob/living/human/proc/offer_people_naming()
	if (!(/mob/living/human/proc/name_our_people in verbs))
		verbs += /mob/living/human/proc/name_our_people
	to_chat(src, SPAN_NOTICE("As leader of the [civilization], you can name your new people with <b>Name Our People</b> in the IC tab. Naming them needs a Discord-verified account (OOC > Verify Discord)."))

/proc/people_pending_for(nation)
	var/list/pending = language_lineage_part("people_pending")
	var/list/keys = list()
	for (var/key in pending)
		var/list/parts = people_community_parts(key)
		if (parts && parts[1] == nation)
			keys += key
	return keys

// Called at login (knowledge_spread.dm's Login).
/mob/living/human/proc/offer_pending_people_naming()
	if (map && civilization != "none" && map.is_faction_leader(src, civilization) && people_pending_for(civilization).len)
		offer_people_naming()

/mob/living/human/proc/name_our_people()
	set category = "IC"
	set name = "Name Our People"
	set desc = "Name the people your nation has become."
	var/list/keys = people_pending_for(civilization)
	if (!map.is_faction_leader(src, civilization))
		verbs -= /mob/living/human/proc/name_our_people
		to_chat(src, SPAN_WARNING("Only your nation's leader can name its people."))
		return
	if (!keys.len)
		verbs -= /mob/living/human/proc/name_our_people
		to_chat(src, SPAN_WARNING("Your nation has no new people to name."))
		return
	if (!account_verified(nation_account()))
		to_chat(src, SPAN_WARNING("Naming a people needs a Discord-verified account. Use OOC > Verify Discord first."))
		return
	var/key = keys[1]
	if (keys.len > 1)
		var/list/choices = list()
		for (var/k in keys)
			var/datum/origin/O = origin_by_id(people_community_parts(k)[2])
			choices[O ? O.name : k] = k
		var/picked = player_input(src, "More than one of your nation's peoples has grown apart. Which one do you want to name?", "Name Our People", null, "anything", choices, TRUE)
		if (!picked)
			return
		key = choices[picked]
	var/datum/origin/parent = origin_by_id(people_community_parts(key)[2])
	var/wanted = player_input(src, "Your nation's [parent ? parent.name : "people"] have become a people of their own. What are they called? (3 to 24 letters, a name of this world. The name cannot be changed later.)", "Name Our People", null, "text", null, TRUE)
	if (isnull(wanted))
		return
	var/problem = people_name_problem(wanted)
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return
	if (!(key in language_lineage_part("people_pending")) || !map.is_faction_leader(src, civilization))
		to_chat(src, SPAN_WARNING("Your nation has no new people to name."))
		return
	var/datum/origin/N = split_people(key, people_clean_name(wanted))
	if (!N)
		to_chat(src, SPAN_WARNING("The people could not be named. Please adminhelp this."))
		return
	log_game("[key_name(src)] named [civilization]'s new people, grown from the [parent ? parent.name : "?"]: [N.name].")
	message_admins("[key_name_admin(src)] named [civilization]'s new people: [N.name].")
	if (!people_pending_for(civilization).len)
		verbs -= /mob/living/human/proc/name_our_people

// The split itself: the living members of the nation who belong to the
// parent people join the new one. Returns it, or null.
/proc/split_people(key, name)
	var/list/pending = language_lineage_part("people_pending")
	var/list/parts = people_community_parts(key)
	if (!(key in pending) || !parts || people_name_problem(name))
		return null
	var/nation = parts[1]
	var/datum/origin/parent = origin_by_id(parts[2])
	if (!parent)
		return null
	// Their mother tongue is what most of them speak natively now, which may be
	// a daughter language their nation named (language/daughter.dm).
	var/list/tongues = list()
	var/list/members = list()
	for (var/mob/living/human/H in human_mob_list)
		if (H.stat == DEAD || H.civilization != nation || H.origin_id != parent.id)
			continue
		members += H
		var/datum/language/L = H.mother_tongue()
		if (L)
			tongues[L.name] = (tongues[L.name] || 0) + 1
	var/tongue = parent.language
	for (var/lname in tongues)
		if (tongues[lname] > (tongues[tongue] || 0))
			tongue = lname
	var/datum/origin/N = found_people(name, list(parent.id), tongue, land_display_name(map), nation)
	if (!N)
		return null
	pending -= key
	var/list/isolation = language_lineage_part("people_isolation")
	isolation -= key
	for (var/mob/living/human/H in members)
		var/old_summary = H.origin_summary()
		if (old_summary)
			H.remove_note("Origin", old_summary)
		H.origin_id = N.id
		H.add_note("Origin", H.origin_summary())
		if (H.client)
			to_chat(H, SPAN_NOTICE("<b>Your people are the [N.name] now.</b> You grew from the [parent.name], and those born among you from now on are [N.name] too."))
	return N

// For admins (Check Peoples): every community's isolation and any waiting split.
/proc/people_isolation_report()
	var/list/lines = list()
	var/list/isolation = language_lineage_part("people_isolation")
	var/list/pending = language_lineage_part("people_pending")
	for (var/key in isolation | pending)
		var/list/parts = people_community_parts(key)
		if (!parts)
			continue
		var/datum/origin/O = origin_by_id(parts[2])
		var/list/counts = people_nation_counts(parts[1], parts[2])
		lines += "[parts[1]], [O ? O.name : parts[2]]: [isnum(isolation[key]) ? isolation[key] : 0] of [PEOPLE_SPLIT_YEARS] years apart, [counts[1]] of [counts[2]] living members[(key in pending) ? ", waiting for its leader to name it" : ""]."
	if (!lines.len)
		lines += "No nation is growing apart."
	return lines
