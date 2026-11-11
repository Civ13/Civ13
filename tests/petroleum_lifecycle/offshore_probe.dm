// Offshore drilling rig fixture; ordinary game startup is disabled by the launcher.
// With no map loaded the field seed is the empty-ID seed 7. The expected
// richness values below match the integer model in code/modules/1713/offshore_rig.dm
// (computed independently in Python).
/world
	hub = ""
	hub_password = ""
	maxx = 24
	maxy = 8
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/offshore_failures = 0
var/offshore_runtime_error = FALSE
/proc/offshore_check(condition, label)
	if (!condition)
		offshore_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	offshore_runtime_error = TRUE
	world.log << "runtime error: [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new /decl/observ/moved
		GLOB.dir_set_event = new /decl/observ/dir_set
		GLOB.destroyed_event = new /decl/observ/destroyed
		movementMachine = new
		populate_material_list()
		offshore_check(!world.port, "fixture has no listening port")
		offshore_check(offshore_map_seed() == 7, "empty map ID gives the base seed")
		offshore_check(offshore_field_richness_at(7, 1, 1, 1) == 0 && offshore_field_richness_at(7, 9, 1, 1) == 3 && offshore_field_richness_at(7, 9, 9, 1) == 1 && offshore_field_richness_at(7, 17, 17, 1) == 1 && offshore_field_richness_at(7, 33, 1, 1) == 0, "field richness matches the independent model")
		offshore_check(offshore_field_richness_at(7, 9, 1, 1) == offshore_field_richness_at(7, 16, 8, 1), "a field covers its whole eight-tile square")
		var/fields = 0
		for (var/cx in 0 to 63)
			for (var/cy in 0 to 63)
				if (offshore_field_richness_at(7, cx * 8 + 1, cy * 8 + 1, 1))
					fields++
		offshore_check(fields == 1366, "about one sea square in three holds oil ([fields] of 4096)")

		var/turf/dry = new /turf/floor/beach/water/deep/saltwater(locate(2, 2, 1))
		var/turf/rich = new /turf/floor/beach/water/deep/saltwater(locate(10, 2, 1))
		var/turf/fresh = new /turf/floor/beach/water/deep(locate(11, 2, 1))
		offshore_check(offshore_oil_richness(rich) == 3 && !offshore_oil_richness(dry), "sea turfs read their square's field")
		offshore_check(!offshore_oil_richness(fresh), "deep fresh water holds no offshore oil")

		var/mob/builder = new /mob(rich)
		offshore_check(offshore_rig_build_refusal(builder, /obj/structure/oilwell) == null, "other recipes are not checked")
		offshore_check(findtext(offshore_rig_build_refusal(builder, /obj/structure/oilwell/offshore), "bridge deck"), "open water without a deck is refused")
		new /obj/covers/bridge(rich)
		offshore_check(offshore_rig_build_refusal(builder, /obj/structure/oilwell/offshore) == null, "a deck over an oil field is accepted")
		builder.loc = dry
		new /obj/covers/bridge(dry)
		offshore_check(findtext(offshore_rig_build_refusal(builder, /obj/structure/oilwell/offshore), "no oil"), "a deck over dry seabed is refused")
		builder.loc = rich

		var/obj/item/weapon/reagent_containers/glass/barrel/B = new(rich)
		var/obj/structure/oilwell/offshore/R = new(rich)
		offshore_check(!R.base && !R.work_barrel && B.loc == rich, "rig needs no spring and leaves floor barrels alone on build")
		offshore_check(findtext(offshore_rig_build_refusal(builder, /obj/structure/oilwell/offshore), "already"), "a second rig on the same deck is refused")
		R.load_barrel()
		offshore_check(R.work_barrel == B && B.loc == R && R.extracting_now && R.extraction_pending, "loading a barrel starts drilling")
		R.extraction_due = 0
		sleep(21)
		offshore_check(B.reagents.get_reagent_amount("petroleum") == 30, "one cycle on a rich field pumps thirty petroleum")
		offshore_check(R.extraction_due >= world.time + 1100, "next cycle waits the full interval")
		var/list/saved = R.get_saved_vars()
		offshore_check(!("work_barrel" in saved) && !("extraction_pending" in saved) && !("extracting_now" in saved), "rig saves no runtime links")
		R.before_save()
		offshore_check(!R.extracting_now && B.loc == R, "save stops drilling and keeps the barrel inside")
		R.after_load()
		offshore_check(R.work_barrel == B && R.extracting_now, "load relinks the barrel and resumes")
		R.unload_barrel()
		sleep(21)
		offshore_check(B.loc == rich && !R.extracting_now && !R.extraction_pending, "unloading returns the barrel and settles")

		var/obj/item/weapon/reagent_containers/glass/barrel/D = new(dry)
		var/obj/structure/oilwell/offshore/dry_rig = new(dry)
		dry_rig.load_barrel()
		dry_rig.extraction_due = 0
		sleep(21)
		offshore_check(D.loc == dry_rig && !dry_rig.extracting_now && !D.reagents.total_volume, "a rig moved over dry seabed pumps nothing")
		qdel(dry_rig)
		offshore_check(D.loc == dry, "destroying a rig returns its barrel")
		qdel(R)
	catch(var/exception/e)
		offshore_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = offshore_failures, "runtime_error" = offshore_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
