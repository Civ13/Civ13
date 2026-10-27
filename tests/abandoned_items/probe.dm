/world
	maxx = 4
	maxy = 4
	maxz = 1
	turf = /turf

var/decay_assertions = 0
/proc/decay_assert(ok, message)
	decay_assertions++
	if (!ok)
		throw EXCEPTION(message)

/obj/item/trash/decay_probe
	// Actual inherited production lifecycle, no synthetic cleanup overrides.

/obj/item/trash/decay_probe_occupied

/obj/map_metadata/nomads/decay_probe/New()
	map = src // Isolated metadata: no normal map timers or systems.

/obj/map_metadata/nomads/mountain/decay_admin_probe
	valid_weather_types = list(WEATHER_NONE)

/obj/map_metadata/nomads/mountain/decay_admin_probe/New()
	map = src // Real season routine, isolated metadata startup.

/obj/map_metadata/nomads/ice_age/decay_admin_probe
	valid_weather_types = list(WEATHER_NONE)

/obj/map_metadata/nomads/ice_age/decay_admin_probe/New()
	map = src // Real season routine, isolated metadata startup.

/obj/map_metadata/nomads/asia/decay_admin_probe
	valid_weather_types = list(WEATHER_NONE)

/obj/map_metadata/nomads/asia/decay_admin_probe/New()
	map = src // Real season routine, isolated metadata startup.

/obj/map_metadata/colonia/decay_admin_probe
	valid_weather_types = list(WEATHER_NONE)

/obj/map_metadata/colonia/decay_admin_probe/New()
	map = src // Real season routine, isolated metadata startup.

/obj/map_metadata/pepelsibirsk/decay_admin_probe
	valid_weather_types = list(WEATHER_NONE)

/obj/map_metadata/pepelsibirsk/decay_admin_probe/New()
	map = src // Real season routine, isolated metadata startup.

/proc/decay_counts()
	var/waste = 0
	var/pending = 0
	for (var/obj/item/trash/decay_probe/I)
		waste++
		if (I.gcDestroyed)
			pending++
	return list("objects" = waste, "pending" = pending, "registry" = abandoned_items.len)

/world/New()
	text2file(json_encode(list("commit" = world.params["tested_commit"], "byond" = "[world.byond_version].[world.byond_build]", "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz)), "metadata.json")
	try
		decay_assert(ABANDONED_ITEM_WARNING == 216000 && ABANDONED_ITEM_LIFETIME == 432000, "human6/12-hour thresholds")
		decay_assert(ABANDONED_ITEM_SEASON_WARNING == 2 && ABANDONED_ITEM_SEASON_LIFETIME == 4, "human seasonal thresholds")
		config = new
		var/obj/map_metadata/nomads/decay_probe/season_map = new
		season = "SPRING"
		decay_assert(season_map.abandonment_uses_seasons(), "ancient nomads uses seasonal clock before first transition")
		var/transition_count = abandonment_season_changes
		season_map.valid_weather_types = list(WEATHER_NONE)
		season_map.seasons(FALSE, TRUE)
		decay_assert(season == "SUMMER" && abandonment_season_changes == transition_count, "forced base transition preserves decay by default")
		season_map.seasons(FALSE, TRUE, TRUE)
		decay_assert(season == "FALL" && abandonment_season_changes == transition_count+1, "explicit forced base transition advances decay")
		season_map.seasons(FALSE)
		decay_assert(season == "WINTER" && abandonment_season_changes == transition_count+2, "natural base transition advances decay")
		for (var/metadata_type in list(/obj/map_metadata/nomads/mountain/decay_admin_probe, /obj/map_metadata/nomads/ice_age/decay_admin_probe, /obj/map_metadata/nomads/asia/decay_admin_probe, /obj/map_metadata/colonia/decay_admin_probe, /obj/map_metadata/pepelsibirsk/decay_admin_probe))
			var/obj/map_metadata/custom_map = new metadata_type
			season = "SPRING"
			transition_count = abandonment_season_changes
			custom_map.seasons(FALSE, TRUE)
			decay_assert(abandonment_season_changes == transition_count && season != "SPRING", "forced [metadata_type] preserves decay by default")
			custom_map.seasons(FALSE, TRUE, TRUE)
			decay_assert(abandonment_season_changes == transition_count+1, "explicit forced [metadata_type] advances decay")
			custom_map.seasons(FALSE)
			decay_assert(abandonment_season_changes == transition_count+2, "natural [metadata_type] advances decay")
			qdel(custom_map)
		map = season_map
		season = "SPRING"
		abandonment_season_changes = 0
		var/turf/season_turf = locate(1,1,1)
		var/obj/item/trash/decay_probe/season_waste = new(season_turf)
		season_waste.check_abandonment(0)
		decay_assert(!season_waste.check_abandonment(ABANDONED_ITEM_LIFETIME*100), "seasonal waste has no elapsed-hour deadline")
		season = "SUMMER"
		decay_assert(abandonment_season_changes == 0, "startup/direct climate assignment does not count as a transition")
		season_map.record_abandonment_season_change()
		decay_assert(!season_waste.check_abandonment(ABANDONED_ITEM_LIFETIME*101) && !season_waste.abandonment_notice(), "first change preserves waste without warning")
		season_map.record_abandonment_season_change()
		decay_assert(findtext(season_waste.abandonment_notice(), "four season changes"), "second change warns")
		season_map.record_abandonment_season_change()
		decay_assert(!season_waste.check_abandonment(ABANDONED_ITEM_LIFETIME*102), "third change preserves waste")
		season_map.record_abandonment_season_change()
		decay_assert(season_waste.check_abandonment(ABANDONED_ITEM_LIFETIME*103), "fourth change decays waste")
		season_waste = new(season_turf)
		season_waste.check_abandonment(0)
		season_map.record_abandonment_season_change()
		season_waste.forceMove(locate(2,1,1))
		season_waste.check_abandonment(0)
		decay_assert(season_waste.abandonment_season_since == abandonment_season_changes, "movement starts fresh seasonal window")
		config.seasons_on = FALSE
		season_waste.check_abandonment(100)
		decay_assert(!season_waste.abandonment_seasonal && !season_waste.check_abandonment(100+ABANDONED_ITEM_LIFETIME-1), "disabling standard seasons grants full real-time window")
		config.seasons_on = TRUE
		season_waste.check_abandonment(100+ABANDONED_ITEM_LIFETIME)
		decay_assert(!season_waste.gcDestroyed && season_waste.abandonment_seasonal, "enabling seasons resets clock conservatively")
		season = "Wet Season"
		decay_assert(!season_map.abandonment_uses_seasons(), "fixed wet label uses fallback")
		season_map.abandonment_season_autonomous = TRUE
		config.seasons_on = FALSE
		decay_assert(season_map.abandonment_uses_seasons(), "custom wet/dry cycle ignores standard config")
		season_map.abandonment_season_cycle = FALSE
		decay_assert(!season_map.abandonment_uses_seasons(), "static map uses fallback")
		qdel(season_waste)
		map = null
		qdel(season_map)
		season = "SPRING"
		config.seasons_on = TRUE
		var/process/garbage/G = new
		G.setup()
		var/process/abandoned_items/P = new
		P.setup()
		var/turf/T = locate(1,1,1)
		var/obj/item/trash/decay_probe/I = new(T)
		decay_assert(I.abandonment_index > 0, "New registers waste")
		I.register_abandoned_item()
		decay_assert(abandoned_items.len == 1, "duplicate registration is idempotent")
		I.check_abandonment(0)
		decay_assert(!I.check_abandonment(ABANDONED_ITEM_LIFETIME-1), "full recovery window")
		decay_assert(I.check_abandonment(ABANDONED_ITEM_LIFETIME), "expired exposed waste decays")
		decay_assert(!I.abandonment_index && I.gcDestroyed && !I.loc, "qdel releases registry and location")
		I = new(T)
		I.abandonment_since = world.time - ABANDONED_ITEM_WARNING
		I.abandonment_location = "\ref[T]"
		decay_assert(findtext(I.abandonment_notice(), "weathered"), "6-hour examine warning")
		var/obj/item/weapon/storage/backpack/bag = new(T)
		var/obj/item/weapon/storage/backpack/inner = new(bag)
		I.forceMove(inner)
		decay_assert(isnull(I.abandonment_since), "forceMove resets exposure immediately")
		I.check_abandonment(ABANDONED_ITEM_LIFETIME*2)
		decay_assert(!I.gcDestroyed && isnull(I.abandonment_since), "nested storage protects waste")
		I.forceMove(T)
		I.check_abandonment(ABANDONED_ITEM_LIFETIME*2)
		decay_assert(!I.check_abandonment(ABANDONED_ITEM_LIFETIME*3-10), "leaving storage grants fresh window")
		I.loc = inner
		I.check_abandonment(ABANDONED_ITEM_LIFETIME*4)
		decay_assert(isnull(I.abandonment_since), "direct loc assignment sampled safely")
		var/mob/M = new(T)
		bag.forceMove(M)
		decay_assert(I.abandonment_protected(), "nested mob inventory protected")
		I.forceMove(M)
		decay_assert(I.abandonment_protected(), "direct mob inventory protected")
		I.forceMove(T)
		I.pickup(M)
		decay_assert(isnull(I.abandonment_since), "pickup resets even before loc changes")
		I.check_abandonment(0)
		I.equipped(M, slot_l_hand)
		decay_assert(isnull(I.abandonment_since), "equipped hook resets")
		I.check_abandonment(0)
		I.dropped(M)
		decay_assert(isnull(I.abandonment_since), "drop hook resets")
		var/obj/structure/closet/crate/C = new(T)
		I.forceMove(C)
		decay_assert(I.abandonment_protected(), "closed real crate protects")
		C.opened = TRUE
		decay_assert(!I.abandonment_protected(), "open crate does not preserve residual contents")
		var/obj/fake = new(T)
		I.forceMove(fake)
		decay_assert(!I.abandonment_protected(), "fake object location grants no preservation")
		I.forceMove(T)
		var/obj/item/child = new(I)
		decay_assert(I.abandonment_protected(), "occupied waste never deletes children")
		qdel(child)
		I.anchored = TRUE
		decay_assert(I.abandonment_protected(), "anchored object protected")
		I.anchored = FALSE
		I.throwing = TRUE
		decay_assert(I.abandonment_protected(), "active throw protected")
		I.throwing = FALSE
		var/obj/item/trash/money/cash = new(T)
		var/obj/item/trash/candle/candle = new(T)
		var/obj/item/trash/tray/tray = new(T)
		var/obj/item/weapon/material/tool = new(T)
		decay_assert(!cash.abandonment_index && !candle.abandonment_index && !tray.abandonment_index && !tool.abandonment_index, "money/candle/tray/useful tool excluded")
		var/obj/item/ammo_casing/arrow/arrow = new(T)
		decay_assert(!arrow.abandonment_index, "recoverable arrow excluded")
		var/obj/item/ammo_casing/loaded = new(T)
		loaded.spent_icon = "empty"
		loaded.BB = new /obj/item/projectile(loaded)
		loaded.register_abandoned_item()
		decay_assert(!loaded.abandonment_index, "loaded ammunition excluded")
		var/obj/item/projectile/projectile = loaded.expend()
		projectile.forceMove(T)
		qdel(projectile)
		decay_assert(loaded.abandonment_index > 0, "spent casing opts in after expend")
		loaded.check_abandonment(0)
		decay_assert(loaded.check_abandonment(ABANDONED_ITEM_LIFETIME), "spent empty casing decays")
		var/obj/item/ammo_magazine/magazine = new(T)
		var/obj/item/ammo_casing/stored = new(T)
		stored.spent_icon = "empty"
		stored.register_abandoned_item()
		stored.forceMove(magazine)
		magazine.stored_ammo += stored
		stored.check_abandonment(0)
		decay_assert(stored.abandonment_protected() && !stored.check_abandonment(ABANDONED_ITEM_LIFETIME*2), "native magazine preserves spent casings")
		stored.forceMove(T)
		magazine.stored_ammo -= stored
		stored.check_abandonment(0)
		decay_assert(stored.check_abandonment(ABANDONED_ITEM_LIFETIME), "dumped spent casing becomes exposed waste")
		qdel(magazine)
		var/obj/item/weapon/gun/gun = new(T)
		stored = new(T)
		stored.spent_icon = "empty"
		stored.register_abandoned_item()
		stored.forceMove(gun)
		stored.check_abandonment(0)
		decay_assert(stored.abandonment_protected() && !stored.check_abandonment(ABANDONED_ITEM_LIFETIME*2), "native gun preserves internal spent casing")
		qdel(stored); qdel(gun)
		I.abandonment_since = 123
		I.abandonment_location = "old-runtime"
		var/savefile/F = new("isolated-decay.sav")
		F["/format_version"] << 2
		map_storage.saving_z = 1
		var/ref = map_storage.BuildVarDirectory(F, I, 1)
		F.cd = map_storage.entry_path(F, ref)
		decay_assert(!("abandonment_index" in F.dir) && !("abandonment_since" in F.dir) && !("abandonment_location" in F.dir) && !("abandonment_season_since" in F.dir) && !("abandonment_seasonal" in F.dir), "production serializer excludes runtime state")
		// Restore a real nested container entry with forged stale runtime fields.
		I.forceMove(inner)
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/container_ref = map_storage.BuildVarDirectory(F, bag, 1)
		var/item_ref = map_storage.saving_references["\ref[I]"]
		F.cd = map_storage.entry_path(F, item_ref)
		F["abandonment_index"] << list("kind" = "value", "value" = 999999)
		F["abandonment_since"] << list("kind" = "value", "value" = -ABANDONED_ITEM_LIFETIME*10)
		F["abandonment_season_since"] << list("kind" = "value", "value" = -99999)
		F["abandonment_seasonal"] << list("kind" = "value", "value" = TRUE)
		F["abandonment_location"] << list("kind" = "value", "value" = "stale")
		map_storage.clear_bookkeeping()
		var/obj/item/weapon/storage/backpack/restored = map_storage.Load_Entry(F, container_ref, null, T)
		decay_assert(restored && restored != bag && restored.loc == T, "native entry restores container")
		var/obj/item/trash/decay_probe/restored_waste
		for(var/obj/item/weapon/storage/backpack/nested in restored)
			for(var/obj/item/trash/decay_probe/target in nested)
				restored_waste = target
		decay_assert(restored_waste && restored_waste.abandonment_index != 999999 && isnull(restored_waste.abandonment_since) && isnull(restored_waste.abandonment_season_since) && !restored_waste.abandonment_seasonal, "nested restored waste ignores stale scheduler fields")
		for(var/datum/loaded_datum in map_storage.all_loaded)
			loaded_datum.after_load()
		decay_assert(restored_waste.abandonment_protected() && !restored_waste.gcDestroyed, "restored nested contents survive decay check")
		restored_waste.forceMove(T)
		restored_waste.check_abandonment(0)
		decay_assert(!restored_waste.check_abandonment(ABANDONED_ITEM_LIFETIME-1), "restored waste receives full12-hour exposed window")
		qdel(restored_waste); qdel(restored)
		I.after_load()
		decay_assert(isnull(I.abandonment_since) && I.abandonment_index, "load reset does not duplicate registry")
		map_storage.clear_bookkeeping()
		decay_assert(!map_storage.saving_references.len && !map_storage.existing_references.len && !map_storage.all_loaded.len, "save bookkeeping releases references")
		// Force legitimate qdel for retained fixtures before repeated production.
		qdel(I); qdel(bag); qdel(M); qdel(C); qdel(fake)
		qdel(cash); qdel(candle); qdel(tray); qdel(tool); qdel(arrow)
		decay_assert(!abandoned_items.len, "fixture registry returns to baseline")
		// Mixed preservation and swap removals cannot starve exposed entries.
		var/obj/item/weapon/storage/backpack/protected_bag = new(T)
		for (var/n = 1, n <= 600, n++)
			new /obj/item/trash/decay_probe(protected_bag)
			var/obj/item/trash/decay_probe/exposed = new(T)
			exposed.abandonment_since = world.time - ABANDONED_ITEM_LIFETIME
			exposed.abandonment_location = "\ref[T]"
		for (var/batch = 1, batch <= 10, batch++)
			P.fire()
		decay_assert(abandoned_items.len == 600, "mixed sweep preserves600 and removes600 without starvation")
		qdel(protected_bag)
		decay_assert(!abandoned_items.len, "container deletion unregisters all children")
		var/obj/item/trash/decay_probe/raw = new(T)
		raw.loc = null
		del(raw)
		decay_assert(!abandoned_items.len, "native Del releases registry")
		for (var/cycle = 1, cycle <= 60, cycle++)
			fdel("phase.json")
			text2file(json_encode(list("phase" = "allocating", "cycle" = cycle)), "phase.json")
			for (var/n = 1, n <= 1024, n++)
				var/obj/item/trash/decay_probe/waste = new(T)
				waste.abandonment_since = world.time - ABANDONED_ITEM_LIFETIME
				waste.abandonment_location = "\ref[T]"
			var/before = abandoned_items.len
			P.fire()
			decay_assert(before - abandoned_items.len == ABANDONED_ITEM_BATCH, "batch cap exactly 256")
			for (var/batch = 1, batch <= 3, batch++)
				P.fire()
			decay_assert(!abandoned_items.len, "burst sweep visits every swapped candidate")
			// Flush only probe's queued garbage by aging its numeric GC timestamps.
			// Keep production AddTrash/fire logic and cap; no direct del shortcut.
			for (var/ref_id in G.destroyed)
				var/datum/D = locate(ref_id)
				if (D)
					D.gcDestroyed = world.time - 301
				G.destroyed[ref_id] = world.time - 301
			while (G.destroyed.len)
				G.fire()
			sleep(1)
			var/list/counts = decay_counts()
			decay_assert(!counts["objects"] && !counts["pending"], "no retained probe objects after GC drain")
			text2file(json_encode(list("cycle" = cycle, "counts" = counts, "gc_queue" = G.destroyed.len)), "cycles.jsonl")
			fdel("phase.json")
			text2file(json_encode(list("phase" = "settled", "cycle" = cycle)), "phase.json")
			sleep(3)
			world.log << "DECAY CYCLE [cycle]: registry=[abandoned_items.len] objects=[counts["objects"]] queued=[G.destroyed.len]"
		text2file("PASS: [decay_assertions] assertions; 60 cycles x 1024 discarded items", "result.txt")
	catch(var/exception/error)
		text2file("FAIL: [error] at [error.file]:[error.line]", "result.txt")
	del(world)
