// Solid pillars, bollards and barriers against vehicles.
//
// Roof supports and stone pillars block people, animals and vehicles. Shots
// often get past a pillar, since it is narrow, and flying drones go over.
// Bollards stop vehicles but let people and animals walk between them.
// Barriers (sandbags, jersey barriers, palisades, railings) and bollards are
// building parts for structure_impact(), so a vehicle that hits one spends its
// force there before it reaches the wall behind.

// Chance in 100 that a shot through a pillar's tile is stopped by the pillar.
#define PILLAR_SHOT_BLOCK 30

/proc/pillar_can_pass(obj/structure/S, atom/movable/mover, turf/target)
	if (!S.density)
		return TRUE
	if (istype(mover, /obj/structure/drone))
		var/obj/structure/drone/D = mover
		if (D.flying)
			return TRUE
	if (istype(mover, /obj/effect))
		return TRUE
	if (istype(mover, /obj/item/projectile))
		return !prob(PILLAR_SHOT_BLOCK)
	return FALSE

/obj/structure/roof_support/CanPass(atom/movable/mover, turf/target, height = 0, air_group = 0)
	return pillar_can_pass(src, mover, target)

/obj/structure/mine_support/stone/CanPass(atom/movable/mover, turf/target, height = 0, air_group = 0)
	return pillar_can_pass(src, mover, target)

#undef PILLAR_SHOT_BLOCK

// ---- bollards ---------------------------------------------------------------

/obj/structure/bollard
	name = "wooden bollard"
	desc = "A stout post set in the ground. People walk past it, but it stops carts, cars and trucks."
	icon = 'icons/obj/bollards.dmi'
	icon_state = "bollard_wood"
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	flammable = TRUE
	not_movable = TRUE
	not_disassemblable = FALSE
	health = 150
	maxhealth = 150
	var/material_name = "wood"

/obj/structure/bollard/stone
	name = "stone bollard"
	desc = "A dressed stone post set in the ground. People walk past it, but it stops carts, cars and trucks."
	icon_state = "bollard_stone"
	flammable = FALSE
	health = 400
	maxhealth = 400
	material_name = "stone"

/obj/structure/bollard/iron
	name = "iron bollard"
	desc = "A cast iron post set in the ground. People walk past it, but it stops cars and trucks."
	icon_state = "bollard_iron"
	flammable = FALSE
	health = 500
	maxhealth = 500
	material_name = "iron"

/obj/structure/bollard/concrete
	name = "concrete bollard"
	desc = "A concrete post set in the ground. People walk past it, but it stops cars, trucks and most tanks."
	icon_state = "bollard_concrete"
	flammable = FALSE
	health = 600
	maxhealth = 600
	material_name = "concrete"

// People, animals and anything carried or thrown pass between bollards.
/obj/structure/bollard/CanPass(atom/movable/mover, turf/target, height = 0, air_group = 0)
	if (ismob(mover) || isitem(mover) || istype(mover, /obj/effect))
		return TRUE
	return !density

/obj/structure/bollard/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon))
		weapon_structure_damage(W, user, 1, 0.2, material_name == "wood" ? 'sound/effects/wood_cutting.ogg' : 'sound/weapons/smash.ogg')
		return
	return ..()

/obj/structure/bollard/examine(mob/user)
	..()
	if (health < maxhealth)
		to_chat(user, SPAN_WARNING("It is [health < maxhealth / 2 ? "badly " : ""]battered."))

// ---- barriers and bollards take impacts -----------------------------------

/obj/structure/bollard/structure_impact_material()
	return material_name

/obj/structure/bollard/impact_structure_damage(amount)
	return impact_smash(amount)

/obj/structure/window/barrier/structure_impact_material()
	return "dirt"

/obj/structure/window/barrier/sandbag/structure_impact_material()
	return "sandbag"

/obj/structure/window/barrier/concrete/structure_impact_material()
	return "concrete"

/obj/structure/window/barrier/jersey/structure_impact_material()
	return "concrete"

/obj/structure/window/barrier/rock/structure_impact_material()
	return "stone"

/obj/structure/window/barrier/sandstone/structure_impact_material()
	return "stone"

/obj/structure/window/barrier/railing/stone/structure_impact_material()
	return "stone"

/obj/structure/window/barrier/railing/brick/structure_impact_material()
	return "brick"

/obj/structure/window/barrier/palisade/structure_impact_material()
	return "wood"

/obj/structure/window/barrier/snowwall/structure_impact_material()
	return "snow"

/obj/structure/window/barrier/impact_structure_damage(amount)
	return impact_smash(amount)

// ---- taking pillars down ----------------------------------------------------
//
// Any roof support, mine support or stone pillar comes down with a hammer (not
// on harm intent, which strikes it instead) and gives back what it cost, but
// not while a roof near it, or a storey above it, stands on it alone: put up
// another support or a wall first. Concrete pillars give nothing back.

#define PILLAR_DISMANTLE_WOOD 40
#define PILLAR_DISMANTLE_STONE 80

/proc/pillar_dismantle_tool(obj/structure/S, obj/item/W, mob/user)
	if (!is_tool(W, TOOL_HAMMER) || !user || user.a_intent == I_HARM)
		return FALSE
	if (istype(S, /obj/structure/roof_support/admin))
		return FALSE
	return istype(S, /obj/structure/roof_support) || istype(S, /obj/structure/mine_support)

// What a dismantled pillar gives back: list(stack type, amount), or null.
/proc/pillar_refund(obj/structure/S)
	if (istype(S, /obj/structure/mine_support/stone/concrete))
		return null
	if (istype(S, /obj/structure/roof_support/bamboo))
		return list(/obj/item/stack/material/bamboo, 2)
	if (!istype(S, /obj/structure/mine_support/stone))
		return list(/obj/item/stack/material/wood, 2)
	var/path = "[S.type]"
	if (findtext(path, "obsidian"))
		return list(/obj/item/stack/material/obsidian, 2)
	if (findtext(path, "sandstone") || istype(S, /obj/structure/mine_support/stone/egyptian))
		return list(/obj/item/stack/material/sandstone, 2)
	if (findtext(path, "marble"))
		return list(/obj/item/stack/material/marble, 2)
	if (findtext(path, "/rock") || S.type == /obj/structure/mine_support/stone || S.type == /obj/structure/mine_support/stone/aztec)
		return list(/obj/item/stack/material/stone, 2)
	// The plain ionic and solomonic columns are marble.
	return list(/obj/item/stack/material/marble, 2)

// How many roofs, near S or on the storeys above it, stand only because of S
// (building_dismantle.dm).
/proc/pillar_roofs_held(obj/structure/S)
	return building_load_held(S)

/obj/structure/proc/pillar_dismantle(mob/user)
	if (!pillar_dismantle_check(user))
		return
	var/stone = istype(src, /obj/structure/mine_support/stone)
	playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
	user.visible_message(SPAN_NOTICE("[user] starts taking \the [src] down."), SPAN_NOTICE("You start taking \the [src] down."))
	if (!do_after(user, stone ? PILLAR_DISMANTLE_STONE : PILLAR_DISMANTLE_WOOD, src) || QDELETED(src) || !pillar_dismantle_check(user))
		return
	var/list/refund = pillar_refund(src)
	var/turf/T = get_turf(src)
	if (refund)
		var/stack_type = refund[1]
		new stack_type(T, refund[2])
		user.visible_message(SPAN_NOTICE("[user] takes \the [src] down."), SPAN_NOTICE("You take \the [src] down."))
	else
		user.visible_message(SPAN_NOTICE("[user] breaks \the [src] down."), SPAN_NOTICE("You break \the [src] down. Nothing of it is worth keeping."))
	qdel(src)

/obj/structure/proc/pillar_dismantle_check(mob/user)
	var/held = pillar_roofs_held(src)
	if (!held)
		return TRUE
	to_chat(user, SPAN_WARNING(building_load_refusal(src, held)))
	return FALSE

#undef PILLAR_DISMANTLE_WOOD
#undef PILLAR_DISMANTLE_STONE
