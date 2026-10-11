// Production petroleum types; ordinary game startup is disabled by the launcher.
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 5
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/petroleum_failures = 0
var/petroleum_runtime_error = FALSE
/proc/petroleum_check(condition, label)
	if (!condition)
		petroleum_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	petroleum_runtime_error = TRUE
	world.log << "runtime error: [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.moved_event = new /decl/observ/moved
		movementMachine = new
		populate_material_list()
		petroleum_check(!world.port, "fixture has no listening port")
		var/turf/T = locate(2,2,1)
		var/obj/structure/oil_spring/S = new(T)
		var/obj/item/weapon/reagent_containers/glass/barrel/B = new(T)
		var/obj/structure/oilwell/W = new(T)
		petroleum_check(W.base == S && W.work_barrel == B && B.loc == W, "well owns contained barrel and colocated spring")
		petroleum_check(W.extracting_now && W.extraction_pending, "well starts one callback")
		for (var/i in 1 to 30)
			W.unload_barrel()
			W.load_barrel()
		sleep(21)
		petroleum_check(W.extraction_pending && B.reagents.total_volume == 0 && W.extraction_due > world.time, "30 restarts leave one callback and full production delay")
		S.counter = 2
		W.extraction_due = 0
		sleep(21)
		petroleum_check(B.reagents.get_reagent_amount("petroleum") == 10 && S.counter == 1, "one due batch transfers ten petroleum and spends one charge")
		W.unload_barrel()
		sleep(21)
		petroleum_check(!W.extraction_pending && !W.extracting_now && B.loc == T, "unloading settles callback and returns barrel")
		W.unload_barrel()
		W.before_save()
		petroleum_check(!W.work_barrel, "empty well unload and save are null-safe")
		W.load_barrel()
		var/list/saved = W.get_saved_vars()
		petroleum_check(!("work_barrel" in saved) && !("base" in saved) && !("extraction_pending" in saved) && !("extraction_due" in saved) && !("extracting_now" in saved), "serializer excludes runtime petroleum links and flags")
		W.before_save()
		petroleum_check(B.loc == T && !W.extracting_now, "save releases barrel to durable world location")
		W.name = "saved petroleum well"
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/savefile/F = new("petroleum.sav")
		F["/format_version"] << 2
		var/well_id = map_storage.BuildVarDirectory(F, W, 1)
		var/barrel_id = map_storage.BuildVarDirectory(F, B, 1)
		F.Flush()
		qdel(W)
		qdel(B)
		F = null
		map_storage.clear_bookkeeping()
		F = new("petroleum.sav")
		B = map_storage.Load_Entry(F, barrel_id, null, T)
		var/obj/structure/oilwell/restored = map_storage.Load_Entry(F, well_id, null, T)
		for (var/datum/A in map_storage.all_loaded)
			A.after_load()
		petroleum_check(restored.name == "saved petroleum well" && B.reagents.get_reagent_amount("petroleum") == 10, "disk entry round trip preserves well identity and barrel petroleum")
		map_storage.clear_bookkeeping()
		petroleum_check(restored.work_barrel == B && B.loc == restored && restored.extraction_pending && restored.extraction_due >= world.time + 1200, "load relinks barrel with fresh full interval")
		B.reagents.add_reagent("petroleum", B.reagents.get_free_space())
		sleep(21)
		petroleum_check(!restored.extracting_now && !restored.extraction_pending && S.counter == 1, "full barrel stops without spending a spring charge")
		B.reagents.remove_reagent("petroleum", 240)
		restored.start_extraction()
		qdel(S)
		sleep(21)
		petroleum_check(!restored.base && !restored.extracting_now && !restored.extraction_pending, "removed spring releases link and stops scheduling")
		qdel(restored)
		petroleum_check(B.loc == T, "destroy returns live barrel")
		var/obj/structure/oilwell/empty = new(locate(4,4,1))
		qdel(empty)
		var/obj/structure/oil_spring/deleted_barrel_spring = new(locate(3,3,1))
		var/obj/item/weapon/reagent_containers/glass/barrel/deleted_barrel = new(locate(3,3,1))
		var/obj/structure/oilwell/deleted_barrel_well = new(locate(3,3,1))
		qdel(deleted_barrel)
		deleted_barrel_well.unload_barrel()
		sleep(21)
		petroleum_check(!deleted_barrel.loc && !deleted_barrel_well.work_barrel && !deleted_barrel_well.extraction_pending, "unload never returns a deleted barrel to the world")
		qdel(deleted_barrel_well)
		qdel(deleted_barrel_spring)
		var/obj/structure/oil_spring/refilling = new(T)
		refilling.counter = 0
		refilling.timeout = world.time + 20
		for (var/i in 1 to 30)
			refilling.refill()
		petroleum_check(refilling.refill_pending, "repeated refill requests share one callback")
		sleep(51)
		petroleum_check(refilling.counter == 1 && !refilling.refill_pending, "refill completes once and settles")
		saved = refilling.get_saved_vars()
		petroleum_check(!("refill_pending" in saved) && !("timeout" in saved), "spring save excludes callback and absolute deadline")
		refilling.counter = 0
		refilling.after_load()
		petroleum_check(refilling.timeout >= world.time + 600 && refilling.refill_pending, "dry loaded spring waits new full refill interval")
		qdel(refilling)
		sleep(51)
		petroleum_check(!refilling.refill_pending, "destroyed spring settles pending callback")
	catch(var/exception/e)
		petroleum_check(FALSE, "exception [e]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = petroleum_failures, "runtime_error" = petroleum_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
