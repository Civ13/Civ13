// Earthworking tools between the shovel and the steam shovel (Val, 2026-11-19).
//
// Mattock: a pick-mattock (adze blade and pick on a long haft) from Bronze
// Working. Counts as a shovel for every digging job and breaks ground faster
// than a shovel of the same metal, but it is a poor tool for scooping loose
// earth, so piles, backfill and road filling go at half speed.
//
// Wheelbarrow: a wooden barrow from Iron Tools that carries up to six loads
// of dirt or sand. Earth you dig while one is beside you (or in tow) goes
// straight into it, and building ground up takes a load from it, so a digger
// no longer walks one pile at a time.

// ---- mattock --------------------------------------------------------------

/obj/item/weapon/material/shovel/mattock
	name = "mattock"
	desc = "A pick-mattock: a broad adze blade on one side and a pick on the other, on a long wooden haft. It breaks hard ground and roots fast, but is clumsy for shovelling loose earth."
	icon = 'icons/obj/earthworking_tools.dmi'
	icon_state = "mattock"
	item_state = "mattock"
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_earthworking.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_earthworking.dmi',
		)
	slot_flags = SLOT_BACK
	force = 14
	throwforce = 6
	usespeed = 2
	shifting_mult = 0.5
	default_material = "iron"
	health = 35
	maxhealth = 35

// The mattock's own family speeds (usespeed; higher is faster). Iron matches
// the plain family default so tool_speeds.dm's interpolation keeps its anchors.
/obj/item/weapon/material/shovel/mattock/apply_tool_material_speed()
	if (!material)
		return
	var/speed = tool_material_speed(/obj/item/weapon/material/shovel/mattock, material.name)
	if (speed)
		usespeed = speed

// ---- wheelbarrow ----------------------------------------------------------

#define WHEELBARROW_LOADS 6

/obj/structure/wheelbarrow
	name = "wheelbarrow"
	desc = "A wooden barrow on one wheel, for moving dirt and sand. Earth you dig beside it goes straight in; click it with an empty hand to tip a load out."
	icon = 'icons/obj/earthworking_tools.dmi'
	icon_state = "wheelbarrow"
	density = TRUE
	anchored = FALSE
	opacity = FALSE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/dirt_loads = 0
	var/sand_loads = 0

/obj/structure/wheelbarrow/after_load()
	..()
	update_icon()

/obj/structure/wheelbarrow/proc/loads()
	return dirt_loads + sand_loads

/obj/structure/wheelbarrow/proc/has_room()
	return loads() < WHEELBARROW_LOADS

/obj/structure/wheelbarrow/update_icon()
	overlays.Cut()
	var/kind = dirt_loads >= sand_loads ? "dirt" : "sand"
	if (loads() > 0)
		overlays += image(icon, "wheelbarrow_[kind][loads() > WHEELBARROW_LOADS / 2 ? "_full" : ""]", dir = dir)

/obj/structure/wheelbarrow/set_dir(ndir)
	. = ..()
	update_icon()

/obj/structure/wheelbarrow/examine(mob/user)
	..()
	if (!loads())
		to_chat(user, "It is empty.")
	else
		var/list/parts = list()
		if (dirt_loads)
			parts += "[dirt_loads] load\s of dirt"
		if (sand_loads)
			parts += "[sand_loads] load\s of sand"
		to_chat(user, "It holds [english_list(parts)] (room for [WHEELBARROW_LOADS]).")

// Takes in one load of this kind ("dirt" or "sand"). FALSE when full.
/obj/structure/wheelbarrow/proc/take_load(kind)
	if (!has_room())
		return FALSE
	if (kind == "sand")
		sand_loads++
	else
		dirt_loads++
	update_icon()
	return TRUE

// Gives up one load of this kind; FALSE when it holds none.
/obj/structure/wheelbarrow/proc/give_load(kind)
	if (kind == "sand")
		if (sand_loads <= 0)
			return FALSE
		sand_loads--
	else
		if (dirt_loads <= 0)
			return FALSE
		dirt_loads--
	update_icon()
	return TRUE

/obj/structure/wheelbarrow/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/barrier))
		if (!has_room())
			to_chat(user, SPAN_WARNING("\The [src] is full."))
			return TRUE
		take_load("dirt")
		user.visible_message(SPAN_NOTICE("[user] tips the dirt into \the [src]."), SPAN_NOTICE("You tip the dirt into \the [src]."))
		qdel(W)
		return TRUE
	if (istype(W, /obj/item/stack/ore/glass))
		var/obj/item/stack/ore/glass/G = W
		if (!has_room())
			to_chat(user, SPAN_WARNING("\The [src] is full."))
			return TRUE
		take_load("sand")
		user.visible_message(SPAN_NOTICE("[user] tips some sand into \the [src]."), SPAN_NOTICE("You tip some sand into \the [src]."))
		G.use(1)
		return TRUE
	return ..()

// An empty hand tips one load out onto the barrow's own tile.
/obj/structure/wheelbarrow/attack_hand(mob/user)
	if (!loads() || !Adjacent(user) || user.a_intent == I_GRAB)
		return ..()
	var/kind = dirt_loads ? "dirt" : "sand"
	give_load(kind)
	earth_pile_drop(get_turf(src), kind)
	user.visible_message(SPAN_NOTICE("[user] tips a load of [kind] out of \the [src]."), SPAN_NOTICE("You tip a load of [kind] out of \the [src]."))
	return TRUE

// A wheelbarrow this worker is pulling, or one beside them, that has room
// for a load (want_room) or holds a load of kind (otherwise). The pulled one
// wins so the barrow you're steering fills first.
/proc/wheelbarrow_for(mob/user, kind, want_room = TRUE)
	if (!user)
		return null
	var/list/candidates = list()
	if (istype(user.pulling, /obj/structure/wheelbarrow))
		candidates += user.pulling
	for (var/obj/structure/wheelbarrow/B in range(1, user))
		candidates |= B
	for (var/obj/structure/wheelbarrow/B in candidates)
		if (QDELETED(B) || get_dist(B, user) > 1)
			continue
		if (want_room ? B.has_room() : (kind == "sand" ? B.sand_loads > 0 : B.dirt_loads > 0))
			return B
	return null

// A fresh pile of dug earth on T.
/proc/earth_pile_drop(turf/T, kind)
	if (kind == "sand")
		return new /obj/item/stack/ore/glass(T)
	return new /obj/item/weapon/barrier(T)

// Where newly dug earth goes: into a wheelbarrow at the worker's side when
// there is one with room, otherwise a pile on T. Returns the wheelbarrow or
// the new pile.
/proc/earth_pile_out(turf/T, mob/user, kind = "dirt")
	var/obj/structure/wheelbarrow/B = wheelbarrow_for(user, kind, TRUE)
	if (B && B.take_load(kind))
		to_chat(user, SPAN_NOTICE("The [kind] goes into \the [B]."))
		return B
	return earth_pile_drop(T, kind)

#undef WHEELBARROW_LOADS
