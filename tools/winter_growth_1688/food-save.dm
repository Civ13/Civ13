// Produce exists from writer setup. Only the paid oral-transfer seam is invoked;
// no food_decay, metabolism, age/bitecount assignment or growth helper calls.
/proc/winter_create_food()
	for (var/kind in list("turnip", "plump_helmet"))
		var/x = kind == "turnip" ? 1 : 2
		var/mob/living/human/winter_tester/H = new(locate(5,8,1))
		H.species = new /datum/species/human
		H.ingested = new /datum/reagents/metabolism(1000,H,CHEM_INGEST)
		H.nutrition = 100
		H.mob_size = MOB_MEDIUM
		H.stat = 0
		var/food_path = text2path("/obj/item/weapon/reagent_containers/food/snacks/grown/[kind]")
		var/obj/item/weapon/reagent_containers/food/snacks/F = new food_path(locate(x,6,1))
		winter_check(F.reagents && F.reagents.get_reagent_amount("nutriment") == 2, "[kind] fresh produce contains two nutriment")
		F.take_food_bite(H,1)
		winter_check(F.reagents.get_reagent_amount("nutriment") == 1 && H.ingested.get_reagent_amount("nutriment") == 1, "[kind] paid bite transfers one nutriment")
		winter_check(F.decaytimer == 0, "[kind] food begins at natural age zero")

/proc/winter_food_snapshot()
	var/list/rows = list()
	var/census = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/grown/F in world)
		census++
	winter_check(census == 2, "exact two-produce census")
	for (var/kind in list("turnip", "plump_helmet"))
		var/turf/T = locate(kind == "turnip" ? 1 : 2,6,1)
		var/obj/item/weapon/reagent_containers/food/snacks/grown/F = locate(/obj/item/weapon/reagent_containers/food/snacks/grown) in T
		winter_check(F && F.reagents, "[kind] food remains at its coordinate with reagents")
		rows += list(list("id" = kind, "type" = "[F.type]", "x" = F.x, "y" = F.y, "z" = F.z, "identity" = "\ref[F]", "nutriment" = F.reagents.get_reagent_amount("nutriment"), "age" = F.decaytimer, "decay" = F.decay))
	return rows

/proc/winter_seed_snapshot()
	var/list/rows = list()
	var/census = 0
	for (var/obj/item/stack/farming/seeds/S in world)
		census++
	winter_check(census == 2, "exact two-seed-stock census")
	for (var/kind in list("turnip", "plump_helmet"))
		var/turf/T = locate(kind == "turnip" ? 1 : 2,7,1)
		var/obj/item/stack/farming/seeds/S = locate(/obj/item/stack/farming/seeds) in T
		winter_check(S, "[kind] seed stock remains at its coordinate")
		rows += list(list("id" = kind, "type" = "[S.type]", "x" = S.x, "y" = S.y, "z" = S.z, "identity" = "\ref[S]", "amount" = S.amount))
	return rows
