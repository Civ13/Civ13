// Lighting under a built hull's upper deck on an added building level
// (code/modules/craft/built_body.dm, code/modules/multiz/building_lighting.dm).
// An added level is lazy: its open-air cells have no lighting until something
// wakes them, and an unlit cell draws black. Her upper deck sails onto cells
// nobody has woken, so each cell she reaches must be lit, or a sailor who
// climbs up after a voyage sees nothing at all.
/world
	hub = ""
	hub_password = ""
	maxx = 70
	maxy = 40
	maxz = 2
	turf = /turf/sky/building // as on the live worlds, so an added level is born asleep
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/naval_research_done = FALSE
/obj/map_metadata/naval_probe/New()
	return
/obj/map_metadata/naval_probe/is_node_done(faction, node_id)
	return naval_research_done
/mob/living/human/naval_probe/New()
	return
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

/proc/deck_roof(x, y)
	return building_construct_roof(locate(x, y, 2), /obj/roof/wood, null)

// Upper deck cells of hers that have no lighting (they draw black).
/proc/deck_unlit(datum/craft_body/built/B)
	. = 0
	for (var/turf/U in B.upper_cells())
		if (!U.lighting_overlay)
			.++

/proc/naval_checks()
	// Rock under deep sea; the level above is added at runtime, as on Gaia.
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			locate(x, y, 1).ChangeTurf(/turf/wall/rockwall)
			locate(x, y, 2).ChangeTurf(/turf/floor/beach/water/deep/saltwater)
	create_lighting()
	naval_check(created_lighting_corners_and_overlays, "lighting is up")
	naval_check(building_allocate_level(3), "a building level is added over the sea ([world_z_budget.last_error])")
	naval_research_done = TRUE
	naval_check(building_upper_z(2) == 3 && building_level_lazy(3), "the added level is lazy")
	var/turf/far = locate(50, 11, 3)
	naval_check(building_cell_asleep(far), "a cell far ahead of her is asleep ([far.type] registry [turf_registry_has(far)] lit [!!far.lighting_overlay])")

	for (var/x = 10, x <= 14, x++)
		for (var/y = 10, y <= 12, y++)
			hull_lay(x, y)
	new /obj/structure/roof_support(locate(12, 11, 2))
	var/roofs = 0
	for (var/x = 10, x <= 14, x++)
		for (var/y = 10, y <= 12, y++)
			if (deck_roof(x, y))
				roofs++
	var/obj/structure/multiz/ladder/up/foot = new(locate(11, 12, 2))
	var/obj/structure/multiz/ladder/head = new(locate(11, 12, 3))
	foot.find_target()
	head.find_target()
	var/obj/structure/hull_tiller/tiller = new(locate(10, 11, 2))
	naval_check(roofs == 15 && isnull(tiller.commission("Heron", EAST)) && tiller.craft, "a roofed hull is commissioned ([roofs])")
	var/datum/craft/C = tiller.craft
	var/datum/craft_body/built/B = C.body
	naval_check(B.upper_tile_count() == 15, "her upper deck is fifteen tiles ([B.upper_tile_count()])")
	sleep(10) // floors wake the cells around them a moment after they are laid
	naval_check(deck_unlit(B) == 0, "her upper deck is lit where she was built ([deck_unlit(B)] unlit)")

	// Sail well past the cells her building woke.
	var/steps = 0
	for (var/i = 1, i <= 30, i++)
		var/turf/O = B.origin()
		if (!B.move_to(O.x + 1, O.y, EAST))
			break
		steps++
	naval_check(steps == 30, "she sails thirty tiles east ([steps], [B.last_refusal])")
	naval_check(B.upper_tile_count() == 15, "her upper deck came along ([B.upper_tile_count()])")
	naval_check(deck_unlit(B) == 0, "every tile of her upper deck is lit after the voyage ([deck_unlit(B)] unlit)")
	var/turf/U = locate(head.x, head.y, 3)
	naval_check(head.loc == U && U.lighting_overlay, "the ladder top she carried stands on a lit tile ([head.x],[head.y])")
	// The open air past her side is woken by the level-view scan of a sailor
	// standing there (the fixture's bare /area has no dynamic lighting, so
	// woken is the test there).
	var/turf/side = locate(head.x, head.y + 2, 3)
	naval_check(building_cell_asleep(side), "the open air past her side is still asleep")
	open_air_view_link_around(3, head.x, head.y, 3, 3)
	naval_check(!building_cell_asleep(side), "a sailor's scan wakes the open air past her side")

	// A floor set down without a lighting update (as a load or a carry can)
	// is still woken by the scan of someone who can see it.
	var/turf/sky/building/quiet_cell = locate(60, 30, 3)
	var/obj/covers/repairedfloor/F = new(null)
	F.loc = quiet_cell
	naval_check(!quiet_cell.lighting_overlay && building_cell_asleep(quiet_cell), "a floor set down quietly leaves its cell unlit")
	open_air_view_link_around(3, 60, 30, 2, 2)
	naval_check(quiet_cell.lighting_overlay, "the scan lights a floored cell in sight")

/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/naval_probe
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
