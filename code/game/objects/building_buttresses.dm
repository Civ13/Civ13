// Buttresses, flying buttresses and corbels: architecture fixed to a wall.
//
// A brace's dir points from it to the wall it serves. A buttress stands
// against the wall; a flying buttress is a pier two tiles out whose arch
// reaches the wall; a corbel is a bracket under the wall's edge.
//
// - A buttress or flying buttress makes a masonry wall carry one storey more
//   (building_support_tier) and doubles its resistance to a blow that pushes
//   the wall towards the brace (structure_impact).
// - A flying buttress or a corbel lets the wall hold a slab one tile further
//   out (building_support_reach): a wider hall, a balcony, a jettied floor.
//
// Nothing is saved for this; it is read from what stands next to the wall.

/obj/structure/building_brace
	name = "buttress"
	desc = "A mass of masonry built against a wall to strengthen it."
	icon = 'icons/obj/buttresses.dmi'
	icon_state = "buttress"
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	flammable = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	health = 600
	maxhealth = 600
	// How far out from its wall the brace stands.
	var/brace_distance = 1
	// What it adds to the wall it serves.
	var/brace_tier = 1
	var/brace_reach = 0
	var/brace_resist = TRUE
	var/material_name = "stone"

/obj/structure/building_brace/flying
	name = "flying buttress"
	desc = "A tall pier with an arch to a wall two paces away. It carries the wall's outward thrust, so the wall stands taller and the hall inside can be wider."
	icon_state = "flying_buttress"
	health = 500
	maxhealth = 500
	brace_distance = 2
	brace_reach = 2

/obj/structure/building_brace/corbel
	name = "stone corbel"
	desc = "A carved bracket under the edge of a wall. It lets a floor above overhang the wall by one pace."
	icon_state = "corbel_stone"
	density = FALSE
	layer = 4.1
	health = 200
	maxhealth = 200
	brace_tier = 0
	brace_reach = 2
	brace_resist = FALSE

/obj/structure/building_brace/corbel/wood
	name = "wooden corbel"
	desc = "A timber bracket with a diagonal brace under the edge of a wall. It lets a floor above overhang the wall by one pace."
	icon_state = "corbel_wood"
	flammable = TRUE
	health = 120
	maxhealth = 120
	material_name = "wood"

/obj/structure/building_brace/structure_impact_material()
	return material_name

/obj/structure/building_brace/structure_impact_part()
	return !isnull(health)

/obj/structure/building_brace/impact_structure_damage(amount)
	return impact_smash(amount)

/obj/structure/building_brace/attackby(obj/item/W, mob/user)
	// Not on harm intent, a hammer takes a brace down (structures.dm) unless a
	// roof stands only because it braces its wall (building_dismantle.dm).
	if (is_tool(W, TOOL_HAMMER) && user && user.a_intent != I_HARM && !not_disassemblable)
		if (!brace_dismantle_check(user))
			return
		return ..()
	if (istype(W, /obj/item/weapon))
		weapon_structure_damage(W, user, 1, 0.2, material_name == "wood" ? 'sound/effects/wood_cutting.ogg' : 'sound/weapons/smash.ogg')
		return
	return ..()

// A brace turns to face a wall it can serve, preferring the way it was set.
/obj/structure/building_brace/set_dir(new_dir)
	return ..(brace_best_dir(new_dir))

/obj/structure/building_brace/proc/brace_best_dir(wanted)
	if (wanted && building_brace_wall(wanted))
		return wanted
	for (var/d in cardinal)
		if (building_brace_wall(d))
			return d
	return wanted

// The wall this brace would serve facing d, or null.
/obj/structure/building_brace/proc/building_brace_wall(d = dir)
	var/turf/T = get_turf(src)
	for (var/i in 1 to brace_distance)
		T = T ? get_step(T, d) : null
	if (!T)
		return null
	return building_brace_target(T, src)

/obj/structure/building_brace/proc/brace_works()
	return health > 0 && !QDELETED(src)

/obj/structure/building_brace/examine(mob/user)
	..()
	var/atom/W = building_brace_wall()
	if (!W)
		to_chat(user, SPAN_WARNING("It is not set against a wall it can brace."))
	else
		to_chat(user, SPAN_NOTICE("It braces \the [W]."))

// The wall on T a brace can serve, or null. Buttresses only help masonry.
/proc/building_brace_target(turf/T, obj/structure/building_brace/B)
	if (!T)
		return null
	if (istype(T, /turf/wall) && !istype(T, /turf/wall/rockwall))
		return T
	for (var/obj/covers/C in T)
		if (!C.wall || C.incomplete)
			continue
		if (!B.brace_tier && !B.brace_resist)
			return C
		if (building_masonry(C.material))
			return C
	return null

/proc/building_masonry(material)
	return lowertext("[material]") in list("stone", "brick", "concrete", "marble", "sandstone", "granite", "basalt")

// Braces serving wall W. d limits it to braces on that side of the wall.
/proc/building_braces(atom/W, d = 0)
	. = list()
	var/turf/home = get_turf(W)
	if (!home)
		return
	for (var/side in (d ? list(d) : cardinal))
		var/turf/T = home
		for (var/i in 1 to 2)
			T = get_step(T, side)
			if (!T)
				break
			for (var/obj/structure/building_brace/B in T)
				if (B.brace_distance == i && B.dir == turn(side, 180) && B.brace_works() && building_brace_target(home, B))
					. += B

/proc/building_brace_tier_bonus(atom/W)
	for (var/obj/structure/building_brace/B in building_braces(W))
		if (B.brace_tier)
			return B.brace_tier
	return 0

/proc/building_brace_reach(atom/W)
	var/best = 0
	for (var/obj/structure/building_brace/B in building_braces(W))
		best = max(best, B.brace_reach)
	return best

// A blow travelling dir pushes the wall towards that side: a brace there
// takes the thrust.
/proc/building_brace_resists(atom/W, dir)
	if (!dir)
		return FALSE
	for (var/obj/structure/building_brace/B in building_braces(W, dir))
		if (B.brace_resist)
			return TRUE
	return FALSE

// The roofs a brace helped hold check whether they still stand.
/obj/structure/building_brace/Destroy()
	var/atom/W = building_brace_wall()
	if (W)
		for (var/obj/roof/R in range(3, W))
			R.collapse_check()
		building_recheck_storeys_above(W)
	return ..()
