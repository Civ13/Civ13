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
		fire_water_checks()
		fire_blanket_checks()
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

/proc/fire_water_checks()
	var/mob/living/fire_tester/U = new(locate(10, 15, 1))
	var/turf/site = locate(11, 15, 1)
	fire_check(fire_douse_chance(0) == 0 && fire_douse_chance(10) == 20 && fire_douse_chance(50) == 100 && fire_douse_chance(120) == 100, "douse odds scale with the water and cap at certain")
	var/obj/item/weapon/reagent_containers/glass/bucket/K = new(site)
	var/obj/effect/fire/F = new(site)
	fire_check(!F.attackby(K, U) && !QDELETED(F), "an empty bucket does nothing to a fire")
	K.reagents.add_reagent("petroleum", 20)
	fire_check(!F.attackby(K, U) && K.reagents.get_reagent_amount("petroleum") == 20, "a bucket without water is not emptied")
	K.reagents.add_reagent("water", 60)
	fire_check(F.attackby(K, U) && QDELETED(F) && K.reagents.get_reagent_amount("water") == 0 && K.reagents.get_reagent_amount("petroleum") == 20, "sixty water always puts the fire out and only the water is used")
	// A splash of water is used up and seldom works.
	var/out = 0
	for (var/i = 1, i <= 40, i++)
		F = new(site)
		K.reagents.add_reagent("water", 5)
		F.attackby(K, U)
		if (QDELETED(F))
			out++
		else
			qdel(F)
	fire_check(out <= 15 && K.reagents.get_reagent_amount("water") == 0, "five water rarely puts a fire out ([out] of 40)")
	K.reagents.clear_reagents()
	// A full bucket splashes the neighbours and puts out a burning person.
	var/splashed = 0
	for (var/i = 1, i <= 10, i++)
		F = new(site)
		var/list/ring = list()
		for (var/turf/T in orange(1, site))
			ring += new /obj/effect/fire(T)
		K.reagents.add_reagent("water", 120)
		F.attackby(K, U)
		for (var/obj/effect/fire/N in ring)
			if (QDELETED(N))
				splashed++
			else
				qdel(N)
	fire_check(splashed >= 15 && splashed <= 65, "a full bucket splashes about half the neighbouring fires ([splashed] of 80)")
	var/mob/living/fire_tester/V = new(site)
	V.fire_stacks = 5
	V.on_fire = TRUE
	F = new(site)
	K.reagents.add_reagent("water", 120)
	F.attackby(K, U)
	fire_check(!V.on_fire, "a full bucket puts out a person burning on the tile")
	var/obj/item/weapon/reagent_containers/glass/fire_extinguisher/E = new(site)
	F = new(site)
	fire_check(!F.attackby(E, U) && E.reagents.get_reagent_amount("water") == 30, "the extinguisher is not emptied by clicking the fire")
	qdel(F)
	qdel(E)
	qdel(V)
	qdel(K)
	qdel(U)

/proc/fire_blanket_checks()
	var/mob/living/fire_tester/U = new(locate(15, 15, 1))
	var/turf/site = locate(16, 15, 1)
	var/turf/water = locate(15, 16, 1)
	water.ChangeTurf(/turf/floor/beach/water, FALSE, FALSE)
	var/obj/item/weapon/bedsheet/S = new(null)
	fire_hold(U, S)
	fire_check(S.resolve_attackby(water, U) && S.wet_uses == 4, "open water soaks a bedsheet")
	var/out = 0
	for (var/i = 1, i <= 40, i++)
		var/obj/effect/fire/F = new(site)
		S.wet_uses = 4
		S.next_smother = 0
		S.resolve_attackby(F, U)
		if (QDELETED(F))
			out++
		else
			qdel(F)
	fire_check(out >= 24 && !QDELETED(S) && S.wet_uses == 3, "a wet blanket smothers most fires and never burns ([out] of 40)")
	var/mob/living/fire_tester/V = new(site)
	U.a_intent = I_HELP
	V.fire_stacks = 9
	V.on_fire = TRUE
	S.next_smother = 0
	fire_check(S.resolve_attackby(V, U) && !V.on_fire && S.wet_uses == 2, "a wet blanket puts a burning person out in one go")
	S.wet_uses = 0
	V.fire_stacks = 5
	V.on_fire = TRUE
	S.next_smother = 0
	S.resolve_attackby(V, U)
	fire_check(V.on_fire && V.fire_stacks == 3, "a dry sheet only knocks the flames back")
	var/burned = 0
	for (var/i = 1, i <= 40, i++)
		var/obj/item/weapon/bedsheet/D = new(null)
		var/obj/effect/fire/F = new(site)
		D.resolve_attackby(F, U)
		if (QDELETED(D))
			burned++
		else
			qdel(D)
		if (!QDELETED(F))
			qdel(F)
	fire_check(burned >= 2 && burned <= 22, "dry sheets sometimes burn up ([burned] of 40)")
	var/obj/item/weapon/reagent_containers/glass/bucket/K = new(site)
	K.reagents.add_reagent("water", 30)
	fire_check(S.try_soak_blanket(K, U) && S.wet_uses == 4 && K.reagents.get_reagent_amount("water") == 20, "a bucket soaks the sheet for ten water")
	fire_check(("wet_uses" in S.get_saved_vars()) && S.persistence_runtime_var("next_smother"), "wetness is saved, the cooldown is not")
	qdel(K)
	qdel(V)
	qdel(S)
	qdel(U)
	water.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
