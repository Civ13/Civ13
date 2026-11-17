// Chimneys carry a hearth's heat upstairs. A stone chimney built on the floor
// straight above a fireplace, oven or brazier, or above another chimney, gives
// the room it stands in half the heat of the fire below it, a storey at a time
// (building_heat_power in building_insulation.dm), so the bedroom over the
// kitchen is the warm room in winter. Nothing is saved but the chimney; the
// heat is worked out when a room's warmth is asked for.
//
// Art: icons/obj/storey_fittings.dmi, drawn by Fable with
// tests/sprites/create_storey_fittings.py.

#define CHIMNEY_CARRY 0.5          // share of the heat below that reaches each storey
#define CHIMNEY_MAX_STOREYS 6
#define CHIMNEY_SMOKE_CHECK 10     // seconds between looks at the fire below

/obj/structure/chimney
	name = "chimney"
	desc = "A stone flue rising through the floor. Built over a hearth, it carries the fire's warmth up into the rooms above."
	icon = 'icons/obj/storey_fittings.dmi'
	icon_state = "chimney_top"
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	var/tmp/smoking = FALSE
	var/tmp/smoke_seconds = 0

/obj/structure/chimney/persistence_runtime_var(key)
	return key == "smoking" || key == "smoke_seconds" || ..()

/obj/structure/chimney/New()
	..()
	chimney_refresh_column()

/obj/structure/chimney/after_load()
	..()
	chimney_refresh_column()

/obj/structure/chimney/Destroy()
	processing_objects -= src
	var/turf/T = get_turf(src)
	. = ..()
	if (T)
		var/obj/structure/chimney/below = chimney_below_turf(T)
		if (below)
			below.chimney_refresh()

/proc/chimney_turf_above(turf/T)
	var/level = T ? multiz_level_above(T.z) : 0
	return level ? locate(T.x, T.y, level) : null

/proc/chimney_turf_below(turf/T)
	var/level = T ? multiz_level_below(T.z) : 0
	return level ? locate(T.x, T.y, level) : null

/proc/chimney_below_turf(turf/T)
	var/turf/B = chimney_turf_below(T)
	return B ? locate(/obj/structure/chimney) in B : null

// This chimney and the one beneath it look again at how they join.
/obj/structure/chimney/proc/chimney_refresh_column()
	chimney_refresh()
	var/obj/structure/chimney/below = chimney_below_turf(get_turf(src))
	if (below)
		below.chimney_refresh()

/obj/structure/chimney/proc/is_top()
	var/turf/up = chimney_turf_above(get_turf(src))
	return !up || !(locate(/obj/structure/chimney) in up)

/obj/structure/chimney/proc/chimney_refresh()
	if (is_top())
		processing_objects |= src
		smoking = chimney_heat() > 0
	else
		processing_objects -= src
		smoking = FALSE
	update_icon()

/obj/structure/chimney/update_icon()
	overlays.Cut()
	icon_state = is_top() ? "chimney_top" : "chimney"
	if (smoking)
		overlays += image(icon, "chimney_smoke")

// Heat the fire below sends up into this chimney's room.
/obj/structure/chimney/proc/chimney_heat(depth = 0)
	if (depth >= CHIMNEY_MAX_STOREYS)
		return 0
	var/turf/B = chimney_turf_below(get_turf(src))
	if (!B)
		return 0
	var/obj/structure/chimney/lower = locate(/obj/structure/chimney) in B
	if (lower)
		return lower.chimney_heat(depth + 1) * CHIMNEY_CARRY
	var/power = 0
	for (var/obj/structure/S in B)
		if (!istype(S, /obj/structure/chimney))
			power += building_heat_power(S)
	return power * CHIMNEY_CARRY

// The top of a stack smokes while a fire burns below; it looks every few seconds.
/obj/structure/chimney/process_interval(configured_seconds = 2)
	if (QDELETED(src) || !is_top())
		processing_objects -= src
		return PROCESS_KILL
	smoke_seconds += max(0, configured_seconds)
	if (smoke_seconds < CHIMNEY_SMOKE_CHECK)
		return
	smoke_seconds = 0
	var/now = chimney_heat() > 0
	if (now != smoking)
		smoking = now
		update_icon()

/obj/structure/chimney/examine(mob/user, distance = -1)
	..()
	if (get_dist(user, src) > 2)
		return
	var/heat = chimney_heat()
	if (heat > 0)
		to_chat(user, SPAN_NOTICE("It is warm to the touch: a fire burns below."))
	else if (!chimney_turf_below(get_turf(src)))
		to_chat(user, SPAN_NOTICE("There is nothing below it to draw from."))
	else
		to_chat(user, SPAN_NOTICE("It is cold. Build it straight over a hearth, or over another chimney."))

#undef CHIMNEY_CARRY
#undef CHIMNEY_MAX_STOREYS
#undef CHIMNEY_SMOKE_CHECK
