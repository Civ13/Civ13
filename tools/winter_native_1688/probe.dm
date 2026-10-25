// Prepared only. Full production sources; parent generator isolates startup.
// No world/New, Error or Topic wrapper here. No native execution is authorized.
/world
	hub = ""
	hub_password = ""
	visibility = 0
	maxx = 8
	maxy = 4
	maxz = 1
	turf = /turf/floor/plating
	area = /area/caribbean

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/client/New()
	del(src)
	return

/obj/map_metadata/winter_tester/New()
	return

/mob/living/human/winter_tester/New()
	return

/mob/living/human/winter_tester/adaptStat(stat, amount)
	return

// The crop predicate needs only an actual roof subtype in the turf. Suppress
// roof topology, collapse timers and area reconstruction, which are not tested.
/obj/roof/winter_tester/New()
	return

/obj/roof/winter_tester/Destroy()
	return QDEL_HINT_HARDDEL_NOW

/proc/winter_check(condition, message)
	return winter_record(condition, message)

/proc/winter_setup()
	world.OpenPort("none")
	winter_check(!world.port, "fixture has no open port")
	winter_check(!world.OpenPort(12345) && !world.port, "fixture refuses reopening its port")
	if (config)
		config.webhook_can_fire = FALSE
	if (!chemical_reagents_list)
		initialize_chemical_reagents()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	map = new /obj/map_metadata/winter_tester
	map.ID = MAP_NOMADS_EUROPE
	map.heat_wave = FALSE
	season = "WINTER"
	var/area/A = get_area(locate(2,2,1))
	A.location = AREA_OUTSIDE
	A.climate = "temperate"
	A.icon_state = ""
	A.is_void_area = FALSE

// Direct real stage calls are bounded test work, not elapsed growth-time proof.
/proc/winter_advance_until(obj/structure/farming/plant/P, target_stage)
	for (var/attempt = 1, attempt <= 512 && P.stage < target_stage, attempt++)
		P.stageGrowth()
	return P.stage == target_stage

/proc/winter_seed_total(turf/T, seed_type)
	var/total = 0
	for (var/obj/item/stack/farming/seeds/S in T)
		if (S.type == seed_type)
			total += S.amount
	return total

/proc/winter_food_count(turf/T, food_type)
	var/total = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/grown/F in T)
		if (F.type == food_type)
			total++
	return total

/proc/winter_fixture()
	var/start_time = world.time
	var/list/turnip_states = icon_states('icons/farming/pocket_stronghold_turnip.dmi')
	var/list/plump_states = icon_states('icons/farming/pocket_stronghold_plump_helmet.dmi')
	for (var/state_suffix in list("", "-seeds", "-grow1", "-grow2", "-grow3", "-grow4", "-grow5", "-grow6", "-harvest", "-dead"))
		winter_check(("turnip[state_suffix]" in turnip_states), "turnip native resource contains state [state_suffix]")
		winter_check(("plump_helmet[state_suffix]" in plump_states), "plump native resource contains state [state_suffix]")
	var/mob/living/human/H = new /mob/living/human/winter_tester(locate(1,2,1))
	var/obj/item/weapon/material/kitchen/utensil/knife/K = new(H)
	var/turf/floor/dirt/ploughed/T = new(locate(2,2,1))
	var/area/A = get_area(T)
	var/obj/item/stack/farming/seeds/turnip/S = new(H, 3)
	A.location = AREA_INSIDE
	T.attackby(S, H)
	winter_check(S.amount == 3 && !(locate(/obj/structure/farming/plant/turnip) in T), "turnip indoor sowing rejects before seed debit")
	A.location = AREA_OUTSIDE
	var/obj/roof/winter_tester/R = new(T)
	T.attackby(S, H)
	winter_check(S.amount == 3 && !(locate(/obj/structure/farming/plant/turnip) in T), "turnip roofed sowing rejects before seed debit")
	qdel(R)
	winter_check(!(locate(/obj/roof) in T), "fixture removes roof predicate object")
	T.attackby(S, H)
	var/obj/structure/farming/plant/turnip/P = locate() in T
	winter_check(P && S.amount == 2, "turnip sowing creates crop and spends exactly one seed")
	// Keep constructor-owned delayed growth quiescent; direct production helpers
	// below remain real. The final guard verifies no 600-tick growth wait elapsed.
	P.vstatic = TRUE
	T.attackby(S, H)
	winter_check(S.amount == 2, "occupied turnip plot does not spend another seed")
	winter_check(P.icon_state == "turnip-grow1", "turnip constructor selects existing growth sprite")
	winter_check(P.winter_hardy && P.max_water == 90 && ("WINTER" in P.seasons), "turnip native defaults opt into winter and bounded water")
	A.icon_state = "snow_storm"
	P.stage = 1
	P.water = 60
	P.water_proc()
	winter_check(P.stage == 1 && P.water == 45, "turnip survives snowstorm while paying water")
	P.water = 15
	P.water_proc()
	winter_check(P.stage == 11 && P.water == 0, "winter hardiness does not prevent drought death")
	winter_check(P.icon_state == "turnip-dead", "turnip drought selects existing dead sprite")
	P.stage = 1
	P.water = 60
	A.icon_state = "sandstorm"
	P.water_proc()
	winter_check(P.stage == 11, "winter hardiness does not prevent sandstorm death")
	A.icon_state = "rain"
	P.stage = 1
	P.water = 85
	P.water_proc()
	winter_check(P.water == 90, "turnip rain recharge stays bounded")
	A.icon_state = ""
	T.soil_nutrition = 150
	P.soil_nutrition_proc()
	winter_check(T.soil_nutrition == 147 && P.plant_nutrition == 147, "turnip charges existing soil cost")
	P.stage = 6
	R = new(T)
	P.stageGrowth()
	winter_check(P.stage == 6, "late roof blocks immature turnip growth")
	P.stage = 7
	for (var/age_step = 1, age_step <= 4, age_step++)
		P.stageGrowth()
	winter_check(P.stage == 11, "late roof cannot preserve ripe turnips indefinitely")
	qdel(R)
	P.vstatic = FALSE
	var/before_soil = T.soil_nutrition
	P.growth()
	winter_check(P.stage == 11 && T.soil_nutrition == before_soil, "dead turnip growth stops before consuming soil")
	P.vstatic = TRUE
	P.stage = 7
	P.plant_nutrition = 79 // No fertile bonus: exact one-item harvest oracle.
	P.attackby(K, H)
	winter_check(!(locate(/obj/structure/farming/plant/turnip) in T), "turnip harvest retires its paid crop")
	winter_check(winter_seed_total(T, /obj/item/stack/farming/seeds/turnip) == 2, "turnip harvest returns exactly two seeds")
	winter_check(winter_food_count(T, /obj/item/weapon/reagent_containers/food/snacks/grown/turnip) == 1, "turnip unfertilized harvest yields exactly one food")
	var/obj/item/stack/farming/seeds/turnip/returned = locate() in T
	T.attackby(returned, H)
	P = locate() in T
	winter_check(P && returned.amount == 1, "harvested turnip seed replants with one-unit debit")
	P.vstatic = TRUE
	P.stage = 2
	P.attackby(K, H)
	winter_check(winter_food_count(T, /obj/item/weapon/reagent_containers/food/snacks/grown/turnip) == 1 && winter_seed_total(T, /obj/item/stack/farming/seeds/turnip) == 1, "uprooting immature turnip creates no food or extra seeds")

	var/turf/floor/dirt/ploughed/O = new(locate(5,2,1))
	var/obj/structure/farming/plant/carrot/ordinary = new(O)
	ordinary.vstatic = TRUE
	ordinary.stage = 1
	ordinary.water = 60
	A.icon_state = "snow_storm"
	ordinary.water_proc()
	winter_check(!ordinary.winter_hardy && ordinary.stage == 11, "ordinary crop retains snowstorm death")

	var/turf/floor/dirt/ploughed/U = new(locate(8,2,1))
	A.location = AREA_INSIDE
	A.climate = "desert" // Seed accessibility is broader than outdoor fungus biomes.
	var/obj/item/stack/farming/seeds/plump_helmet/SP = new(H, 3)
	U.attackby(SP, H)
	var/obj/structure/farming/plant/plump_helmet/M = locate() in U
	winter_check(M && SP.amount == 2, "plump helmet sows indoors with one-spore debit")
	M.vstatic = TRUE
	winter_check(istype(M, /obj/structure/farming/plant/mushroom) && M.max_water == 0, "plump helmet retains native mushroom ancestry")
	M.stage = 1
	M.water = 0
	M.water_proc()
	winter_check(M.stage == 1 && M.water == 0, "plump helmet inherits weather and watering exemption")
	U.soil_nutrition = 150
	M.soil_nutrition_proc()
	winter_check(U.soil_nutrition == 147 && M.plant_nutrition == 147, "plump helmet still consumes soil nutrition")
	M.plant_nutrition = 150
	var/advances = 0
	var/pauses = 0
	for (var/trial = 1, trial <= 128, trial++)
		M.stage = 3
		M.stageGrowth()
		winter_check(M.stage == 3 || M.stage == 4, "plump growth trial advances at most one stage")
		if (M.stage == 4)
			advances++
		else
			pauses++
	// These counts are diagnostic, not a probabilistic acceptance threshold.
	world.log << "WINTER RNG DIAGNOSTIC: trials=128 advances=[advances] pauses=[pauses]"
	M.stage = 6
	var/reached_ripe = winter_advance_until(M, 7)
	var/reached_overmature = FALSE
	if (reached_ripe)
		reached_overmature = winter_advance_until(M, 11)
	world.log << "WINTER RNG DIAGNOSTIC: reached_ripe=[reached_ripe] reached_overmature=[reached_overmature]; bounded direct calls, not elapsed-time acceptance"
	M.stage = 7
	winter_check(M.readyHarvest(), "plump ripe stage remains harvestable")
	M.stage = 11
	winter_check(!M.readyHarvest(), "plump overmature stage is not harvestable")
	M.vstatic = FALSE
	before_soil = U.soil_nutrition
	M.growth()
	winter_check(M.stage == 11 && U.soil_nutrition == before_soil, "dead plump growth stops before consuming soil")
	M.vstatic = TRUE
	M.stage = 7
	M.plant_nutrition = 79
	M.attackby(K, H)
	winter_check(!(locate(/obj/structure/farming/plant/plump_helmet) in U), "plump harvest retires its paid crop")
	winter_check(winter_seed_total(U, /obj/item/stack/farming/seeds/plump_helmet) == 2, "plump harvest returns exactly two spores")
	winter_check(winter_food_count(U, /obj/item/weapon/reagent_containers/food/snacks/grown/plump_helmet) == 1, "plump unfertilized harvest yields exactly one food")
	var/obj/item/stack/farming/seeds/plump_helmet/returned_spores = locate() in U
	U.attackby(returned_spores, H)
	M = locate() in U
	winter_check(M && returned_spores.amount == 1, "harvested plump spore replants with one-unit debit")
	M.vstatic = TRUE

	var/obj/structure/wild/smallbush/B = new(locate(7,3,1))
	var/list/biomes = list("sea", "temperate", "tundra", "taiga", "desert", "semiarid", "savanna", "jungle")
	for (var/biome in biomes)
		B.generate_seed_list(biome)
	var/list/catalogs = list(seed_list_sea, seed_list_temperate, seed_list_tundra, seed_list_taiga, seed_list_desert, seed_list_semiarid, seed_list_savanna, seed_list_jungle)
	for (var/biome_index = 1, biome_index <= biomes.len, biome_index++)
		var/list/catalog = catalogs[biome_index]
		var/turnip_expected = (biomes[biome_index] in list("sea", "temperate", "tundra", "taiga"))
		winter_check((/obj/item/stack/farming/seeds/plump_helmet in catalog), "plump native starter pool includes [biomes[biome_index]]")
		winter_check((/obj/item/stack/farming/seeds/turnip in catalog) == turnip_expected, "turnip native starter pool matches [biomes[biome_index]]")
	winter_check((/obj/item/stack/farming/seeds/turnip in seed_list_temperate) && !(/obj/item/stack/farming/seeds/turnip in seed_list_desert), "turnip starter seed follows its biome pool")
	winter_check((/obj/item/stack/farming/seeds/plump_helmet in seed_list_temperate) && (/obj/item/stack/farming/seeds/plump_helmet in seed_list_desert), "plump starter spores enter both cold and desert pools")
	winter_check(world.time - start_time < 600, "direct crop fixture completes before pending growth waits")
	text2file("PASS: winter crop native direct production paths", "result.txt")
