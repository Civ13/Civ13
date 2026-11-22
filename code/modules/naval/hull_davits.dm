// ============================================================
// Lifeboat davits (docs/vessel-entries.md, phase 6)
// ------------------------------------------------------------
// A pair of davits stands at her edge, facing out over the side. A small boat
// (a raft, a dugout, an outrigger or a boat) brought alongside under them is
// hoisted up and stowed; at need it is lowered into the water beside her and
// her crew climb down into it. Only while she is stopped, and only an empty
// boat with nobody and nothing aboard.
//
// The stowed boat rides inside the davit as ordinary nested contents, the way
// a boathouse keeps boats (boathouse.dm), so it moves and saves with her.
// ============================================================

#define HULL_DAVIT_TIME (8 SECONDS)

/obj/structure/lifeboat_davit
	name = "lifeboat davits"
	desc = "A pair of curved steel arms at a ship's side, with falls and blocks, for hoisting a small boat aboard and lowering it into the water."
	icon = 'icons/obj/vessel_openings.dmi'
	icon_state = "davit"
	anchored = TRUE
	density = FALSE
	flammable = FALSE
	var/tmp/busy = FALSE

/obj/structure/lifeboat_davit/persistence_runtime_var(key)
	return key == "busy" || ..(key)

/obj/structure/lifeboat_davit/New()
	..()
	update_icon()

/obj/structure/lifeboat_davit/after_load()
	..()
	update_icon()

/obj/structure/lifeboat_davit/update_icon()
	icon_state = stowed() ? "davit_boat" : "davit"

// The boat stowed in the davits, or null.
/obj/structure/lifeboat_davit/proc/stowed()
	for (var/obj/structure/vehicle/V in contents)
		if (boathouse_is_small_boat(V))
			return V
	return null

// The water below the davits, over her side.
/obj/structure/lifeboat_davit/proc/water_below()
	return get_step(src, dir)

// Why she cannot work her davits now, or null.
/obj/structure/lifeboat_davit/proc/ship_refusal()
	if (busy)
		return "The falls are already being worked."
	var/datum/craft/C = craft_holding(get_turf(src))
	if (C && C.speed != VESSEL_SPEED_STOP)
		return "She must be stopped before a boat goes up or down."
	return null

// Why boat V cannot be hoisted now, or null.
/obj/structure/lifeboat_davit/proc/hoist_refusal(obj/structure/vehicle/V)
	. = ship_refusal()
	if (.)
		return
	if (stowed())
		return "A boat is already stowed in \the [src]."
	if (!boathouse_is_small_boat(V))
		return "Only a small boat hangs in davits."
	if (V.loc != water_below() || !V.afloat())
		return "Bring the boat alongside, afloat right under \the [src]."
	if (V.moving || V.driver || V.buckled_mob)
		return "Get everyone out of the boat first."
	for (var/mob/living/L in V.ontop)
		return "Get everyone out of the boat first."
	for (var/atom/movable/A in V.ontop_o)
		return "Unload the boat first."
	if (V.engine && V.engine.on)
		return "Stop the boat's engine first."
	return null

// Why the stowed boat cannot be lowered now, or null.
/obj/structure/lifeboat_davit/proc/lower_refusal()
	. = ship_refusal()
	if (.)
		return
	if (!stowed())
		return "No boat is stowed in \the [src]."
	var/turf/T = water_below()
	if (!istype(T, /turf/floor/beach/water) || T.density)
		return "There is no open water under \the [src] to lower the boat into."
	for (var/atom/movable/M in T)
		if (istype(M, /obj/structure/vehicle) || istype(M, /obj/structure/vehicleparts) || (M.density && M.anchored))
			return "\The [M] is in the way below \the [src]."
	return null

/obj/structure/lifeboat_davit/proc/hoist(obj/structure/vehicle/V, mob/living/human/H = null)
	var/why = hoist_refusal(V)
	if (why)
		if (H)
			to_chat(H, SPAN_WARNING(why))
		return FALSE
	if (H)
		busy = TRUE
		H.visible_message(SPAN_NOTICE("[H] hooks on the falls and starts hoisting \the [V] up to \the [src]."))
		var/done = do_after(H, HULL_DAVIT_TIME, src)
		busy = FALSE
		if (!done)
			return FALSE
		why = hoist_refusal(V)
		if (why)
			to_chat(H, SPAN_WARNING(why))
			return FALSE
	V.forceMove(src)
	playsound(loc, 'sound/effects/lever.ogg', 40, TRUE)
	update_icon()
	if (H)
		log_game("[key_name(H)] hoisted [V] into davits at [x],[y],[z].")
	return TRUE

/obj/structure/lifeboat_davit/proc/lower(mob/living/human/H = null)
	var/why = lower_refusal()
	if (why)
		if (H)
			to_chat(H, SPAN_WARNING(why))
		return null
	var/obj/structure/vehicle/V = stowed()
	if (H)
		busy = TRUE
		H.visible_message(SPAN_NOTICE("[H] casts off the gripes and starts lowering \the [V] from \the [src]."))
		var/done = do_after(H, HULL_DAVIT_TIME, src)
		busy = FALSE
		if (!done)
			return null
		why = lower_refusal()
		if (why)
			to_chat(H, SPAN_WARNING(why))
			return null
	var/turf/T = water_below()
	V.forceMove(T)
	V.dir = dir
	V.update_icon()
	playsound(loc, 'sound/effects/lever.ogg', 40, TRUE)
	update_icon()
	if (H)
		H.visible_message(SPAN_NOTICE("\The [V] touches the water beside her."))
		log_game("[key_name(H)] lowered [V] from davits at [x],[y],[z].")
	return V

/obj/structure/lifeboat_davit/attack_hand(mob/living/human/H)
	if (!istype(H) || !Adjacent(H) || H.travel_held() || H.incapacitated())
		return ..()
	if (!stowed())
		to_chat(H, SPAN_NOTICE("Bring a small boat alongside under \the [src] and drag it onto them to hoist it aboard."))
		return
	lower(H)

/obj/structure/lifeboat_davit/MouseDrop_T(atom/movable/A, mob/living/human/H)
	if (!istype(H) || !istype(A, /obj/structure/vehicle) || !Adjacent(H) || H.travel_held() || H.incapacitated())
		return ..()
	hoist(A, H)

/obj/structure/lifeboat_davit/examine(mob/user)
	. = ..()
	var/obj/structure/vehicle/V = stowed()
	to_chat(user, SPAN_NOTICE(V ? "\A [V] is stowed in them: click them to lower it into the water while she is stopped." : "They are empty: bring a small boat alongside under them and drag it onto them to hoist it aboard."))

// A davit that goes drops its boat where it stood.
/obj/structure/lifeboat_davit/Destroy()
	var/obj/structure/vehicle/V = stowed()
	if (V)
		V.forceMove(loc)
	return ..()

#undef HULL_DAVIT_TIME
