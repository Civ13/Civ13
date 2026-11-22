// What river floodwater does to people and fires (docs/river-flood.md,
// "Effects"). Everything here asks flood_depth_at() from code that already
// runs for that tile or person: a step, a life tick, a fire's own tick, a
// client's view moving. Nothing loops over the map.

// Depth bands (FLOOD_BAND_*) are in code/__defines/turfs.dm.
/proc/flood_band(depth)
	if (depth <= 0)
		return FLOOD_BAND_NONE
	if (depth < 0.25)
		return FLOOD_BAND_ANKLE
	if (depth < 0.5)
		return FLOOD_BAND_KNEE
	if (depth <= 1)
		return FLOOD_BAND_WAIST
	return FLOOD_BAND_DEEP

/proc/flood_band_name(band)
	switch (band)
		if (FLOOD_BAND_ANKLE)
			return "ankle-deep"
		if (FLOOD_BAND_KNEE)
			return "knee-deep"
		if (FLOOD_BAND_WAIST)
			return "waist-deep"
		if (FLOOD_BAND_DEEP)
			return "over your head"
	return ""

/proc/flood_band_at(turf/T)
	return flood_band(flood_depth_at(T))

// Step delay from standing water on a floor, before footwear: puddles from
// spilled containers, a flooded submarine deck, or river floodwater. The
// deepest wins; 2, 4 and 6 are the sub-deck wading rule.
/proc/standing_water_delay(turf/floor/F)
	. = 0
	for (var/obj/effect/flooding/FLD in F)
		switch (FLD.flood_level)
			if (1)
				. = max(., 2)
			if (2)
				. = max(., 4)
			if (3)
				. = max(., 6)
	if (istype(F, /turf/floor/sub_deck))
		var/turf/floor/sub_deck/SD = F
		if (SD.water_depth >= 150)
			. = max(., 6)
		else if (SD.water_depth >= 100)
			. = max(., 4)
		else if (SD.water_depth >= 50)
			. = max(., 2)
	switch (flood_band_at(F))
		if (FLOOD_BAND_ANKLE)
			. = max(., 2)
		if (FLOOD_BAND_KNEE)
			. = max(., 4)
		if (FLOOD_BAND_WAIST, FLOOD_BAND_DEEP)
			. = max(., 6)

// ---- fires ----------------------------------------------------
// A fire on flooded ground goes out, and none can be lit there.

/proc/flood_douses(atom/A)
	return flood_depth_at(get_turf(A)) > 0

// ---- crops ---------------------------------------------------
// A crop under knee-deep water or more drowns: after 6 growth minutes at the
// knee, 3 at the waist or deeper. Rice grows in standing water. A crop that
// comes through a flood alive leaves fresh silt in the soil.

#define FLOOD_SILT_NUTRITION 40

/obj/structure/farming/plant
	var/flood_tolerant = FALSE
	var/tmp/flooded_minutes = 0

/obj/structure/farming/plant/rice
	flood_tolerant = TRUE

/obj/structure/farming/plant/persistence_runtime_var(key)
	return key == "flooded_minutes" || ..()

// One growth minute. Returns TRUE while the plant stands in floodwater, which
// waters it fully.
/obj/structure/farming/plant/proc/flood_plant_step()
	var/turf/T = get_turf(src)
	var/band = flood_band_at(T)
	if (!band)
		if (flooded_minutes && stage <= readyStageMax)
			flooded_minutes = 0
			var/turf/floor/dirt/D = T
			if (istype(D))
				D.soil_nutrition = min(D.max_soil_nutrition, D.soil_nutrition + FLOOD_SILT_NUTRITION)
				plant_nutrition = D.soil_nutrition
		return FALSE
	water = max_water
	flooded_minutes++
	if (!flood_tolerant && band >= FLOOD_BAND_KNEE && flooded_minutes >= (band >= FLOOD_BAND_WAIST ? 3 : 6))
		set_dead("drowned")
	return TRUE

#undef FLOOD_SILT_NUTRITION

// ---- wells -----------------------------------------------------
// Floodwater over a well fouls it until it is scrubbed clean with soap.

/obj/structure/sink/well/proc/flood_foul()
	if (!dirty && flood_depth_at(get_turf(src)) > 0)
		dirty = TRUE
	return dirty

// ---- clothes -----------------------------------------------------
// Waist-deep floodwater soaks clothes like wading in a river.

/proc/flood_soaks(turf/T)
	return T && !T.iscovered() && flood_band_at(T) >= FLOOD_BAND_WAIST

// ---- flood marks -------------------------------------------------
// The last floods leave a line of dried silt on trees, walls and the ground.

/proc/flood_mark_text(turf/T)
	var/depth = flood_depth_at(T)
	if (depth > 0)
		return "It stands in [flood_band_name(flood_band(depth))] floodwater."
	var/mark = flood_mark_at(T)
	if (mark <= 0)
		return null
	switch (flood_band(mark))
		if (FLOOD_BAND_ANKLE)
			return "A thin line of dried silt shows a recent flood stood ankle-deep here."
		if (FLOOD_BAND_KNEE)
			return "A line of dried silt shows a recent flood stood knee-deep here."
		if (FLOOD_BAND_WAIST)
			return "A line of dried silt at waist height shows how high a recent flood rose here."
	return "Dried silt and wrack sit high above your head: a recent flood ran deep here."

/proc/flood_mark_examine(atom/A, mob/user)
	if (!user || get_dist(A, user) > 2)
		return
	var/text = flood_mark_text(get_turf(A))
	if (text)
		to_chat(user, SPAN_NOTICE(text))

// ---- things on the floor --------------------------------------------
// Floodwater ruins flour and gunpowder left on the floor (the flour sack falls
// apart, a gunpowder pouch is left empty), rots loose grain and seed and floats small light things toward deeper water. A table
// keeps things above anything shallower than the waist. It runs for the tiles
// a player can see (the drawing scan below), once per river tick per tile, so
// unwatched land costs nothing.

var/global/list/flood_items_done = list()
var/global/flood_items_revision = -1

/proc/flood_ruins(obj/item/I)
	return istype(I, /obj/item/weapon/reagent_containers/food/condiment/flour) || istype(I, /obj/item/weapon/reagent_containers/food/drinks/gunpowder)

// Harvested grain and seed rot once floodwater soaks them.
/proc/flood_rots(obj/item/I)
	return istype(I, /obj/item/stack/farming/seeds) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/wheat) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/rice) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/oat) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/barley) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/grown/corn)

/proc/flood_items_at(turf/T, band)
	if (flood_items_revision != flood_draw_revision)
		flood_items_revision = flood_draw_revision
		flood_items_done.Cut()
	if (flood_items_done[T])
		return
	flood_items_done[T] = TRUE
	fish_flood_stranding(T, band) // fishing_grounds.dm
	if (band < FLOOD_BAND_WAIST && (locate(/obj/structure/table) in T))
		return
	var/turf/deeper = null
	if (band >= FLOOD_BAND_KNEE)
		var/best = flood_depth_at(T)
		for (var/d in cardinal)
			var/turf/N = get_step(T, d)
			if (!N || N.density)
				continue
			var/depth = istype(N, /turf/floor/beach/water) ? 99 : flood_depth_at(N)
			if (depth > best)
				best = depth
				deeper = N
	for (var/obj/item/I in T)
		if (I.anchored)
			continue
		if (flood_ruins(I) && I.reagents && I.reagents.total_volume)
			// An emptied flour sack falls apart; a gunpowder pouch stays, empty.
			I.visible_message(SPAN_WARNING("Floodwater soaks \the [I] and ruins what was inside."))
			I.reagents.clear_reagents()
		else if (flood_rots(I))
			// Grain and seed left on the ground sour in floodwater; stores upstairs stay dry.
			I.visible_message(SPAN_WARNING("Floodwater soaks \the [I] and it starts to rot."))
			qdel(I)
		else if (deeper && I.w_class <= ITEM_SIZE_SMALL)
			I.Move(deeper)

// ---- currents -------------------------------------------------
// A river in flood carries things further; at low water it barely moves them.
// Steps per current pulse (5 seconds): 0 or 1 at low water, 1 normally, 2 in
// flood. Waterwheels turn in proportion.

/proc/river_current_steps(turf/T)
	var/stage = river_stage_at(T)
	if (stage >= 1)
		return 2
	if (stage <= -1 && prob(50))
		return 0
	return 1

/proc/river_current_power_factor(turf/T)
	return clamp(1 + river_stage_at(T) / 3, 0.5, 2)

// ---- drawing ----------------------------------------------------
// Floodwater over land (icons/effects/floodwater.dmi, drawn by Fable with
// tests/sprites/create_floodwater.py) as images only the viewer's client
// holds: one depth band per flooded tile, a waterline on each dry neighbour
// and a soft step where a deeper band meets a shallower one. The ripple runs
// in step with the river's own water. Rebuilt when the viewer has moved a few
// tiles or the rivers have changed (once a minute).

#define FLOOD_VIEW_RADIUS 12
#define FLOOD_VIEW_MOVE 4
#define FLOOD_LAYER 2.04

var/global/flood_draw_revision = 0

/client
	var/tmp/list/flood_images = null
	var/tmp/flood_drawn_revision = -1
	var/tmp/flood_drawn_x = 0
	var/tmp/flood_drawn_y = 0
	var/tmp/flood_drawn_z = 0

// TRUE when some reach is above the lowest bank or a hollow holds rain, so
// anything may be under water.
/proc/flood_anywhere()
	var/datum/river_flood/F = map && map.river_flood()
	return F && F.flooding

/client/proc/flood_clear_images()
	if (flood_images)
		images -= flood_images
		flood_images = null

/proc/flood_image(turf/T, state, direction = SOUTH)
	var/image/I = image('icons/effects/floodwater.dmi', T, state, FLOOD_LAYER, direction)
	I.mouse_opacity = 0
	return I

// TRUE when tile x, y on level z may stand under water, so the drawing asks
// its depth. Below ground any open tile may: seepage under shallows, swamp and
// coast water and tunnel water from a breach stand whatever the river does.
/datum/river_flood/proc/may_be_wet(x, y, z)
	if (z == cellar_z())
		return TRUE
	var/r = reach_at(x, y)
	return (r && stage[r] > 0) || hollow_at(x, y)

/client/proc/flood_refresh_view()
	var/turf/centre = get_turf(eye)
	var/datum/river_flood/F = map && map.river_flood()
	if (!centre || !F || (!F.flooding && centre.z != F.cellar_z()))
		flood_clear_images()
		flood_drawn_revision = flood_draw_revision
		return
	if (flood_drawn_revision == flood_draw_revision && flood_drawn_z == centre.z && abs(flood_drawn_x - centre.x) < FLOOD_VIEW_MOVE && abs(flood_drawn_y - centre.y) < FLOOD_VIEW_MOVE)
		return
	flood_drawn_revision = flood_draw_revision
	flood_drawn_x = centre.x
	flood_drawn_y = centre.y
	flood_drawn_z = centre.z
	flood_clear_images()
	if (centre.z != F.z_level && centre.z != F.cellar_z())
		return
	// Bands over the view and a one-tile ring, so edges at the rim are right.
	var/x0 = max(1, centre.x - FLOOD_VIEW_RADIUS - 1)
	var/y0 = max(1, centre.y - FLOOD_VIEW_RADIUS - 1)
	var/x1 = min(F.maxx, centre.x + FLOOD_VIEW_RADIUS + 1)
	var/y1 = min(F.maxy, centre.y + FLOOD_VIEW_RADIUS + 1)
	var/w = x1 - x0 + 1
	var/list/bands = new /list(w * (y1 - y0 + 1))
	var/any = FALSE
	for (var/y in y0 to y1)
		for (var/x in x0 to x1)
			if (!F.may_be_wet(x, y, centre.z))
				continue
			var/band = flood_band_at(locate(x, y, centre.z))
			if (band)
				bands[(y - y0) * w + (x - x0) + 1] = band
				any = TRUE
	if (!any)
		return
	var/list/drawn = list()
	for (var/y in y0 + 1 to y1 - 1)
		var/row_offset = (y - y0) * w
		for (var/x in x0 + 1 to x1 - 1)
			var/band = bands[row_offset + (x - x0) + 1]
			if (!band)
				continue
			var/turf/T = locate(x, y, centre.z)
			if (abs(x - centre.x) <= FLOOD_VIEW_RADIUS && abs(y - centre.y) <= FLOOD_VIEW_RADIUS)
				flood_items_at(T, band)
			drawn += flood_image(T, "flood[band]")
			for (var/d in cardinal)
				var/turf/D = get_step(T, d)
				if (!D)
					continue
				var/other = bands[(D.y - y0) * w + (D.x - x0) + 1] || 0
				if (other >= band)
					continue
				if (!other)
					// The river's own water needs no waterline.
					// Nor does solid rock below ground.
					if (!istype(D, /turf/floor/beach/water) && (D.z != F.cellar_z() || cellar_holds_water(D)))
						drawn += flood_image(D, "flood_edge[band]", d)
				else
					drawn += flood_image(D, "flood_step[band]", d)
	flood_images = drawn
	images += drawn

/mob/living/human/proc/flood_life_tick()
	if (client)
		client.flood_refresh_view()
		client.fish_signs_refresh() // fish_signs.dm
		client.scum_refresh_view() // river_foul.dm

#undef FLOOD_VIEW_RADIUS
#undef FLOOD_VIEW_MOVE
#undef FLOOD_LAYER
