// ============================================================
// Pushing a hull off by hand (docs/craft-core.md)
// ------------------------------------------------------------
// A built hull only sails forward along her heading and swings round her
// pivot, so a long hull run up against a shore can be stuck: land ahead, and
// no room to turn. Her crew get her off the way crews always have: they stand
// ashore or wade in the shallows beside her and push.
//
// Click one of her planks with an empty hand (any intent but harm) while
// standing next to her, off her deck, on land or in shallow water. After a
// heave of three seconds your strength counts towards pushing her one tile
// away from you. Everyone who heaved the same way in the last five seconds
// and is still beside her counts together; an average person moves about
// HULL_PUSH_TILES_PER_PERSON tiles of hull, so a big hull needs a gang. She
// keeps her heading, and the tile is drawn as a short glide.
// ============================================================

#define HULL_PUSH_TILES_PER_PERSON 20
#define HULL_PUSH_HEAVE_TIME 30 // Deciseconds a heave takes.
#define HULL_PUSH_WINDOW 50     // Deciseconds heaves from different people still add up.
#define HULL_PUSH_GLIDE 10      // Deciseconds the tile she is pushed is drawn over.

/datum/craft
	var/tmp/list/push_heaves = null // pusher = list(direction, strength, world.time)

// The strength of people it takes to push her.
/datum/craft/proc/push_strength_needed()
	return max(1, round(mass() / HULL_PUSH_TILES_PER_PERSON, 0.1))

// The tile of her hull H stands beside, pushing towards plank P, or null with
// the reason in reason.
/proc/hull_push_refusal(mob/living/human/H, obj/covers/P)
	if (!istype(H) || !P)
		return "nothing to push"
	var/turf/at = get_turf(H)
	var/turf/plank = get_turf(P)
	var/datum/craft/C = craft_at(plank)
	if (!C || !istype(C.body, /datum/craft_body/built))
		return "that is not a hull"
	if (H.stat || H.lying || H.restrained() || H.buckled)
		return "you are in no state to push"
	if (!at || at.z != plank.z || get_dist(at, plank) != 1 || !(get_dir(at, plank) in cardinal))
		return "stand right beside her to push"
	if (C.body.contains(at))
		return "you cannot push her from her own deck"
	if (istype(at, /turf/floor/beach/water/deep))
		return "you need your feet on the ground or in the shallows to push"
	if (C.speed > 0 && !C.anchored)
		return "she is under way"
	if (C.hop_timer || C.turning_to)
		return "she is moving"
	var/datum/craft_body/built/B = C.body
	for (var/obj/structure/hull_tiller/T in locate(B.px, B.py, B.z))
		if (T.craft == C && T.voyage)
			return "she is on a voyage"
	if (persistence_save_in_progress)
		return "the world is being saved"
	return null

// Clicking her plank from beside her pushes.
/obj/covers/attack_hand(mob/user)
	if (ishuman(user) && user.a_intent != I_HARM && !stairs)
		var/turf/plank = get_turf(src)
		var/datum/craft/C = plank ? craft_at(plank) : null
		var/turf/at = get_turf(user)
		if (C && istype(C.body, /datum/craft_body/built) && at && !C.body.contains(at) && get_dist(at, plank) == 1)
			hull_push_heave(user, src)
			return
	return ..()

// One heave by H against plank P. TRUE when she moved.
/proc/hull_push_heave(mob/living/human/H, obj/covers/P)
	var/why = hull_push_refusal(H, P)
	if (why)
		to_chat(H, SPAN_WARNING("You cannot push \the [P]: [why]."))
		return FALSE
	var/datum/craft/C = craft_at(get_turf(P))
	var/direction = get_dir(H, P)
	H.visible_message(SPAN_NOTICE("[H] sets [H.gender == FEMALE ? "her" : (H.gender == MALE ? "his" : "their")] shoulder to the [C.name] and heaves."), SPAN_NOTICE("You set your shoulder to the [C.name] and heave."))
	if (!do_after(H, HULL_PUSH_HEAVE_TIME, P))
		return FALSE
	why = hull_push_refusal(H, P)
	if (why)
		to_chat(H, SPAN_WARNING("You cannot push \the [P]: [why]."))
		return FALSE
	return hull_push_add(C, H, direction)

// Counts H's heave towards direction, and moves her one tile that way when
// enough people heaved together. TRUE when she moved.
/proc/hull_push_add(datum/craft/C, mob/living/human/H, direction)
	if (!C.push_heaves)
		C.push_heaves = list()
	C.push_heaves[H] = list(direction, max(0.3, H.getStatCoeff("strength")), world.time)
	var/total = 0
	var/list/gang = list()
	for (var/mob/living/human/M in C.push_heaves.Copy())
		var/list/heave = C.push_heaves[M]
		if (QDELETED(M) || world.time - heave[3] > HULL_PUSH_WINDOW)
			C.push_heaves -= M
			continue
		if (heave[1] != direction || !C.body || get_dist(M, H) > 30)
			continue
		var/next_to = FALSE
		for (var/turf/T in orange(1, M))
			if (C.body.contains(T) && get_dir(M, T) == direction)
				next_to = TRUE
				break
		if (!next_to)
			continue
		total += heave[2]
		gang += M
	var/needed = C.push_strength_needed()
	if (total < needed)
		var/short = max(1, round(needed - total + 0.49))
		for (var/mob/living/human/M in gang)
			to_chat(M, SPAN_WARNING("The [C.name] shifts a little but does not move. About [short] more [short == 1 ? "pair" : "pairs"] of hands heaving with you would do it."))
		return FALSE
	var/datum/craft_body/built/B = C.body
	var/list/box = B.box(B.offsets)
	var/dx = (direction & EAST) ? 1 : ((direction & WEST) ? -1 : 0)
	var/dy = (direction & NORTH) ? 1 : ((direction & SOUTH) ? -1 : 0)
	B.glide_time = HULL_PUSH_GLIDE
	var/moved = B.move_to(B.px + box[1] + dx, B.py + box[2] + dy, B.dir)
	B.glide_time = 0
	if (!moved)
		for (var/mob/living/human/M in gang)
			to_chat(M, SPAN_WARNING("The [C.name] will not go that way: [B.last_refusal]."))
		return FALSE
	B.glide_rest(HULL_PUSH_GLIDE)
	for (var/mob/living/human/M in gang)
		C.push_heaves -= M
	C.crew_message(SPAN_NOTICE("The [C.name] is pushed off a tile by hand."))
	for (var/mob/living/human/M in gang)
		to_chat(M, SPAN_NOTICE("Together you push the [C.name] off a tile."))
	return TRUE

#undef HULL_PUSH_TILES_PER_PERSON
#undef HULL_PUSH_HEAVE_TIME
#undef HULL_PUSH_WINDOW
#undef HULL_PUSH_GLIDE
