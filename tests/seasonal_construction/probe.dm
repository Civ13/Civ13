// Prepared only. Uses the durable fixture's startup isolation and assertions.
// No production startup, process scheduler, service IPC, or client admission.
/world
	maxz = 1
	area = /area/caribbean
	visibility = 0

/world/OpenPort(port)
	return ..("none")
/world/Topic()
	return null
/client/New()
	del(src)
	return

/proc/construction_probe_transition(advance = TRUE)
	switch (season)
		if ("SPRING") season = "SUMMER"
		if ("SUMMER") season = "FALL"
		if ("FALL") season = "WINTER"
		if ("WINTER") season = "SPRING"
	map.record_abandonment_season_change(advance)

/proc/construction_probe_rates()
	var/list/designs = list(/obj/covers/straw_wall = 16, /obj/roof/thatch = 16, /obj/roof/palm = 16, /obj/covers/dirt_wall = 32, /obj/covers/wood_wall = 64, /obj/covers/wood_wall/bamboo = 64, /obj/covers/wood_wall/log = 64, /obj/roof/wood = 64)
	for (var/path in designs)
		var/obj/O = new path(locate(3,3,1))
		var/lifetime = designs[path]
		var/design_health = O.seasonal_construction_design_health()
		durable_world_check(O.seasonal_construction_index && O.seasonal_construction_lifetime() == lifetime, "construction design rate or registration wrong: [path]")
		for (var/i = 1, i < lifetime, i++)
			construction_probe_transition()
			O.check_seasonal_construction()
			durable_world_check(!O.gc_destroyed && O.seasonal_construction_health() == design_health * (lifetime - i) / lifetime, "construction damage wrong: [path] [i]")
		construction_probe_transition()
		O.check_seasonal_construction()
		durable_world_check(O.gc_destroyed && !O.seasonal_construction_index, "construction did not retire normally: [path]")
		qdel(O) // Idempotence, including registry disposal.
	for (var/path in list(/obj/covers/vault, /obj/covers/stone_wall, /obj/covers/wood_wall/medieval, /obj/covers, /obj/roof, /obj/roof/concrete, /obj/roof/clay, /obj/roof/glass, /obj/roof/canopy))
		var/obj/O = new path(locate(4,4,1))
		durable_world_check(!O.seasonal_construction_index && !O.seasonal_construction_lifetime(), "unlisted design opted in: [path]")
		qdel(O)
	var/obj/roof/wood/slab = new(locate(4,4,1))
	slab.building_pair_id = "synthetic-paired-slab"
	construction_probe_transition()
	slab.check_seasonal_construction()
	durable_world_check(slab.health == 100 && !slab.seasonal_construction_index, "paired slab deteriorated")
	slab.building_pair_id = null
	qdel(slab)

/proc/construction_probe_modes()
	var/obj/covers/straw_wall/W = new(locate(3,3,1))
	var/start_clock = construction_season_changes
	map.persistence = FALSE
	construction_probe_transition()
	durable_world_check(construction_season_changes == start_clock, "nonpersistence season counted")
	map.persistence = TRUE
	construction_probe_transition(FALSE)
	W.check_seasonal_construction()
	durable_world_check(W.health == 75, "age-preserving forced transition charged")
	construction_probe_transition()
	map.record_abandonment_season_change(TRUE)
	W.check_seasonal_construction()
	durable_world_check(W.health == 75 * 15 / 16, "repeated season callback charged twice")
	W.check_seasonal_construction()
	durable_world_check(W.health == 75 * 15 / 16, "repeated sweep charged twice")
	qdel(W)

/proc/construction_probe_contents()
	var/obj/covers/straw_wall/W = new(locate(3,3,1))
	var/obj/item/child = new(W)
	var/obj/item/nested = new(child)
	var/obj/item/neighbor = new(locate(3,3,1))
	for (var/i = 1, i <= 16, i++) construction_probe_transition()
	W.check_seasonal_construction()
	durable_world_check(!W.gc_destroyed && W.seasonal_construction_due == 16 && child.loc == W && nested.loc == child, "contained objects were retired or debt consumed")
	child.forceMove(locate(3,3,1))
	W.check_seasonal_construction()
	durable_world_check(W.gc_destroyed && !child.gc_destroyed && nested.loc == child && neighbor.loc == locate(3,3,1), "normal retirement lost building contents")
	qdel(child)
	qdel(neighbor)

/proc/construction_probe_entry_save()
	var/entry_number = 0
	for (var/path in list(/obj/covers/straw_wall, /obj/roof/thatch))
		entry_number++
		var/obj/O = new path(locate(3,3,1))
		var/design_health = O.seasonal_construction_design_health()
		for (var/i = 1, i <= 3, i++) construction_probe_transition()
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/savefile/F = new("construction-[entry_number].sav")
		F["/format_version"] << 2
		persistence_save_in_progress = TRUE
		var/ref = map_storage.BuildVarDirectory(F, O, 1)
		O.check_seasonal_construction()
		persistence_save_in_progress = FALSE
		durable_world_check(O.seasonal_construction_due == 3 && O.seasonal_construction_health() == design_health, "save did not retain unpaid construction debt")
		var/entry = map_storage.entry_path(F, ref)
		F.cd = entry
		durable_world_check(("seasonal_construction_due" in F.dir) && !("seasonal_construction_index" in F.dir) && !("seasonal_construction_last" in F.dir), "construction save fields wrong")
		// Historical runtime fields must be ignored before they can corrupt slots.
		F["seasonal_construction_index"] << list("kind" = "value", "value" = 999)
		F["seasonal_construction_last"] << list("kind" = "value", "value" = 999)
		map_storage.clear_bookkeeping()
		map_storage.loading_z = 1
		construction_season_changes = 1000 + entry_number
		var/obj/R = map_storage.Load_Entry(F, ref, null, locate(5,5,1))
		durable_world_check(R && R.seasonal_construction_index != 999 && R.seasonal_construction_last != 999, "historical runtime construction fields imported")
		R.after_load()
		R.check_seasonal_construction()
		R.check_seasonal_construction()
		durable_world_check(R.seasonal_construction_health() == design_health * 13 / 16 && R.seasonal_construction_due == 0, "loaded construction debt lost or charged twice")
		qdel(O)
		qdel(R)
		map_storage.clear_bookkeeping()

/world/New()
	OpenPort("none")
	try
		durable_world_check(world.port == 0 && !OpenPort(0) && world.port == 0, "construction fixture opened a port")
		config = new
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
		ticker = new
		ticker.current_state = GAME_STATE_PREGAME
		map = new /obj/map_metadata/nomads/gaia(locate(1,1,1))
		map.persistence = TRUE
		map.age = "2023" // Primitive designs still weather in a modern world.
		season = "SPRING"
		construction_probe_modes()
		construction_probe_rates()
		construction_probe_contents()
		construction_probe_entry_save()
		durable_world_check(!seasonal_construction.len && !durable_probe_failed && world.port == 0, "construction registry, diagnostics or port state invalid")
		text2file(json_encode(list("done" = TRUE, "checks" = durable_probe_checks)), "construction-result.json")
	catch (var/exception/E)
		text2file(json_encode(list("done" = FALSE, "checks" = durable_probe_checks, "error" = "[E]")), "construction-result.json")
	del(world)
	return
