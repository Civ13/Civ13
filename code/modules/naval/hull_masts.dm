// ============================================================
// Going aloft: climbing a ship's mast, and the crow's nest (docs/ship-edges.md)
// ------------------------------------------------------------
// Grab intent with a free hand on a mast (or its Climb the Mast verb) climbs
// it, the same way as climbing a tree (tree_climbing.dm): the climber is drawn
// at the masthead, sees over walls and hills (los_up_tree), and Look into
// Distance reaches further. A movement key, grab-clicking the mast again or
// Climb Down comes back down; a stun or the mast going away is a fall.
//
// Someone aloft on her mast keeps a better lookout: her lookout sees
// MAST_ALOFT_REACH tiles further through murk and dark, or MAST_NEST_REACH
// from a crow's nest. A crow's nest is fitted to a mast with
// MAST_NEST_WOOD wood; it is also a draught piece (N), a mast with its nest.
// ============================================================

#define MAST_CLIMB_TIME 40
#define MAST_NEST_TIME 60
#define MAST_NEST_WOOD 8
#define MAST_ALOFT_REACH 4
#define MAST_NEST_REACH 8
#define MAST_ALOFT_LOOK 8
#define MAST_NEST_LOOK 11

/obj/structure/vehicleparts/movement/sail
	var/crows_nest = FALSE
	// Read by the shared climbing code (tree_climbing.dm), as for a tree.
	var/tmp/mob/living/human/tree_climber = null
	var/trunk_center_x = 0
	var/tree_canopy_top = 0

// A mast with her crow's nest already fitted (draught piece N).
/obj/structure/vehicleparts/movement/sail/crows_nest
	name = "wood mast with a crow's nest"
	crows_nest = TRUE

/obj/structure/vehicleparts/movement/sail/proc/mast_aloft()
	return tree_climber && tree_climber.climbed_tree == src && tree_climber.loc == loc ? tree_climber : null

// Null when H can climb mast M now, otherwise why not.
/mob/living/human/proc/mast_climb_refusal(obj/structure/vehicleparts/movement/sail/M)
	if (QDELETED(M) || !isturf(M.loc) || M.axis)
		return "That mast can't be climbed."
	if (M.broken)
		return "\The [M] is broken."
	if (climbed_tree)
		return "You are already aloft."
	if (!isturf(loc) || M.z != z || get_dist(src, M) > 1)
		return "You need to stand next to \the [M]."
	if (stat || lying || resting || prone || weakened || stunned || paralysis || restrained() || buckled)
		return "You can't climb right now."
	if (l_hand && r_hand)
		return "You need a free hand to climb."
	if (M.mast_aloft() && M.tree_climber != src)
		return "Someone is already up \the [M]."
	if (grabbed_by && grabbed_by.len)
		return "You can't climb while someone holds you."
	return null

/mob/living/human/proc/climb_mast(obj/structure/vehicleparts/movement/sail/M)
	if (!M)
		return FALSE
	if (climbed_tree)
		if (climbed_tree == M)
			start_climb_down()
			return TRUE
		to_chat(src, SPAN_WARNING("You are already aloft."))
		return FALSE
	if (tree_climb_busy)
		return FALSE
	var/why = mast_climb_refusal(M)
	if (why)
		to_chat(src, SPAN_WARNING(why))
		return FALSE
	tree_climb_busy = TRUE
	visible_message(SPAN_NOTICE("[src] starts climbing \the [M]."), SPAN_NOTICE("You start climbing \the [M]..."))
	var/climbed = hull_wait(src, MAST_CLIMB_TIME, M, climb = 1)
	tree_climb_busy = FALSE
	if (!climbed)
		return FALSE
	why = mast_climb_refusal(M)
	if (why)
		to_chat(src, SPAN_WARNING(why))
		return FALSE
	return go_aloft(M)

// Puts H at the masthead of M at once.
/mob/living/human/proc/go_aloft(obj/structure/vehicleparts/movement/sail/M)
	stop_pulling()
	if (pulledby)
		pulledby.stop_pulling()
	tree_climb_from = loc
	tree_climb_from_x = step_x
	tree_climb_from_y = step_y
	if (loc != M.loc)
		forceMove(M.loc)
		step_x = 0
		step_y = 0
	if (loc != M.loc)
		tree_climb_from = null
		return FALSE
	climbed_tree = M
	M.tree_climber = src
	masts_aloft |= M
	tree_climb_pose(M)
	tree_climb_apply_pose(4)
	visible_message(SPAN_NOTICE("[src] climbs up \the [M]."), SPAN_NOTICE("You climb up to [M.crows_nest ? "the crow's nest" : "the masthead"]. You see over walls and hills from up here, and the ship's lookout sees further while you keep watch. Press Space (Look into Distance) to see further, and use the movement keys to look another way; press Space again before you climb down. Move or grab the mast again to climb down."))
	tree_climb_refresh_sight()
	return TRUE

// Hook from the mast's attack_hand (hull_rigging.dm): grab intent and a free
// hand climbs it. TRUE when handled.
/obj/structure/vehicleparts/movement/sail/proc/mast_grab_climb(mob/living/human/H)
	if (!istype(H) || H.a_intent != I_GRAB || H.get_active_hand() || !isturf(loc) || axis)
		return FALSE
	H.climb_mast(src)
	return TRUE

/obj/structure/vehicleparts/movement/sail/verb/climb_mast_verb()
	set name = "Climb the Mast"
	set category = null
	set src in view(1)
	if (ishuman(usr))
		var/mob/living/human/H = usr
		H.climb_mast(src)

// ---- The crow's nest ----

// Hook from the mast's attackby (hull_rigging.dm): wood fits a crow's nest.
// TRUE when handled.
/obj/structure/vehicleparts/movement/sail/proc/fit_crows_nest(obj/item/I, mob/living/human/H)
	if (crows_nest || axis || !isturf(loc) || !istype(H) || !istype(I, /obj/item/stack/material/wood))
		return FALSE
	var/obj/item/stack/material/wood/S = I
	if (S.amount < MAST_NEST_WOOD)
		to_chat(H, SPAN_WARNING("A crow's nest takes [MAST_NEST_WOOD] wood."))
		return TRUE
	if (mast_aloft())
		to_chat(H, SPAN_WARNING("Someone is up \the [src]."))
		return TRUE
	H.visible_message(SPAN_NOTICE("[H] starts building a crow's nest on \the [src]."), SPAN_NOTICE("You start building a crow's nest at the masthead..."))
	if (!hull_wait(H, MAST_NEST_TIME, src) || QDELETED(src) || QDELETED(S) || crows_nest || S.amount < MAST_NEST_WOOD)
		return TRUE
	S.use(MAST_NEST_WOOD)
	crows_nest = TRUE
	name = "[initial(name)] with a crow's nest"
	to_chat(H, SPAN_NOTICE("The crow's nest is up. Climb the mast to keep a lookout from it."))
	return TRUE

// What examining a mast adds, from hull_rigging.dm's examine.
/obj/structure/vehicleparts/movement/sail/proc/aloft_examine(mob/user)
	var/mob/living/human/up = mast_aloft()
	if (up)
		to_chat(user, SPAN_NOTICE("[up] is up [crows_nest ? "in the crow's nest" : "at the masthead"]."))
	if (!axis && isturf(loc))
		to_chat(user, SPAN_NOTICE("Grab it with a free hand to climb it[crows_nest ? " to the crow's nest" : ""].[crows_nest ? "" : " [MAST_NEST_WOOD] wood used on it builds a crow's nest."]"))

// How far Look into Distance reaches from the masthead.
/proc/mast_look_amount(obj/structure/vehicleparts/movement/sail/M)
	return M.crows_nest ? MAST_NEST_LOOK : MAST_ALOFT_LOOK

// ---- The lookout aloft ----

var/global/list/masts_aloft = list()

// How many tiles further her lookout sees with someone aloft: the best of
// her manned masts.
/datum/craft/proc/aloft_reach()
	. = 0
	for (var/obj/structure/vehicleparts/movement/sail/M in masts_aloft)
		if (QDELETED(M) || !M.mast_aloft())
			masts_aloft -= M
			continue
		if (craft_at(get_turf(M)) == src)
			. = max(., M.crows_nest ? MAST_NEST_REACH : MAST_ALOFT_REACH)

#undef MAST_CLIMB_TIME
#undef MAST_NEST_TIME
#undef MAST_NEST_WOOD
#undef MAST_ALOFT_REACH
#undef MAST_NEST_REACH
#undef MAST_ALOFT_LOOK
#undef MAST_NEST_LOOK
