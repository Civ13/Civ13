// Railings players build along the edge of a floor: balconies, roof terraces,
// wall walks and the sides of a stairwell (docs/balcony-railings.md).
//
// - A railing stands on the floor tile and runs along the side its builder
//   faced, like a sandbag wall or a parapet. Two on one tile make a corner;
//   only one railing may run along each side of a tile.
// - Nobody walks over it; it can be climbed over like any railing. Thrown
//   things and shots pass over it. A stone, sandstone or brick balustrade
//   covers someone lying down behind it from some shots.
// - A hammer takes it apart for what it cost to build. It falls with its floor
//   (building_floor_lost) and is a building part for impacts.
//
// Red brick railings are laid from fired bricks (clay_items.dm); the others
// are crafting recipes on their material.

#define RAILING_BUILT_DISMANTLE_TIME 30
#define RAILING_BUILT_BRICK_TIME 25
#define RAILING_BALUSTRADE_COVER 30	// % of shots a masonry balustrade stops for someone lying behind it

/obj/structure/railing/built
	name = "wooden railing"
	desc = "A timber handrail on square balusters along the edge of a floor. It keeps people from walking off the edge."
	icon = 'icons/obj/railings_built.dmi'
	icon_state = "wood"
	health = 100
	maxhealth = 100
	// The icon state, and the material for impacts.
	var/railing_style = "wood"
	var/material_name = "wood"
	// Someone lying down behind it is covered from some shots coming in.
	var/masonry_cover = FALSE

/obj/structure/railing/built/stone
	name = "stone balustrade"
	desc = "A row of turned stone balusters under a stone coping along the edge of a floor."
	icon_state = "stone"
	railing_style = "stone"
	material_name = "stone"
	health = 300
	maxhealth = 300
	flammable = FALSE
	masonry_cover = TRUE

/obj/structure/railing/built/sandstone
	name = "sandstone balustrade"
	desc = "A row of turned sandstone balusters under a coping along the edge of a floor."
	icon_state = "sandstone"
	railing_style = "sandstone"
	material_name = "sandstone"
	health = 250
	maxhealth = 250
	flammable = FALSE
	masonry_cover = TRUE

/obj/structure/railing/built/brick
	name = "brick railing"
	desc = "A low brick wall with a stone coping along the edge of a floor."
	icon_state = "brick"
	railing_style = "brick"
	material_name = "brick"
	health = 300
	maxhealth = 300
	flammable = FALSE
	masonry_cover = TRUE

/obj/structure/railing/built/wrought_iron
	name = "wrought iron railing"
	desc = "Thin iron bars under a forged handrail along the edge of a floor."
	icon_state = "wrought_iron"
	railing_style = "wrought_iron"
	material_name = "iron"
	health = 250
	maxhealth = 250
	flammable = FALSE

/obj/structure/railing/built/steel_pipe
	name = "steel pipe railing"
	desc = "A galvanised steel pipe handrail with a middle rail, bolted along the edge of a floor."
	icon_state = "steel_pipe"
	railing_style = "steel_pipe"
	material_name = "steel"
	health = 350
	maxhealth = 350
	flammable = FALSE

/obj/structure/railing/built/glass
	name = "glass balustrade"
	desc = "Panes of thick glass between thin steel posts along the edge of a floor."
	icon_state = "glass"
	railing_style = "glass"
	material_name = "glass"
	health = 80
	maxhealth = 80
	flammable = FALSE

// Built railings are fixed to the floor when they are made.
/obj/structure/railing/built/New(loc, constructed = 0)
	..(loc, 0)
	anchored = TRUE
	update_icon()

// Each piece is drawn whole, with a post at each end, so neighbours join.
/obj/structure/railing/built/update_icon(UpdateNeighbors = TRUE)
	overlays.Cut()
	icon_state = railing_style

/obj/structure/railing/built/examine(mob/user)
	. = ..()
	to_chat(user, SPAN_NOTICE("It runs along the [dir2text(dir)] side of its tile. A hammer takes it apart."))

/obj/structure/railing/built/structure_impact_material()
	return material_name

/obj/structure/railing/built/structure_impact_part()
	return !isnull(health)

/obj/structure/railing/built/impact_structure_damage(amount)
	take_damage(amount)
	return QDELETED(src)

/obj/structure/railing/built/take_damage(amount)
	health -= amount
	if (health > 0)
		return
	visible_message(SPAN_WARNING("\The [src] breaks apart!"))
	playsound(loc, 'sound/effects/grillehit.ogg', 50, TRUE)
	qdel(src)

/obj/structure/railing/built/attackby(obj/item/W, mob/user)
	if (is_tool(W, TOOL_WRENCH))
		to_chat(user, SPAN_NOTICE("\The [src] is built into the floor. Take it apart with a hammer instead."))
		return
	if (is_tool(W, TOOL_HAMMER))
		user.visible_message(SPAN_NOTICE("[user] starts taking down \the [src]."), SPAN_NOTICE("You start taking down \the [src]."))
		playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
		if (!do_after(user, RAILING_BUILT_DISMANTLE_TIME, src) || QDELETED(src))
			return
		user.visible_message(SPAN_NOTICE("[user] takes down \the [src]."), SPAN_NOTICE("You take down \the [src]."))
		railing_dismantle_refund()
		qdel(src)
		return
	return ..()

// What taking it apart gives back: never more than it cost (dismantle_refund.dm).
/obj/structure/railing/built/proc/railing_dismantle_refund()
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return null
	var/turf/T = get_turf(src)
	if (!T)
		return null
	var/units = crafted_refund_units(type)
	var/refund = crafted_refund_stack(type, null)
	if (!ispath(refund, /obj/item/stack) || units <= 0)
		return null
	return new refund(T, units)

// Laid from one pile of fired bricks, not a recipe.
/obj/structure/railing/built/brick/railing_dismantle_refund()
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return null
	var/turf/T = get_turf(src)
	return T ? new /obj/item/weapon/clay/advclaybricks/fired(T) : null

// ---- building ----------------------------------------------------------------

// Why a railing of new_type can't be built along side `facing` of T, or null.
// facing is a direction, or the builder, whose facing is the side.
/proc/railing_build_refusal(turf/T, new_type, facing)
	if (!T || !ispath(new_type, /obj/structure/railing))
		return null
	var/direction = facing
	if (ismob(facing))
		var/mob/M = facing
		direction = M.dir
	if (!(direction in cardinal))
		return "Face the edge you want the railing along."
	for (var/obj/structure/railing/R in T)
		if (!QDELETED(R) && R.dir == direction)
			return "There is already \a [R] along that side."
	for (var/obj/structure/window/barrier/B in T)
		if (!QDELETED(B) && B.dir == direction && (B.flags & ON_BORDER))
			return "There is already \a [B] along that side."
	return null

// Lay a brick railing from fired bricks along the side user faces.
/obj/item/weapon/clay/advclaybricks/fired/proc/build_brick_railing(mob/user)
	var/turf/T = get_turf(user)
	var/direction = user.dir
	if (!tile_has_floor(T))
		to_chat(user, SPAN_WARNING("Stand on a floor to build a railing along its edge."))
		return FALSE
	var/refusal = railing_build_refusal(T, /obj/structure/railing/built/brick, direction)
	if (refusal)
		to_chat(user, SPAN_WARNING(refusal))
		return FALSE
	to_chat(user, SPAN_NOTICE("You start laying a brick railing along the [dir2text(direction)] edge..."))
	if (!do_after(user, RAILING_BUILT_BRICK_TIME, src) || get_turf(user) != T || !tile_has_floor(T) || railing_build_refusal(T, /obj/structure/railing/built/brick, direction))
		return FALSE
	var/obj/structure/railing/built/brick/R = new(T)
	R.set_dir(direction)
	R.add_fingerprint(user)
	loose_pile_use(1)
	to_chat(user, SPAN_NOTICE("You finish the brick railing."))
	return TRUE

// ---- shots -------------------------------------------------------------------

// Shots fly over a railing. Coming in across a masonry balustrade, some stop
// in it when the person behind it is lying down (castle_defences.dm asks).
/proc/railing_cover_verdict(obj/structure/railing/built/R, obj/item/projectile/P)
	if (!R.masonry_cover)
		return DIRECTIONAL_COVER_PASS
	var/travel = P.get_direction()
	var/turf/behind = get_turf(R)
	if (!(travel & turn(R.dir, 180)) || P.starting == behind)
		return DIRECTIONAL_COVER_PASS
	for (var/mob/living/L in behind)
		if (L.lying || L.prone)
			return prob(RAILING_BALUSTRADE_COVER) ? DIRECTIONAL_COVER_BLOCK : DIRECTIONAL_COVER_PASS
	return DIRECTIONAL_COVER_PASS

// ---- floors ------------------------------------------------------------------

// Fittings that go down with the floor they stand on (building_floor_lost).
/obj/structure/proc/falls_with_floor()
	return FALSE

/obj/structure/railing/built/falls_with_floor()
	return TRUE

#undef RAILING_BUILT_DISMANTLE_TIME
#undef RAILING_BUILT_BRICK_TIME
#undef RAILING_BALUSTRADE_COVER
