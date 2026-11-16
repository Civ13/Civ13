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
