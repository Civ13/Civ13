// Native firefighting probe, included by tests/ecology_spawning/run_linux.py,
// never by the game DME. It drives the production handlers in
// code/modules/1713/firefighting.dm against real /obj/effect/fire.
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
/obj/map_metadata/fire_probe/New()
	map = src
/mob/living/fire_tester/New()
	return
var/fire_failures = 0
var/fire_runtime_error = FALSE
/proc/fire_check(condition, label)
	if (!condition)
		fire_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	fire_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/fire_probe
		fire_setup()
		fire_beater_checks()
		fire_soak_checks()
		fire_mob_checks()
		fire_smother_checks()
		fire_recipe_checks()
	catch(var/exception/e)
		fire_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = fire_failures, "runtime_error" = fire_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/fire_setup()
	var/area/A = get_area(locate(1, 1, 1))
	A.location = AREA_OUTSIDE
	A.climate = "temperate"
	A.weather = WEATHER_NONE
	for (var/turf/T in block(locate(1, 1, 1), locate(20, 20, 1)))
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)

/proc/fire_hold(mob/living/fire_tester/U, obj/item/I)
	I.loc = U
	U.hand = TRUE
	U.l_hand = I

/proc/fire_beater_checks()
	var/mob/living/fire_tester/U = new(locate(5, 5, 1))
	var/turf/site = locate(6, 5, 1)
	var/obj/item/weapon/fire_beater/B = new(null)
	fire_hold(U, B)
	fire_check(B.icon_state == "fire_beater" && B.swing_chance() == 50, "a new beater is dry with even odds")
	// A swing that fails leaves the fire and scorches a dry beater.
	var/obj/effect/fire/F = new(site)
	B.dry_chance = 0
	fire_check(B.resolve_attackby(F, U) && !QDELETED(F) && B.uses_left == 27, "a failed dry swing leaves the fire and costs three wear")
	// The swing cooldown stops a second swing in the same moment.
	B.dry_chance = 100
	fire_check(B.resolve_attackby(F, U) && !QDELETED(F) && B.uses_left == 27, "a swing inside the cooldown does nothing")
	B.next_beat = 0
	fire_check(B.resolve_attackby(F, U) && QDELETED(F) && B.uses_left == 24, "a successful swing puts the fire out")
	// Clicking the burning tile itself finds the fire on it.
	F = new(site)
	B.next_beat = 0
	fire_check(B.resolve_attackby(site, U) && QDELETED(F), "clicking the burning ground beats the fire on it")
	// Worn through: the beater is gone after its last swing.
	F = new(site)
	B.next_beat = 0
	B.uses_left = 2
	B.resolve_attackby(F, U)
	fire_check(QDELETED(B) && QDELETED(F), "a worn out beater falls apart after its last swing")
	fire_check(B.persistence_runtime_var("next_beat"), "the swing cooldown is not saved")
	var/obj/item/weapon/fire_beater/flapper/P = new(null)
	fire_check(P.dry_chance > 50 && P.wet_chance > 85 && P.uses_left > 30 && P.icon_state == "fire_flapper", "the flapper beats the branch on odds and wear")
	qdel(P)
	qdel(U)

/proc/fire_soak_checks()
	var/mob/living/fire_tester/U = new(locate(10, 5, 1))
	var/turf/water = locate(11, 5, 1)
	water.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
	var/turf/site = locate(10, 6, 1)
	var/obj/item/weapon/fire_beater/B = new(null)
	fire_hold(U, B)
	fire_check(B.resolve_attackby(water, U) && B.wet_swings == 6 && B.icon_state == "fire_beater_wet" && B.swing_chance() == 85, "open water soaks the beater")
	var/obj/effect/fire/F = new(site)
	B.wet_chance = 0
	B.resolve_attackby(F, U)
	fire_check(B.wet_swings == 5 && B.uses_left == 29, "a wet swing costs one wetness and one wear")
	B.wet_swings = 1
	B.next_beat = 0
	B.resolve_attackby(F, U)
	fire_check(B.wet_swings == 0 && B.icon_state == "fire_beater", "the beater dries out after its last wet swing")
	qdel(F)
	// A container needs enough water and gives it up.
	var/obj/item/weapon/reagent_containers/glass/bucket/K = new(site)
	fire_check(!B.try_soak(K, U) && B.wet_swings == 0, "an empty bucket does not wet the beater")
	K.reagents.add_reagent("water", 20)
	fire_check(B.try_soak(K, U) && B.wet_swings == 6 && K.reagents.get_reagent_amount("water") == 15, "a bucket of water soaks the beater and loses five units")
	fire_check(B.try_soak(K, U) && K.reagents.get_reagent_amount("water") == 15, "an already soaked beater takes no more water")
	qdel(K)
	// A well.
	B.wet_swings = 0
	var/obj/structure/sink/well/W = new(site)
	var/before = W.volume
	fire_check(B.try_soak(W, U) && B.wet_swings == 6 && W.volume == before - 5, "a well soaks the beater")
	B.wet_swings = 0
	W.dry = TRUE
	fire_check(!B.try_soak(W, U) && B.wet_swings == 0, "a dry well does not")
	B.wet_swings = 3
	B.icon_state = "fire_beater"
	B.after_load()
	fire_check(B.icon_state == "fire_beater_wet" && ("wet_swings" in B.get_saved_vars()) && ("uses_left" in B.get_saved_vars()), "wetness and wear are saved and the sprite follows after load")
	qdel(W)
	qdel(B)
	qdel(U)
	water.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)

/proc/fire_mob_checks()
	var/mob/living/fire_tester/U = new(locate(15, 5, 1))
	var/mob/living/fire_tester/V = new(locate(16, 5, 1))
	var/obj/item/weapon/fire_beater/B = new(null)
	fire_hold(U, B)
	U.a_intent = I_HELP
	V.fire_stacks = 5
	V.on_fire = TRUE
	fire_check(B.resolve_attackby(V, U) && V.on_fire && V.fire_stacks == 3, "a dry swing knocks two fire stacks off a burning person")
	B.next_beat = 0
	B.wet_swings = 6
	fire_check(B.resolve_attackby(V, U) && !V.on_fire && V.fire_stacks == 0, "a wet swing puts them out")
	qdel(B)
	qdel(V)
	qdel(U)

/proc/fire_smother_checks()
	var/mob/living/fire_tester/U = new(locate(5, 15, 1))
	var/turf/site = locate(6, 15, 1)
	var/obj/item/stack/material/pelt/P = new(null, 40, FALSE)
	fire_hold(U, P)
	var/out = 0
	for (var/i = 1, i <= 40, i++)
		var/obj/effect/fire/F = new(site)
		if (QDELETED(P))
			qdel(F)
			break
		P.resolve_attackby(F, U)
		if (QDELETED(F))
			out++
		else
			qdel(F)
	fire_check(out >= 3 && out <= 25, "a pelt smothers some fires and fails at others ([out] of 40)")
	fire_check(QDELETED(P) || P.amount < 40, "pelts scorch away while smothering")
	if (!QDELETED(P))
		qdel(P)
	var/obj/item/stack/material/leather/L = new(null, 5, FALSE)
	var/obj/effect/fire/F2 = new(site)
	fire_check(L.resolve_attackby(F2, U), "leather is accepted for smothering")
	qdel(F2)
	qdel(L)
	qdel(U)

/proc/fire_recipe_checks()
	build_research_tree()
	fire_check(get_recipe_node_req("/obj/item/weapon/fire_beater") == "primitive_construction", "the fire beater is Primitive Construction knowledge")
	fire_check(get_recipe_node_req("/obj/item/weapon/fire_beater/flapper") == "primitive_construction", "the fire flapper is Primitive Construction knowledge")
