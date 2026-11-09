// Full-source probe for ground pollution: real turfs, plants, reagents and
// fuel burning, isolated startup. 12x12 level of grass with a wall column.
/world
	hub = ""
	visibility = 0
	maxx = 12
	maxy = 12
	maxz = 1
	fps = 20
	turf = /turf/floor/grass
	area = /area

/world/OpenPort(port)
	if (port == "none")
		return ..("none")
	return FALSE

/world/Topic()
	return null

/client/New()
	del(src)

// Skip the real metadata constructor (schedules, factions); only the map global matters.
/obj/map_metadata/pollution_probe/New()
	map = src

var/pollution_probe_checks = 0

/proc/pollution_probe_assert(ok, label)
	pollution_probe_checks++
	if (!ok)
		throw EXCEPTION(label)

/proc/pollution_probe_close(a, b)
	return abs(a - b) < 0.02

/proc/pollution_probe_registry_ok()
	for (var/i in 1 to polluted_turfs.len)
		var/turf/T = polluted_turfs[i]
		if (!istype(T) || T.pollution_index != i || T.pollution <= 0)
			return FALSE
	return TRUE

/proc/pollution_probe_reset()
	for (var/turf/T in block(locate(1, 1, 1), locate(world.maxx, world.maxy, 1)))
		T.pollution_set(0)
	pollution_pending = list()
	pollution_pending_radius = list()
	polluted_turfs_cursor = 1

/proc/pollution_probe_run()
	map = new /obj/map_metadata/pollution_probe
	var/turf/center = locate(6, 6, 1)
	var/turf/wall_turf = locate(12, 6, 1)
	wall_turf.ChangeTurf(/turf/wall/rockwall)
	wall_turf = locate(12, 6, 1)

	// Adding, clamping, registry and stains.
	pollution_probe_assert(pollution_add(center, 10) == 10 && center.pollution == 10, "add")
	pollution_probe_assert(polluted_turfs.len == 1 && center.pollution_index == 1, "registered")
	pollution_probe_assert(center.pollution_stain == 0, "no_stain_below_visible")
	pollution_add(center, 200)
	pollution_probe_assert(center.pollution == 100 && center.pollution_stain == 3, "clamped_and_stained")
	pollution_probe_assert(locate(/obj/effect/pollution_stain) in center.vis_contents, "stain_shown")
	pollution_probe_assert(pollution_add(wall_turf, 50) == 0 && wall_turf.pollution == 0 && !wall_turf.pollution_index, "wall_refuses")
	center.pollution_set(0)
	pollution_probe_assert(!polluted_turfs.len && !center.pollution_index && !center.pollution_stain, "cleared")
	pollution_probe_assert(!(locate(/obj/effect/pollution_stain) in center.vis_contents), "stain_removed")

	// Queued emission spreads once, full at the centre and fading outward.
	pollution_emit(center, 8, 3)
	pollution_emit(center, 2, 1)
	pollution_probe_assert(pollution_pending.len == 1 && pollution_pending[center] == 10 && pollution_pending_radius[center] == 3, "queued")
	pollution_probe_assert(center.pollution == 0, "queue_is_lazy")
	pollution_flush_pending()
	pollution_probe_assert(!pollution_pending.len && !pollution_pending_radius.len, "queue_flushed")
	var/turf/near = locate(7, 6, 1)
	var/turf/edge = locate(9, 6, 1)
	var/turf/outside = locate(10, 6, 1)
	pollution_probe_assert(center.pollution == 10, "centre_full")
	pollution_probe_assert(pollution_probe_close(near.pollution, 7.5), "falloff_near")
	pollution_probe_assert(pollution_probe_close(edge.pollution, 2.5), "falloff_edge")
	pollution_probe_assert(outside.pollution == 0, "outside_radius")
	pollution_probe_assert(pollution_probe_registry_ok(), "registry_after_spread")

	// Decay: half a point a minute, doubled in rain, tripled under a tree.
	pollution_probe_reset()
	center.pollution_set(50)
	center.pollution_decay_tick = world.time - 10 MINUTES
	center.pollution_decay()
	// Grass alone speeds recovery by half.
	pollution_probe_assert(pollution_probe_close(center.pollution, 50 - 7.5), "decay_grass")
	var/turf/plain = locate(2, 2, 1)
	plain.ChangeTurf(/turf/floor/dirt)
	plain = locate(2, 2, 1)
	plain.pollution_set(50)
	plain.pollution_decay_tick = world.time - 10 MINUTES
	plain.pollution_decay()
	pollution_probe_assert(pollution_probe_close(plain.pollution, 45), "decay_plain")
	var/area/A = plain.loc
	A.weather = WEATHER_WET
	plain.pollution_decay_tick = world.time - 10 MINUTES
	plain.pollution_decay()
	A.weather = WEATHER_NONE
	pollution_probe_assert(pollution_probe_close(plain.pollution, 35), "decay_rain")
	var/obj/structure/wild/tree/live_tree/tree = new(plain)
	plain.pollution_decay_tick = world.time - 10 MINUTES
	plain.pollution_decay()
	qdel(tree)
	pollution_probe_assert(pollution_probe_close(plain.pollution, 20), "decay_tree")
	plain.pollution_decay_tick = world.time - 100 MINUTES
	plain.pollution_decay()
	pollution_probe_assert(pollution_probe_close(plain.pollution, 15), "decay_elapsed_capped")

	// The batch walks the registry and drops cleared turfs.
	pollution_probe_reset()
	for (var/x in 1 to 5)
		var/turf/T = locate(x, 10, 1)
		T.pollution_set(x == 3 ? 0.1 : 40)
		T.pollution_decay_tick = world.time - 1 MINUTE
	pollution_decay_batch()
	pollution_probe_assert(polluted_turfs.len == 4 && pollution_probe_registry_ok(), "batch_drops_cleared")

	// Changing the turf keeps the pollution and its registry slot.
	pollution_probe_reset()
	var/turf/field = locate(4, 4, 1)
	field.ChangeTurf(/turf/floor/dirt)
	field = locate(4, 4, 1)
	field.pollution_set(70)
	var/index = field.pollution_index
	field.ChangeTurf(/turf/floor/dirt/ploughed)
	field = locate(4, 4, 1)
	pollution_probe_assert(istype(field, /turf/floor/dirt/ploughed) && field.pollution == 70 && field.pollution_index == index, "change_turf_keeps")
	pollution_probe_assert(field.pollution_stain == 3 && (locate(/obj/effect/pollution_stain) in field.vis_contents), "change_turf_stain")
	pollution_probe_assert(pollution_probe_registry_ok() && polluted_turfs.len == 1, "change_turf_registry")
	var/turf/walled = locate(5, 4, 1)
	walled.pollution_set(30)
	walled.ChangeTurf(/turf/wall/rockwall)
	walled = locate(5, 4, 1)
	pollution_probe_assert(walled.pollution == 0 && !walled.pollution_index && polluted_turfs.len == 1 && pollution_probe_registry_ok(), "wall_drops")

	// Saving: the field is written only while polluted; loading registers it.
	pollution_probe_assert("pollution" in field.get_saved_vars(), "saved_when_polluted")
	var/turf/clean = locate(8, 8, 1)
	pollution_probe_assert(!("pollution" in clean.get_saved_vars()), "not_saved_when_clean")
	field.pollution_unregister()
	pollution_probe_assert(!polluted_turfs.len && field.pollution == 70, "unregistered_for_load")
	field.after_load()
	pollution_probe_assert(field.pollution_index == 1 && polluted_turfs.len == 1, "after_load_registers")

	// Growth thresholds.
	pollution_probe_reset()
	pollution_probe_assert(pollution_allows_growth(center), "clean_grows")
	center.pollution_set(29)
	pollution_probe_assert(pollution_allows_growth(center), "light_grows")
	center.pollution_set(60)
	pollution_probe_assert(!pollution_allows_growth(center), "heavy_blocks")
	center.pollution_set(45)
	var/grew = 0
	for (var/i in 1 to 400)
		if (pollution_allows_growth(center))
			grew++
	pollution_probe_assert(grew > 120 && grew < 280, "slow_halves")

	// A crop on heavily polluted ploughed soil does not advance; clean soil does.
	pollution_probe_reset()
	var/obj/structure/farming/plant/wheat/crop = new(field)
	crop.vstatic = TRUE // no growth loop of its own during the probe
	var/start_stage = crop.stage
	field.pollution_set(80)
	crop.plant_nutrition = 150
	crop.advance_stage_if_allowed(TRUE)
	pollution_probe_assert(crop.stage == start_stage, "crop_blocked")
	field.pollution_set(0)
	crop.advance_stage_if_allowed(TRUE)
	pollution_probe_assert(crop.stage == start_stage + 1, "crop_grows_clean")
	field.pollution_set(80)
	crop.vstatic = FALSE
	var/list/notes = crop.farming_diagnostics(2)
	pollution_probe_assert(jointext(notes, " ") && findtext(jointext(notes, " "), "too polluted"), "crop_diagnostic")
	qdel(crop)

	// Wild plants avoid soiled ground; stumps do not regrow on fouled ground.
	var/datum/flora_regrowth/F = new
	field.pollution_set(35)
	pollution_probe_assert(F.plant_site_error(field) == "polluted", "wild_plant_site")

	// Fuel burnt in a furnace queues smoke on its turf.
	pollution_probe_reset()
	var/obj/structure/furnace/furnace = new(center)
	furnace.fuel = 10
	pollution_probe_assert(furnace.burn_structure_fuel(2) == 2, "furnace_burns")
	pollution_probe_assert(pollution_pending[center] == 4 && pollution_pending_radius[center] == 3, "furnace_queues")
	qdel(furnace)

	// Spilled gasoline soils the tile and its neighbours.
	pollution_probe_reset()
	var/datum/reagent/gasoline/G = new
	G.touch_turf(center, 20)
	pollution_probe_assert(center.pollution == 20 && pollution_probe_close(near.pollution, 10), "spill")
	var/datum/reagent/water/W = new
	W.touch_turf(outside, 20)
	pollution_probe_assert(outside.pollution == 0, "water_clean")

	// Charcoal cleanup removes pollution around the tile.
	pollution_probe_assert(-pollution_spread(center, -20, 1) > 20 && center.pollution == 0 && near.pollution == 0, "charcoal_spread")
	pollution_probe_assert(pollution_probe_registry_ok(), "registry_end")

/world/New()
	OpenPort("none")
	var/error = null
	try
		pollution_probe_run()
	catch (var/exception/probe_error)
		error = "[probe_error.name] ([probe_error.file]:[probe_error.line])"
	text2file(error ? "FAIL [error]" : "PASS", "result.txt")
	text2file(json_encode(list("checks" = pollution_probe_checks, "error" = error, "byond_build" = byond_build)), "receipt.json")
	del(world)
