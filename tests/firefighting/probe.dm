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
		fire_hook_checks()
		fire_pump_checks()
		fire_reel_checks()
		fire_extinguisher_checks()
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
	fire_check(get_recipe_node_req("/obj/item/weapon/fire_hook") == "iron_tools", "the fire hook is Iron Tools knowledge")
	fire_check(get_recipe_node_req("/obj/structure/fire_pump") == "wagons_ships", "the hand pump fire engine is Wagons & Ships knowledge")
	fire_check(get_recipe_node_req("/obj/structure/fire_pump/reel") == "machined_tools", "the fire hose reel is Machined Tools knowledge")

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
	fire_check(!F.attackby(E, U) && E.reagents.get_reagent_amount("water") == 60, "the extinguisher is not emptied by clicking the fire")
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

/obj/covers/fire_probe_wall
	wall = TRUE
	density = TRUE
	buildstackamount = 8
/obj/covers/fire_probe_wall/New()
	return
/obj/covers/fire_probe_floor
	buildstackamount = 5
/obj/covers/fire_probe_floor/New()
	return
/obj/covers/fire_probe_stone
	flammable = FALSE
	wall = TRUE
/obj/covers/fire_probe_stone/New()
	return
/obj/roof/fire_probe/New()
	return
/obj/roof/fire_probe/Destroy()
	loc = null
	return QDEL_HINT_QUEUE
/obj/roof/fire_probe/tile
	flammable = FALSE
/obj/structure/wild/smallbush/fire_probe/New()
	return
/obj/structure/wild/tree/fire_probe/New()
	return

/proc/fire_hook_wood(turf/T)
	. = 0
	for (var/obj/item/stack/material/wood/W in T)
		. += W.amount
		qdel(W)

/proc/fire_hook_checks()
	var/mob/living/fire_tester/U = new(locate(3, 10, 1))
	var/turf/site = locate(4, 10, 1)
	var/obj/item/weapon/fire_hook/H = new(null)
	fire_hold(U, H)
	var/obj/covers/fire_probe_wall/W = new(site)
	var/obj/covers/fire_probe_floor/F = new(site)
	var/obj/covers/fire_probe_stone/S = new(site)
	var/obj/roof/fire_probe/R = new(site)
	var/obj/roof/fire_probe/tile/RT = new(site)
	var/obj/structure/wild/smallbush/fire_probe/B = new(site)
	var/obj/structure/wild/tree/fire_probe/T = new(site)
	fire_check(fire_hook_base_time(W) == 50 && fire_hook_base_time(F) == 30 && fire_hook_base_time(R) == 25 && fire_hook_base_time(B) == 15, "walls, floors, roofs and brush have their own pull-down times")
	fire_check(!fire_hook_base_time(S) && !fire_hook_base_time(RT) && !fire_hook_base_time(T) && !fire_hook_base_time(site), "stone, tiled roofs, trees and bare ground are refused")
	fire_check(fire_hook_time(W) == 150 && fire_hook_time(R) == 75, "with no fire near, the work takes three times as long")
	var/obj/effect/fire/near = new(locate(7, 10, 1))
	fire_check(fire_hook_time(W) == 50 && fire_hook_time(B) == 15, "a fire three tiles away makes it urgent")
	qdel(near)
	near = new(locate(8, 10, 1))
	fire_check(fire_hook_time(W) == 150, "a fire four tiles away does not")
	qdel(near)
	fire_check(!H.pull_down(S, U) && !QDELETED(S) && !H.pull_down(T, U) && !QDELETED(T), "pulling at stone or a tree does nothing")
	fire_check(H.pull_down(W, U) && QDELETED(W) && fire_hook_wood(site) == 4, "a pulled-down wall gives back half its wood")
	fire_check(H.pull_down(R, U) && QDELETED(R), "a thatch roof comes down")
	fire_check(H.pull_down(B, U) && QDELETED(B), "brush is ripped out")
	near = new(site)
	fire_check(H.pull_down(F, U) && QDELETED(F) && fire_hook_wood(site) == 0, "a floor pulled out from under a fire gives nothing back")
	qdel(near)
	fire_check(H.persistence_runtime_var("hooking") && H.icon_state == "fire_hook", "the busy flag is not saved")
	qdel(S)
	qdel(RT)
	qdel(T)
	qdel(H)
	qdel(U)

/obj/covers/fire_probe_wall/solid
	opacity = TRUE

/proc/fire_pump_checks()
	var/mob/living/fire_tester/U = new(locate(3, 17, 1))
	var/obj/structure/fire_pump/P = new(locate(3, 18, 1))
	fire_check(P.water == 0 && P.max_water == 400 && !P.anchored && P.density, "a new engine is an empty tub that can be pulled")
	// Filling by bucket.
	var/obj/item/weapon/reagent_containers/glass/bucket/K = new(locate(2, 17, 1))
	K.reagents.add_reagent("petroleum", 10)
	fire_check(P.attackby(K, U) && P.water == 0 && K.reagents.get_reagent_amount("petroleum") == 10, "a bucket without water puts nothing in the tub")
	K.reagents.add_reagent("water", 60)
	fire_check(P.attackby(K, U) && P.water == 60 && K.reagents.get_reagent_amount("water") == 0 && K.reagents.get_reagent_amount("petroleum") == 10, "a bucket pours only its water into the tub")
	P.water = 390
	K.reagents.add_reagent("water", 60)
	fire_check(P.attackby(K, U) && P.water == 400 && K.reagents.get_reagent_amount("water") == 50, "a full tub leaves the rest in the bucket")
	fire_check(P.attackby(K, U) && P.water == 400 && K.reagents.get_reagent_amount("water") == 50, "a full tub takes no more")
	qdel(K)
	// Where a jet lands.
	fire_check(fire_jet_landing(U, locate(6, 17, 1)) == locate(6, 17, 1), "a jet lands on a tile three away")
	fire_check(fire_jet_landing(U, locate(12, 17, 1)) == locate(8, 17, 1), "a jet aimed too far lands five tiles out")
	fire_check(fire_jet_landing(U, U) == get_turf(U), "a jet at your own feet lands there")
	var/obj/covers/fire_probe_wall/solid/W = new(locate(5, 17, 1))
	fire_check(fire_jet_landing(U, locate(7, 17, 1)) == locate(4, 17, 1), "a wall stops the jet on the tile before it")
	qdel(W)
	// The nozzle and its jets.
	var/obj/item/weapon/fire_nozzle/N = P.get_nozzle()
	fire_check(N.loc == P && N.pump == P && P.get_nozzle() == N && !P.nozzle_out(), "the engine has one nozzle, stowed on it")
	fire_hold(U, N)
	fire_check(P.nozzle_out(), "a nozzle in hand is run out")
	var/turf/site = locate(7, 17, 1)
	var/obj/effect/fire/F = new(site)
	var/mob/living/fire_tester/V = new(site)
	V.fire_stacks = 5
	V.on_fire = TRUE
	P.water = 50
	N.afterattack(site, U, FALSE)
	fire_check(QDELETED(F) && !V.on_fire && P.water == 30, "a jet puts out the fire and the person where it lands for twenty water")
	F = new(site)
	N.afterattack(site, U, FALSE)
	fire_check(!QDELETED(F) && P.water == 30, "a second jet inside the cooldown does nothing")
	N.next_spray = 0
	N.afterattack(site, U, TRUE)
	fire_check(!QDELETED(F) && P.water == 30, "an adjacent click is left to the click handler")
	fire_check(N.resolve_attackby(site, U) && QDELETED(F) && P.water == 10, "the click handler sprays too")
	F = new(site)
	N.next_spray = 0
	fire_check(!N.spray(site, U) && !QDELETED(F) && P.water == 10, "too little water throws no jet")
	// Splash: a jet reaches the tiles around where it lands, by chance.
	P.water = 400
	var/obj/effect/fire/side = new(locate(7, 16, 1))
	var/tries = 0
	while (!QDELETED(side) && tries < 12)
		tries++
		N.next_spray = 0
		N.spray(site, U)
	fire_check(QDELETED(F) && QDELETED(side), "jets splash the fire on the next tile out")
	// The hose.
	P.water = 400
	N.next_spray = 0
	U.loc = locate(3, 14, 1)
	fire_check(!N.spray(locate(3, 12, 1), U) && N.loc == P && P.water == 400 && !P.nozzle_out(), "four tiles from the engine the hose pulls the nozzle back")
	fire_hold(U, N)
	U.loc = locate(3, 15, 1)
	N.next_spray = 0
	fire_check(N.spray(locate(3, 12, 1), U) && P.water == 380, "three tiles from the engine it still sprays")
	P.Move(locate(4, 19, 1))
	fire_check(N.loc == P, "pulling the engine away takes the nozzle with it")
	fire_hold(U, N)
	U.loc = locate(4, 18, 1)
	fire_check(P.attackby(N, U) && N.loc == P, "the nozzle hangs back on the engine")
	fire_check(P.persistence_runtime_var("nozzle") && !N.should_save && P.should_save, "the engine is saved with its water, the nozzle is not")
	qdel(P)
	fire_check(QDELETED(N), "the nozzle goes with its engine")
	qdel(V)
	qdel(U)

/obj/structure/sink/fire_probe/New()
	return
/obj/structure/sink/puddle/fire_probe/New()
	return

/proc/fire_reel_checks()
	var/mob/living/fire_tester/U = new(locate(14, 17, 1))
	var/obj/structure/fire_pump/reel/R = new(locate(14, 18, 1))
	fire_check(R.anchored && !R.density && R.hose_length == 7 && R.icon_state == "fire_hose_reel", "a hose reel is fixed in place with a long hose")
	var/obj/item/weapon/fire_nozzle/N = R.get_nozzle()
	fire_hold(U, N)
	R.update_icon()
	fire_check(R.icon_state == "fire_hose_reel_out", "the drum shows bare while the hose is out")
	var/turf/site = locate(17, 17, 1)
	var/obj/effect/fire/F = new(site)
	fire_check(R.water_left() == 0 && !N.spray(site, U) && !QDELETED(F), "with no sink or well beside it the reel gives no water")
	var/obj/structure/sink/puddle/fire_probe/P = new(locate(15, 18, 1))
	P.volume = 500
	fire_check(R.water_left() == 0, "a puddle is not a water supply")
	qdel(P)
	var/obj/structure/sink/fire_probe/far = new(locate(16, 18, 1))
	far.volume = 500
	fire_check(R.water_left() == 0, "a sink two tiles away is not plumbed in")
	qdel(far)
	var/obj/structure/sink/fire_probe/S = new(locate(15, 18, 1))
	S.volume = 30
	N.next_spray = 0
	fire_check(R.water_left() == 30 && N.spray(site, U) && QDELETED(F) && S.volume == 10, "a jet draws twenty water from the sink beside the reel")
	F = new(site)
	N.next_spray = 0
	fire_check(!N.spray(site, U) && !QDELETED(F) && S.volume == 10, "a sink that is nearly dry gives no jet")
	S.volume = 100
	S.dry = TRUE
	fire_check(R.water_left() == 0, "a dried-up sink gives nothing")
	S.dry = FALSE
	var/obj/item/weapon/reagent_containers/glass/bucket/K = new(locate(13, 17, 1))
	K.reagents.add_reagent("water", 40)
	R.attackby(K, U)
	fire_check(R.water == 0 && K.reagents.get_reagent_amount("water") == 40, "a reel has no tub to pour water into")
	qdel(K)
	// The hose is long but not endless.
	U.loc = locate(7, 18, 1)
	N.next_spray = 0
	fire_check(N.spray(locate(5, 18, 1), U) && S.volume == 80, "seven tiles from the reel it still sprays")
	U.loc = locate(6, 18, 1)
	N.next_spray = 0
	fire_check(!N.spray(locate(5, 18, 1), U) && N.loc == R && R.icon_state == "fire_hose_reel", "eight tiles out the hose winds back onto the drum")
	qdel(F)
	qdel(S)
	qdel(R)
	qdel(U)

/proc/fire_extinguisher_checks()
	var/mob/living/fire_tester/U = new(locate(3, 3, 1))
	var/obj/item/weapon/reagent_containers/glass/fire_extinguisher/E = new(null)
	fire_hold(U, E)
	fire_check(E.reagents.get_reagent_amount("water") == 60 && E.max_range == 3, "a new extinguisher is full, twelve bursts")
	var/obj/item/weapon/reagent_containers/glass/fire_extinguisher/ww2/E2 = new(null)
	var/obj/item/weapon/reagent_containers/glass/fire_extinguisher/empty/E3 = new(null)
	fire_check(E2.reagents.get_reagent_amount("water") == 60 && E3.reagents.total_volume == 0, "the old pattern is full too and a newly made one is empty")
	qdel(E2)
	qdel(E3)
	var/obj/effect/fire/F1 = new(locate(4, 3, 1))
	var/obj/effect/fire/F3 = new(locate(6, 3, 1))
	var/obj/effect/fire/F4 = new(locate(7, 3, 1))
	var/mob/living/fire_tester/V = new(locate(5, 3, 1))
	V.fire_stacks = 5
	V.on_fire = TRUE
	fire_check(E.process_foam(U, EAST, locate(9, 3, 1)) && QDELETED(F1) && QDELETED(F3) && !QDELETED(F4) && !V.on_fire, "a burst clears three tiles in a line and anyone burning on them")
	fire_check(E.reagents.get_reagent_amount("water") == 55 && (locate(/obj/effect/decal/cleanable/foam) in locate(6, 3, 1)) && !(locate(/obj/effect/decal/cleanable/foam) in locate(7, 3, 1)), "it uses five water and leaves foam only where it reached")
	// A wall stops the burst.
	var/obj/covers/fire_probe_wall/solid/W = new(locate(3, 5, 1))
	var/obj/effect/fire/behind = new(locate(3, 6, 1))
	var/obj/effect/fire/before = new(locate(3, 4, 1))
	E.process_foam(U, NORTH, locate(3, 6, 1))
	fire_check(QDELETED(before) && !QDELETED(behind), "a wall stops the burst")
	qdel(W)
	qdel(behind)
	// Clicks that are not out in the world do nothing.
	var/obj/item/weapon/fire_beater/held = new(U)
	E.lastfire = 0
	E.fire(U, EAST, held)
	fire_check(E.reagents.get_reagent_amount("water") == 50, "clicking something you carry does not spray")
	qdel(held)
	E.reagents.clear_reagents()
	F1 = new(locate(4, 3, 1))
	fire_check(!E.process_foam(U, EAST, F1) && !QDELETED(F1), "an empty extinguisher does nothing")
	qdel(F1)
	qdel(F4)
	qdel(V)
	qdel(E)
	qdel(U)
