// ============================================================
// Research Tree - naturalist's finds (research beyond waiting, Val 2026-11-14)
// ------------------------------------------------------------
// Book-research worlds only. A scholar with paper, parchment or a book and a
// pen can record the wild things of the world: a living animal, a wild plant,
// an ore or rock, or the night sky. Each record is worth a twentieth of a
// chapter in a subject of the matching discipline that the scholar could
// research now. A book takes each kind of find once, and finds fill at most
// three tenths of any one chapter. Weather seen outdoors (once per kind a
// season) and the waters beside you are Natural Science finds too (player
// request relayed by Val, 2026-11-18). On a land reached by expedition a record
// is worth double. Records on a sheet are used on a bench working on a
// subject of that discipline.
// ============================================================

#define FIND_POINTS 0.05
#define FIND_CHAPTER_CAP 0.3
#define FIND_RANGE 2
#define FIND_TIME 200
#define FIND_SKY "the night sky"

/obj/item/weapon/book
	var/research_finds = "" // "node>kind>points;..." naturalist's finds written into this book

/obj/item/weapon/paper
	var/find_kind = null // what these naturalist's notes record
	var/find_discipline = null // the discipline the record belongs to
	var/find_double = FALSE // recorded on a land reached by expedition

// ---------- What counts as a find ----------

// Simple mobs that are people or traders, not wildlife.
var/global/list/find_not_animals = list(
	/mob/living/simple_animal/civilian,
	/mob/living/simple_animal/hostage,
	/mob/living/simple_animal/npc_vendor,
	/mob/living/simple_animal/pepelsibirsk_trader,
	/mob/living/simple_animal/wizard,
	/mob/living/simple_animal/hostile/human,
	/mob/living/simple_animal/hostile/commanded,
	/mob/living/simple_animal/hostile/wizard)

// The discipline a thing's record belongs to, or null when it is no find.
/proc/find_discipline(atom/A)
	// Preserved organs on an anatomy table (organ_uses.dm), a few records each.
	if (istype(A, /obj/item/organ_specimen))
		var/obj/item/organ_specimen/S = A
		return S.studyable() ? "medicine" : null
	if (istype(A, /mob/living/simple_animal))
		var/mob/living/simple_animal/S = A
		if (S.stat == DEAD || is_type_in_list(S, find_not_animals))
			return null
		return "agriculture"
	if (istype(A, /obj/structure/wild/rock) || istype(A, /obj/item/stack/ore))
		return istype(A, /obj/item/stack/ore/charcoal) ? null : "natural_science"
	if (istype(A, /obj/structure/wild))
		if (istype(A, /obj/structure/wild/burnedbush) || istype(A, /obj/structure/wild/burnedtree) || istype(A, /obj/structure/wild/tree_stump))
			return null
		return "medicine"
	return null

// The night sky can be recorded outdoors at night, once per season.
/proc/find_sky_visible(mob/living/human/H)
	if (!istype(H) || time_of_day != "Night")
		return FALSE
	var/area/A = get_area(H)
	return A && A.location == AREA_OUTSIDE

/proc/find_sky_kind()
	return "sky:[lowertext("[season]")]"

// The weather falling on H outdoors, as list(kind, name), or null. Each kind
// is one find a season.
/proc/find_weather(mob/living/human/H)
	var/turf/T = get_turf(H)
	var/area/A = get_area(H)
	if (!T || !A || A.location != AREA_OUTSIDE)
		return null
	var/what = null
	switch (weather_look_at(T))
		if ("rain1", "rain2", "rain3")
			what = "rain"
		if ("monsoon")
			what = "monsoon"
		if ("snow1", "snow2")
			what = "snow"
		if ("snow_storm")
			what = "blizzard"
		if ("sandstorm")
			what = "sandstorm"
	if (!what && weather_wind_at(T) >= 3)
		what = "gale"
	if (!what && weather_heat_at(T))
		what = "heat wave"
	if (!what)
		return null
	return list("weather:[what]:[lowertext("[season]")]", "the [what]")

// The kind of water T is, for a find: list(kind, name), or null.
/proc/find_water(turf/T)
	if (!istype(T, /turf/floor/beach/water) || T.density || istype(T, /turf/floor/beach/water/deep/saltwater/underwater))
		return null
	if (istype(T, /turf/floor/beach/water/ice))
		return list("water:ice", "frozen water")
	if (istype(T, /turf/floor/beach/water/swamp) || istype(T, /turf/floor/beach/water/deep/swamp))
		return list("water:swamp", "a swamp")
	if (istype(T, /turf/floor/beach/water/flooded))
		return list("water:flood", "floodwater")
	var/turf/floor/F = T
	if (F.salty)
		return list("water:sea", "the sea")
	if (istype(T, /turf/floor/beach/water/jungle) || istype(T, /turf/floor/beach/water/deep/jungle))
		return list("water:jungle", "a jungle river")
	return list("water:fresh", "fresh water")

// Finds that are no thing to point at: the sky, the weather and the waters
// near H. Each is list(kind, discipline, name).
/proc/find_place_targets(mob/living/human/H)
	var/list/found = list()
	if (!istype(H))
		return found
	if (find_sky_visible(H))
		found += list(list(find_sky_kind(), "mathematics", FIND_SKY))
	var/list/W = find_weather(H)
	if (W)
		found += list(list(W[1], "natural_science", W[2]))
	var/list/waters = list()
	for (var/turf/T in range(FIND_RANGE, H))
		var/list/water = find_water(T)
		if (water && !(water[1] in waters))
			waters += water[1]
			found += list(list(water[1], "natural_science", water[2]))
	return found

// Whether a place find of this kind is still there for H.
/proc/find_place_still_here(mob/living/human/H, kind)
	for (var/list/P in find_place_targets(H))
		if (P[1] == kind)
			return TRUE
	return FALSE

// Whether records made here count double.
/proc/find_double_here()
	return expedition_land() ? TRUE : FALSE

// ---------- The book's record ----------

/obj/item/weapon/book/proc/find_list()
	var/list/result = list()
	if (istext(research_finds) && length(research_finds))
		for (var/part in splittext(research_finds, ";"))
			if (length(part))
				result += part
	return result

/obj/item/weapon/book/proc/has_find(kind)
	for (var/entry in find_list())
		var/list/parts = splittext(entry, ">")
		if (parts.len >= 2 && parts[2] == kind)
			return TRUE
	return FALSE

// Points finds have already written into a chapter of this book.
/obj/item/weapon/book/proc/find_points(node_id)
	. = 0
	for (var/entry in find_list())
		var/list/parts = splittext(entry, ">")
		if (parts.len >= 3 && parts[1] == node_id)
			. += text2num(parts[3])

// Points one more find would add to a chapter of this book (0 when it takes none).
/obj/item/weapon/book/proc/find_room(node_id, kind, double = FALSE)
	var/datum/research_node/N = get_research_node(node_id)
	if (!N || !valid_recipe_node_id(node_id) || has_research_chapter(node_id) || has_find(kind))
		return 0
	var/room = round(N.cost_ticks * FIND_CHAPTER_CAP) - find_points(node_id)
	return max(0, min(room, max(1, round(N.cost_ticks * FIND_POINTS * (double ? 2 : 1)))))

// Writes one find into the book. Returns the points added, or 0.
/obj/item/weapon/book/proc/record_find(node_id, kind, double = FALSE)
	var/points = find_room(node_id, kind, double)
	if (points <= 0)
		return 0
	var/list/done = find_list()
	done += "[node_id]>[kind]>[points]"
	research_finds = jointext(done, ";")
	add_research_work(node_id, points)
	return points

// Subjects of a discipline that H could research now and this book has room for.
/proc/find_subjects(mob/living/human/H, discipline, obj/item/weapon/book/B, kind, double = FALSE)
	var/list/found = list()
	if (!istype(H) || !istype(B) || !map || !map.book_research_enabled())
		return found
	for (var/node_id in research_nodes)
		if (node_discipline(node_id) != discipline)
			continue
		if (H.knows_recipe_node(node_id) || !H.knows_research_prereqs(node_id))
			continue
		if (B.find_room(node_id, kind, double) > 0)
			found += node_id
	return found

/proc/find_paper_ok(obj/item/weapon/paper/P)
	return istype(P) && !istype(P, /obj/item/weapon/paper/research_page) && !P.demonstration_node && !P.field_study_node && !P.find_kind

/proc/find_book_ok(obj/item/weapon/book/B)
	return istype(B) && !istype(B, /obj/item/weapon/book/research/tree_book)

// Things near H that can be recorded, label => list(kind, discipline, atom, name).
/proc/find_targets(mob/living/human/H)
	var/list/found = list()
	if (!istype(H))
		return found
	for (var/atom/movable/A in range(FIND_RANGE, H))
		if (A == H)
			continue
		var/discipline = find_discipline(A)
		if (!discipline)
			continue
		var/label = "[A.name] ([scholar_disciplines[discipline]])"
		var/kind = "[A.type]"
		if (istype(A, /obj/item/organ_specimen))
			var/obj/item/organ_specimen/S = A
			kind = S.find_kind()
		if (!(label in found))
			found[label] = list(kind, discipline, A, A.name)
	for (var/list/P in find_place_targets(H))
		found["[P[3]] ([scholar_disciplines[P[2]]])"] = list(P[1], P[2], null, P[3])
	return found

// Writes a finished record down. No waiting here. Returns the points added
// (1 for a sheet of notes), or 0.
/proc/commit_find(mob/living/human/H, obj/item/carrier, kind, discipline, thing_name, node_id = null)
	if (!istype(H) || !istext(kind) || !(discipline in scholar_disciplines))
		return 0
	var/double = find_double_here()
	if (istype(carrier, /obj/item/weapon/paper))
		var/obj/item/weapon/paper/P = carrier
		if (!find_paper_ok(P))
			return 0
		P.find_kind = kind
		P.find_discipline = discipline
		P.find_double = double
		P.name = "naturalist's notes ([thing_name])"
		P.desc = "A record of [thing_name] made by [H.real_name]. Use it on a research bench working on a subject of [scholar_disciplines[discipline]], with its book on the bench."
		P.update_icon()
		return 1
	var/obj/item/weapon/book/B = carrier
	if (!find_book_ok(B) || !(node_id in find_subjects(H, discipline, B, kind, double)))
		return 0
	. = B.record_find(node_id, kind, double)
	H.gain_active_scholarship(node_id, ., "find:[kind]")

/mob/living/human/proc/record_a_find(obj/item/carrier)
	if (!map || !map.book_research_enabled())
		to_chat(src, SPAN_WARNING("There is nothing here to record."))
		return FALSE
	if (!(carrier in list(l_hand, r_hand)))
		to_chat(src, SPAN_WARNING("Hold \the [carrier] in your hand first."))
		return FALSE
	if (!held_writing_pen())
		to_chat(src, SPAN_WARNING("You need a pen or pencil in your other hand to make a record."))
		return FALSE
	var/is_paper = istype(carrier, /obj/item/weapon/paper)
	if (is_paper ? !find_paper_ok(carrier) : !find_book_ok(carrier))
		to_chat(src, SPAN_WARNING("\The [carrier] can't take a record. Use a blank sheet or an ordinary book."))
		return FALSE
	var/list/found = find_targets(src)
	if (!found.len)
		to_chat(src, SPAN_WARNING("Nothing near you is worth recording. Stand within [FIND_RANGE] tiles of a living animal, a wild plant, an ore or a rock, water, or a preserved specimen on an anatomy table, or stand outdoors in rain, snow or a storm, or at night to record the sky."))
		return FALSE
	var/choice = found[1]
	if (found.len > 1)
		choice = player_input(src, "What do you record?", "Record a Find", null, "anything", found, TRUE)
		if (!choice || !(choice in found))
			return FALSE
	var/list/entry = found[choice]
	var/kind = entry[1]
	var/discipline = entry[2]
	var/atom/movable/thing = entry[3]
	var/thing_name = entry[4]
	var/node_id = null
	if (!is_paper)
		var/obj/item/weapon/book/B = carrier
		if (B.has_find(kind))
			to_chat(src, SPAN_WARNING("[B] already holds a record of [thing_name]."))
			return FALSE
		var/list/subjects = find_subjects(src, discipline, B, kind, find_double_here())
		if (!subjects.len)
			to_chat(src, SPAN_WARNING("A record of [thing_name] belongs to [scholar_disciplines[discipline]], and [B] has no room for it: you need a subject of that discipline whose groundwork you know, and finds fill at most three tenths of a chapter."))
			return FALSE
		node_id = subjects[1]
		if (subjects.len > 1)
			var/list/names = list()
			for (var/id in subjects)
				var/datum/research_node/SN = get_research_node(id)
				names[SN.name] = id
			var/picked = player_input(src, "Which subject does the record go to?", "Record a Find", null, "anything", names, TRUE)
			if (!picked || !(picked in names))
				return FALSE
			node_id = names[picked]
	visible_message(SPAN_NOTICE("[src] starts observing [thing_name] and writing."), SPAN_NOTICE("You start making a record of [thing_name]."))
	// Animals wander, so the record does not break when they step away.
	if (!do_reading(src, FIND_TIME, ismob(thing) ? null : thing))
		to_chat(src, SPAN_WARNING("You stop before your record is done."))
		return FALSE
	if (!(carrier in list(l_hand, r_hand)))
		return FALSE
	if (thing ? (QDELETED(thing) || get_dist(src, thing) > FIND_RANGE + 2 || !find_discipline(thing)) : !find_place_still_here(src, kind))
		to_chat(src, SPAN_WARNING("You lost sight of what you were recording."))
		return FALSE
	var/points = commit_find(src, carrier, kind, discipline, thing_name, node_id)
	if (!points)
		to_chat(src, SPAN_WARNING("The record came to nothing."))
		return FALSE
	// Same tick as the check above, so two scholars can't share a last study.
	if (istype(thing, /obj/item/organ_specimen))
		var/obj/item/organ_specimen/S = thing
		S.use_study()
	if (is_paper)
		to_chat(src, SPAN_NOTICE("You finish your notes on [thing_name]. Use them on a research bench working on a subject of <b>[scholar_disciplines[discipline]]</b>."))
	else
		var/datum/research_node/N = get_research_node(node_id)
		to_chat(src, SPAN_NOTICE("You write your record of [thing_name] into [carrier]: <b>[N.name]</b> advances by [points] points."))
	return TRUE

/obj/item/weapon/paper/verb/record_find_paper()
	set name = "Record a Find"
	set category = "Object"
	set src in usr
	var/mob/living/human/H = usr
	if (istype(H) && !H.incapacitated())
		H.record_a_find(src)

/obj/item/weapon/book/verb/record_find_book()
	set name = "Record a Find"
	set category = "Object"
	set src in usr
	var/mob/living/human/H = usr
	if (istype(H) && !H.incapacitated())
		H.record_a_find(src)

// Naturalist's notes used on a bench working on a subject of their discipline.
/obj/structure/research_bench/proc/take_find_notes(obj/item/weapon/paper/P, mob/living/human/user)
	if (!istype(P) || !P.find_kind)
		return FALSE
	var/obj/item/weapon/book/B = placed_book()
	var/datum/research_node/N = get_research_node(assigned_node)
	if (!B || !N || node_discipline(assigned_node) != P.find_discipline)
		to_chat(user, SPAN_WARNING("These notes belong to [scholar_disciplines[P.find_discipline]]. Put a book on the bench and research a subject of that discipline first."))
		return TRUE
	if (B.find_room(N.id, P.find_kind, P.find_double) <= 0)
		to_chat(user, SPAN_WARNING("[B] already holds this record, or as many finds as <b>[N.name]</b> takes."))
		return TRUE
	if (!user.remove_from_mob(P))
		return TRUE
	var/kind = P.find_kind
	var/double = P.find_double
	qdel(P)
	var/points = B.record_find(N.id, kind, double)
	user.gain_active_scholarship(N.id, points, "find:[kind]")
	to_chat(user, SPAN_NOTICE("You copy the notes into [B]: <b>[N.name]</b> advances by [points] points[B.has_research_chapter(N.id) ? " and the chapter is finished" : ""]."))
	book_refresh_ui()
	return TRUE

#undef FIND_POINTS
#undef FIND_CHAPTER_CAP
#undef FIND_RANGE
#undef FIND_TIME
#undef FIND_SKY
