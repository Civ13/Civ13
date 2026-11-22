// ============================================================
// Belt armour (docs/craft-core.md "Belt armour")
// ------------------------------------------------------------
// Steel plates bolted along a ship's side at the waterline. A plate stands on
// a tile of her deck; a blast there reaches her floor one step lighter, so a
// shell that would blow out the plank or plate under it only damages it, and
// she is not holed. A direct hit spends the plate, which has to be replaced.
// The floor of her hold right under a plated tile is covered too: the belt
// runs down past the waterline.
//
// Plates are heavy: each counts a tile of weight on her deck (hull_load.dm),
// so a fully belted ship needs more push for the same speed (hull_weight.dm).
// The tiller counts how much of her side is belted.
// ============================================================

/obj/structure/hull_armour
	name = "belt armour plate"
	desc = "A thick steel plate made to be bolted along a ship's side at her waterline. A blast on its tile reaches her floor much weakened, so she is not holed; a direct hit spends the plate."
	icon = 'icons/obj/materials.dmi'
	icon_state = "sheet-plasteel"
	anchored = TRUE
	density = FALSE
	layer = TURF_LAYER + 0.4
	not_disassemblable = FALSE

/obj/structure/hull_armour/hull_load()
	return 1

// The plate takes its blast through the floor it covers (hull_armour_soften()).
/obj/structure/hull_armour/ex_act(severity)
	return

/obj/structure/hull_armour/attackby(obj/item/W, mob/user)
	if (is_tool(W, TOOL_WRENCH))
		to_chat(user, SPAN_NOTICE("You start unbolting \the [src]."))
		if (do_after(user, 5 SECONDS, src))
			new /obj/item/stack/material/steel(get_turf(src), 10)
			qdel(src)
		return
	return ..()

// The live plate covering T: on T itself, or on the deck right over a hold
// tile. Null when there is none.
/proc/hull_armour_at(turf/T)
	if (!T)
		return null
	for (var/obj/structure/hull_armour/A in T)
		if (!QDELETED(A))
			return A
	if (!istype(T, /turf/floor/plating/ship_hold))
		return null
	var/above = multiz_level_above(T.z)
	var/turf/U = above ? locate(T.x, T.y, above) : null
	if (!U)
		return null
	for (var/obj/structure/hull_armour/A in U)
		if (!QDELETED(A))
			return A
	return null

// The severity a floor takes from a blast: one step lighter under a plate.
// 4 or more is no blast at all.
/proc/hull_armour_soften(obj/covers/C, severity)
	if (!C || C.wall || !isnum(severity) || severity > 3)
		return severity
	var/turf/T = get_turf(C)
	var/obj/structure/hull_armour/A = T ? hull_armour_at(T) : null
	if (!A)
		return severity
	// A direct hit spends the plate that took it.
	if (severity <= 1)
		A.visible_message(SPAN_DANGER("\The [A] takes the blast and buckles away."))
		qdel(A)
	return severity + 1

// How many of her edge tiles carry a plate, and how many edge tiles she has.
/datum/craft/proc/armour_belt()
	var/list/mine = list()
	for (var/turf/T in (body ? body.cells() : list()))
		mine[T] = TRUE
	var/edges = 0
	var/plated = 0
	for (var/turf/T in mine)
		var/edge = FALSE
		for (var/d in cardinal)
			if (!mine[get_step(T, d)])
				edge = TRUE
				break
		if (!edge)
			continue
		edges++
		if (locate(/obj/structure/hull_armour) in T)
			plated++
	return list(plated, edges)

/datum/craft/proc/armour_text()
	var/list/belt = armour_belt()
	if (!belt[1])
		return ""
	return " Belt armour covers [belt[1]] of her [belt[2]] side tile\s."
