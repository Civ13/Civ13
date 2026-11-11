// Player-dug shafts are holes, not free ladders. Mapped tunnel pairs are unchanged.
/obj/structure/multiz/ladder/ww2/tunneltop/pit
	name = "dug hole"
	desc = "An open shaft. Leaves can disguise it. From below, face a solid rim and use Climb Up."
	var/leaf_covered = FALSE

/obj/structure/multiz/ladder/ww2/tunneltop/pit/New()
	..()
	ladder_list -= src // Unpaired pits must not shift mapped ladder numbering.

/obj/structure/multiz/ladder/ww2/tunneltop/pit/get_saved_vars()
	. = ..()
	. |= list("leaf_covered")

/obj/structure/multiz/ladder/ww2/tunneltop/pit/find_target()
	target = null
	return null // No automatically created lower ladder or inferred map pair.

/obj/structure/multiz/ladder/ww2/tunneltop/pit/update_icon()
	icon = initial(icon)
	icon_state = initial(icon_state)
	name = initial(name)
	if (leaf_covered)
		icon = 'icons/obj/items.dmi'
		icon_state = "punji2"
		name = "leaves"

/obj/structure/multiz/ladder/ww2/tunneltop/pit/proc/landing()
	var/level = multiz_level_below(z)
	var/turf/T = level ? locate(x, y, level) : null
	return ledge_landing_clear(T, TRUE) ? T : null

/obj/structure/multiz/ladder/ww2/tunneltop/pit/attackby(obj/item/I, mob/user)
	if (!istype(I, /obj/item/stack/material/leaf))
		return ..()
	var/obj/item/stack/material/leaf/leaves = I
	if (leaf_covered || !Adjacent(user) || user.stat || user.restrained() || user.get_active_hand() != leaves || !leaves.can_use(5) || persistence_save_in_progress)
		return
	to_chat(user, SPAN_NOTICE("You start covering the hole with leaves."))
	if (!do_after(user, 30, src))
		return
	if (QDELETED(src) || QDELETED(leaves) || leaf_covered || !Adjacent(user) || user.stat || user.restrained() || user.get_active_hand() != leaves || persistence_save_in_progress || !leaves.use(5))
		return
	leaf_covered = TRUE
	update_icon()
	to_chat(user, SPAN_NOTICE("You disguise the hole. The leaves will not support anyone's weight."))

/obj/structure/multiz/ladder/ww2/tunneltop/pit/attack_hand(mob/user)
	if (!isliving(user) || !isturf(user.loc) || !Adjacent(user) || user.stat || user.restrained())
		return
	if (leaf_covered)
		if (persistence_save_in_progress)
			return
		leaf_covered = FALSE
		update_icon()
		to_chat(user, SPAN_NOTICE("You brush the leaves aside, revealing the hole."))
		return
	to_chat(user, SPAN_NOTICE("You start lowering yourself into the hole."))
	if (!do_after(user, 20, src) || QDELETED(src) || !Adjacent(user) || user.stat || user.restrained() || user.pulling || user.pulledby || user.buckled)
		return
	var/turf/T = landing()
	if (T && persistence_movement_allowed(user, T))
		trench_climb_place(user, T)

/obj/structure/multiz/ladder/ww2/tunneltop/pit/Crossed(atom/movable/A)
	// Crossed follows existing traps' collision semantics. Never call the ladder
	// parent, which would perform a second cross-level move for items.
	var/mob/living/L = A
	if (!istype(L) || !isturf(L.loc) || L.z != z || L.anchored || L.buckled || persistence_save_in_progress)
		return
	var/turf/T = landing()
	if (!T || !persistence_movement_allowed(A, T))
		return
	// A pull link must not bridge the pit: the faller lets go and is let go.
	if (L.pulledby)
		L.pulledby.stop_pulling()
	if (L.pulling)
		L.stop_pulling()
	if (trench_climb_place(L, T))
		leaf_covered = FALSE
		update_icon()
		A.visible_message(SPAN_WARNING("[A] falls into the hole!"))
		L.Stun(3)
		L.adjustBruteLoss(10)

// A deliberately conservative landing test: do not bypass doors, border
// barriers, occupied cells, liquid, unsupported air, or another dug shaft.
/proc/ledge_landing_clear(turf/T, allow_occupants = FALSE)
	if (!T || T.density || istype(T, /turf/floor/dirt/underground) || istype(T, /turf/floor/beach/water) || istype(T, /turf/floor/lava))
		return FALSE
	if (locate(/obj/structure/multiz/ladder/ww2/tunneltop/pit) in T)
		return FALSE
	var/supported = !building_open_turf(T)
	for (var/atom/movable/A in T)
		if (allow_occupants && isliving(A))
			continue // A victim at the bottom must not disable the pit.
		if (A.density || isliving(A))
			return FALSE
		if (istype(A, /obj/covers))
			var/obj/covers/C = A
			if (C.wall || C.incomplete)
				return FALSE
			supported = TRUE
	return supported

/proc/ledge_climber_ready(mob/living/human/H)
	return istype(H) && isturf(H.loc) && !H.stat && !H.lying && !H.restrained() && !H.buckled && !H.pulling && !H.pulledby && H.has_empty_hand() && !persistence_save_in_progress

/proc/ledge_climb_destination(mob/living/human/H, direction)
	if (!ledge_climber_ready(H) || !(direction in list(NORTH, SOUTH, EAST, WEST)))
		return null
	var/turf/here = get_turf(H)
	var/level = multiz_level_above(here.z)
	var/turf/overhead = level ? locate(here.x, here.y, level) : null
	if (!overhead || overhead.density)
		return null
	var/obj/structure/multiz/ladder/ww2/tunneltop/pit/shaft = locate() in overhead
	if (!shaft && !building_open_turf(overhead))
		return null // No climbing through a solid ceiling.
	for (var/atom/movable/A in overhead)
		if (A != shaft && (A.density || istype(A, /obj/covers)))
			return null
	var/turf/wall_turf = get_step(here, direction)
	if (!wall_turf)
		return null
	var/wall = wall_turf.density || istype(wall_turf, /turf/floor/dirt/underground)
	for (var/obj/covers/C in wall_turf)
		if (C.wall && !C.incomplete && C.health > 0)
			wall = TRUE
	// A dug shaft has an earthen rim even if its cave cell opens into a room.
	if (!wall && !shaft)
		return null
	var/turf/destination = locate(wall_turf.x, wall_turf.y, level)
	if (!ledge_landing_clear(destination) || (map && map.check_caribbean_block(H, destination)) || !persistence_movement_allowed(H, destination))
		return null
	return destination

/mob/living/human/verb/climb_up_ledge()
	set name = "Climb Up"
	set category = "IC"
	set desc = "Face a wall or the rim of a dug hole and climb to the floor above. Keep a hand free."
	climb_ledge(dir)

// Shared by the Climb Up verb and an empty-handed grab-intent click on the wall
// or rim, so both take the same checks, wait and placement.
/mob/living/human/proc/climb_ledge(direction)
	var/turf/start = get_turf(src)
	var/turf/destination = ledge_climb_destination(src, direction)
	if (!destination)
		to_chat(src, SPAN_WARNING("You need a free hand, an opening overhead and a clear, solid ledge in front of you."))
		return FALSE
	if (dir != direction)
		set_dir(direction)
	visible_message(SPAN_NOTICE("[src] starts climbing toward the ledge above."))
	if (!do_after(src, 30, start))
		return FALSE
	// Re-resolve terrain and actor admission after the interruptible wait.
	if (get_turf(src) != start || dir != direction || ledge_climb_destination(src, direction) != destination)
		return FALSE
	if (trench_climb_place(src, destination))
		visible_message(SPAN_NOTICE("[src] climbs onto the ledge."))
		return TRUE
	return FALSE

// Grab intent with an empty hand on a wall or hole rim next to you climbs it,
// exactly as Climb Up would. Returns TRUE only when it took over the click;
// otherwise the click falls through to the normal attack_hand().
/mob/living/human/proc/grab_climb_ledge(atom/A)
	if (a_intent != I_GRAB || get_active_hand())
		return FALSE
	var/turf/target = get_turf(A)
	if (!target || (A != target && !istype(A, /obj/covers)))
		return FALSE
	var/turf/here = get_turf(src)
	if (!here || target.z != here.z)
		return FALSE
	var/direction = get_dir(here, target)
	if (!(direction in list(NORTH, SOUTH, EAST, WEST)) || get_step(here, direction) != target)
		return FALSE
	if (!ledge_climb_destination(src, direction))
		return FALSE
	climb_ledge(direction)
	return TRUE
