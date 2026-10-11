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
		decay_assert(ABANDONED_ITEM_WARNING == 432000 && ABANDONED_ITEM_LIFETIME == 864000, "human12/24-hour thresholds")
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
		decay_assert(findtext(I.abandonment_notice(), "weathered"), "12-hour examine warning")
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
		I.abandonment_since = 123
		I.abandonment_location = "old-runtime"
		var/savefile/F = new("isolated-decay.sav")
		F["/format_version"] << 2
		map_storage.saving_z = 1
		var/ref = map_storage.BuildVarDirectory(F, I, 1)
		F.cd = map_storage.entry_path(F, ref)
		decay_assert(!("abandonment_index" in F.dir) && !("abandonment_since" in F.dir) && !("abandonment_location" in F.dir), "production serializer excludes runtime state")
		// Restore a real nested container entry with forged stale runtime fields.
		I.forceMove(inner)
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/container_ref = map_storage.BuildVarDirectory(F, bag, 1)
		var/item_ref = map_storage.saving_references["\ref[I]"]
		F.cd = map_storage.entry_path(F, item_ref)
		F["abandonment_index"] << list("kind" = "value", "value" = 999999)
		F["abandonment_since"] << list("kind" = "value", "value" = -ABANDONED_ITEM_LIFETIME*10)
		F["abandonment_location"] << list("kind" = "value", "value" = "stale")
		map_storage.clear_bookkeeping()
		var/obj/item/weapon/storage/backpack/restored = map_storage.Load_Entry(F, container_ref, null, T)
		decay_assert(restored && restored != bag && restored.loc == T, "native entry restores container")
		var/obj/item/trash/decay_probe/restored_waste
		for(var/obj/item/weapon/storage/backpack/nested in restored)
			for(var/obj/item/trash/decay_probe/target in nested)
				restored_waste = target
		decay_assert(restored_waste && restored_waste.abandonment_index != 999999 && isnull(restored_waste.abandonment_since), "nested restored waste ignores stale scheduler fields")
		for(var/datum/loaded_datum in map_storage.all_loaded)
			loaded_datum.after_load()
		decay_assert(restored_waste.abandonment_protected() && !restored_waste.gcDestroyed, "restored nested contents survive decay check")
		restored_waste.forceMove(T)
		restored_waste.check_abandonment(0)
		decay_assert(!restored_waste.check_abandonment(ABANDONED_ITEM_LIFETIME-1), "restored waste receives full24-hour exposed window")
		qdel(restored)
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
