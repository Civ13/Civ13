// Proposal only. Include after probe.dm; the owning wrapper calls winter_setup().
// No world/client overrides, launcher, callback acceleration or production edits.

/proc/winter_food_eater(turf/T)
	var/mob/living/human/winter_tester/H = new(T)
	// The crop fixture deliberately suppresses human New. Supply only the real
	// species and metabolism dependencies needed by production oral chemistry.
	H.species = new /datum/species/human
	H.ingested = new /datum/reagents/metabolism(1000, H, CHEM_INGEST)
	H.nutrition = 100
	H.mob_size = MOB_MEDIUM
	H.stat = 0 // Use the conscious state value for this inert fixture human.
	return H

/proc/winter_food_bite(obj/item/weapon/reagent_containers/food/snacks/F, mob/living/human/H)
	winter_check(F.reagents && abs(F.reagents.get_reagent_amount("nutriment") - 2) < 0.001, "fresh winter produce contains two nutriment units")
	winter_check(abs(F.nutriments_value() - 60) < 0.001, "fresh winter produce has sixty hunger value")
	var/nutrition_before = H.nutrition
	F.take_food_bite(H, 1)
	winter_check(abs(F.reagents.get_reagent_amount("nutriment") - 1) < 0.001, "production bite spends one paid nutriment unit")
	winter_check(abs(H.ingested.get_reagent_amount("nutriment") - 1) < 0.001, "production oral transfer reaches ingested holder")
	// Bounded actual metabolic service calls, not elapsed Life/gameplay time.
	for (var/i = 1, i <= 20 && H.ingested.get_reagent_amount("nutriment") > 0, i++)
		H.ingested.metabolize()
	winter_check(H.ingested.get_reagent_amount("nutriment") == 0, "oral metabolism consumes the transferred nutriment")
	winter_check(abs(H.nutrition - nutrition_before - 30) < 0.001, "paid winter crop bite supplies thirty hunger nutrition")
	// take_food_bite is the chemistry seam, not attack(): do not pretend it
	// increments bitecount, tests mouth admission, or deletes an empty snack.
	F.bitecount = 1

/proc/winter_food_writer()
	if (!chemical_reagents_list)
		initialize_chemical_reagents()
	var/mob/living/human/H = winter_food_eater(locate(2,3,1))
	var/savefile/F = new("winter-food.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/list/entries = list()
	var/list/kinds = list("turnip", "plump_helmet")
	for (var/i = 1, i <= kinds.len, i++)
		var/kind = kinds[i]
		var/food_path = text2path("/obj/item/weapon/reagent_containers/food/snacks/grown/[kind]")
		var/turf/T = locate(2+i,3,1)
		var/obj/item/weapon/reagent_containers/food/snacks/food = new food_path(T)
		winter_food_bite(food, H)
		food.decaytimer = 1200
		var/food_id = map_storage.BuildVarDirectory(F, food, 1)
		winter_check(food_id, "writer exports partially consumed winter food graph")
		var/plant_path = text2path("/obj/structure/farming/plant/[kind]")
		var/obj/structure/farming/plant/P = new plant_path(T)
		// Frozen scalar snapshots isolate graph persistence from sleeping growth.
		P.vstatic = TRUE
		P.stage = 3
		P.water = (kind == "turnip") ? 42 : 0
		P.plant_nutrition = 87
		var/plant_id = map_storage.BuildVarDirectory(F, P, 1)
		winter_check(plant_id, "writer exports winter crop scalar snapshot")
		var/seed_path = text2path("/obj/item/stack/farming/seeds/[kind]")
		var/obj/item/stack/farming/seeds/S = new seed_path(T, 7)
		var/seed_id = map_storage.BuildVarDirectory(F, S, 1)
		winter_check(seed_id, "writer exports winter seed stock")
		entries += list(list("kind" = kind, "food" = food_id, "plant" = plant_id, "seed" = seed_id))
	F.Flush()
	F = null
	text2file(json_encode(entries), "winter-food-entries.json")
	world.log << "WINTER FOOD WRITER: two paid partial foods, frozen crops and seed stocks flushed"

/proc/winter_food_reader()
	if (!chemical_reagents_list)
		initialize_chemical_reagents()
	var/list/entries = json_decode(file2text("winter-food-entries.json"))
	winter_check(islist(entries) && entries.len == 2, "reader has two writer records")
	var/savefile/F = new("winter-food.sav")
	map_storage.clear_bookkeeping()
	var/list/kinds = list("turnip", "plump_helmet")
	for (var/i = 1, i <= kinds.len, i++)
		var/list/record = entries[i]
		var/kind = kinds[i]
		winter_check(islist(record) && record["kind"] == kind, "reader record belongs to expected crop")
		var/turf/T = locate(2+i,4,1)
		var/obj/item/weapon/reagent_containers/food/snacks/food = map_storage.Load_Entry(F, record["food"], starting_loc = T)
		var/expected_food = text2path("/obj/item/weapon/reagent_containers/food/snacks/grown/[kind]")
		winter_check(food && food.type == expected_food && food.loc == T, "reader restores actual winter food type and destination")
		winter_check(food.reagents && abs(food.reagents.get_reagent_amount("nutriment") - 1) < 0.001 && abs(food.nutriments_value() - 30) < 0.001, "reader preserves partial paid nutrition without constructor refill")
		winter_check(food.bitecount == 1 && food.decaytimer == 1200, "reader preserves bite count and accumulated food age")
		winter_check(food.decay == ((kind == "turnip") ? 54000 : 36000), "reader retains finite crop-specific decay limit")
		var/obj/structure/farming/plant/P = map_storage.Load_Entry(F, record["plant"], starting_loc = T)
		var/expected_plant = text2path("/obj/structure/farming/plant/[kind]")
		winter_check(P && P.type == expected_plant && P.vstatic && P.stage == 3 && P.plant_nutrition == 87, "reader preserves frozen crop stage and sampled fertility")
		winter_check(P.water == ((kind == "turnip") ? 42 : 0), "reader preserves crop-specific water state")
		winter_check(P.winter_hardy == (kind == "turnip"), "reader retains opt-in hardiness without granting mushroom flag")
		var/obj/item/stack/farming/seeds/S = map_storage.Load_Entry(F, record["seed"], starting_loc = T)
		var/expected_seed = text2path("/obj/item/stack/farming/seeds/[kind]")
		winter_check(S && S.type == expected_seed && S.amount == 7, "reader preserves seven paid seeds or spores")
		// No call to food_decay(): New already schedules it. Calling it again
		// would create another production chain and corrupt an ownership test.
	world.log << "WINTER FOOD READER: restored amounts/age/scalars; callback resumption NOT exercised"

/proc/winter_food_roundtrip()
	winter_food_writer()
	winter_food_reader()
	// Same-process graph check only. The separate writer/reader phases provide
	// the fresh-process boundary; neither claims native callback resumption.
