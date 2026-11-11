// Native hay probe, included by tests/ecology_spawning/run_linux.py, never by
// the game DME. It drives the production handlers in code/modules/1713/hay.dm.
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
/obj/map_metadata/hay_probe/New()
	map = src
/mob/living/hay_tester/New()
	return
/mob/living/simple_animal/cattle/cow/hay_tester/New()
	return
/mob/living/simple_animal/cattle/cow/hay_tester/crush()
	return
var/hay_failures = 0
var/hay_runtime_error = FALSE
/proc/hay_check(condition, label)
	if (!condition)
		hay_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	hay_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/hay_probe
		hay_drying_checks()
		hay_bale_checks()
		hay_feeding_checks()
	catch(var/exception/e)
		hay_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = hay_failures, "runtime_error" = hay_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/hay_setup()
	var/area/A = get_area(locate(1, 1, 1))
	A.location = AREA_OUTSIDE
	A.climate = "temperate"
	A.weather = WEATHER_NONE
	for (var/turf/T in block(locate(1, 1, 1), locate(20, 20, 1)))
		T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
	return A

/proc/hay_hold(mob/living/hay_tester/U, obj/item/I)
	I.loc = U
	U.hand = TRUE
	U.l_hand = I

/proc/hay_count(turf/T, path)
	. = 0
	for (var/obj/item/stack/S in T)
		if (istype(S, path))
			. += S.amount

/proc/hay_drying_checks()
	var/area/A = hay_setup()
	var/turf/stand = locate(5, 5, 1)
	var/turf/site = locate(6, 5, 1)
	var/mob/living/hay_tester/U = new(stand)
	var/obj/item/stack/grass_cuttings/G = new(null, 5, FALSE)
	hay_hold(U, G)
	// Grass turf overrides discard the return value; the spread itself is checked.
	site.attackby(G, U)
	var/obj/structure/hay_drying/D = locate() in site
	hay_check(D && D.portions == 5 && QDELETED(G), "all five cuttings are spread on the ground")
	hay_check(D && D.icon_state == "drying_grass", "fresh drying grass sprite")
	var/old_epoch = D.drying_epoch
	A.weather = WEATHER_WET
	D.dry_step(D.drying_epoch)
	hay_check(D.dry_steps == 0, "rain under open sky stops drying")
	var/obj/roof/R = new(site)
	D.dry_step(D.drying_epoch)
	hay_check(D.dry_steps == 1, "a roof keeps the grass drying in rain")
	qdel(R)
	A.weather = WEATHER_NONE
	D.dry_step(D.drying_epoch)
	D.dry_step(D.drying_epoch)
	hay_check(D.icon_state == "drying_grass_half", "half-dry sprite at half progress")
	hay_check(!D.dry_step(old_epoch - 1), "a stale drying callback is ignored")
	hay_check(D.persistence_runtime_var("drying_epoch") && ("portions" in D.get_saved_vars()) && ("dry_steps" in D.get_saved_vars()) && !("drying_epoch" in D.get_saved_vars()), "progress is saved, the callback epoch is not")
	var/before = D.drying_epoch
	D.after_load()
	hay_check(!QDELETED(D) && D.dry_steps == 3 && D.drying_epoch == before + 1, "a loaded batch resumes with its progress")
	// Adding fresh grass restarts the drying.
	var/obj/item/stack/grass_cuttings/more = new(null, 3, FALSE)
	hay_hold(U, more)
	D.attackby(more, U)
	hay_check(D.portions == 8 && D.dry_steps == 0 && QDELETED(more), "fresh cuttings join the batch and restart drying")
	for (var/i = 1, i <= 6, i++)
		D.dry_step(D.drying_epoch)
	hay_check(QDELETED(D) && hay_count(site, /obj/item/stack/hay) == 8 && !hay_count(site, /obj/item/stack/grass_cuttings), "six dry checks turn eight cuttings into eight hay")
	for (var/obj/item/I in site)
		qdel(I)
	// Picking the grass up returns the cuttings and drops the progress.
	var/obj/item/stack/grass_cuttings/again = new(null, 4, FALSE)
	hay_hold(U, again)
	site.attackby(again, U)
	D = locate() in site
	D.dry_step(D.drying_epoch)
	U.l_hand = null
	D.attack_hand(U)
	hay_check(QDELETED(D) && hay_count(U, /obj/item/stack/grass_cuttings) + hay_count(stand, /obj/item/stack/grass_cuttings) + hay_count(site, /obj/item/stack/grass_cuttings) == 4, "picking drying grass up returns every cutting")
	for (var/obj/item/I in U)
		qdel(I)
	for (var/obj/item/I in stand)
		qdel(I)
	// Water and distance are refused without paying.
	var/turf/water = locate(4, 5, 1)
	water.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
	var/obj/item/stack/grass_cuttings/wet = new(null, 2, FALSE)
	hay_hold(U, wet)
	water.attackby(wet, U)
	hay_check(!(locate(/obj/structure/hay_drying) in water) && wet.amount == 2, "water is refused")
	var/turf/far = locate(9, 5, 1)
	far.attackby(wet, U)
	hay_check(!(locate(/obj/structure/hay_drying) in far) && wet.amount == 2, "distant ground is refused")
	qdel(wet)
	qdel(U)

/proc/hay_bale_checks()
	hay_setup()
	var/turf/stand = locate(10, 10, 1)
	var/turf/front = locate(10, 11, 1)
	var/mob/living/hay_tester/U = new(stand)
	U.dir = NORTH
	var/obj/item/stack/hay/H = new(null, 12, FALSE)
	hay_hold(U, H)
	hay_check(H.tie_hay_bale(U), "twelve hay tie a bale")
	var/obj/structure/hay_bale/B = locate() in front
	hay_check(B && B.hay_left == 10 && H.amount == 2 && B.density, "the dense bale stands in front with ten hay")
	hay_check(!H.tie_hay_bale(U) && H.amount == 2, "two hay are not enough for a bale")
	hay_check(!H.bundle_thatch(U) && H.amount == 2, "thatch needs roofing knowledge")
	U.l_hand = null
	for (var/i = 1, i <= 6, i++)
		B.attack_hand(U)
	hay_check(B.hay_left == 4 && B.icon_state == "hay_bale_half", "hay comes off the bale one portion at a time")
	// The plain tester has no hands, so taken hay falls beside the bale.
	var/taken = hay_count(U, /obj/item/stack/hay) - H.amount + hay_count(stand, /obj/item/stack/hay) + hay_count(front, /obj/item/stack/hay)
	hay_check(taken == 6, "six portions reached the worker")
	hay_hold(U, H)
	B.attackby(H, U)
	hay_check(B.hay_left == 6 && QDELETED(H) && B.icon_state == "hay_bale", "hay stuffed back into the bale")
	for (var/i = 1, i <= 6, i++)
		B.take_hay(1)
	hay_check(QDELETED(B), "an empty bale is gone")
	for (var/obj/item/I in U)
		qdel(I)
	for (var/obj/item/I in stand)
		qdel(I)
	for (var/obj/item/I in front)
		qdel(I)
	qdel(U)

/proc/hay_feeding_checks()
	hay_setup()
	var/turf/stand = locate(15, 15, 1)
	var/mob/living/hay_tester/U = new(stand)
	var/mob/living/simple_animal/cattle/cow/hay_tester/C = new(locate(16, 15, 1))
	C.stat = CONSCIOUS
	C.herbivore = 1
	C.simplehunger = 100
	var/obj/item/stack/hay/H = new(null, 3, FALSE)
	hay_hold(U, H)
	C.attackby(H, U)
	hay_check(C.simplehunger == 650 && H.amount == 2, "a hungry cow eats one hay by hand")
	C.simplehunger = 900
	C.attackby(H, U)
	hay_check(H.amount == 2, "a full cow refuses hay")
	C.simplehunger = 100
	C.herbivore = 0
	C.attackby(H, U)
	hay_check(H.amount == 2 && C.simplehunger == 100, "a non-grazing animal refuses hay")
	C.herbivore = 1
	var/obj/structure/hay_bale/B = new(locate(16, 16, 1))
	hay_check(C.eat_nearby_hay() && B.hay_left == 9 && C.simplehunger == 650, "a grazing animal eats from a bale next to it")
	qdel(B)
	H.loc = locate(17, 15, 1)
	U.l_hand = null
	C.simplehunger = 100
	hay_check(C.eat_nearby_hay() && H.amount == 1, "a grazing animal eats hay lying next to it")
	qdel(H)
	qdel(C)
	qdel(U)
