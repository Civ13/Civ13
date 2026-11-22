// Native drug crop probe, included by tests/ecology_spawning/run_linux.py, never
// by the game DME. It drives the drug crops in farming.dm and their wild sources.
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/drugcrop_probe/New()
	map = src
/mob/living/human/drugcrop_probe/New()
	icon_update = FALSE // no species: skip body overlays when held items change
	return
var/drugcrop_failures = 0
var/drugcrop_runtime_error = FALSE
/proc/drugcrop_check(condition, label)
	if (!condition)
		drugcrop_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	drugcrop_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/drugcrop_probe
		season = "SUMMER"
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		drugcrop_harvest_checks()
		drugcrop_material_checks()
	catch(var/exception/e)
		drugcrop_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = drugcrop_failures, "runtime_error" = drugcrop_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// Every drug crop grows wild, harvests its own product and drops its own seed.
/proc/drugcrop_harvest_checks()
	var/list/products = list(
		/obj/structure/farming/plant/cannabis = /obj/item/stack/material/cannabis_fresh,
		/obj/structure/farming/plant/hemp = /obj/item/stack/material/hemp,
		/obj/structure/farming/plant/tobacco = /obj/item/stack/material/tobacco_green,
		/obj/structure/farming/plant/poppy = /obj/item/stack/material/poppy,
		/obj/structure/farming/plant/coca = /obj/item/stack/material/coca)
	var/x = 2
	for (var/path in products)
		var/turf/T = locate(x, 2, 1)
		x += 2
		var/obj/structure/farming/plant/P = new path(T)
		P.make_wild()
		drugcrop_check(P.wild && findtext(P.icon_state, "-harvest"), "[P.plant] grows wild with a harvest sprite")
		P.spawn_produce(0)
		P.spawn_seeds(0)
		var/product = products[path]
		drugcrop_check(locate(product) in T, "[P.plant] harvests [product]")
		drugcrop_check(locate(text2path("/obj/item/stack/farming/seeds/[P.plant]")) in T, "[P.plant] drops its own seeds")

// Fresh tops dry into smokable cannabis; hemp fibre is no longer contraband.
/proc/drugcrop_material_checks()
	var/turf/T = locate(20, 20, 1)
	var/obj/item/stack/material/cannabis_fresh/F = new(T, 3)
	drugcrop_check(F.material && F.material.name == "cannabis_fresh", "fresh cannabis has its material")
	drugcrop_check(F.dried_type == /obj/item/stack/material/cannabis, "fresh cannabis dries into dried cannabis")
	var/obj/item/stack/material/cannabis/D = new(locate(21, 20, 1), 2)
	drugcrop_check(D.material && D.material.name == "cannabis", "dried cannabis has its material")
	drugcrop_check(D.is_contraband, "dried cannabis is contraband")
	var/obj/item/stack/material/hemp/H = new(locate(22, 20, 1), 2)
	drugcrop_check(!H.is_contraband, "hemp fibre is not contraband")
