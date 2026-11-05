// Zombie city loot: what a building of each kind holds.
//
// The city generator places loot spots and calls zombie_city_roll_loot with
// the building's table and tier (1 to 3). Each entry is
// list(path, weight, min_age, min_tier): min_age is the research age
// (map.ordinal_age) the item needs, so a city run cannot hand out items the
// world has not reached; min_tier keeps the best items in the deeper, more
// infested buildings. Salvage materials have no age.

var/global/list/zombie_city_loot_tables = list(
	"residential" = list(
		list(/obj/item/weapon/reagent_containers/food/snacks/cracker, 20, 0, 1),
		list(/obj/item/weapon/reagent_containers/food/snacks/pemmican, 10, 0, 1),
		list(/obj/item/weapon/reagent_containers/food/drinks/can/water, 12, 5, 1),
		list(/obj/item/weapon/reagent_containers/food/drinks/can/cola, 8, 5, 1),
		list(/obj/item/stack/material/cloth, 15, 0, 1),
		list(/obj/item/stack/material/glass, 6, 0, 1),
		list(/obj/item/stack/medical/bruise_pack, 8, 0, 1),
		list(/obj/item/weapon/screwdriver, 5, 4, 1),
		list(/obj/item/weapon/gun/projectile/revolver/coltpolicepositive, 2, 5, 2),
		list(/obj/item/weapon/gun/projectile/shotgun/pump/remington870, 1, 6, 3)),
	"grocery" = list(
		list(/obj/item/weapon/reagent_containers/food/snacks/cracker, 20, 0, 1),
		list(/obj/item/weapon/reagent_containers/food/snacks/pemmican, 15, 0, 1),
		list(/obj/item/weapon/reagent_containers/food/snacks/chocolatebar, 10, 4, 1),
		list(/obj/item/weapon/reagent_containers/food/drinks/can/water, 15, 5, 1),
		list(/obj/item/weapon/reagent_containers/food/drinks/can/cola, 10, 5, 1),
		list(/obj/item/weapon/reagent_containers/food/drinks/bottle/plastic/water, 10, 7, 1),
		list(/obj/item/stack/material/plastic, 5, 0, 2)),
	"pharmacy" = list(
		list(/obj/item/stack/medical/bruise_pack, 25, 0, 1),
		list(/obj/item/stack/medical/advanced/bruise_pack, 10, 6, 1),
		list(/obj/item/stack/medical/advanced/ointment, 8, 6, 1),
		list(/obj/item/weapon/reagent_containers/syringe/antitoxin, 6, 6, 2),
		list(/obj/item/weapon/reagent_containers/syringe/morphine, 4, 6, 2),
		list(/obj/item/weapon/reagent_containers/syringe/adrenaline, 3, 7, 3)),
	"medical" = list(
		list(/obj/item/stack/medical/bruise_pack, 20, 0, 1),
		list(/obj/item/stack/medical/advanced/bruise_pack, 15, 6, 1),
		list(/obj/item/stack/medical/advanced/ointment, 12, 6, 1),
		list(/obj/item/weapon/reagent_containers/syringe/antitoxin, 8, 6, 1),
		list(/obj/item/weapon/reagent_containers/syringe/morphine, 6, 6, 2),
		list(/obj/item/weapon/reagent_containers/syringe/adrenaline, 5, 7, 2),
		list(/obj/item/stack/material/plastic, 5, 0, 1)),
	"hardware" = list(
		list(/obj/item/stack/material/steel, 15, 0, 1),
		list(/obj/item/stack/material/iron, 15, 0, 1),
		list(/obj/item/stack/material/glass, 10, 0, 1),
		list(/obj/item/stack/material/plastic, 8, 0, 1),
		list(/obj/item/stack/material/electronics, 4, 0, 2),
		list(/obj/item/weapon/crowbar, 8, 4, 1),
		list(/obj/item/weapon/wrench, 8, 4, 1),
		list(/obj/item/weapon/screwdriver, 8, 4, 1),
		list(/obj/item/weapon/wirecutters, 6, 4, 1),
		list(/obj/item/weapon/hammer/modern, 6, 4, 1),
		list(/obj/item/weapon/weldingtool, 4, 6, 2)),
	"garage" = list(
		list(/obj/item/stack/material/steel, 20, 0, 1),
		list(/obj/item/stack/material/iron, 15, 0, 1),
		list(/obj/item/stack/material/rope, 8, 0, 1),
		list(/obj/item/stack/material/plastic, 8, 0, 1),
		list(/obj/item/weapon/wrench, 10, 4, 1),
		list(/obj/item/weapon/crowbar, 8, 4, 1),
		list(/obj/item/weapon/weldingtool, 6, 6, 1),
		list(/obj/item/stack/material/electronics, 4, 0, 2)),
	"police" = list(
		list(/obj/item/stack/medical/bruise_pack, 10, 0, 1),
		list(/obj/item/weapon/gun/projectile/revolver/coltpolicepositive, 10, 5, 1),
		list(/obj/item/weapon/gun/projectile/pistol/m1911, 8, 5, 1),
		list(/obj/item/weapon/gun/projectile/pistol/glock17, 8, 8, 1),
		list(/obj/item/weapon/gun/projectile/shotgun/pump/remington870, 6, 6, 2),
		list(/obj/item/ammo_magazine/shellbox, 6, 6, 2),
		list(/obj/item/clothing/head/helmet/kevlarhelmet, 4, 7, 2),
		list(/obj/item/clothing/head/helmet/swat, 2, 8, 3),
		list(/obj/item/weapon/gun/projectile/semiautomatic/ar15, 2, 8, 3)),
	"military" = list(
		list(/obj/item/stack/medical/advanced/bruise_pack, 10, 6, 1),
		list(/obj/item/weapon/gun/projectile/boltaction/springfield, 10, 5, 1),
		list(/obj/item/weapon/gun/projectile/semiautomatic/m1garand, 8, 6, 1),
		list(/obj/item/weapon/gun/projectile/submachinegun/m16, 6, 7, 2),
		list(/obj/item/weapon/gun/projectile/submachinegun/ak47, 6, 7, 2),
		list(/obj/item/clothing/head/helmet/kevlarhelmet, 6, 7, 1),
		list(/obj/item/stack/material/steel, 10, 0, 1),
		list(/obj/item/stack/material/electronics, 5, 0, 2),
		list(/obj/item/weapon/gun/projectile/submachinegun/scarl, 2, 8, 3)))

// Items per roll by tier: low, high.
var/global/list/zombie_city_loot_counts = list(list(1, 2), list(2, 3), list(3, 4))

/proc/zombie_city_loot_age()
	return map ? map.ordinal_age : 0

// The entries of a table available at this age and tier, as path = weight.
/proc/zombie_city_loot_choices(table, tier, age)
	var/list/rows = zombie_city_loot_tables[table]
	var/list/out = list()
	if (!islist(rows))
		return out
	for (var/list/row in rows)
		if (row[3] > age || row[4] > tier)
			continue
		out[row[1]] = row[2]
	return out

/proc/zombie_city_roll_loot(turf/T, table, tier)
	var/list/made = list()
	if (!istype(T) || !(table in zombie_city_loot_tables))
		return made
	tier = clamp(round(tier), 1, 3)
	var/list/choices = zombie_city_loot_choices(table, tier, zombie_city_loot_age())
	if (!choices.len)
		return made
	var/list/count_range = zombie_city_loot_counts[tier]
	for (var/i in 1 to rand(count_range[1], count_range[2]))
		var/path = pickweight(choices)
		var/obj/item/I = new path(T)
		I.should_save = FALSE
		made += I
		if (istype(I, /obj/item/stack))
			var/obj/item/stack/S = I
			S.amount = clamp(rand(2, 6) * tier, 1, S.max_amount)
			S.update_icon()
		else if (istype(I, /obj/item/weapon/gun/projectile))
			var/obj/item/weapon/gun/projectile/G = I
			// One spare magazine of the gun's own type, if it takes one.
			if (G.magazine_type && prob(60))
				var/obj/item/M = new G.magazine_type(T)
				M.should_save = FALSE
				made += M
	return made
