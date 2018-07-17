/process/supply
	var/tmpTime1 = 0
	var/tmpTime2 = 0
	var/list/points = list(GERMAN = 500, SOVIET = 500)
	var/list/codes = list(GERMAN = 1234, SOVIET = 1234)
	var/list/german_crate_types = list(

		// AMMO AND MISC.
		"Flammenwerfer Fuel Tanks" = /obj/structure/closet/crate/flammenwerfer_fueltanks,
		"Vehicle Fuel Tanks" = /obj/structure/closet/crate/vehicle_fueltanks,
		"MG34 Belts" = /obj/structure/closet/crate/mg34belt,
		"Gauze" = /obj/structure/closet/crate/gauze,
		"Luger Ammo" = /obj/structure/closet/crate/lugerammo,
		"Mauser Ammo" = /obj/structure/closet/crate/mauserammo,
		"Walther Ammo" = /obj/structure/closet/crate/waltherammo,
		"Kar Ammo" = /obj/structure/closet/crate/kar98kammo,
		"Mp40 Ammo" = /obj/structure/closet/crate/mp40kammo,
		"Mg34 Ammo" = /obj/structure/closet/crate/mg34ammo,
		"Mp43 Ammo" = /obj/structure/closet/crate/mp43ammo,
		"PTRD Ammo" = /obj/structure/closet/crate/ptrdammo,
	//		"Mines" = /obj/structure/closet/crate/bettymines,
		"Explosive Grenades" = /obj/structure/closet/crate/german_grenade,
		"Shrapnel Grenades" = /obj/structure/closet/crate/german_grenade2,
		"Smoke Grenades" = /obj/structure/closet/crate/german_smoke_grenade,
		"Panzerfausts" = /obj/structure/closet/crate/panzerfaust,
		"Mortar Shells" = /obj/structure/closet/crate/mortar_shells,
		"Gas Mask Crate" = /obj/structure/closet/crate/gasmasks,
		"Barbwire Crate" = /obj/structure/closet/crate/barbwire,
		"Sandbags Crate" = /obj/structure/closet/crate/sandbags,
		"Flaregun Ammo" = /obj/structure/closet/crate/flares_ammo,
		"Flares" = /obj/structure/closet/crate/flares,
		"Bayonet Crate" = /obj/structure/closet/crate/bayonets,

		"Solid Rations" = /obj/structure/closet/crate/rations/german_solids,
		"Liquid Rations" = /obj/structure/closet/crate/rations/german_liquids,
		"Dessert Rations" = /obj/structure/closet/crate/rations/german_desserts,
		"Water Rations" = /obj/structure/closet/crate/rations/water,
		"Alcohol Rations" = /obj/structure/closet/crate/rations/german_alcohol,
		"Meat Rations" = /obj/structure/closet/crate/rations/german_meat,

		// MATERIALS
		"Wood Planks" = /obj/structure/closet/crate/wood,
		"Steel Sheets" = /obj/structure/closet/crate/steel,
		"Iron Ingots" = /obj/structure/closet/crate/iron,
		"Glass Sheets" = /obj/structure/closet/crate/glass,

		// GUNS & ARTILLERY
		"MP40" = /obj/item/weapon/gun/projectile/submachinegun/mp40,
		"MG34" = /obj/item/weapon/gun/projectile/automatic/mg34,
		"Gewehr 41" = /obj/item/weapon/gun/projectile/semiautomatic/g41,
		"PTRD" = /obj/item/weapon/gun/projectile/heavy/ptrd,
		"Flammenwerfer" = /obj/item/weapon/storage/backpack/flammenwerfer,
		"7,5 cm FK 18 Artillery Piece" = /obj/structure/artillery,
		"Luger Crate" = /obj/structure/closet/crate/lugers,
		"Movable MG34" = /obj/item/weapon/gun/projectile/automatic/stationary/kord/mg34,

		// ARTILLERY AMMO
		"Artillery Ballistic Shells Crate" = /obj/structure/closet/crate/artillery,
		"Artillery Gas Shells Crate" = /obj/structure/closet/crate/artillery_gas,

		// CLOSETS
		"Tool Closet" = /obj/structure/closet/toolcloset,

		// MINES
	//		"Betty Mines Crate" = /obj/structure/closet/crate/bettymines,

		// ANIMAL CRATES
	//		"German Shepherd Crate" = /obj/structure/largecrate/animal/dog/german,

		// MEDICAL STUFF
		"Medical Crate" = /obj/structure/closet/crate/medical
	)

	var/static/list/soviet_crate_types = list(

		// AMMO AND MISC.
		"Vehicle Fuel Tanks" = /obj/structure/closet/crate/vehicle_fueltanks,
		"Maxim Belts" = /obj/structure/closet/crate/maximbelt,
		"Bint" = /obj/structure/closet/crate/bint,
		"Nagant Revolver Ammo" = /obj/structure/closet/crate/nagantrevolverammo,
		"Tokarev Ammo" = /obj/structure/closet/crate/tokarevammo,
		"Mosin Ammo" = /obj/structure/closet/crate/mosinammo,
		"PPSH Ammo" = /obj/structure/closet/crate/ppshammo,
		"DP Ammo" = /obj/structure/closet/crate/dpammo,
		"PPS-43 Ammo" = /obj/structure/closet/crate/ppsammo,
		"PTRD Ammo" = /obj/structure/closet/crate/ptrdammo,
	//	"SVT Ammo" = /obj/structure/closet/crate/svtammo,
	//		"Mines" = /obj/structure/closet/crate/bettymines,
		"Explosive Grenades" = /obj/structure/closet/crate/soviet_grenade,
		"Shrapnel Grenades" = /obj/structure/closet/crate/soviet_grenade2,
		"Smoke Grenades" = /obj/structure/closet/crate/soviet_smoke_grenade,
		"Mortar Shells" = /obj/structure/closet/crate/mortar_shells,
		"Gas Mask Crate" = /obj/structure/closet/crate/gasmasks/soviet,
		"Barbwire Crate" = /obj/structure/closet/crate/barbwire,
		"Sandbags Crate" = /obj/structure/closet/crate/sandbags,
		"Flaregun Ammo" = /obj/structure/closet/crate/flares_ammo,
		"Flares" = /obj/structure/closet/crate/flares,
		"Bayonet Crate" = /obj/structure/closet/crate/bayonets,

		"Solid Rations" = /obj/structure/closet/crate/rations/soviet_solids,
		"Liquid Rations" = /obj/structure/closet/crate/rations/soviet_liquids,
	//	"Dessert Rations" = /obj/structure/closet/crate/rations/soviet_desserts,
		"Water Rations" = /obj/structure/closet/crate/rations/water,
		"Alcohol Rations" = /obj/structure/closet/crate/rations/soviet_alcohol,
		"Meat Rations" = /obj/structure/closet/crate/rations/soviet_meat,

		// MATERIALS
		"Wood Planks" = /obj/structure/closet/crate/wood,
		"Steel Sheets" = /obj/structure/closet/crate/steel,
		"Iron Ingots" = /obj/structure/closet/crate/iron,
		"Glass Sheets" = /obj/structure/closet/crate/glass,

		// GUNS & ARTILLERY
		"PPSH-41" = /obj/item/weapon/gun/projectile/submachinegun/ppsh,
		"PPS-43" = /obj/item/weapon/gun/projectile/submachinegun/pps,
		"SVT40" = /obj/item/weapon/gun/projectile/semiautomatic/svt,
		"DP-28" = /obj/item/weapon/gun/projectile/automatic/dp,
		"PTRD" = /obj/item/weapon/gun/projectile/heavy/ptrd,
		"37mm Spade Mortar" = /obj/structure/mortar/spade,
		"Maxim" = /obj/item/weapon/gun/projectile/automatic/stationary/kord/maxim,

		// CLOSETS
		"Tool Closet" = /obj/structure/closet/toolcloset,

		// MINES
	//		"Betty Mines Crate" = /obj/structure/closet/crate/bettymines,

		// ANIMAL CRATES
	//		"Samoyed Crate" = /obj/structure/largecrate/animal/dog/soviet,

		// MEDICAL STUFF
		"Medical Crate" = /obj/structure/closet/crate/medical

	)

	var/list/crate_costs = list(

		// AMMO AND MISC.
		"Flammenwerfer Fuel Tanks" = 100,
		"Vehicle Fuel Tanks" = 100,
		"Maxim Belts" = 60,
		"MG34 Belts" = 60,
		"Gauze" = 50,
		"Bint" = 50,
		"Luger Ammo" = 50,
		"Walther Ammo" = 50,
		"Mauser Ammo" = 50,
		"Kar Ammo" = 60,
		"Mp40 Ammo" = 75,
		"Mg34 Ammo" = 85,
		"Mp43 Ammo" = 75,
		"PTRD Ammo" = 100,
	//	"SVT Ammo" = 100,
		"Tokarev Ammo" = 50,
		"Nagant Revolver Ammo" = 50,
		"Mosin Ammo" = 60,
		"PPSH Ammo" = 75,
		"PPS-43 Ammo" = 75,
		"DP Ammo" = 85,

	//		"Mines" = 50,
		"Explosive Grenades" = 100,
		"Shrapnel Grenades" = 100,
		"Panzerfausts" = 200,
		"Smoke Grenades" = 75,
		"Mortar Shells" = 125,
		"Gas Mask Crate" = 100,
		"Barbwire Crate" = 100,
		"Sandbags Crate" = 100,
		"Flaregun Ammo" = 40,
		"Flares" = 30,
		"Bayonet Crate" = 80,

		"Solid Rations" = 100,
		"Liquid Rations" = 100,
		"Dessert Rations" = 100,
		"Alcohol Rations" = 100,
		"Meat Rations" = 100,
		"Water Rations" = 50,

		// MATERIALS
		"Wood Planks" = 100,
		"Glass Sheets" = 125,
		"Iron Ingots" = 150,
		"Steel Sheets" = 175,

		// GUNS & ARTILLERY
		"MP40" = 125,
		"MG34" = 175,
		"PPSH-41" = 125,
		"DP-28" = 175,
		"PTRD" = 200,
		"SVT40" = 150,
		"Gewehr 41" = 150,
		"PPS-43" = 150,
		"37mm Spade Mortar" = 200,
		"Flammenwerfer" = 250,
		"7,5 cm FK 18 Artillery Piece" = 300,
		"Luger Crate" = 400,
		"Colt Crate" = 400,
		"Maxim" = 300,
		"Movable MG34" = 300,

		// ARTILLERY AMMO
		"Artillery Ballistic Shells Crate" = 150,
		"Artillery Gas Shells Crate" = 250,

		// CLOSETS
		"Tool Closet" = 100,

		// MINES
	//		"Betty Mines Crate" = 200,

		// ANIMAL CRATES
	//		"German Shepherd Crate" = 100,
	//		"Samoyed Crate" = 100,

		// MEDICAL STUFF
		"Medical Crate" = 150

	)

/process/supply/setup()
	name = "supply points"
	schedule_interval = 2 SECONDS
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.supply = src

/process/supply/fire()

	tmpTime1 += schedule_interval
	tmpTime2 += schedule_interval

	if (!map)
		return

	if (german_supplytrain_master)
		german_supplytrain_master.supply_points += map.supply_points_per_tick[GERMAN]
	else
		points[GERMAN] += map.supply_points_per_tick[GERMAN]

	points[SOVIET] += map.supply_points_per_tick[SOVIET]

	// change supply codes every 10 minutes (but not both at once) to stop metagaming
	if (prob(10) && tmpTime1 >= 6000 && !german_supplytrain_master)
		var/original_code = codes[GERMAN]
		codes[GERMAN] = rand(1000,9999)
		for (var/mob/living/carbon/human/H in human_mob_list)
			if (H.original_job && H.original_job.is_officer)
				if (H.original_job.base_type_flag() == GERMAN)
					H.replace_memory(original_code, codes[GERMAN])
		radio2germans("The supply passcode has been changed to [codes[GERMAN]] due to security concerns.", "High Command Private Announcements")
		tmpTime1 = 0

	else if (prob(10) && tmpTime2 >= 6000)
		var/original_code = codes[SOVIET]
		codes[SOVIET] = rand(1000,9999)
		for (var/mob/living/carbon/human/H in human_mob_list)
			if (H.original_job && H.original_job.is_officer)
				if (H.original_job.base_type_flag() == SOVIET)
					H.replace_memory(original_code, codes[SOVIET])
		radio2soviets("The supply passcode has been changed to [codes[SOVIET]] due to security concerns.", "High Command Private Announcements")
		tmpTime2 = 0