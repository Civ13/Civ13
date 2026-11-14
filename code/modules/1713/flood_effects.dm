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
// Placeholder floodwater: the flooded-dirt water drawn over land, deeper bands
// more opaque, as images only the viewer's client holds. Rebuilt when the
// viewer has moved a few tiles or the rivers have changed (once a minute).
// Fable's depth and edge art replaces the placeholder later.

#define FLOOD_VIEW_RADIUS 12
#define FLOOD_VIEW_MOVE 4

var/global/flood_draw_revision = 0
var/global/list/flood_band_alpha = list(90, 140, 190, 230)

/client
	var/tmp/list/flood_images = null
	var/tmp/flood_drawn_revision = -1
	var/tmp/flood_drawn_x = 0
	var/tmp/flood_drawn_y = 0
	var/tmp/flood_drawn_z = 0

// TRUE when some reach is above the lowest bank, so anything may be under water.
/proc/flood_anywhere()
	var/datum/river_flood/F = map && map.river_flood()
	return F && F.flooding

/client/proc/flood_clear_images()
	if (flood_images)
		images -= flood_images
		flood_images = null

/client/proc/flood_refresh_view()
	var/turf/centre = get_turf(eye)
	if (!centre || !flood_anywhere())
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
	var/datum/river_flood/F = map.river_flood()
	if (centre.z != F.z_level)
		return
	var/list/drawn = list()
	for (var/x in max(1, centre.x - FLOOD_VIEW_RADIUS) to min(F.maxx, centre.x + FLOOD_VIEW_RADIUS))
		for (var/y in max(1, centre.y - FLOOD_VIEW_RADIUS) to min(F.maxy, centre.y + FLOOD_VIEW_RADIUS))
			var/r = F.reach_at(x, y)
			if (!r || F.stage[r] <= 0)
				continue
			var/turf/T = locate(x, y, centre.z)
			var/band = flood_band_at(T)
			if (!band)
				continue
			var/image/I = image('icons/turf/beach.dmi', T, "seashallow", 2.04)
			I.alpha = flood_band_alpha[band]
			I.mouse_opacity = 0
			drawn += I
	if (drawn.len)
		flood_images = drawn
		images += drawn

/mob/living/human/proc/flood_life_tick()
	if (client)
		client.flood_refresh_view()

#undef FLOOD_VIEW_RADIUS
#undef FLOOD_VIEW_MOVE
