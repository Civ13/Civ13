/obj/map_metadata/food_fixture/New()
	return
/mob/living/human/food_fixture/New()
	return
/mob/living/human/food_fixture/adaptStat(stat, amount)
	return
/proc/food_check(condition, message)
	if (!condition)
		text2file("FAIL: [message]", "food_result.txt")
		del(world)
		sleep(1) // Stop this caller while world shutdown completes.
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 3
	maxz = 1
	fps = 20
	turf = /turf
/world/New()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	initialize_chemical_reagents()
	initialize_chemical_reactions()
	map = new /obj/map_metadata/food_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	season = "SUMMER"
	var/turf/floor/dirt/ploughed/T = new(locate(2,2,1))
	T.soil_nutrition = 150
	var/area/A = get_area(T)
	A.climate = "temperate"
	A.location = 1
	new /turf/floor/beach/water(locate(3,2,1))
	var/mob/living/human/H = new /mob/living/human/food_fixture(T)
	var/obj/item/stack/farming/seeds/tomato/S = new(T, 3)
	T.attackby(S, H)
	var/obj/structure/farming/plant/tomato/P = locate() in T
	food_check(P && S.amount == 2, "production planting consumes one seed")
	T.attackby(S, H)
	food_check(S.amount == 2, "occupied soil rejects planting without consuming seeds")
	var/turf/floor/dirt/D = new(locate(5,2,1))
	D.attackby(S,H)
	food_check(S.amount == 2 && !(locate(/obj/structure/farming/plant) in D), "unploughed soil rejects planting")
	// Generated source shortens only the growth wait.
	sleep(14)
	food_check(P && P.readyHarvest(), "summer crop reaches harvest stage")
	var/obj/item/weapon/material/kitchen/utensil/knife/K = new(T)
	P.attackby(K,H)
	food_check((locate(/obj/item/weapon/reagent_containers/food/snacks/grown/tomato) in T), "actual tomato produce spawned")
	var/returned = 0
	for (var/obj/item/stack/farming/seeds/tomato/R in T)
		if (R != S)
			returned += R.amount
	food_check(returned == 2, "harvest returns two tomato seeds")
	var/obj/structure/farming/plant/tomato/W = new(D)
	W.vstatic = TRUE
	var/turf/floor/dirt/ploughed/Wsoil = new(D)
	Wsoil.soil_nutrition = 150
	W.vstatic = FALSE
	season = "WINTER"
	W.growth()
	var/stage_before = W.stage
	sleep(5)
	food_check(W.stage == stage_before, "temperate winter pauses tomato development")
	season = "SPRING"
	sleep(5)
	food_check(W.stage > stage_before, "spring resumes tomato development")
	text2file("PASS: production planting, rejection, growth, harvest, seed return and season gating", "food_result.txt")
	del(world)
