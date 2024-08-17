/// CAFR civilian crate costs ///
#define WOODCOST_CAFR 50
#define IRONCOST_CAFR 50
#define STEELCOST_CAFR 80
#define GLASSCOST_CAFR 50
#define STONECOST_CAFR 50
#define VEGETABLESCOST_CAFR 30
#define FRUITCOST_CAFR 30
#define BISCUITCOST_CAFR 30
#define BEERCOST_CAFR 30
#define ALECOST_CAFR 30
#define COWCOST_CAFR 150
#define SHEEPCOST_CAFR 80
#define PIGCOST_CAFR 100
#define CHICKENCOST_CAFR 50
#define HORSECOST_CAFR 200
#define BRICKCOST_CAFR 100
#define FIRSTAIDADVCOST_CAFR 50
/////////////////////////////////

///CAFR military crate costs ///
#define GUNPOWDERCOST_CAFR 22.5 // Level 1/10 gunpowder factory in Tajikistan
#define SUICIDEVESTCOST_CAFR 400
#define SKSCOST_CAFR 500
#define AKMCOST_CAFR 1000
#define AK74COST_CAFR 1200
#define SVDCOST_CAFR 1000
#define MOSINCOST_CAFR 500
#define PPSHCOST_CAFR 400
#define MAKAROVCOST_CAFR 150
#define PKMCOST_CAFR 300
#define WW2SURPLUSUNIFORMCOST_CAFR 200
#define AFGHANKACOST_CAFR 250
#define RGD5COST_CAFR 720 // Level 1/10 RGD-5 grenade factory in Tajikistan
#define AKAMMOCOST_CAFR 100
#define MOSINAMMOCOST_CAFR 100
#define MAKAROVAMMOCOST_CAFR 50
#define SIXB1COST_CAFR 300
#define SIXB2COST_CAFR 1000
#define PUCOST_CAFR 500
#define PSO1COST_CAFR 720 // Level 1/10 PSO-1 factory in Kyrgyzstan
#define ARTILLERYCOST_CAFR 1500
#define SHELLCOST_CAFR 1000
#define MORTARCOST_CAFR 1200
#define MSHELLCOST_CAFR 720 // Level 1/10 mortar shell factory in Kyrgyzstan
#define KAMAZCOST_CAFR 1500
#define BMD2COST_CAFR 5000
#define T55COST_CAFR 8000
#define T72COST_CAFR 10000
/////////////////////////////////

/// TSFSR civilian crate costs ///
#define WOODCOST_TSFSR 50
#define IRONCOST_TSFSR 50
#define STEELCOST_TSFSR 80
#define GLASSCOST_TSFSR 50
#define STONECOST_TSFSR 50
#define VEGETABLESCOST_TSFSR 30
#define FRUITCOST_TSFSR 30
#define BISCUITCOST_TSFSR 30
#define BEERCOST_TSFSR 30
#define ALECOST_TSFSR 30
#define COWCOST_TSFSR 150
#define SHEEPCOST_TSFSR 80
#define PIGCOST_TSFSR 100
#define CHICKENCOST_TSFSR 50
#define HORSECOST_TSFSR 200
#define BRICKCOST_TSFSR 100
#define FIRSTAIDADVCOST_TSFSR 50
/////////////////////////////////

///TSFSR military crate costs ///
#define GUNPOWDERCOST_TSFSR 25
#define SUICIDEVESTCOST_TSFSR 400
#define SKSCOST_TSFSR 500
#define AKMCOST_TSFSR 900 // Level 1/10 AKM factory in Uzbekistan
#define AK74COST_TSFSR 1200
#define SVDCOST_TSFSR 1000
#define MOSINCOST_TSFSR 500
#define PPSHCOST_TSFSR 400
#define MAKAROVCOST_TSFSR 150
#define PKMCOST_TSFSR 300
#define WW2SURPLUSUNIFORMCOST_TSFSR 200
#define AFGHANKACOST_TSFSR 250
#define RGD5COST_TSFSR 800
#define AKAMMOCOST_TSFSR 100
#define MOSINAMMOCOST_TSFSR 100
#define MAKAROVAMMOCOST_TSFSR 50
#define SIXB1COST_TSFSR 300
#define SIXB2COST_TSFSR 900 // Level 1/10 6B2 factory in Kazakhstan
#define PUCOST_TSFSR 500
#define PSO1COST_TSFSR 800
#define ARTILLERYCOST_TSFSR 1500
#define SHELLCOST_TSFSR 1000
#define MORTARCOST_TSFSR 1200
#define MSHELLCOST_TSFSR 800
#define KAMAZCOST_TSFSR 1500
#define BMD2COST_TSFSR 5000
#define T55COST_TSFSR 8000
#define T72COST_TSFSR 9000 // Level 1/10 T-72 factory in Kazakhstan
/////////////////////////////////

/obj/structure/pepelsibirsk_radio/supply_radio/no_scam/campaign
	name = "long range high-sensitivity supply radio"

/obj/structure/pepelsibirsk_radio/supply_radio/no_scam/campaign/cafr
	factionarea = "SupplyCAFR"
	civ_catalogue = list( //type name, path, price
			list("wood crate", /obj/structure/closet/crate/wood, WOODCOST_CAFR),
			list("iron crate", /obj/structure/closet/crate/iron, IRONCOST_CAFR),
			list("steel crate", /obj/structure/closet/crate/steel, STEELCOST_CAFR),
			list("glass crate", /obj/structure/closet/crate/glass, GLASSCOST_CAFR),
			list("stone crate", /obj/structure/closet/crate/stone, STONECOST_CAFR),
			list("vegetables crate", /obj/structure/closet/crate/rations/vegetables, VEGETABLESCOST_CAFR),
			list("fruits crate", /obj/structure/closet/crate/rations/fruits, FRUITCOST_CAFR),
			list("biscuits crate", /obj/structure/closet/crate/rations/biscuits, BISCUITCOST_CAFR),
			list("beer crate", /obj/structure/closet/crate/rations/beer, BEERCOST_CAFR),
			list("ale crate", /obj/structure/closet/crate/rations/ale, ALECOST_CAFR),
			list("cow", /mob/living/simple_animal/cattle/cow, COWCOST_CAFR),
			list("bull", /mob/living/simple_animal/cattle/bull, COWCOST_CAFR),
			list("sheep ram", /mob/living/simple_animal/sheep, SHEEPCOST_CAFR),
			list("sheep ewe", /mob/living/simple_animal/sheep/female, SHEEPCOST_CAFR),
			list("pig boar", /mob/living/simple_animal/pig_boar, PIGCOST_CAFR),
			list("pig gilt", /mob/living/simple_animal/pig_gilt, PIGCOST_CAFR),
			list("hen", /mob/living/simple_animal/chicken, CHICKENCOST_CAFR),
			list("rooster", /mob/living/simple_animal/rooster, CHICKENCOST_CAFR),
			list("horse", /mob/living/simple_animal/horse, HORSECOST_CAFR),
			list("brick crate", /obj/structure/closet/crate/brick, BRICKCOST_CAFR),
			list("medical supplies", /obj/item/weapon/storage/firstaid/adv, FIRSTAIDADVCOST_CAFR),
		)
	mil_catalogue = list(
			list("gunpowder barrel", /obj/item/weapon/reagent_containers/glass/barrel/gunpowder,GUNPOWDERCOST_CAFR),
			list("gunpowder barrel bomb", /obj/item/weapon/grenade/bomb,GUNPOWDERCOST_CAFR),
			list("suicide vest crate (4)", /obj/structure/closet/crate/suicidevests,SUICIDEVESTCOST_CAFR),
			list("sks crate (5)", /obj/structure/closet/crate/pepelsibirsk/sks,SKSCOST_CAFR),
			list("akm crate (5)", /obj/structure/closet/crate/pepelsibirsk/akm,AKMCOST_CAFR),
			list("ak-74 crate (5)", /obj/structure/closet/crate/pepelsibirsk/ak74,AK74COST_CAFR),
			list("svd crate (2)", /obj/structure/closet/crate/pepelsibirsk/svd,SVDCOST_CAFR),
			list("mosin-nagant crate (10)", /obj/structure/closet/crate/pepelsibirsk/mosin,MOSINCOST_CAFR),
			list("PPSh-41 crate (2)", /obj/structure/closet/crate/pepelsibirsk/ppsh,PPSHCOST_CAFR),
			list("makarov crate (5)", /obj/structure/closet/crate/pepelsibirsk/makarov,MAKAROVCOST_CAFR),
			list("PKM crate (1)", /obj/structure/closet/crate/airdrops/soviet/pkm,PKMCOST_CAFR),
			list("surplus red army uniform crate (5)", /obj/structure/closet/crate/pepelsibirsk/surplus_ww2,WW2SURPLUSUNIFORMCOST_CAFR),
			list("afghanka uniform crate (5)", /obj/structure/closet/crate/pepelsibirsk/sov_uniforms,AFGHANKACOST_CAFR),
			list("frag grenade crate (12)", /obj/structure/closet/crate/pepelsibirsk/rgd5,RGD5COST_CAFR),
			list("7.62x39mm ammunition crate (300)", /obj/structure/closet/crate/pepelsibirsk/seven62x39mm,AKAMMOCOST_CAFR),
			list("7.62x54mmR ammunition crate (200)", /obj/structure/closet/crate/pepelsibirsk/seven62x54mmr,MOSINAMMOCOST_CAFR),
			list("9x18mm ammunition crate (240)", /obj/structure/closet/crate/pepelsibirsk/ninex18mm,MAKAROVAMMOCOST_CAFR),
			list("6B1 vest crate (5)", /obj/structure/closet/crate/pepelsibirsk/sixb1,SIXB1COST_CAFR),
			list("6B2 vest crate (5)", /obj/structure/closet/crate/pepelsibirsk/sixb2,SIXB2COST_CAFR),
			list("PU (Mosin/SVT) scope crate (5)", /obj/structure/closet/crate/scopes/pu,PUCOST_CAFR),
			list("PSO-1 (Dovetail) scope crate (5)", /obj/structure/closet/crate/scopes/pso1,PSO1COST_CAFR),
			list("towed artillery", /obj/structure/cannon/modern,ARTILLERYCOST_CAFR),
			list("artillery shells", /obj/structure/closet/crate/ww2/artillery_shells,SHELLCOST_CAFR),
			list("foldable mortar", /obj/structure/cannon/mortar/foldable/generic,MORTARCOST_CAFR),
			list("mortar shells", /obj/structure/closet/crate/ww2/mortar_shells,MSHELLCOST_CAFR),
			list("KAMAZ truck", /obj/effects/premadevehicles/truck/kamaz,KAMAZCOST_CAFR),
			list("BMD-2 IFV", /obj/effects/premadevehicles/apc/bmd2,BMD2COST_CAFR),
			list("T-55 tank", /obj/effects/premadevehicles/tank/t55,T55COST_CAFR),
			list("T-72 tank", /obj/effects/premadevehicles/tank/t72,T72COST_CAFR),
		)

/obj/structure/pepelsibirsk_radio/supply_radio/no_scam/campaign/tsfsr
	factionarea = "SupplyTSFSR"
	civ_catalogue = list( //type name, path, price
			list("wood crate", /obj/structure/closet/crate/wood,WOODCOST_TSFSR),
			list("iron crate", /obj/structure/closet/crate/iron,IRONCOST_TSFSR),
			list("steel crate", /obj/structure/closet/crate/steel,IRONCOST_TSFSR),
			list("glass crate", /obj/structure/closet/crate/glass,GLASSCOST_TSFSR),
			list("stone crate", /obj/structure/closet/crate/stone,STONECOST_TSFSR),
			list("vegetables crate", /obj/structure/closet/crate/rations/vegetables,VEGETABLESCOST_TSFSR),
			list("fruits crate", /obj/structure/closet/crate/rations/fruits,FRUITCOST_TSFSR),
			list("biscuits crate", /obj/structure/closet/crate/rations/biscuits,BISCUITCOST_TSFSR),
			list("beer crate", /obj/structure/closet/crate/rations/beer,BEERCOST_TSFSR),
			list("ale crate", /obj/structure/closet/crate/rations/ale,ALECOST_TSFSR),
			list("cow", /mob/living/simple_animal/cattle/cow,COWCOST_TSFSR),
			list("bull", /mob/living/simple_animal/cattle/bull,COWCOST_TSFSR),
			list("sheep ram", /mob/living/simple_animal/sheep,SHEEPCOST_TSFSR),
			list("sheep ewe", /mob/living/simple_animal/sheep/female,SHEEPCOST_TSFSR),
			list("pig boar", /mob/living/simple_animal/pig_boar,PIGCOST_TSFSR),
			list("pig gilt", /mob/living/simple_animal/pig_gilt,PIGCOST_TSFSR),
			list("hen", /mob/living/simple_animal/chicken,CHICKENCOST_TSFSR),
			list("rooster", /mob/living/simple_animal/rooster,CHICKENCOST_TSFSR),
			list("horse", /mob/living/simple_animal/horse,HORSECOST_TSFSR),
			list("brick crate", /obj/structure/closet/crate/brick,BRICKCOST_TSFSR),
			list("medical supplies", /obj/item/weapon/storage/firstaid/adv,FIRSTAIDADVCOST_TSFSR),
		)
	mil_catalogue = list(
			list("gunpowder barrel", /obj/item/weapon/reagent_containers/glass/barrel/gunpowder,GUNPOWDERCOST_TSFSR),
			list("gunpowder barrel bomb", /obj/item/weapon/grenade/bomb,GUNPOWDERCOST_TSFSR),
			list("suicide vest crate (4)", /obj/structure/closet/crate/suicidevests,SUICIDEVESTCOST_TSFSR),
			list("sks crate (5)", /obj/structure/closet/crate/pepelsibirsk/sks,SKSCOST_TSFSR),
			list("akm crate (5)", /obj/structure/closet/crate/pepelsibirsk/akm,AKMCOST_TSFSR),
			list("ak-74 crate (5)", /obj/structure/closet/crate/pepelsibirsk/ak74,AK74COST_TSFSR),
			list("svd crate (2)", /obj/structure/closet/crate/pepelsibirsk/svd,SVDCOST_TSFSR),
			list("mosin-nagant crate (10)", /obj/structure/closet/crate/pepelsibirsk/mosin,MOSINCOST_TSFSR),
			list("PPSh-41 crate (2)", /obj/structure/closet/crate/pepelsibirsk/ppsh,PPSHCOST_TSFSR),
			list("makarov crate (5)", /obj/structure/closet/crate/pepelsibirsk/makarov,MAKAROVCOST_TSFSR),
			list("PKM crate (1)", /obj/structure/closet/crate/airdrops/soviet/pkm,PKMCOST_TSFSR),
			list("surplus red army uniform crate (5)", /obj/structure/closet/crate/pepelsibirsk/surplus_ww2,WW2SURPLUSUNIFORMCOST_TSFSR),
			list("afghanka uniform crate (5)", /obj/structure/closet/crate/pepelsibirsk/sov_uniforms,AFGHANKACOST_TSFSR),
			list("frag grenade crate (12)", /obj/structure/closet/crate/pepelsibirsk/rgd5,RGD5COST_TSFSR),
			list("7.62x39mm ammunition crate (300)", /obj/structure/closet/crate/pepelsibirsk/seven62x39mm,AKAMMOCOST_TSFSR),
			list("7.62x54mmR ammunition crate (200)", /obj/structure/closet/crate/pepelsibirsk/seven62x54mmr,MOSINAMMOCOST_TSFSR),
			list("9x18mm ammunition crate (240)", /obj/structure/closet/crate/pepelsibirsk/ninex18mm,MAKAROVAMMOCOST_TSFSR),
			list("6B1 vest crate (5)", /obj/structure/closet/crate/pepelsibirsk/sixb1,SIXB1COST_TSFSR),
			list("6B2 vest crate (5)", /obj/structure/closet/crate/pepelsibirsk/sixb2,SIXB2COST_TSFSR),
			list("PU (Mosin/SVT) scope crate (5)", /obj/structure/closet/crate/scopes/pu,PUCOST_TSFSR),
			list("PSO-1 (Dovetail) scope crate (5)", /obj/structure/closet/crate/scopes/pso1,PSO1COST_TSFSR),
			list("towed artillery", /obj/structure/cannon/modern,ARTILLERYCOST_TSFSR),
			list("artillery shells", /obj/structure/closet/crate/ww2/artillery_shells,SHELLCOST_TSFSR),
			list("foldable mortar", /obj/structure/cannon/mortar/foldable/generic,MORTARCOST_TSFSR),
			list("mortar shells", /obj/structure/closet/crate/ww2/mortar_shells,MSHELLCOST_TSFSR),
			list("KAMAZ truck", /obj/effects/premadevehicles/truck/kamaz,KAMAZCOST_TSFSR),
			list("BMD-2 IFV", /obj/effects/premadevehicles/apc/bmd2,BMD2COST_TSFSR),
			list("T-55 tank", /obj/effects/premadevehicles/tank/t55,T55COST_TSFSR),
			list("T-72 tank", /obj/effects/premadevehicles/tank/t72,T72COST_TSFSR),
		)

/obj/structure/pepelsibirsk_radio/supply_radio/no_scam/campaign/company(user)
	///VARS///
	var/catalogue = list()
	var/list/companies = list(
		"Cancel Purchase",
		"Military Supplies",
		"Civilian Supplies",
	)

	///PURCHASING LOGIC///
	var/choice = WWinput(user, "Pick a catalogue:", "Supplier", "Cancel Purchase", companies) //Dialog box
	if (choice == "Cancel Purchase")
		///Giving your money back///
		if((round(money) >= 1))
			new/obj/item/stack/money/rubles(loc, round(money))		//Rubles
		if (((money) - round(money)) > 0)
			new/obj/item/stack/money/coppercoin(loc, round(((money) - round(money)), 0.01) * 100)  //This should never happen, but just in case
		money = 0
		return
	if (choice == "Civilian Supplies")
		catalogue = civ_catalogue
	else if (choice == "Military Supplies")
		catalogue = mil_catalogue
	purchase(user, choice, catalogue)
	return

/obj/structure/pepelsibirsk_radio/supply_radio/no_scam/campaign/purchase(user, choice, catalogue)
	///VARS///
	var/final_cost //The final cost of the purchased product
	var/list/final_list = list() //The details for the product to be purchased
	var/list/display = list() //The products to be displayed, includes name of crate and price
	///Display the menu asking for what you want to purchase
	for (var/list/i in catalogue)
		display += "[i[1]], [i[3]] rubles"
		display += "Cancel Purchase"
	var/choice2 = WWinput(user, "Current Rubles: [money]", "Order a crate", "Cancel Purchase", display)
	var/list/choicename = splittext(choice2, ", ")

	///ACTUAL PURCHASING LOGIC///
	if (choice2 != "Cancel Purchase")
		for(var/list/i2 in catalogue) //Goes through everything in the chosen catalogue
			if (i2[1]== choicename[1]) //Checks if each item it goes through is the correct item
				final_list = i2 //If it is, set that to final_list
				world.log << "A purchase has been made: [final_list[1]], [final_list[2]], [final_list[3]]"
				final_cost = (final_list[3]) //Set the cost of the item based on the cost value in the list
				if (final_list[3] <= money)
					money -= final_cost
					update_cost(final_list, final_cost, choice, user)
					if((round(money) >= 1))
						new/obj/item/stack/money/rubles(loc, round(money))
					if (((money) - round(money)) > 0)
						new/obj/item/stack/money/coppercoin(loc, round(((money) - round(money)), 0.01) * 100)	//This should never happen, but just in case
					money = 0
				else // you're broke
					if((round(money) >= 1))
						new/obj/item/stack/money/rubles(loc, round(money))
					if (((money) - round(money)) > 0)
						new/obj/item/stack/money/coppercoin(loc, round(((money) - round(money)), 0.01) * 100)	//This should never happen, but just in case
					money = 0
					to_chat(user, "You don't have enough money for this item.")
				break
	else
		if((round(money) >= 1)) //giving money back
			new/obj/item/stack/money/rubles(loc, round(money))
		if (((money) - round(money)) > 0)
			new/obj/item/stack/money/coppercoin(loc, round(((money) - round(money)), 0.01) * 100)	//This should never happen, but just in case
		money = 0
		return

/obj/structure/pepelsibirsk_radio/supply_radio/no_scam/campaign/update_cost(final_list, final_cost, choice, user)
	to_chat(user, "Your [final_list[1]] will arrive in 60 seconds.")
	spawn(1 MINUTE)
		var/list/turfs = list()
		if (faction_treasury != "craftable")
			turfs = latejoin_turfs[factionarea]
		else
			turfs = list(get_turf(locate(x,y+1,z)))
		var/spawnpoint
		spawnpoint = pick(turfs)
		var/tpath = final_list[2]
		new tpath(get_turf(spawnpoint))
		to_chat(user, "Your [final_list[1]] has arrived.")
	return

// CAMPAIGN METATATA //

/obj/map_metadata/campaign_new
	ID = MAP_CAMPAIGN_NEW
	title = "Campaign"
	lobby_icon = 'icons/lobby/campaign2.png'
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/desert)
	respawn_delay = 2 MINUTES
	no_winner = "The battle is going on."
	victory_time = 45 MINUTES
	grace_wall_timer = 8 MINUTES
	can_spawn_on_base_capture = TRUE
	faction_organization = list(
		TSFSR,
		CAFR)

	roundend_condition_sides = list(
		list(TSFSR) = /area/caribbean/faction1,
		list(CAFR) = /area/caribbean/british/land/inside/objective,
		)
	is_campaign_map = TRUE
	age = "1976"
	ordinal_age = 7
	faction_distribution_coeffs = list(TSFSR = 0.5, CAFR = 0.5)
	battle_name = "battle of Emberburg"
	mission_start_message = "<font size=4><b>8 minutes</b> until the battle begins. The CAFR must hold the road tunnel for 45 minutes to achieve victory.</font>"
	faction1 = TSFSR
	faction2 = CAFR
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"Black Vortex - Kevin Macleod:1" = 'sound/music/black-vortex.ogg',)
	artillery_count = 0

	scores = list(
		"Turkestan SFSR" = 0,
		"Central Asian Federal Republic" = 0,
	)
	var/list/squad_jobs_red = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	var/list/squad_jobs_blue = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)

/obj/map_metadata/campaign_new/New()
	..()

/obj/map_metadata/campaign_new/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/tsfsr))
		. = TRUE
	else if (istype(J, /datum/job/cafr))
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/campaign_new/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= grace_wall_timer || admin_ended_all_grace_periods)

/obj/map_metadata/campaign_new/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= grace_wall_timer || admin_ended_all_grace_periods)

/obj/map_metadata/campaign_new/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/temperate/two))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/temperate/one))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE

/obj/map_metadata/campaign_new/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 2 MINUTES
	else
		return 5 MINUTES

/obj/map_metadata/campaign_new/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 2 MINUTES
	else
		return 7 MINUTES

//role selector
/mob/new_player/proc/LateChoicesCampaignNew(factjob)
	var/list/available_jobs_per_side = list(
		CAFR = FALSE,
		TSFSR = FALSE,
	)
	var/obj/map_metadata/campaign_new/MC = map
	src << browse(null, "window=latechoices")

	var/list/dat = list("<center>")
	dat += "<b><big>Welcome, [key].</big></b>"
	dat += "<br>"
	dat += "Round Duration: [roundduration2text_days()]"
	dat += "<br>"
	dat += "<b>Current Autobalance Status</b>: "
	if (CAFR in map.faction_organization)
		dat += "[alive_bluefaction.len] CAFR soldiers "
	if (TSFSR in map.faction_organization)
		dat += "[alive_redfaction.len] Turkestan SFSR soldiers "

	dat += "<br>"
	switch (factjob)
		if ("blue")
			dat +="<b><h1><big>Central Asian Federal Republic</big></h1></b>"
		if ("red")
			dat +="<b><h1><big>Turkestan SFSR</big></h1></b>"
	for (var/datum/job/job in job_master.faction_organized_occupations)
		switch (factjob)
			if ("red")
				if(!findtext(job.title, "TSFSR"))
					continue
				if(findtext(job.title, "TSFSR Doctor") && MC.squad_jobs_blue["none"]["Doctor"]<= 0)
					continue
				if(findtext(job.title, "TSFSR Officer") && MC.squad_jobs_blue["none"]["Officer"]<= 0)
					continue
				if(findtext(job.title, "TSFSR Commander") && MC.squad_jobs_blue["none"]["Commander"]<= 0)
					continue
				if(findtext(job.title, "TSFSR Squad [job.squad] Squadleader") && MC.faction2_squad_leaders[job.squad])
					continue
				if(findtext(job.title, "TSFSR Armored Squadleader") && MC.faction2_squad_leaders[job.squad])
					continue
				if(findtext(job.title, "TSFSR Armored Crew") && MC.squad_jobs_red["Armored"]["Crew"]<= 0)
					continue
				if(findtext(job.title, "TSFSR Recon") && MC.squad_jobs_blue["Recon"]["Sniper"]<= 0)
					continue
				if(findtext(job.title, "TSFSR Anti-Tank") && MC.squad_jobs_blue["AT"]["Anti-Tank"]<= 0)
					continue
				if(findtext(job.title, "TSFSR Engineer") && MC.squad_jobs_blue["Engineer"]["Engineer"]<= 0)
					continue
				if(findtext(job.title, "TSFSR Squad [job.squad] Machinegunner") && MC.squad_jobs_blue["Squad [job.squad]"]["Machinegunner"]<= 0)
					continue
			if ("blue")
				if(!findtext(job.title, "CAFR"))
					continue
				if(findtext(job.title, "CAFR Doctor") && MC.squad_jobs_red["none"]["Doctor"]<= 0)
					continue
				if(findtext(job.title, "CAFR Officer") && MC.squad_jobs_red["none"]["Officer"]<= 0)
					continue
				if(findtext(job.title, "CAFR Commander") && MC.squad_jobs_red["none"]["Commander"]<= 0)
					continue
				if(findtext(job.title, "CAFR Squad [job.squad] Squadleader") && MC.faction1_squad_leaders[job.squad])
					continue
				if(findtext(job.title, "CAFR Armored Squadleader") && MC.faction1_squad_leaders[job.squad])
					continue
				if(findtext(job.title, "CAFR Armored Crew") && MC.squad_jobs_red["Armored"]["Crew"]<= 0)
					continue
				if(findtext(job.title, "CAFR Recon") && MC.squad_jobs_red["Recon"]["Sniper"]<= 0)
					continue
				if(findtext(job.title, "CAFR Anti-Tank") && MC.squad_jobs_red["AT"]["Anti-Tank"]<= 0)
					continue
				if(findtext(job.title, "CAFR Engineer") && MC.squad_jobs_red["Engineer"]["Engineer"]<= 0)
					continue
				if(findtext(job.title, "CAFR Squad [job.squad] Machinegunner") && MC.squad_jobs_red["Squad [job.squad]"]["Machinegunner"]<= 0)
					continue
		if (job)
			var/active = processes.job_data.get_active_positions(job)
			var/extra_span = "<b>"
			var/end_extra_span = "</b>"
			if (job.is_squad_leader)
				extra_span = "<br><b><font size=2>"
				end_extra_span = "</font></b>"
			else if (job.is_commander)
				extra_span = "<br><font size=3>"
				end_extra_span = "</font>"
			else if ((job.is_medic && !findtext(job.title, "Corpsman")) || !findtext(job.title, "Squad"))
				extra_span = "<br>"
				end_extra_span = ""

			dat += "[extra_span]<a style=\"background-color:[job.selection_color];\" href='byond://?src=\ref[src];SelectedJob=[job.title]'>[job.title] (Active: [active])</a>[end_extra_span]"
			++available_jobs_per_side[job.base_type_flag()]

	dat += "</center>"

	var/data = ""
	for (var/line in dat)
		if (line != null)
			if (line != "<br>")
				data += "<span style = 'font-size:2.0rem;'>[line]</span>"
			data += "<br>"

	data = {"
		<br>
		<html>
		<head>
		[common_browser_style]
		</head>
		<body>
		[data]
		</body>
		</html>
		<br>
	"}

	spawn (1)
		src << browse(data, "window=latechoices;size=600x640;can_close=1")

/obj/map_metadata/campaign_new/update_win_condition()
	// Win when timer reaches zero
	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = SPAN_BLUE("The <b>CAFR</b> is victorious [battle_name ? "in the [battle_name]" : "the battle"]!")
		to_chat(world, SPAN_NOTICE("<font size = 4>[message]</font>"))
		
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_ca == FALSE)
		ticker.finished = TRUE
		var/message = "The [battle_name ? battle_name : "battle"] has ended in a stalemate!"
		if (current_winner && current_loser)
			message = SPAN_RED("The <b>Turkestan SFSR</b> is victorious [battle_name ? "in the [battle_name]" : "the battle"]!")
		to_chat(world, SPAN_NOTICE("<font size = 4>[message]</font>"))

		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_ca = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Turkestan SFSR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Turkestan SFSR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>CAFR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>CAFR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>CAFR</b> has retaken control over the objective!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/campaign_new/campaign1
	ID = MAP_CAMPAIGN_1A
	battle_name = "Battle of the Road"
	squad_jobs_red = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	squad_jobs_blue = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)

/obj/map_metadata/campaign_new/campaign1b
	ID = MAP_CAMPAIGN_1B
	battle_name = "Battle of the Road"
	mission_start_message = "<font size=4><b>5 minutes</b> until the battle begins. The Turkestan SFSR must hold the road tunnel for 45 minutes to achieve victory.</font>"
	squad_jobs_red = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	squad_jobs_blue = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	roundend_condition_sides = list(
		list(TSFSR) = /area/caribbean/british/land/inside/objective,
		list(CAFR) = /area/caribbean/faction2,
		)

/obj/map_metadata/campaign_new/campaign1b/update_win_condition()
	// Win when timer reaches zero
	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = SPAN_RED("The <b>Turkestan SFSR</b> is victorious [battle_name ? "in the [battle_name]" : "the battle"]!")
		to_chat(world, SPAN_NOTICE("<font size = 4>[message]</font>"))
		
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_ca == FALSE)
		ticker.finished = TRUE
		var/message = "The [battle_name ? battle_name : "battle"] has ended in a stalemate!"
		if (current_winner && current_loser)
			message = SPAN_BLUE("The <b>Central Asian Federal Republic</b> is victorious [battle_name ? "in the [battle_name]" : "the battle"]!")
		to_chat(world, SPAN_NOTICE("<font size = 4>[message]</font>"))

		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_ca = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Turkestan SFSR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Turkestan SFSR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>CAFR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>CAFR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>CAFR</b> has retaken control over the objective!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/campaign_new/campaign2a
	ID = MAP_CAMPAIGN_2A
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/semiarid)
	battle_name = "Battle of Samarkand"
	mission_start_message = "<font size=4><b>8 minutes</b> until the battle begins. The Turkestan SFSR must hold the madrasa for 45 minutes to achieve victory.</font>"
	squad_jobs_red = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	squad_jobs_blue = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	faction_organization = list(
		CAFR,
		TSFSR)
	roundend_condition_sides = list(
		list(TSFSR) = /area/caribbean/british/land/inside/objective,
		list(CAFR) = /area/caribbean/faction2,
		)
	can_spawn_on_base_capture = FALSE

/obj/map_metadata/campaign_new/campaign2a/update_win_condition()
	// Win when timer reaches zero
	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = SPAN_RED("The <b>Turkestan SFSR</b> is victorious [battle_name ? "in the [battle_name]" : "the battle"]!")
		to_chat(world, SPAN_NOTICE("<font size = 4>[message]</font>"))
		
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_ca == FALSE)
		ticker.finished = TRUE
		var/message = "The [battle_name ? battle_name : "battle"] has ended in a stalemate!"
		if (current_winner && current_loser)
			message = SPAN_BLUE("The <b>Central Asian Federal Republic</b> is victorious [battle_name ? "in the [battle_name]" : "the battle"]!")
		to_chat(world, SPAN_NOTICE("<font size = 4>[message]</font>"))

		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_ca = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Turkestan SFSR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Turkestan SFSR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>CAFR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>CAFR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>CAFR</b> has retaken control over the objective!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/campaign_new/campaign2b
	ID = MAP_CAMPAIGN_2B
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/semiarid)
	battle_name = "Battle of Samarkand"
	mission_start_message = "<font size=4><b>8 minutes</b> until the battle begins. The Central Asian Federal Republic must hold the madrasa for 45 minutes to achieve victory.</font>"
	squad_jobs_red = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	squad_jobs_blue = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	roundend_condition_sides = list(
		list(TSFSR) = /area/caribbean/faction1,
		list(CAFR) = /area/caribbean/british/land/inside/objective,
		)
	can_spawn_on_base_capture = FALSE

/obj/map_metadata/campaign_new/campaign3a
	ID = MAP_CAMPAIGN_3A
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/semiarid)
	battle_name = "Battle of Bokhtar"
	mission_start_message = "<font size=4><b>8 minutes</b> until the battle begins. The Central Asian Federal Republic must hold the command post at the eastern end of the bridge for 45 minutes to achieve victory!.</font>"
	squad_jobs_red = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	squad_jobs_blue = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	roundend_condition_sides = list(
		list(TSFSR) = /area/caribbean/faction1,
		list(CAFR) = /area/caribbean/british/land/outside/objective,
		)

/obj/map_metadata/campaign_new/campaign3b
	ID = MAP_CAMPAIGN_3B
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/semiarid)
	battle_name = "Battle of Bokhtar"
	victory_time = 25 MINUTES
	mission_start_message = "<font size=4><b>8 minutes</b> until the battle begins. The Turkestan SFSR must hold the command post at the eastern end of the bridge for 25 minutes to achieve victory!.</font>"
	squad_jobs_red = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	squad_jobs_blue = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	roundend_condition_sides = list(
		list(TSFSR) = /area/caribbean/british/land/outside/objective,
		list(CAFR) = /area/caribbean/faction1,
		)

/obj/map_metadata/campaign_new/campaign3b/update_win_condition()
	// Win when timer reaches zero
	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = SPAN_RED("The <b>Turkestan SFSR</b> is victorious [battle_name ? "in the [battle_name]" : "the battle"]!")
		to_chat(world, SPAN_NOTICE("<font size = 4>[message]</font>"))
		
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_ca == FALSE)
		ticker.finished = TRUE
		var/message = "The [battle_name ? battle_name : "battle"] has ended in a stalemate!"
		if (current_winner && current_loser)
			message = SPAN_BLUE("The <b>Central Asian Federal Republic</b> is victorious [battle_name ? "in the [battle_name]" : "the battle"]!")
		to_chat(world, SPAN_NOTICE("<font size = 4>[message]</font>"))

		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_ca = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Turkestan SFSR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Turkestan SFSR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>CAFR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>CAFR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>CAFR</b> has retaken control over the objective!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/campaign_new/campaign4a
	ID = MAP_CAMPAIGN_4A
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/tundra)
	battle_name = "Route to Alma-Ata"
	mission_start_message = "<font size=4><b>8 minutes</b> until the battle begins. The Turkestan Soviet Federative Socialist Republic must hold the far-northern end of the path for 45 minutes to achieve victory!.</font>"
	squad_jobs_red = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	squad_jobs_blue = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	roundend_condition_sides = list(
		list(TSFSR) = /area/caribbean/british/land/outside/objective,
		list(CAFR) = /area/caribbean/faction1,
		)

/obj/map_metadata/campaign_new/campaign4a/update_win_condition()
	// Win when timer reaches zero
	if (world.time >= victory_time)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = SPAN_RED("The <b>Turkestan SFSR</b> is victorious [battle_name ? "in the [battle_name]" : "the battle"]!")
		to_chat(world, SPAN_NOTICE("<font size = 4>[message]</font>"))
		
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_ca == FALSE)
		ticker.finished = TRUE
		var/message = "The [battle_name ? battle_name : "battle"] has ended in a stalemate!"
		if (current_winner && current_loser)
			message = SPAN_BLUE("The <b>Central Asian Federal Republic</b> is victorious [battle_name ? "in the [battle_name]" : "the battle"]!")
		to_chat(world, SPAN_NOTICE("<font size = 4>[message]</font>"))

		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_ca = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Turkestan SFSR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>Turkestan SFSR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>CAFR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The <b>CAFR</b> has captured the objective! They will win in {time} minutes."
				next_win = world.time + short_win_time(CAFR)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The <b>CAFR</b> has retaken control over the objective!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/campaign_new/campaign4b
	ID = MAP_CAMPAIGN_4B
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/tundra)
	battle_name = "Route to Alma-Ata"
	mission_start_message = "<font size=4><b>8 minutes</b> until the battle begins. 40 points for victory!</font>"
	squad_jobs_red = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	squad_jobs_blue = list(
		"Squad 1" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 2" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Squad 3" = list("Corpsman" = 2, "Machinegunner" = 1),
		"Recon" = list("Sniper" = 4),
		"Armored" = list("Crew" = 8),
		"AT" = list("Anti-Tank" = 3),
		"Engineer" = list("Engineer" = 3),
		"none" = list("Commander" = 1, "Officer" = 3, "Doctor" = 2),
	)
	roundend_condition_sides = list(
		list(TSFSR) = /area/caribbean/faction1,
		list(CAFR) = /area/caribbean/british/land/outside/objective,
		)
	var/tsfsr_points = 0
	var/cafr_points = 0
	var/a1_control = "none"
	var/a2_control = "none"
	var/a3_control = "none"
	var/a4_control = "none"

/obj/map_metadata/campaign_new/campaign4b/proc/points_check()
	if (processes.ticker.playtime_elapsed > 8 MINUTES)
		var/c1 = 0
		var/c2 = 0
		var/cust_color = "white"
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/one/outside))
				if (H.faction_text == faction2 && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == faction1 && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a1_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a1_control = "Central Asian Federal Republic"
			cust_color="blue"
			cafr_points++
		else if (c2 > c1)
			a1_control = "Turkestan Soviet Federative Socialist Republic"
			cust_color="red"
			tsfsr_points++
		if (a1_control != "none")
			if (a1_control == "Turkestan Soviet Federative Socialist Republic")
				cust_color = "red"
			else
				cust_color = "blue"
			world << "<big><font color='[cust_color]'><b>Southern Road</b>: [a1_control]</font></big>"
		else
			world << "<big><b>Southern Road</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/two))
				if (H.faction_text == faction2 && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == faction1 && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a2_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a2_control = "Central Asian Federal Republic"
			cust_color="blue"
			cafr_points++
		else if (c2 > c1)
			a2_control = "Turkestan Soviet Federative Socialist Republic"
			cust_color="red"
			tsfsr_points++
		if (a2_control != "none")
			if (a2_control == "Turkestan Soviet Federative Socialist Republic")
				cust_color = "red"
			else
				cust_color = "blue"
			world << "<big><font color='[cust_color]'><b>Mountain Ledge</b>: [a2_control]</font></big>"
		else
			world << "<big><b>Mountain Ledge</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/three))
				if (H.faction_text == faction2 && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == faction1 && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a3_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a3_control = "Central Asian Federal Republic"
			cust_color="blue"
			cafr_points++
		else if (c2 > c1)
			a3_control = "Turkestan Soviet Federative Socialist Republic"
			cust_color="red"
			tsfsr_points++
		if (a3_control != "none")
			if (a3_control == "Turkestan Soviet Federative Socialist Republic")
				cust_color = "red"
			else
				cust_color = "blue"
			world << "<big><font color='[cust_color]'><b>Mountain Tunnels</b>: [a3_control]</font></big>"
		else
			world << "<big><b>Mountain Tunnels</b>: Nobody</big>"
		c1 = 0
		c2 = 0
		for (var/mob/living/human/H in player_list)
			var/area/temp_area = get_area(H)
			if (istype(temp_area, /area/caribbean/no_mans_land/capturable/four/outside))
				if (H.faction_text == faction2 && H.stat == CONSCIOUS)
					c1++
				else if (H.faction_text == faction1 && H.stat == CONSCIOUS)
					c2++
		if (c1 == c2 && c1 != 0)
			a4_control = "none"
			cust_color="white"
		else if (c1 > c2)
			a4_control = "Central Asian Federal Republic"
			cust_color="blue"
			cafr_points++
		else if (c2 > c1)
			a4_control = "Turkestan Soviet Federative Socialist Republic"
			cust_color="red"
			tsfsr_points++
		if (a4_control != "none")
			if (a4_control == "Turkestan Soviet Federative Socialist Republic")
				cust_color = "red"
			else
				cust_color = "blue"
			world << "<big><font color='[cust_color]'><b>Northern Road</b>: [a4_control]</font></big>"
		else
			world << "<big><b>Northern Road</b>: Nobody</big>"
	world << "<big><b>Current Points:</big></b>"
	world << "<big>Central Asian Federal Republic: [cafr_points]</big>"
	world << "<big>Turkestan Soviet Federative Socialist Republic: [tsfsr_points]</big>"
	spawn(300)
		points_check()

/obj/map_metadata/campaign_new/campaign4b/New()
	..()
	spawn(3000)
		points_check()


/obj/map_metadata/campaign_new/campaign4b/update_win_condition()
	if (processes.ticker.playtime_elapsed > 12 MINUTES)
		if (tsfsr_points < 40 && cafr_points < 40)
			return TRUE
		if (tsfsr_points >= 40 && tsfsr_points > cafr_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>TSFSR</b> has reached [tsfsr_points] points and won!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
		if (cafr_points >= 40 && cafr_points > tsfsr_points)
			if (win_condition_spam_check)
				return FALSE
			ticker.finished = TRUE
			var/message = "The <b>CAFR</b> has reached [cafr_points] points and won!"
			world << "<font size = 4><span class = 'notice'>[message]</span></font>"
			show_global_battle_report(null)
			win_condition_spam_check = TRUE
			return FALSE
	return TRUE
