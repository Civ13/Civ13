// Wrought-iron floors: a riveted plate floor and an open grating.
// Both are ordinary floor covers laid from iron through normal floor placement.

/obj/covers/iron_plate
	name = "iron plate floor"
	desc = "Riveted wrought-iron plates. It will not burn and takes a great deal of punishment."
	icon = 'icons/turf/flooring/iron.dmi'
	icon_state = "iron_plate"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 3
	health = 160
	maxhealth = 160
	hardness = 80
	material = "Iron"
	buildstack = /obj/item/stack/material/iron

/obj/covers/iron_grating
	name = "iron grating"
	desc = "Flat iron bars over a shallow drain. Blood and spills run through it when it is walked on."
	icon = 'icons/turf/flooring/iron.dmi'
	icon_state = "iron_grating"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 3
	health = 120
	maxhealth = 120
	hardness = 70
	material = "Iron"
	buildstack = /obj/item/stack/material/iron

// Loose muck does not stay on open bars: a footstep knocks it through.
/obj/covers/iron_grating/Crossed(atom/movable/AM)
	if (isliving(AM))
		drain_muck()
	return ..()

/obj/covers/iron_grating/proc/drains(obj/effect/decal/cleanable/C)
	// Solid remains and things stuck to the bars stay where they are.
	if (istype(C, /obj/effect/decal/cleanable/blood/gibs) || istype(C, /obj/effect/decal/cleanable/blood/writing))
		return FALSE
	if (istype(C, /obj/effect/decal/cleanable/cobweb) || istype(C, /obj/effect/decal/cleanable/molten_item))
		return FALSE
	return TRUE

/obj/covers/iron_grating/proc/drain_muck()
	for (var/obj/effect/decal/cleanable/C in loc)
		if (drains(C))
			qdel(C)
