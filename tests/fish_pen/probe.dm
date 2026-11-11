// Native fish pen probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives code/modules/1713/fish_pen.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/fish_pen_probe/New()
	map = src
/mob/living/fish_pen_tester/New()
	return
var/fp_failures = 0
var/fp_runtime_error = FALSE
/proc/fp_check(condition, label)
	if (!condition)
		fp_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	fp_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/fish_pen_probe
		fish_pen_checks()
	catch(var/exception/e)
		fp_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = fp_failures, "runtime_error" = fp_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/fp_hold(mob/living/fish_pen_tester/U, obj/item/I)
	I.loc = U
	U.hand = TRUE
	U.l_hand = I

/proc/fp_cycles(obj/structure/fish_pen/P, n)
	for (var/i in 1 to n)
		P.fish_cycle(P.cycle_epoch)

/proc/fish_pen_checks()
	var/area/A = get_area(locate(1, 1, 1))
	A.location = AREA_OUTSIDE
	A.climate = "temperate"
	season = "SUMMER"
	var/turf/pond = locate(5, 5, 1)
	pond.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
	var/turf/shore = locate(4, 5, 1)
	shore.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/mob/living/fish_pen_tester/U = new(shore)
	var/obj/structure/fish_pen/P = new(shore)
	fp_check(!P.in_water() && P.icon_state == "crabcage0", "a pen on land is dry")
	var/obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon/S1 = new(U)
	fp_hold(U, S1)
	P.attackby(S1, U)
	fp_check(P.stock == 0 && !QDELETED(S1), "a dry pen refuses fish")
	P.loc = pond
	P.update_icon()
	fp_check(P.in_water() && P.icon_state == "crabcage1", "fresh water admits the pen")
	P.attackby(S1, U)
	var/obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon/S2 = new(U)
	fp_hold(U, S2)
	P.attackby(S2, U)
	fp_check(P.stock == 2 && QDELETED(S1) && QDELETED(S2) && P.fish_type == /obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon, "two salmon stock the pen")

	// Unfed fish do not breed, and die off.
	fp_cycles(P, 2)
	fp_check(P.stock == 2 && P.hungry_cycles == 2, "unfed fish do not breed")
	fp_cycles(P, 1)
	fp_check(P.stock == 1, "three unfed cycles cost a fish")
	var/obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon/S3 = new(U)
	fp_hold(U, S3)
	P.attackby(S3, U)

	// Feeding: grain, seeds by the seed, meat; capped.
	var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/G = new(U)
	fp_hold(U, G)
	P.attackby(G, U)
	fp_check(P.feed == 2 && QDELETED(G), "grain is feed")
	var/obj/item/stack/farming/seeds/wheat/Sd = new(U, 30)
	fp_hold(U, Sd)
	P.attackby(Sd, U)
	fp_check(P.feed == 20 && Sd.amount == 12, "seeds feed one each up to the cap, the rest stay")
	var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/G2 = new(U)
	fp_hold(U, G2)
	P.attackby(G2, U)
	fp_check(!QDELETED(G2), "a full feed store refuses more")

	// Fed fish breed up to the cap and eat half a portion each.
	fp_cycles(P, 1)
	fp_check(P.stock == 3 && P.feed == 19, "a fed pair breeds, eating one feed per two fish")
	P.feed = 100
	fp_cycles(P, 10)
	fp_check(P.stock == 8, "breeding stops at eight")
	var/before = P.feed
	P.feed = 100
	fp_cycles(P, 1)
	fp_check(P.stock == 8 && P.feed == 96, "a full pen still eats")
	P.feed = before

	// Winter outdoors: no breeding.
	P.stock = 2
	P.feed = 10
	season = "WINTER"
	fp_cycles(P, 1)
	fp_check(P.stock == 2, "no breeding outdoors in winter")
	season = "SUMMER"

	// Catching.
	var/obj/item/weapon/reagent_containers/food/snacks/rawfish/F = P.catch_fish(U)
	fp_check(istype(F, /obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon) && P.stock == 1, "catching gives the stocked species")
	P.catch_fish(U)
	fp_check(P.stock == 0 && isnull(P.catch_fish(U)), "an empty pen gives nothing")

	// Salt water and stale callbacks.
	P.stock = 3
	pond.ChangeTurf(/turf/floor/beach/water/shallowsaltwater, FALSE, FALSE)
	P.loc = locate(5, 5, 1)
	fp_check(!P.in_water(), "salt water does not count")
	fp_cycles(P, 1)
	fp_check(P.stock == 2, "fish die out of fresh water")
	fp_check(!P.fish_cycle(P.cycle_epoch - 1), "a stale callback is ignored")

	// Saving.
	var/list/saved = P.get_saved_vars()
	fp_check(("stock" in saved) && ("feed" in saved) && ("fish_type" in saved) && P.persistence_runtime_var("cycle_epoch"), "stock, feed and species are saved, the timer epoch is not")
	var/epoch = P.cycle_epoch
	P.after_load()
	fp_check(P.cycle_epoch == epoch + 1, "loading restarts the cycle")
	var/obj/item/weapon/reagent_containers/food/snacks/rawfish/cod/salted/SC = new(U)
	fp_check(!fish_pen_stock_ok(SC), "salted fish cannot stock a pen")
