/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 2
	turf = /turf/floor/plating
	area = /area
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/mob/yeast_tester/New()
	return

/obj/map_metadata/yeast_tester/New()
	return

/proc/yeast_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)
	world.log << "YEAST PASS: [message]"

// Runs the production oven conversion on a single item and returns the
// product, which the oven ejects onto its own turf.
/proc/yeast_bake(obj/structure/oven/O, obj/item/I)
	var/turf/T = get_turf(O)
	var/list/before = list()
	for (var/obj/item/old in T)
		before += old
	I.loc = O
	O.process()
	var/list/products = list()
	for (var/obj/item/product in T)
		if (!(product in before))
			products += product
	yeast_assert(products.len == 1 && I.loc != T && !O.contents.len, "oven consumes [I.name] into one product")
	return products[1]

/proc/yeast_load(datum/D, turf/site, filename)
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/savefile/F = new(filename)
	F["/format_version"] << 2
	var/id = map_storage.BuildVarDirectory(F,D,1)
	F.Flush()
	F = null
	F = new(filename)
	map_storage.clear_bookkeeping()
	var/datum/loaded = map_storage.Load_Entry(F,id,starting_loc = site)
	loaded.after_load()
	return loaded

/world/New()
	OpenPort("none")
	sleep(1)
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		text2file(json_encode(list("byond_version" = world.byond_version, "byond_build" = world.byond_build, "dimensions" = "8x8x2", "network" = "closed", "startup" = "disabled")), "fixture.json")
		var/turf/site = locate(3,3,1)
		map = new /obj/map_metadata/yeast_tester
		var/mob/yeast_tester/U = new(site)
		var/obj/structure/oven/O = new(locate(6,6,1))

		var/obj/item/weapon/reagent_containers/food/snacks/dough/plain = new(site)
		yeast_assert(!plain.leavened && !plain.check_risen(), "fresh dough is unleavened")
		yeast_assert(istype(yeast_bake(O, plain), /obj/item/weapon/reagent_containers/food/snacks/flatbread), "unleavened dough bakes flat")

		var/obj/item/weapon/reagent_containers/food/condiment/enzyme/Y = new(site)
		var/start_yeast = Y.reagents.get_reagent_amount("enzyme")
		var/obj/item/weapon/reagent_containers/food/snacks/dough/yeasted = new(site)
		yeast_assert(yeasted.attackby(Y, U) && yeasted.leavened && !yeasted.risen, "yeast is kneaded into dough")
		yeast_assert(Y.reagents.get_reagent_amount("enzyme") == start_yeast - 5, "kneading consumes five units of yeast")
		yeast_assert(yeasted.rise_ready_at > world.time && !yeasted.check_risen(), "yeasted dough must rise before baking")
		yeast_assert(yeasted.attackby(Y, U) && Y.reagents.get_reagent_amount("enzyme") == start_yeast - 5, "second yeast addition is refused without payment")

		var/obj/item/weapon/reagent_containers/glass/beaker/trace = new(site)
		trace.reagents.add_reagent("enzyme", 4)
		var/obj/item/weapon/reagent_containers/food/snacks/dough/short = new(site)
		short.attackby(trace, U)
		yeast_assert(!short.leavened && trace.reagents.get_reagent_amount("enzyme") == 4, "trace yeast cannot leaven dough")

		var/obj/item/weapon/reagent_containers/food/snacks/dough/early = new(site)
		early.attackby(Y, U)
		yeast_assert(istype(yeast_bake(O, early), /obj/item/weapon/reagent_containers/food/snacks/flatbread), "unrisen yeasted dough bakes flat")

		yeast_assert("rise_ready_at" in yeasted.vars, "rise deadline var present")
		yeast_assert(!("rise_ready_at" in yeasted.get_saved_vars()), "rise deadline excluded")
		var/obj/item/weapon/reagent_containers/food/snacks/dough/restored = yeast_load(yeasted, site, "rising.sav")
		yeast_assert(restored.leavened && !restored.risen && restored.rise_ready_at > world.time, "unrisen dough restarts rising after load")
		qdel(yeasted)

		restored.rise_ready_at = world.time
		yeast_assert(restored.check_risen() && restored.risen && restored.name == "risen dough", "dough rises once its deadline passes")
		var/obj/item/weapon/reagent_containers/food/snacks/dough/risen_copy = yeast_load(restored, site, "risen.sav")
		yeast_assert(risen_copy.risen && risen_copy.check_risen(), "risen dough native disk round trip")
		qdel(risen_copy)
		yeast_assert(istype(yeast_bake(O, restored), /obj/item/weapon/reagent_containers/food/snacks/sliceable/bread), "risen dough bakes a loaf")
		text2file("PASS: yeast leavening, baking and native disk round trips", "result.txt")
	catch (var/exception/E)
		world.log << "YEAST exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()
