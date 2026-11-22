// Crop frost and frost covers (docs/crop-frost.md).
//
// Frost forms on the open ground on clear, calm nights (weather_frost_at in
// weather_fog.dm), and any night cold enough is a hard freeze. Tender crops
// out in it suffer:
// - a light frost nips back a growing crop by one stage, once a night;
// - a hard freeze (the air at -4 C or colder) kills a young crop and ruins a
//   ripe one.
// Winter-hardy crops, trees and mushrooms shrug it off, and so does anything
// under a roof or a greenhouse's glass.
//
// A farmer can cover a crop against it: straw mulch keeps off 2 degrees, a
// cloth row cover 3, a glass cloche 5. Use straw or hay, cloth or glass on the
// crop to cover it; an empty hand takes the cover off again and gives the
// material back. Art by Fable 5.2 (tests/sprites/create_frost_covers.py).

#define CROP_FROST_HARD -4 // C: a hard freeze
#define CROP_FROST_NIGHT 12000 // one nip a night at most (20 minutes)

/obj/structure/farming/plant
	var/frost_cover = "" // "", "mulch", "row_cover" or "cloche"
	var/tmp/frost_nipped_at = -CROP_FROST_NIGHT
	var/tmp/frost_cover_drawn = ""

// Degrees of frost each cover keeps off, what it takes and what it is called.
/proc/crop_frost_cover_warmth(cover)
	switch (cover)
		if ("mulch")
			return 2
		if ("row_cover")
			return 3
		if ("cloche")
			return 5
	return 0

/proc/crop_frost_cover_name(cover)
	switch (cover)
		if ("mulch")
			return "straw mulch"
		if ("row_cover")
			return "cloth row cover"
		if ("cloche")
			return "glass cloche"
	return ""

// list(cover, amount) for a stack that can cover a crop, or null.
/proc/crop_frost_cover_for(obj/item/I)
	if (istype(I, /obj/item/stack/material/straw) || istype(I, /obj/item/stack/hay))
		return list("mulch", 1)
	if (istype(I, /obj/item/stack/material/cloth))
		return list("row_cover", 2)
	if (istype(I, /obj/item/stack/material/glass) && !istype(I, /obj/item/stack/material/glass/reinforced))
		return list("cloche", 2)
	return null

// TRUE for a crop the frost can hurt.
/obj/structure/farming/plant/proc/frost_tender()
	if (vstatic || winter_hardy || stage > readyStageMax)
		return FALSE
	if (istype(src, /obj/structure/farming/plant/tree) || istype(src, /obj/structure/farming/plant/mushroom) || istype(src, /obj/structure/farming/plant/mushroompsy))
		return FALSE
	return TRUE

// "", "frost" or "freeze": what tonight's cold does to this crop under its cover.
/obj/structure/farming/plant/proc/frost_now()
	var/turf/T = get_turf(src)
	var/area/A = T ? T.loc : null
	if (!istype(A) || A.location != AREA_OUTSIDE || (locate(/obj/roof) in T))
		return ""
	var/temp = weather_precip_temp(T)
	if (isnull(temp))
		return ""
	temp += crop_frost_cover_warmth(frost_cover)
	if (temp <= CROP_FROST_HARD)
		return "freeze"
	if (weather_frost_at(T) && temp <= 1)
		return "frost"
	return ""

// Each growth tick (water_proc in farming.dm). TRUE when the cold killed it.
/obj/structure/farming/plant/proc/frost_plant_step()
	update_frost_cover()
	if (!frost_tender())
		return FALSE
	var/cold = frost_now()
	if (!cold)
		return FALSE
	if (cold == "freeze")
		set_dead("frozen")
		update_frost_cover()
		return TRUE
	if (world.time < frost_nipped_at + CROP_FROST_NIGHT)
		return FALSE
	frost_nipped_at = world.time
	if (stage > 1 && stage < readyStageMin)
		stage--
	return FALSE

// Draw the cover: mulch under the crop, row cover and cloche over it.
/obj/structure/farming/plant/proc/update_frost_cover()
	if (frost_cover_drawn == frost_cover)
		return
	if (frost_cover_drawn)
		underlays -= image('icons/obj/frost_covers.dmi', "mulch")
		overlays -= image('icons/obj/frost_covers.dmi', frost_cover_drawn)
	frost_cover_drawn = frost_cover
	if (frost_cover == "mulch")
		underlays += image('icons/obj/frost_covers.dmi', "mulch")
	else if (frost_cover)
		overlays += image('icons/obj/frost_covers.dmi', frost_cover)

/obj/structure/farming/plant/after_load()
	..()
	frost_cover_drawn = ""
	underlays -= image('icons/obj/frost_covers.dmi', "mulch")
	overlays -= image('icons/obj/frost_covers.dmi', "row_cover")
	overlays -= image('icons/obj/frost_covers.dmi', "cloche")
	update_frost_cover()

// Cover a crop. TRUE when it was handled.
/obj/structure/farming/plant/proc/apply_frost_cover(obj/item/stack/S, mob/user)
	var/list/cover = crop_frost_cover_for(S)
	if (!cover || vstatic || istype(src, /obj/structure/farming/plant/tree))
		return FALSE
	if (frost_cover)
		to_chat(user, SPAN_WARNING("\The [src] already has [crop_frost_cover_name(frost_cover)] over it. Take it off with an empty hand first."))
		return TRUE
	if (!S.can_use(cover[2]))
		to_chat(user, SPAN_WARNING("You need [cover[2]] of \the [S] to cover \the [src]."))
		return TRUE
	S.use(cover[2])
	frost_cover = cover[1]
	update_frost_cover()
	to_chat(user, SPAN_NOTICE("You put [crop_frost_cover_name(frost_cover)] over \the [src]. It keeps off about [crop_frost_cover_warmth(frost_cover)] degrees of frost."))
	return TRUE

// Take the cover off and give back what it was made of.
/obj/structure/farming/plant/proc/remove_frost_cover(mob/user)
	if (!frost_cover)
		return FALSE
	var/turf/T = get_turf(src)
	switch (frost_cover)
		if ("mulch")
			new /obj/item/stack/material/straw(T, 1)
		if ("row_cover")
			new /obj/item/stack/material/cloth(T, 2)
		if ("cloche")
			new /obj/item/stack/material/glass(T, 2)
	if (user)
		to_chat(user, SPAN_NOTICE("You take the [crop_frost_cover_name(frost_cover)] off \the [src]."))
	frost_cover = ""
	update_frost_cover()
	return TRUE

/obj/structure/farming/plant/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack) && crop_frost_cover_for(W) && apply_frost_cover(W, user))
		return TRUE
	return ..()

/obj/structure/farming/plant/attack_hand(mob/user)
	if (frost_cover && user && !user.get_active_hand() && remove_frost_cover(user))
		return
	return ..()

// The cover comes off with the crop: harvested or uprooted, its material
// stays. Not while the world is loading or shutting down.
/obj/structure/farming/plant/Destroy()
	if (frost_cover && isturf(loc) && ticker && ticker.current_state == GAME_STATE_PLAYING)
		remove_frost_cover()
	return ..()

/obj/structure/farming/plant/farming_diagnostics(farming_skill)
	. = ..()
	if (frost_cover)
		. += "[crop_frost_cover_name(frost_cover)] covers \the [src], keeping off about [crop_frost_cover_warmth(frost_cover)] degrees of frost."
	if (frost_tender() && world.time < frost_nipped_at + CROP_FROST_NIGHT)
		. += SPAN_WARNING("Frost has nipped \the [src] back.")
	else if (frost_tender() && farming_skill >= 1.1 && !frost_cover && (season == SEASON_WINTER || season == SEASON_FALL || season == SEASON_SPRING))
		. += "Frost can nip a tender crop back on a clear, still night. Straw, cloth or glass over it keeps it off."

#undef CROP_FROST_HARD
#undef CROP_FROST_NIGHT
