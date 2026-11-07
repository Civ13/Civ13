// ============================================================
// EVA in orbit (orbital stations, stage B)
// ------------------------------------------------------------
// Outside a station there is nothing to push against. On an orbit world a
// person on vacuum moves freely only while something to hold is within
// reach: a hull, deck or other solid ground, a truss, or any anchored or
// solid structure. Leaving the last handhold behind pushes them off, and
// they drift on in that direction, one tile every ORBIT_DRIFT_DELAY ticks,
// until they reach something to catch hold of.
//
// A safety tether clipped to a handhold stops a drift at its reach (seven
// tiles) and pulls the drifter back to it, and lets them haul themselves
// along it. Drifting across a linked plane edge carries on into the next
// plane (and unclips any tether). Drifting into an unlinked edge stops the
// drifter there, out of reach of anything: they stay until rescued or until
// their air runs out.
//
// Drifting is a short process-local loop, never saved: it stops while the
// world is empty and wakes on the next move. A person restored mid-drift is
// still and can push off again in any direction, unless they are lost at an
// unlinked edge. Nothing here is a world.time stamp.
// ============================================================

#define ORBIT_DRIFT_DELAY 4
#define ORBIT_TETHER_LENGTH 7

var/global/list/orbit_drifters = list()
var/global/orbit_drift_running = FALSE
var/global/mob/orbit_drift_mover = null
var/global/list/orbit_eva_notices = list()

// ---------------------------------------------------------------- handholds

// TRUE when this turf itself is something to hold: not vacuum, or holding a
// truss or an anchored or solid structure.
/turf/proc/orbit_hold_point(atom/except)
	if (!istype(src, /turf/floor/space/orbit))
		return TRUE
	for (var/obj/O in contents)
		if (O == except || O.invisibility >= 101 || istype(O, /obj/effect) || istype(O, /obj/item))
			continue
		if (istype(O, /obj/structure/orbit_truss) || O.anchored || O.density)
			return TRUE
	return FALSE

// TRUE when a hold point is within reach of this turf.
/turf/proc/orbit_handhold(atom/except)
	for (var/turf/T in range(1, src))
		if (T.orbit_hold_point(except))
			return TRUE
	return FALSE

/proc/orbit_eva_notice(mob/living/human/H, message)
	if (!H || orbit_eva_notices[H] == message)
		return
	orbit_eva_notices[H] = message
	to_chat(H, message)

/proc/orbit_eva_tether(mob/living/human/H)
	if (!H)
		return null
	for (var/obj/item/eva_tether/T in H)
		if (T.anchor)
			return T
	return null

// ---------------------------------------------------------------- drifting

/proc/orbit_start_drift(mob/living/human/H, direction)
	if (!H || !direction)
		return
	orbit_drifters[H] = direction
	orbit_eva_notices -= H
	to_chat(H, "<span class='warning'>You push off into open space and drift.</span>")
	orbit_drift_wake()

/proc/orbit_stop_drift(mob/living/human/H)
	orbit_drifters -= H
	orbit_eva_notices -= H

/proc/orbit_drift_wake()
	if (orbit_drift_running || !orbit_drifters.len || !clients.len)
		return
	orbit_drift_running = TRUE
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(orbit_drift_tick)), ORBIT_DRIFT_DELAY)

// One drift tick for everyone drifting; queues the next while anyone drifts
// and someone is connected.
/proc/orbit_drift_tick()
	orbit_drift_running = FALSE
	orbit_drifters -= null
	if (!clients.len)
		return
	for (var/mob/living/human/H in orbit_drifters.Copy())
		orbit_drift_step(H)
	orbit_drift_wake()

// One tile of drift. Returns TRUE when the drifter moved.
/proc/orbit_drift_step(mob/living/human/H)
	var/direction = orbit_drifters[H]
	if (!direction || !H || QDELETED(H) || H.stat == DEAD || !orbit_world())
		orbit_stop_drift(H)
		return FALSE
	var/turf/here = H.loc
	if (!istype(here, /turf/floor/space/orbit) || H.buckled || H.anchored || H.pulledby || here.orbit_handhold(H))
		orbit_stop_drift(H)
		return FALSE
	var/obj/item/eva_tether/tether = orbit_eva_tether(H)
	if (tether && tether.anchor.z != H.z)
		tether.unclip(H, "<span class='warning'>Your tether comes loose.</span>")
		tether = null
	var/turf/next = get_step(H, direction)
	if (tether && next && get_dist(tether.anchor, next) > tether.reach)
		direction = get_dir(H, tether.anchor)
		orbit_drifters[H] = direction
		to_chat(H, "<span class='notice'>Your tether pulls taut and draws you back.</span>")
		next = get_step(H, direction)
	if (!next)
		orbit_stop_drift(H)
		to_chat(H, "<span class='danger'>You drift to the edge of everything. There is nothing left within reach.</span>")
		return FALSE
	if (!persistence_movement_allowed(H, next))
		return FALSE
	orbit_drift_mover = H
	var/moved = H.Move(next, direction)
	orbit_drift_mover = null
	if (!moved && H.loc == here)
		orbit_stop_drift(H)
		return FALSE
	return TRUE

/turf/floor/space/orbit/Exit(atom/movable/O, atom/newloc)
	if (!ishuman(O) || !orbit_world() || !isturf(newloc))
		return ..()
	var/mob/living/human/H = O
	if (H == orbit_drift_mover || H.pulledby || H.buckled || orbit_handhold(H))
		return ..()
	var/obj/item/eva_tether/tether = orbit_eva_tether(H)
	if (tether && tether.anchor.z == z && get_dist(tether.anchor, newloc) < get_dist(tether.anchor, src))
		return ..()
	if (orbit_drifters[H])
		orbit_eva_notice(H, "<span class='warning'>There is nothing to push against.</span>")
		orbit_drift_wake()
		return FALSE
	// Still, with nothing in reach (restored mid-drift): push off again,
	// unless lost at a plane edge.
	if (orbit_edge_side())
		orbit_eva_notice(H, "<span class='danger'>There is nothing within reach to hold or push against.</span>")
		return FALSE
	orbit_start_drift(H, get_dir(src, newloc))
	return FALSE

// Called from /turf/floor/space/orbit/Entered once a move ends here.
/turf/floor/space/orbit/proc/orbit_eva_entered(mob/living/human/H, atom/old_loc)
	if (!orbit_world() || H.buckled || H.pulledby)
		return
	if (orbit_handhold(H))
		if (orbit_drifters[H])
			orbit_stop_drift(H)
			to_chat(H, "<span class='notice'>You catch hold.</span>")
		return
	if (orbit_drifters[H])
		return
	var/turf/from = get_turf(old_loc)
	var/direction = (from && from.z == z && get_dist(from, src) == 1) ? get_dir(from, src) : H.dir
	orbit_start_drift(H, direction)

// ---------------------------------------------------------------- truss

/obj/structure/orbit_truss
	name = "truss"
	desc = "An open frame of steel struts, bolted out into space to give a hand something to hold."
	icon = 'icons/obj/structures.dmi'
	icon_state = "grille"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	flammable = FALSE
	layer = 2.9

// ---------------------------------------------------------------- tether

/obj/item/eva_tether
	name = "safety tether"
	desc = "A steel-cored line with a clip. Use it beside a handhold to clip on, and again to unclip."
	icon = 'icons/obj/materials.dmi'
	icon_state = "rope"
	w_class = ITEM_SIZE_SMALL
	slot_flags = SLOT_BELT
	flammable = FALSE
	// How far the line pays out, in tiles.
	var/reach = ORBIT_TETHER_LENGTH
	// Where the tether is clipped. Process-local: a restored tether is unclipped.
	var/tmp/turf/anchor = null

/obj/item/eva_tether/persistence_runtime_var(key)
	return (key in list("anchor")) || ..()

/obj/item/eva_tether/Destroy()
	anchor = null
	return ..()

/obj/item/eva_tether/proc/unclip(mob/user, message)
	anchor = null
	if (user && message)
		to_chat(user, message)

/obj/item/eva_tether/attack_self(mob/user)
	if (anchor)
		unclip(user, "<span class='notice'>You unclip [src].</span>")
		return
	var/turf/here = get_turf(user)
	if (!here)
		return
	for (var/turf/T in range(1, here))
		if (T.orbit_hold_point(user))
			anchor = T
			to_chat(user, "<span class='notice'>You clip [src] on.</span>")
			return
	to_chat(user, "<span class='warning'>There is nothing within reach to clip [src] to.</span>")
