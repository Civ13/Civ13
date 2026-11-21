// Peoples blend, and belonging grows (docs/peoples.md).
//
// Blend: a nation where two peoples each make up at least a quarter of its
// living members, year after played year, grows a blended people of both.
// After PEOPLE_BLEND_YEARS such years, the nation's verified leader names it
// with Name Our People (peoples_split.dm). Nobody's people changes: the
// blend is the people new characters are born into among that nation
// (community_blend_people, read by choose_origin in origins.dm).
//
// Belong: a character who plays a year among a community whose most common
// people is not their own counts one year raised among that people. After
// PEOPLE_RAISED_YEARS their notes read "Raised among the X", and that
// people's leader can welcome them (Welcome Among Us). Both are notes and a
// record only: a character keeps their birth people for life, and no game
// rule reads either.
//
// Saved in map.language_lineage_state["people_blend"] = list("Nation|a+b" = years)
// and on the character in people_raised (id = years) and people_welcomed.

/mob/living/human/var/list/people_raised = null	// people id -> played years lived among them
/mob/living/human/var/list/people_welcomed = null	// people ids whose leader welcomed this character
/mob/living/human/var/tmp/people_played_year = FALSE

// "Nation|a+b" for two peoples, in a fixed order.
/proc/people_blend_key(nation, a, b)
	if (!istext(a) || !istext(b) || a == b)
		return null
	var/list/pair = sortList(list(a, b))
	return people_community_key(nation, "[pair[1]]+[pair[2]]")

// list(a, b) for the people part of a blend key, or null.
/proc/people_blend_pair(id_part)
	if (!istext(id_part))
		return null
	var/at = findtext(id_part, "+")
	if (at <= 1 || at >= length(id_part))
		return null
	return list(copytext(id_part, 1, at), copytext(id_part, at + 1))

// Living members of a nation by people: list(id = count), and the total.
/proc/people_nation_mix(nation)
	var/list/mix = list()
	var/total = 0
	for (var/mob/living/human/H in human_mob_list)
		if (H.stat == DEAD || H.civilization != nation || !istext(H.origin_id))
			continue
		mix[H.origin_id] = (mix[H.origin_id] || 0) + 1
		total++
	return list(mix, total)

// One played year for every nation that had a member playing.
/proc/people_blend_year(list/active, year)
	var/list/nations = list()
	for (var/key in active)
		var/list/parts = people_community_parts(key)
		if (parts)
			nations[parts[1]] = TRUE
	var/list/blend = language_lineage_part("people_blend")
	var/list/pending = language_lineage_part("people_pending")
	for (var/nation in nations)
		var/list/result = people_nation_mix(nation)
		var/list/mix = result[1]
		var/total = result[2]
		var/list/big = list()
		if (total >= PEOPLE_BLEND_MIN)
			for (var/id in mix)
				if (mix[id] * 4 >= total && origin_by_id(id))
					big += id
		var/kept = null
		if (big.len >= 2)
			// The two largest peoples of the nation.
			var/first = null
			var/second = null
			for (var/id in big)
				if (!first || mix[id] > mix[first])
					second = first
					first = id
				else if (!second || mix[id] > mix[second])
					second = id
			kept = people_blend_key(nation, first, second)
			blend[kept] = (isnum(blend[kept]) ? blend[kept] : 0) + 1
			if (blend[kept] >= PEOPLE_BLEND_YEARS && !(kept in pending) && !people_blend_done(nation, first, second))
				pending[kept] = year
				people_split_ready_notice(nation, null, "Your nation's peoples have lived together so long that a people of both has grown among you.")
		// A mix that no longer holds fades.
		for (var/key in blend.Copy())
			var/list/parts = people_community_parts(key)
			if (!parts || parts[1] != nation || key == kept)
				continue
			blend[key] = round(blend[key] / 2)
			if (blend[key] <= 0)
				blend -= key

// TRUE when the nation already has a blended people of these two.
/proc/people_blend_done(nation, a, b)
	var/list/records = people_records()
	for (var/id in records)
		var/list/R = records[id]
		if (islist(R) && R["nation"] == nation && islist(R["parents"]) && (a in R["parents"]) && (b in R["parents"]))
			return TRUE
	return FALSE

// Names a waiting blend: a people of both, with the larger group's tongue.
/proc/blend_people(key, name)
	var/list/pending = language_lineage_part("people_pending")
	var/list/parts = people_community_parts(key)
	var/list/pair = parts ? people_blend_pair(parts[2]) : null
	if (!(key in pending) || !pair || people_name_problem(name))
		return null
	var/nation = parts[1]
	var/list/result = people_nation_mix(nation)
	var/list/mix = result[1]
	var/larger = (mix[pair[2]] || 0) > (mix[pair[1]] || 0) ? pair[2] : pair[1]
	var/smaller = larger == pair[1] ? pair[2] : pair[1]
	var/datum/origin/L = origin_by_id(larger)
	var/datum/origin/S = origin_by_id(smaller)
	if (!L || !S)
		return null
	var/datum/origin/N = found_people(name, list(larger, smaller), L.language, land_display_name(map), nation)
	if (!N)
		return null
	pending -= key
	var/list/blend = language_lineage_part("people_blend")
	blend -= key
	for (var/mob/living/human/H in living_mob_list)
		if (H.civilization == nation && H.client)
			to_chat(H, SPAN_NOTICE("A people of both the [L.name] and the [S.name] has grown among you: the <b>[N.name]</b>. Those born among you from now on are [N.name]."))
	return N

// The blended people of the nation with the most members around T, if any:
// newcomers there are born into it.
/proc/community_blend_people(turf/T, mob/living/human/except = null)
	if (!T)
		return null
	var/list/nations = list()
	for (var/mob/living/human/H in human_mob_list)
		if (H == except || H.stat == DEAD || H.civilization == "none" || !istext(H.civilization))
			continue
		var/turf/at = get_turf(H)
		if (at && at.z == T.z && max(abs(at.x - T.x), abs(at.y - T.y)) <= PEOPLE_COMMUNITY_RANGE)
			nations[H.civilization] = (nations[H.civilization] || 0) + 1
	var/best = null
	for (var/nation in nations)
		if (!best || nations[nation] > nations[best])
			best = nation
	if (!best)
		return null
	var/datum/origin/found = null
	var/list/records = people_records()
	for (var/id in records)
		var/list/R = records[id]
		if (islist(R) && R["nation"] == best && islist(R["parents"]) && length(R["parents"]) >= 2)
			var/datum/origin/O = world_people(id)
			if (O && (!found || O.formed_year >= found.formed_year))
				found = O
	return found

// ------------------------------------------------------------
// Belonging
// ------------------------------------------------------------

// One played year for every character who played it.
/proc/people_belong_year()
	for (var/mob/living/human/H in human_mob_list)
		if (!H.people_played_year)
			continue
		H.people_played_year = FALSE
		if (H.stat == DEAD || !istext(H.origin_id))
			continue
		var/list/community = community_peoples(get_turf(H), H)
		if (!community.len)
			continue
		var/among = community[1]
		if (among == H.origin_id)
			continue
		if (!islist(H.people_raised))
			H.people_raised = list()
		H.people_raised[among] = (isnum(H.people_raised[among]) ? H.people_raised[among] : 0) + 1
		if (H.people_raised[among] == PEOPLE_RAISED_YEARS)
			var/datum/origin/O = origin_by_id(among)
			if (O)
				H.add_note("Origin", "Raised among the [O.name]")
				if (H.client)
					to_chat(H, SPAN_NOTICE("You have lived among the [O.name] so long that you are one of their own in all but birth. Their leader may welcome you."))

/mob/living/human/proc/raised_among(id)
	return islist(people_raised) && isnum(people_raised[id]) && people_raised[id] >= PEOPLE_RAISED_YEARS

// The leader's verb, given at login (knowledge_spread.dm).
/mob/living/human/proc/offer_people_welcome()
	if (map && civilization != "none" && istext(origin_id) && map.is_faction_leader(src, civilization))
		verbs |= /mob/living/human/proc/welcome_among_us
	else
		verbs -= /mob/living/human/proc/welcome_among_us

/mob/living/human/proc/welcome_among_us()
	set category = "IC"
	set name = "Welcome Among Us"
	set desc = "Welcome someone raised among your people as one of your own. Their people of birth stays as it is."
	if (!map || !map.is_faction_leader(src, civilization))
		verbs -= /mob/living/human/proc/welcome_among_us
		to_chat(src, SPAN_WARNING("Only a nation's leader can welcome someone among their people."))
		return
	var/datum/origin/O = get_origin()
	if (!O)
		return
	var/list/choices = list()
	for (var/mob/living/human/H in view(3, src))
		if (H != src && H.stat != DEAD && H.origin_id != O.id && H.raised_among(O.id) && !(islist(H.people_welcomed) && (O.id in H.people_welcomed)))
			choices[H.real_name] = H
	if (!choices.len)
		to_chat(src, SPAN_WARNING("Nobody near you has been raised among the [O.name] long enough to be welcomed."))
		return
	var/picked = player_input(src, "Whom do you welcome among the [O.name]?", "Welcome Among Us", null, "anything", choices, TRUE)
	var/mob/living/human/H = choices[picked]
	if (!istype(H) || QDELETED(H) || get_dist(src, H) > 3)
		return
	if (!islist(H.people_welcomed))
		H.people_welcomed = list()
	H.people_welcomed |= O.id
	H.add_note("Origin", "Welcomed among the [O.name] by [real_name]")
	to_chat(H, SPAN_NOTICE("<b>[real_name] welcomes you among the [O.name].</b>"))
	to_chat(src, SPAN_NOTICE("You welcome [H.real_name] among the [O.name]."))
	log_game("[key_name(src)] welcomed [key_name(H)] among the [O.name].")
