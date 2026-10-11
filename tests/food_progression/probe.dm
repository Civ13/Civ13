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
	// Real custom persistence entry encoder/loader, with fresh temporary storage.
	W.stage = 3
	stage_before = W.stage
	W.water = 42
	W.plant_nutrition = 87
	W.radiation = 3
	var/savefile/F = new("crop.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, W)
	food_check(ref, "crop has a saved entry")
	map_storage.clear_bookkeeping()
	var/turf/floor/dirt/ploughed/restored_soil = new(locate(1,2,1))
	restored_soil.soil_nutrition = 150
	var/obj/structure/farming/plant/tomato/restored = map_storage.Load_Entry(F, ref, starting_loc = restored_soil)
	food_check(restored && restored.type == W.type && restored.loc == restored_soil, "crop type and location restored")
	food_check(restored.stage == W.stage && restored.water == 42 && restored.plant_nutrition == 87 && restored.radiation == 3, "crop scalar state restored")
	food_check(jointext(restored.biomes, ",") == jointext(W.biomes, ",") && jointext(restored.seasons, ",") == jointext(W.seasons, ","), "crop climate and season lists restored")
	W.vstatic = TRUE
	sleep(5)
	food_check(restored.stage == stage_before, "restored winter crop remains paused")
	season = "SPRING"
	sleep(5)
	food_check(restored.stage > stage_before, "restored crop resumes in spring")
	text2file("PASS: production planting, rejection, growth, harvest, seed return, season gating and crop entry save/load", "food_result.txt")
	del(world)
