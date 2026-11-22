// Breaking ice (docs/fishing-grounds.md, "Breaking ice").
//
// Frozen water can be broken back into open water, a tile at a time, so a
// channel can be cleared for a boat. A pickaxe breaks a tile fastest; a
// hatchet or a crowbar takes longer and a chisel longer still. Bare hands only
// get through thin ice. With a tool, harm intent breaks the whole tile; any
// other intent cuts an ice-fishing hole (ice_fishing.dm) as before. A crowbar
// cannot cut a fishing hole, so it breaks ice on any intent.
//
// Ice is thin while it is newly frozen over, while it is salted, and while
// the air over it is above freezing and it is rotting. Ice also forms and
// melts with the weather (ice_dynamics.dm). Small boats and rafts crunch through thin
// ice but stop at thick ice; a built ship stops at any ice unless belt armour
// (hull_armour.dm) stands at her bow, which breaks thin ice ahead of her.
//
// Nothing ticks over the ice itself. A broken tile carries one hidden marker,
// and one shared pass looks at every marker every few minutes: after enough freezing weather the
// water skins over as thin ice, the thin ice thickens back to ordinary ice
// and the marker goes. Thin ice melts again if it warms up first. The marker
// keeps its progress in saved minutes, so a save does not reset it.

#define ICE_BREAK_CHECK (5 MINUTES)
#define ICE_BREAK_CHECK_MINUTES 5
#define ICE_SKIN_MINUTES 30  // freezing minutes for open water to skin over
#define ICE_THICKEN_MINUTES 60 // more freezing minutes for thin ice to bear like any other
#define ICE_HAND_TIME 150    // bare hands, thin ice only
#define ICE_THIN_FACTOR 0.5  // thin ice breaks in half the time

// Base ticks for an average worker to break a tile of thick ice with W, or 0
// when W cannot break ice.
/proc/ice_break_tool_delay(obj/item/W)
	if (!W)
		return 0
	if (is_tool(W, TOOL_PICKAXE))
		return 120
	if (is_tool(W, TOOL_HATCHET) || is_tool(W, TOOL_CROWBAR))
		return 150
	if (is_tool(W, TOOL_CHISEL))
		return 250
	return 0

// TRUE when the ice at T is thin: newly frozen, or rotting in a thaw.
/proc/ice_is_thin(turf/T)
	if (!istype(T, /turf/floor/beach/water/ice))
		return FALSE
	var/obj/structure/broken_ice/B = locate() in T
	if (B && (B.thin || B.salted()))
		return TRUE
	return get_temp(T) > ICE_MELT_TEMP

// The open water a tile of ice becomes: deep when deep water of its kind
// lies beside it, shallow otherwise.
/proc/ice_open_water_type(turf/floor/beach/water/ice/T)
	var/salty = istype(T, /turf/floor/beach/water/ice/salty)
	// Ice that froze over deep water remembers it (ice_dynamics.dm).
	if (istype(T, /turf/floor/beach/water/ice/salty/deep))
		return /turf/floor/beach/water/deep/saltwater
	if (istype(T, /turf/floor/beach/water/ice/deep))
		return /turf/floor/beach/water/deep
	for (var/dir in cardinal)
		var/turf/N = get_step(T, dir)
		if (!istype(N, /turf/floor/beach/water/deep) || istype(N, /turf/floor/beach/water/deep/saltwater/underwater))
			continue
		if (salty && istype(N, /turf/floor/beach/water/deep/saltwater))
			return /turf/floor/beach/water/deep/saltwater
		if (!salty && !istype(N, /turf/floor/beach/water/deep/saltwater) && !istype(N, /turf/floor/beach/water/deep/swamp) && !istype(N, /turf/floor/beach/water/deep/jungle))
			return /turf/floor/beach/water/deep
	return salty ? /turf/floor/beach/water/shallowsaltwater : /turf/floor/beach/water

// Why the ice at T cannot be broken by H now, or null.
/proc/ice_break_refusal(turf/floor/beach/water/ice/T, mob/living/human/H)
	if (!istype(T))
		return "That is not ice."
	if (T.iscovered())
		return "Something is built over the ice here."
	if (H && get_turf(H) == T)
		return "You are standing on it. Step off onto the shore or the next tile first."
	for (var/mob/living/L in T)
		if (L != H)
			return "[L] is standing on that ice."
	return null

// Turns the ice at T into open water and leaves the marker that freezes it
// again. Returns the new water turf, or null.
/proc/ice_break_turf(turf/floor/beach/water/ice/T)
	if (!istype(T, /turf/floor/beach/water/ice))
		return null
	var/salty = istype(T, /turf/floor/beach/water/ice/salty)
	var/water_type = ice_open_water_type(T)
	for (var/obj/structure/ice_hole/hole in T)
		qdel(hole)
	var/obj/structure/broken_ice/B = locate() in T
	var/turf/W = T.ChangeTurf(water_type)
	if (!W)
		return null
	if (!B || QDELETED(B))
		B = new /obj/structure/broken_ice(W)
	B.opened(salty, !ispath(water_type, /turf/floor/beach/water/deep))
	return W

// H breaks the ice at T with W (null for bare hands). Returns the water turf.
/proc/ice_break(turf/floor/beach/water/ice/T, obj/item/W, mob/living/human/H)
	if (!ishuman(H) || !istype(T))
		return null
	var/thin = ice_is_thin(T)
	var/base = W ? ice_break_tool_delay(W) : (thin ? ICE_HAND_TIME : 0)
	if (!base)
		to_chat(H, SPAN_WARNING("The ice is too thick to break with your bare hands. A pick, an axe or a crowbar will break it."))
		return null
	var/why = ice_break_refusal(T, H)
	if (why)
		to_chat(H, SPAN_WARNING(why))
		return null
	if (thin && W)
		base = round(base * ICE_THIN_FACTOR)
	var/delay = work_delay(H, base, WORK_MINE, W)
	if (W)
		H.visible_message(SPAN_NOTICE("[H] starts breaking up the ice with \the [W]."), SPAN_NOTICE("You start breaking up the [thin ? "thin " : ""]ice with \the [W]."))
		playsound(T, 'sound/effects/pickaxe.ogg', 60, TRUE)
	else
		H.visible_message(SPAN_NOTICE("[H] starts stamping and pounding at the thin ice."), SPAN_NOTICE("You start stamping and pounding at the thin ice."))
	if (!do_after(H, delay, T))
		return null
	if (W && (QDELETED(W) || W.loc != H))
		return null
	if (!istype(T, /turf/floor/beach/water/ice) || ice_break_refusal(T, H))
		return null
	if (!W && !ice_is_thin(T))
		return null
	var/turf/open = ice_break_turf(T)
	if (open)
		H.visible_message(SPAN_NOTICE("[H] breaks the ice into floating pieces, opening the water."), SPAN_NOTICE("The ice gives way and breaks up into the water. It will freeze over again in hard cold."))
	return open

// ---- The ice itself ----

/turf/floor/beach/water/ice/attack_hand(mob/living/human/H)
	if (ishuman(H) && H.a_intent == I_HARM && Adjacent(H))
		ice_break(src, null, H)
		return
	return ..()

/turf/floor/beach/water/ice/examine(mob/user)
	..()
	if (!ishuman(user) || get_dist(user, src) > 2)
		return
	if (ice_is_thin(src))
		var/obj/structure/broken_ice/B = locate() in src
		to_chat(user, SPAN_NOTICE(B && B.thin ? "The ice here is thin and newly frozen. A boat could push through it, and it will break under hands or a tool on harm intent." : "The ice here is soft and rotting in the thaw. A boat could push through it, and it will break under hands or a tool on harm intent."))
	else
		to_chat(user, SPAN_NOTICE("A pick, an axe or a crowbar on harm intent breaks this ice into open water. On any other intent a pick, axe or chisel cuts a fishing hole."))

// ---- The marker on a broken tile ----

/obj/structure/broken_ice
	name = "broken ice"
	desc = "Where the ice was broken."
	icon = null
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	mouse_opacity = 0
	var/salty = FALSE
	var/shallow = TRUE        // broken out as shallow water: refreezing keeps it shallow
	var/thin = FALSE          // TRUE once the water has skinned over as thin ice
	var/cold_minutes = 0      // freezing minutes counted towards the next stage
	var/salted_until = 0      // real minutes (trap_now_minutes) salt keeps the tile open, ice_dynamics.dm

/obj/structure/broken_ice/New()
	..()
	broken_ice_register(src)

/obj/structure/broken_ice/after_load()
	..()
	if (thin && istype(loc, /turf/floor/beach/water/ice))
		var/turf/T = loc
		T.name = "thin ice"
	broken_ice_register(src)

/obj/structure/broken_ice/Destroy()
	LAZYREMOVE(broken_ice_marks, src)
	return ..()

/obj/structure/broken_ice/ex_act(severity)
	return

// The tile was broken open (again): count from the start.
/obj/structure/broken_ice/proc/opened(was_salty, was_shallow)
	salty = was_salty
	shallow = was_shallow
	thin = FALSE
	cold_minutes = 0
	broken_ice_register(src)

// TRUE while salt on the tile still works.
/obj/structure/broken_ice/proc/salted(now = trap_now_minutes())
	return salted_until > now

// ---- One pass over every broken tile ----
// The markers wait in one register and one timer looks at them all, so the
// cost is one look per broken tile every few minutes and nothing for the
// world's other ice. The register is filled lazily (no global list at init).

var/global/list/broken_ice_marks
var/global/broken_ice_pass_due = FALSE

/proc/broken_ice_register(obj/structure/broken_ice/M)
	if (!M || QDELETED(M))
		return
	if (!broken_ice_marks || !(M in broken_ice_marks))
		LAZYADD(broken_ice_marks, M)
	if (!broken_ice_pass_due)
		broken_ice_pass_due = TRUE
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(broken_ice_pass)), ICE_BREAK_CHECK)

/proc/broken_ice_pass()
	broken_ice_pass_due = FALSE
	if (!broken_ice_marks)
		return
	for (var/obj/structure/broken_ice/M in broken_ice_marks.Copy())
		if (!QDELETED(M))
			M.freeze_check()
		CHECK_TICK
	if (broken_ice_marks && broken_ice_marks.len && !broken_ice_pass_due)
		broken_ice_pass_due = TRUE
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(broken_ice_pass)), ICE_BREAK_CHECK)

// The air over the tile.
/obj/structure/broken_ice/proc/air_temp()
	return ice_dynamics_on() ? ice_area_temp(loc) : get_temp(loc)

// Nothing in the water that freezing would trap.
/obj/structure/broken_ice/proc/water_clear()
	var/turf/T = loc
	if (!istype(T) || T.iscovered())
		return FALSE
	for (var/atom/movable/M in T)
		if (M == src)
			continue
		if (ismob(M) || istype(M, /obj/structure/vehicle) || istype(M, /obj/structure/vehicleparts))
			return FALSE
	return TRUE

// One look at the tile: freeze, thicken, melt or wait. Salt keeps ice
// rotting and water open while the air is above ICE_SALT_LIMIT.
/obj/structure/broken_ice/proc/freeze_check()
	if (QDELETED(src))
		return FALSE
	var/turf/T = loc
	if (!isturf(T))
		qdel(src)
		return TRUE
	var/iced = istype(T, /turf/floor/beach/water/ice)
	var/salt = salted()
	var/temp = air_temp()
	if (iced)
		if (salt && temp > ICE_SALT_LIMIT)
			thaw("The salted ice softens and breaks up into slush and open water.")
			return TRUE
		// Only salt kept a marker on thick ice, and it has worn off; or
		// something else froze open water: nothing left to track.
		if (!thin)
			qdel(src)
			return TRUE
		if (temp > ICE_MELT_TEMP)
			thaw()
			return TRUE
		if (temp <= ICE_FREEZE_TEMP)
			cold_minutes += ICE_BREAK_CHECK_MINUTES
		if (cold_minutes >= ICE_THICKEN_MINUTES)
			T.name = initial(T.name)
			qdel(src)
		return TRUE
	if (!is_liquid_water(T))
		qdel(src)
		return TRUE
	if (thin)
		thin = FALSE // something else melted it
		cold_minutes = 0
	if (temp > ICE_FREEZE_TEMP || (salt && temp > ICE_SALT_LIMIT))
		cold_minutes = 0
		// In a thaw where the weather moves the ice (ice_dynamics.dm), the
		// open water is the front's again and freezes from its edges.
		if (!salt && temp > ICE_MELT_TEMP && ice_dynamics_on())
			qdel(src)
		return TRUE
	cold_minutes += ICE_BREAK_CHECK_MINUTES
	if (cold_minutes >= ICE_SKIN_MINUTES && water_clear())
		freeze_over()
	return TRUE

// The open water skins over as thin ice.
/obj/structure/broken_ice/proc/freeze_over()
	var/turf/T = loc
	var/turf/I = T.ChangeTurf(ice_type_for(salty, shallow))
	if (!I)
		return FALSE
	thin = TRUE
	cold_minutes = 0
	I.name = "thin ice"
	I.visible_message(SPAN_NOTICE("The open water skins over with thin ice."))
	return TRUE

// The ice melts back to open water: thin ice in a thaw, or salted ice.
/obj/structure/broken_ice/proc/thaw(message = "The thin ice melts back into open water.")
	var/turf/floor/beach/water/ice/T = loc
	if (!istype(T))
		return FALSE
	var/water_type
	if (shallow)
		water_type = salty ? /turf/floor/beach/water/shallowsaltwater : /turf/floor/beach/water
	else
		water_type = salty ? /turf/floor/beach/water/deep/saltwater : /turf/floor/beach/water/deep
	for (var/obj/structure/ice_hole/hole in T)
		qdel(hole)
	var/turf/W = T.ChangeTurf(water_type)
	if (!W)
		return FALSE
	thin = FALSE
	cold_minutes = 0
	W.visible_message(SPAN_NOTICE(message))
	return TRUE

// ---- Boats ----

/obj/structure/vehicle
	var/tmp/turf/ice_told = null // the ice her driver was last told blocks her

// The tile her driver is heading onto, for the ice check.
/obj/structure/vehicle/proc/small_craft_ahead()
	if (!driver || !isturf(loc))
		return null
	return get_step(src, driver.dir)

// TRUE when this small craft may go onto T as far as ice goes. Thin ice
// breaks under her bow; thick ice stops her.
/obj/structure/vehicle/proc/small_craft_ice_ok(turf/T)
	if (!istype(T, /turf/floor/beach/water/ice))
		if (is_liquid_water(T))
			ice_keep_open(T) // a used channel stays open (ice_dynamics.dm)
		return TRUE
	if (ice_is_thin(T) && !ice_break_refusal(T, null))
		ice_break_turf(T)
		visible_message(SPAN_NOTICE("\The [src] crunches through the thin ice."))
		return TRUE
	if (driver && ice_told != T)
		ice_told = T
		to_chat(driver, SPAN_WARNING("Thick ice blocks the way. Break a channel with a pick, an axe or a crowbar on harm intent."))
	return FALSE

// A built ship: no ice, except thin ice ahead of belt armour at her bow.
/datum/craft_body/built/proc/ice_refusal(turf/D, list/mine_set)
	if (!istype(D, /turf/floor/beach/water/ice))
		return null
	if (ice_is_thin(D))
		for (var/dir in cardinal)
			var/turf/S = get_step(D, dir)
			if (S && mine_set[S] && hull_armour_at(S))
				return null
		return "thin ice ahead at [D.x],[D.y]: belt armour at her bow would break it"
	return "ice ahead at [D.x],[D.y]: break a channel with picks or axes"

// Airships pass over ice.
/datum/craft_body/built/air/ice_refusal(turf/D, list/mine_set)
	return null

// Breaks the thin ice a planned move has cleared her to enter.
/datum/craft_body/built/proc/break_ice_ahead(list/dest, list/old)
	var/list/old_set = list()
	for (var/turf/S in old)
		old_set[S] = TRUE
	for (var/turf/D in dest)
		if (!old_set[D] && istype(D, /turf/floor/beach/water/ice))
			ice_break_turf(D)
		ice_keep_open(D) // her own water stays open while she uses it (ice_dynamics.dm)

#undef ICE_BREAK_CHECK
#undef ICE_BREAK_CHECK_MINUTES
#undef ICE_SKIN_MINUTES
#undef ICE_THICKEN_MINUTES
#undef ICE_HAND_TIME
#undef ICE_THIN_FACTOR
