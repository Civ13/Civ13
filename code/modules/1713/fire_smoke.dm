// Spreading fire smoke and fire compartments (Val, 2026-11-16).
//
// A burning tile puts out smoke. Smoke has a thickness from 1 to 5 and spreads
// to the neighbouring tiles every two seconds, thinning one step each tile it
// travels, so a fire fills the room it is in. Walls and shut windows stop it.
// An ordinary shut door lets a thin wisp seep round it when the smoke against
// it is thick; a
// shut, rated fire door (fire_doors.dm) keeps it out entirely, so a building
// split by fire doors into compartments keeps the smoke where the fire is.
// Open doors, empty frames and open casements let it through. Under the open
// sky it clears quickly; indoors it lingers until the fire is out.
//
// Thick smoke blinds (it blocks sight at 4 and up) and chokes: anyone breathing
// it coughs, and from thickness 3 loses breath, unless they wear a gas mask.

#define FIRE_SMOKE_MAX 5
#define FIRE_SMOKE_OPAQUE 4

/obj/effect/fire_smoke
	name = "smoke"
	desc = "Thick, choking smoke from a fire."
	icon = 'icons/effects/effects.dmi'
	icon_state = "smoke"
	anchored = TRUE
	mouse_opacity = FALSE
	layer = 6
	should_save = FALSE
	var/thickness = 0
	var/settle = 0			// ticks indoors before it thins one step

/obj/effect/fire_smoke/New(_loc, amount = 1)
	..(_loc)
	set_thickness(amount)
	processing_objects |= src

/obj/effect/fire_smoke/Destroy()
	processing_objects -= src
	return ..()

/obj/effect/fire_smoke/proc/set_thickness(amount)
	thickness = clamp(round(amount), 0, FIRE_SMOKE_MAX)
	if (thickness <= 0)
		qdel(src)
		return
	alpha = 50 + thickness * 40
	var/opaque = thickness >= FIRE_SMOKE_OPAQUE
	if (opacity != opaque)
		opacity = opaque

// Thicken the smoke on a tile, making it there if needed.
/proc/add_fire_smoke(turf/T, amount = 1)
	if (!T || T.density || amount <= 0)
		return null
	var/obj/effect/fire_smoke/S = locate() in T
	if (S)
		S.set_thickness(S.thickness + amount)
		return QDELETED(S) ? null : S
	return new /obj/effect/fire_smoke(T, amount)

/proc/fire_smoke_at(turf/T)
	var/obj/effect/fire_smoke/S = T ? locate(/obj/effect/fire_smoke) in T : null
	return S ? S.thickness : 0

// How smoke may pass from one tile to the next: 2 freely, 1 leaking (an
// ordinary shut door), 0 not at all (walls, shut windows, rated fire doors).
/proc/fire_smoke_passage(turf/from, turf/T)
	if (!T || T.density)
		return 0
	. = 2
	for (var/turf/side in list(from, T))
		for (var/obj/O in side)
			if (istype(O, /obj/structure/simple_door))
				var/obj/structure/simple_door/D = O
				if (!D.density)
					continue
				if (D.fire_door_rated())
					return 0
				if (D.judas_open)
					continue
				. = min(., 1)
			else if (side == T && O.density && istype(O, /obj/structure/window))
				return 0
			else if (side == T && istype(O, /obj/covers))
				var/obj/covers/C = O
				if (C.wall && C.density)
					return 0

/obj/effect/fire_smoke/process()
	var/turf/here = loc
	if (!isturf(here))
		qdel(src)
		return PROCESS_KILL
	// Spread: each neighbour is brought up to one step thinner than here.
	if (thickness >= 2)
		for (var/direction in cardinal)
			var/turf/T = get_step(here, direction)
			var/passage = fire_smoke_passage(here, T)
			if (!passage)
				continue
			if (passage == 1)
				// A shut door: thick smoke seeps round its edges to the far side.
				if (thickness < FIRE_SMOKE_OPAQUE || !prob(30))
					continue
				var/turf/beyond = (locate(/obj/structure/simple_door) in T) ? get_step(T, direction) : T
				if (beyond && !beyond.density && !fire_smoke_at(beyond))
					add_fire_smoke(beyond, 1)
				continue
			if (fire_smoke_at(T) < thickness - 1)
				add_fire_smoke(T, 1)
	// Thin smoke cannot affect breathing; retain per-human checks once started.
	if (!(thickness < 2))
		for (var/mob/living/human/H in here)
			fire_smoke_breathe(H, thickness)
	// Clearing: fast in the open, slowly indoors once nothing feeds it.
	if (!door_turf_indoors(here))
		set_thickness(thickness - 2)
	else if (!(locate(/obj/effect/fire) in here))
		settle++
		if (settle >= 5)
			settle = 0
			set_thickness(thickness - 1)
	if (QDELETED(src))
		return PROCESS_KILL

/proc/fire_smoke_breathe(mob/living/human/H, thickness)
	if (!H || H.stat == DEAD || thickness < 2)
		return
	if (H.wear_mask && istype(H.wear_mask, /obj/item/clothing/mask/gas))
		return
	if (thickness >= 3)
		H.adjustOxyLoss(thickness - 2)
	if (prob(10 * thickness))
		H.emote("cough")

#undef FIRE_SMOKE_MAX
#undef FIRE_SMOKE_OPAQUE
