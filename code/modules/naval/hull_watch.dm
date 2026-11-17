// ============================================================
// Stations and the watch (docs/hull-ledger.md)
// ------------------------------------------------------------
// A hull is worked from places on her deck: the helm, the masts, the oars,
// the pumps, the anchor and the bow. Nothing here forces a crew to man them;
// it tells the helm who is where, and it pays a hand for standing in the bow.
//
// - Muster the watch: an option at the tiller that lists everyone aboard and
//   the station each stands at.
// - Lookout: someone on their feet in the bow of a boat or a ship under way
//   sees what lies on her course up to twelve tiles off, and calls it to the
//   crew when it is first sighted and again when it is close. Without a
//   lookout the crew learns of it only as she comes up on it.
//
// The lookout is stepped with the ledger, every half minute.
// ============================================================

// Tiles ahead a lookout sees, and the distance at which they call again.
#define WATCH_SIGHT 12
#define WATCH_CLOSE 4

/datum/hull_ledger
	// Tiles off the thing on her course was when the lookout last called it.
	var/tmp/sighted = 0

// TRUE when H can stand a watch: alive, awake and on their feet.
/proc/watch_fit(mob/living/human/H)
	return istype(H) && !QDELETED(H) && !H.stat && !H.lying

// How far along her heading T lies: the larger, the nearer her bow.
/datum/hull_ledger/proc/along(turf/T)
	switch (craft.body.heading())
		if (NORTH)
			return T.y
		if (SOUTH)
			return -T.y
		if (EAST)
			return T.x
		if (WEST)
			return -T.x
	return 0

// Where her foremost tiles lie, as along() counts it, or null.
/datum/hull_ledger/proc/bow_line()
	. = null
	if (!craft || !craft.body || !craft.body.placed())
		return
	for (var/turf/T in craft.body.cells())
		var/a = along(T)
		if (isnull(.) || a > .)
			. = a

// TRUE when T is in her bow: her two foremost rows, on either deck.
/datum/hull_ledger/proc/in_bow(turf/T, line = null)
	if (!deck_holds(T))
		return FALSE
	if (isnull(line))
		line = bow_line()
	return !isnull(line) && along(T) >= line - 1

// The tiller she is steered from.
/datum/hull_ledger/proc/helm()
	var/datum/craft_body/built/B = craft ? craft.body : null
	if (!istype(B) || !B.placed())
		return null
	for (var/obj/structure/hull_tiller/T in locate(B.px, B.py, B.z))
		if (T.craft == craft)
			return T
	return null

// TRUE when H is busy at the helm or an oar and so keeps no lookout.
/datum/hull_ledger/proc/at_helm_or_oar(mob/living/human/H, obj/structure/hull_tiller/tiller)
	if (istype(H.buckled, /obj/structure/bed/chair/wood/rowing_bench))
		return TRUE
	return tiller && H.z == tiller.z && get_dist(H, tiller) <= 1

// TRUE when a hull of her size keeps a lookout at all.
/datum/hull_ledger/proc/keeps_lookout()
	return hull_class() != HULL_CLASS_SMALL

// Whoever keeps the lookout in her bow, or null.
/datum/hull_ledger/proc/lookout(list/aboard = null)
	if (!craft || !craft.body || !craft.body.placed() || !keeps_lookout())
		return null
	var/line = bow_line()
	var/obj/structure/hull_tiller/tiller = helm()
	if (!aboard)
		aboard = craft.body.aboard()
	for (var/mob/living/human/H in aboard)
		if (watch_fit(H) && in_bow(get_turf(H), line) && !at_helm_or_oar(H, tiller))
			return H
	return null

// What lies on her course within reach tiles: list(tiles off, what), or null
// when the water is clear. Writes nothing.
/datum/hull_ledger/proc/sight_ahead(reach = WATCH_SIGHT)
	var/datum/craft_body/B = craft ? craft.body : null
	var/turf/O = B && B.placed() ? B.origin() : null
	if (!O)
		return null
	var/heading = B.heading()
	var/dx = heading == EAST ? 1 : (heading == WEST ? -1 : 0)
	var/dy = heading == NORTH ? 1 : (heading == SOUTH ? -1 : 0)
	var/refusal_was = B.last_refusal
	. = null
	for (var/d = 1 to reach)
		if (!B.can_move_to(O.x + dx * d, O.y + dy * d, heading))
			var/what = B.last_refusal
			// The helm has no use for map coordinates.
			var/cut = findtext(what, " at ")
			if (cut)
				what = copytext(what, 1, cut)
			cut = findtext(what, " ahead")
			if (cut)
				what = copytext(what, 1, cut)
			. = list(d, what)
			break
	B.last_refusal = refusal_was

// One step of the lookout. TRUE when they called something.
/datum/hull_ledger/proc/step_watch()
	if (!under_way() || craft.turning_to)
		sighted = 0
		return FALSE
	var/mob/living/human/H = lookout()
	if (!H)
		sighted = 0
		return FALSE
	var/list/seen = sight_ahead()
	if (!seen)
		sighted = 0
		return FALSE
	var/off = seen[1]
	var/call_it = !sighted || off > sighted || (off <= WATCH_CLOSE && sighted > WATCH_CLOSE)
	sighted = off
	if (!call_it)
		return FALSE
	craft.crew_message(SPAN_WARNING("<b>[H.name] calls from the bow:</b> [seen[2]], [off] tile\s ahead[off <= WATCH_CLOSE ? "! Stop her or turn her" : ""]."))
	return TRUE

// Where H stands on her, in words.
/datum/hull_ledger/proc/station_of(mob/living/human/H, list/aboard, obj/structure/hull_tiller/tiller, line)
	if (!watch_fit(H))
		return "laid out on her deck"
	if (istype(H.buckled, /obj/structure/bed/chair/wood/rowing_bench))
		return "at an oar"
	if (tiller && H.z == tiller.z && get_dist(H, tiller) <= 1)
		return "at the helm"
	if (keeps_lookout() && in_bow(get_turf(H), line))
		return "in the bow, keeping the lookout"
	for (var/atom/movable/A in aboard)
		if (A.z != H.z || get_dist(A, H) > 1)
			continue
		if (istype(A, /obj/structure/vehicleparts/movement/sail))
			return "at a mast"
		if (istype(A, /obj/structure/cellar_pump))
			return "at a pump"
		if (istype(A, /obj/structure/hull_anchor))
			return "at the anchor"
	return "on deck"

// Everyone aboard and their station, for the helm.
/datum/hull_ledger/proc/muster_text()
	if (!craft || !craft.body || !craft.body.placed())
		return "She is not afloat."
	var/list/aboard = craft.body.aboard()
	var/obj/structure/hull_tiller/tiller = helm()
	var/line = bow_line()
	var/list/lines = list()
	for (var/mob/living/human/H in aboard)
		if (H.stat == DEAD)
			continue
		lines += "[H.name]: [station_of(H, aboard, tiller, line)]"
	. = "<b>The watch of the [craft.name]</b>: [lines.len] aboard."
	for (var/text in lines)
		. += "<br>- [text]"
	if (keeps_lookout() && !lookout(aboard))
		. += "<br>Nobody keeps a lookout. A hand on their feet in her bow calls what lies ahead while she is under way."

#undef WATCH_SIGHT
#undef WATCH_CLOSE
