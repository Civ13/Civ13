/obj/map_metadata/colonia //this is literally just pepelsibirsk but roman
	ID = MAP_COLONIA
	title = "Colonia"
	lobby_icon = "icons/lobby/ancient.png"
	no_winner = "The round is proceeding normally."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/temperate)
	respawn_delay = 1200 // 2 minutes
	has_hunger = TRUE

	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "60 A.D. Q1 (ROUND SETUP)"
	ordinal_age = 1
	civilizations = TRUE
	nomads = TRUE

	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the civilizations"
	mission_start_message = "<big><b>A group of Romans has been sent to establish a colony in these lands. You must ensure the prosperity of the new settlement. The grace wall will be lifted in 5 minutes, prepare by establishing your government.</b></big>"
	ambience = list("sound/ambience/desert.ogg")
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Words Through the Sky:1" = "sound/music/words_through_the_sky.ogg",)
	gamemode = "Colonia"
	age1_done = TRUE
	default_research = 35
	valid_weather_types = list(WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME)
	gamemode_vote = FALSE
	var/real_season = "SPRING"
	var/quarter = 2
	var/year = 60
	
	#define BARBARIAN_RELATIONS external_relations.npc_faction_relations["faction_1_relations"]
	#define ROMAN_RELATIONS external_relations.npc_faction_relations["faction_4_relations"]
	#define LOCAL_TRIBES_RELATIONS external_relations.npc_faction_relations["faction_5_relations"]

/obj/map_metadata/colonia/New()
	..()
	relations_subsystem()
	recover_relations()
	invasion_subsystem()
	time_update(age, quarter, year)
	BARBARIAN_RELATIONS = 0
	ROMAN_RELATIONS = 100
	LOCAL_TRIBES_RELATIONS = 50
	check_relations_msg()

/////////////////////////////////SEASONS//////////////////////////
/obj/map_metadata/colonia/seasons()
	if (season == "FALL")
		season = "WINTER"
		to_chat(world, "<big>The <b>Winter</b> has started. In the hot climates, the wet season has started.</big>")
		change_weather_somehow()
		spawn(1200)
			for (var/obj/structure/wild/tree/live_tree/TREES in world)
				TREES.change_season()
		for (var/turf/floor/dirt/flooded/D)
			D.ChangeTurf(/turf/floor/beach/water/flooded)
		for (var/turf/floor/dirt/ploughed/flooded/D)
			D.ChangeTurf(/turf/floor/beach/water/flooded)
		for(var/obj/structure/sink/S)
			if (istype(S, /obj/structure/sink/well) || istype(S, /obj/structure/sink/puddle))
				S.dry = FALSE
				S.update_icon()
		for (var/turf/floor/beach/drywater/B in get_area_turfs(/area/caribbean/nomads/desert))
			B.ChangeTurf(/turf/floor/beach/water/swamp)
		for (var/turf/floor/beach/drywater2/C in get_area_turfs(/area/caribbean/nomads/desert))
			C.ChangeTurf(/turf/floor/beach/water/deep/swamp)
		for (var/turf/floor/dirt/jungledirt/JD in get_area_turfs(/area/caribbean/nomads/forest/Jungle))
			if (prob(50))
				JD.ChangeTurf(/turf/floor/grass/jungle)
		for (var/turf/floor/dirt/dry_lava/JD in get_area_turfs(/area/caribbean/nomads/forest/Jungle))
			if (prob(50))
				JD.ChangeTurf(/turf/floor/grass/jungle)
		for (var/turf/floor/dirt/jungledirt/JD2 in get_area_turfs(/area/caribbean/nomads/forest/savanna))
			if (prob(50))
				JD2.ChangeTurf(/turf/floor/grass/jungle)
		for (var/turf/floor/dirt/burned/BD in get_area_turfs(/area/caribbean/nomads/desert))
			if (prob(75))
				BD.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/dirt/burned/BDD in get_area_turfs(/area/caribbean/nomads/forest/Jungle))
			if (prob(75))
				BDD.ChangeTurf(/turf/floor/dirt/jungledirt)
		for (var/turf/floor/dirt/burned/BDD2 in get_area_turfs(/area/caribbean/nomads/forest/savanna))
			if (prob(75))
				BDD2.ChangeTurf(/turf/floor/dirt/jungledirt)
		for (var/turf/floor/dirt/DT in get_area_turfs(/area/caribbean/nomads/forest))
			if (!istype(DT, /turf/floor/dirt/underground))
				var/area/A = get_area(DT)
				if (A.climate == "temperate")
					if (prob(75))
						DT.ChangeTurf(/turf/floor/dirt/winter)
				else if (A.climate == "tundra" || A.climate == "taiga")
					DT.ChangeTurf(/turf/floor/dirt/winter)
		for (var/turf/floor/grass/GT in get_area_turfs(/area/caribbean/nomads/forest))
			var/area/A = get_area(GT)
			if (A.climate == "temperate")
				if (prob(80))
					GT.ChangeTurf(/turf/floor/winter/grass)
			else if (A.climate == "tundra" || A.climate == "taiga")
				GT.ChangeTurf(/turf/floor/winter/grass)
		for (var/turf/floor/dirt/DTT in get_area_turfs(/area/caribbean/nomads/snow))
			if (!istype(DTT, /turf/floor/dirt/underground))
				DTT.ChangeTurf(/turf/floor/dirt/winter)
		for (var/turf/floor/grass/GTT in get_area_turfs(/area/caribbean/nomads/snow))
			GTT.ChangeTurf(/turf/floor/winter/grass)

	else if (season == "SPRING")
		season = "SUMMER"
		to_chat(world, "<big>The <b>Summer</b> has started. In the hot climates, the dry season has started.</big>")
		change_weather_somehow()
		spawn(300)
			for (var/obj/structure/wild/tree/live_tree/TREES in world)
				TREES.change_season()
		for(var/obj/structure/sink/S in get_area_turfs(/area/caribbean/nomads/desert))
			if (istype(S, /obj/structure/sink/well) || istype(S, /obj/structure/sink/puddle))
				S.dry = TRUE
				S.update_icon()
		for (var/turf/floor/beach/water/swamp/D in get_area_turfs(/area/caribbean/nomads/desert))
			if (D.z > 1)
				D.ChangeTurf(/turf/floor/beach/drywater)
		for (var/turf/floor/beach/water/deep/swamp/DS in get_area_turfs(/area/caribbean/nomads/desert))
			if (DS.z > 1)
				DS.ChangeTurf(/turf/floor/beach/drywater2)
		for (var/turf/floor/beach/water/flooded/DF)
			if (DF.z > 1)
				DF.ChangeTurf(/turf/floor/dirt/flooded)
		for (var/turf/floor/dirt/winter/DT in get_area_turfs(/area/caribbean/nomads/forest))
			var/area/A = get_area(DT)
			if (A.climate == "temperate")
				DT.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/winter/grass/GT in get_area_turfs(/area/caribbean/nomads/forest))
			var/area/A = get_area(GT)
			if (A.climate == "temperate")
				GT.ChangeTurf(/turf/floor/grass)
		for (var/turf/floor/winter/WT in get_area_turfs(/area/caribbean/roofed))
			WT.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/dirt/winter/WT in get_area_turfs(/area/caribbean/roofed))
			WT.ChangeTurf(/turf/floor/dirt)
	else if (season == "WINTER")
		season = "SPRING"
		to_chat(world, "<big>The weather is getting warmer. It is now <b>Spring</b>. In the hot climates, the wet season continues.</big>")
		spawn(900)
			for (var/obj/structure/wild/tree/live_tree/TREES in world)
				TREES.change_season()
		for (var/turf/floor/dirt/winter/D in get_area_turfs(/area/caribbean/nomads/forest))
			var/area/A = get_area(D)
			if (A.climate == "temperate")
				if (prob(60))
					if (prob(40))
						D.ChangeTurf(/turf/floor/grass)
					else
						D.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/winter/grass/G in get_area_turfs(/area/caribbean/nomads/forest))
			var/area/A = get_area(G)
			if (A.climate == "temperate")
				if (prob(60))
					G.ChangeTurf(/turf/floor/grass)
		spawn(150)
			change_weather(WEATHER_NONE)
			for (var/obj/structure/window/barrier/snowwall/SW1 in world)
				var/area/A = get_area(SW1)
				if (A.climate != "tundra" && A.climate != "taiga")
					if (prob(60))
						qdel(SW1)
			for (var/obj/covers/snow_wall/SW2 in world)
				var/area/A = get_area(SW2)
				if (A.climate != "tundra" && A.climate != "taiga")
					if (prob(60))
						qdel(SW2)
			for (var/obj/item/weapon/snowwall/SW3 in world)
				var/area/A = get_area(SW3)
				if (A.climate != "tundra" && A.climate != "taiga")
					if (prob(60))
						qdel(SW3)
		spawn(3000)
			for (var/turf/floor/dirt/winter/D in get_area_turfs(/area/caribbean/nomads/forest))
				var/area/A = get_area(D)
				if (A.climate == "temperate")
					if (prob(40))
						D.ChangeTurf(/turf/floor/grass)
					else
						D.ChangeTurf(/turf/floor/dirt)
			for (var/turf/floor/winter/grass/G in get_area_turfs(/area/caribbean/nomads/forest))
				var/area/A = get_area(G)
				if (A.climate == "temperate")
					G.ChangeTurf(/turf/floor/grass)
			for (var/turf/floor/dirt/D in get_area_turfs(/area/caribbean/nomads/semiarid))
				var/area/A = get_area(D)
				if (A.climate == "semiarid" && !istype(D, /turf/floor/dirt/dust) && !istype(D, /turf/floor/dirt/underground))
					if (prob(40))
						D.ChangeTurf(/turf/floor/grass)

			for (var/obj/structure/window/barrier/snowwall/SW1 in world)
				var/area/A = get_area(get_turf(SW1))
				if (A.climate != "tundra" && A.climate != "taiga")
					qdel(SW1)
			for (var/obj/covers/snow_wall/SW2 in world)
				var/area/A = get_area(get_turf(SW2))
				if (A.climate != "tundra" &&A.climate != "taiga")
					qdel(SW2)
			for (var/obj/item/weapon/snowwall/SW3 in world)
				var/area/A = get_area(get_turf(SW3))
				if (A.climate != "tundra" && A.climate != "taiga")
					qdel(SW3)
	else if (season == "SUMMER")
		season = "FALL"
		to_chat(world, "<big>The leaves start to fall and the weather gets colder. It is now <b>Fall</b>. In the hot climates, the dry season continues.</big>")
		spawn(900)
			for (var/obj/structure/wild/tree/live_tree/TREES in world)
				TREES.change_season()
		for (var/turf/floor/dirt/burned/BD)
			if ((BD in get_area_turfs(/area/caribbean/nomads/forest/Jungle)) || (BD in get_area_turfs(/area/caribbean/nomads/forest/savanna)))
				BD.ChangeTurf(/turf/floor/dirt/jungledirt)
			else
				BD.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/grass/G)
			G.update_icon()
		spawn(100)
			change_weather(WEATHER_WET)
		spawn(15000)
			change_weather(WEATHER_WET)
			for (var/turf/floor/dirt/D in get_area_turfs(/area/caribbean/nomads/forest))
				var/area/A = get_area(D)
				if (z == world.maxz && prob(40) && !istype(D, /turf/floor/dirt/underground) && !istype(D, /turf/floor/dirt/dust) && !(A.climate == "jungle"))
					D.ChangeTurf(/turf/floor/dirt/winter)
			for (var/turf/floor/grass/G in get_area_turfs(/area/caribbean/nomads/forest))
				var/area/A = get_area(G)
				if (A.climate == "temperate")
					if (prob(40))
						G.ChangeTurf(/turf/floor/winter/grass)
			spawn(1200)
				for (var/turf/floor/dirt/D in get_area_turfs(/area/caribbean/nomads/forest))
					var/area/A = get_area(D)
					if (!istype(D,/turf/floor/dirt/winter) && (A.climate == "temperate"))
						if (D.z == world.maxz && prob(50) && !istype(D,/turf/floor/dirt/underground))
							D.ChangeTurf(/turf/floor/dirt/winter)
				for (var/turf/floor/grass/G in get_area_turfs(/area/caribbean/nomads/forest))
					var/area/A = get_area(G)
					if (A.climate == "temperate")
						if (prob(50))
							G.ChangeTurf(/turf/floor/winter/grass)

/obj/map_metadata/colonia/cross_message(faction)
	return "<font size = 3><span class = 'notice'><b>The grace wall has been lifted.</b></font></span>"

/obj/map_metadata/colonia/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 5 MINUTES || admin_ended_all_grace_periods)

/obj/map_metadata/colonia/proc/relations_subsystem()
	spawn(30 SECONDS)
		for(var/relation in external_relations.npc_faction_relations)
			if (external_relations.npc_faction_relations[relation] > 100)
				external_relations.npc_faction_relations[relation] = 100
			else if (external_relations.npc_faction_relations[relation] < 0)
				external_relations.npc_faction_relations[relation] = 0
		relations_subsystem()
	return

/obj/map_metadata/colonia/proc/invasion_subsystem()
	spawn(1 HOUR)
		var/playercount = 0
		for (var/mob/new_player/player in new_player_mob_list)
			if (player.client)
				++playercount
		if (BARBARIAN_RELATIONS <= 25 && playercount >= 10)
			var/list/turf/invasion_routes = latejoin_turfs["InvasionRoute"]
			var/list/turf/city_centers = latejoin_turfs["CityCenter"]
			var/turf/city_center = null
			
			if (city_centers && city_centers.len)
				city_center = pick(city_centers)
			
			if (invasion_routes && invasion_routes.len && city_center)
				var/num_to_spawn = rand(5, 15)
				if (LOCAL_TRIBES_RELATIONS <= 25)
					num_to_spawn = num_to_spawn * 2
				for(var/i = 1 to num_to_spawn)
					var/turf/spawn_loc = pick(invasion_routes)
					var/mob/living/simple_animal/hostile/human/barbarian/S
					S = new /mob/living/simple_animal/hostile/human/barbarian(spawn_loc)
					S.pathfind_target = city_center
			if (LOCAL_TRIBES_RELATIONS <= 25 && BARBARIAN_RELATIONS <= 25)
				to_chat(world, "<br><font size =3><span class='user'>The barbarians are launching an attack on the colony, and the local tribes have joined in!</font></span>")
			else
				to_chat(world, "<br><font size =3><span class='user'>The barbarians are launching an attack on the colony!</font></span>")
		if (ROMAN_RELATIONS <= 25 && playercount >= 10)
			to_chat(world, "<br><font size =3><span class='user'>The Roman Empire is invading the colony!</font></span>")
			var/list/turf/invasion_routes = latejoin_turfs["InvasionRouteRoman"]
			var/list/turf/city_centers = latejoin_turfs["CityCenter"]
			var/turf/city_center = null
			
			if (city_centers && city_centers.len)
				city_center = pick(city_centers)
			
			if (invasion_routes && invasion_routes.len && city_center)
				var/num_to_spawn = rand(15, 50)
				for(var/i = 1 to num_to_spawn)
					var/turf/spawn_loc = pick(invasion_routes)
					var/mob/living/simple_animal/hostile/human/roman/S
					S = new /mob/living/simple_animal/hostile/human/roman(spawn_loc)
					S.pathfind_target = city_center
		invasion_subsystem()
	return

/obj/map_metadata/colonia/proc/check_relations_msg()
	for(var/relation in external_relations.npc_faction_relations)
		if (external_relations.npc_faction_relations[relation] > 100)
			external_relations.npc_faction_relations[relation] = 100
		else if (external_relations.npc_faction_relations[relation] < 0)
			external_relations.npc_faction_relations[relation] = 0
	to_chat(world, "<font size = 4><span class = 'notice'><b>Diplomatic Relations:</b></font></span>")
	to_chat(world, "<br><font size = 3><span class = 'notice'>Germanic Barbarians: <b>[BARBARIAN_RELATIONS]</b></span></font>")
	to_chat(world, "<br><font size = 3><span class = 'notice'>Roman Empire: <b>[ROMAN_RELATIONS]</b></span></font>")
	to_chat(world, "<br><font size = 3><span class = 'notice'>Local Tribes: <b>[LOCAL_TRIBES_RELATIONS]</b></span></font>")
	spawn(5 MINUTES)
		check_relations_msg()
	return

/obj/map_metadata/colonia/proc/recover_relations()
	if (ROMAN_RELATIONS >= 0)
		ROMAN_RELATIONS -= 0.02 //Romans demand their trade ties
	if (LOCAL_TRIBES_RELATIONS <= 30 && LOCAL_TRIBES_RELATIONS < 100)
		LOCAL_TRIBES_RELATIONS += 0.02 //The local tribes will forgive you, slowly
	spawn(20 MINUTES)
		recover_relations()
	return

////// TIME CODE ////// (thanks malt)

/obj/map_metadata/colonia/proc/time_quarters()
	quarter++
	if(quarter >=5)
		quarter = 1
		year++
		to_chat(world, "<font size = 3><span class = 'notice'><b>The year has advanced to [year].</b></font></span>")
	else
		to_chat(world, "<font size = 3><span class = 'notice'><b>The quarter has advanced to Q[quarter].</b></font></span>")
	return

/obj/map_metadata/colonia/proc/time_update()
	age = "[year] A.D. Q[quarter]"
	world.log << "Time_update has been triggered, the date is now [year] A.D. Q[quarter]."
	spawn (30 MINUTES)
		time_quarters()
		time_update()
		seasons() //an amazing innovation over pepelsibirsk: seasons update with the date, not independently
	return

/obj/structure/pepelsibirsk_radio/supply_radio/colonia //we've come full circle
	name = "import book"
	desc = "Use this to request supplies to be delivered to the colony."
	icon = 'icons/obj/structures.dmi'
	icon_state = "supplybook"
	civ_catalogue = list(
		list("wood crate", /obj/structure/closet/crate/wood,100),
		list("iron crate", /obj/structure/closet/crate/iron,100),
		list("glass crate", /obj/structure/closet/crate/glass,100),
		list("stone crate", /obj/structure/closet/crate/stone,100),
		list("vegetables crate", /obj/structure/closet/crate/rations/vegetables,60),
		list("fruits crate", /obj/structure/closet/crate/rations/fruits,60),
		list("biscuits crate", /obj/structure/closet/crate/rations/biscuits,60),
		list("wine barrel", /obj/item/weapon/reagent_containers/glass/barrel/wine,400),
		list("cow", /mob/living/simple_animal/cattle/cow,300),
		list("bull", /mob/living/simple_animal/cattle/bull,300),
		list("sheep ram", /mob/living/simple_animal/sheep,160),
		list("sheep ewe", /mob/living/simple_animal/sheep/female,160),
		list("pig boar", /mob/living/simple_animal/pig_boar,200),
		list("pig gilt", /mob/living/simple_animal/pig_gilt,200),
		list("hen", /mob/living/simple_animal/chicken,100),
		list("rooster", /mob/living/simple_animal/rooster,100),
		list("horse", /mob/living/simple_animal/horse,400),
		list("roman standard", /obj/item/weapon/material/roman_standard,1000),
		list("roman legionary", /mob/living/simple_animal/hostile/human/roman/friendly,500),
	)
	mil_catalogue = list(
		list("wood crate", /obj/structure/closet/crate/wood,50),
		list("iron crate", /obj/structure/closet/crate/iron,50),
		list("glass crate", /obj/structure/closet/crate/glass,50),
		list("stone crate", /obj/structure/closet/crate/stone,50),
		list("vegetables crate", /obj/structure/closet/crate/rations/vegetables,30),
		list("fruits crate", /obj/structure/closet/crate/rations/fruits,30),
		list("biscuits crate", /obj/structure/closet/crate/rations/biscuits,30),
		list("beer crate", /obj/structure/closet/crate/rations/beer,30),
		list("ale crate", /obj/structure/closet/crate/rations/ale,30),
		list("cow", /mob/living/simple_animal/cattle/cow,150),
		list("bull", /mob/living/simple_animal/cattle/bull,150),
		list("sheep ram", /mob/living/simple_animal/sheep,80),
		list("sheep ewe", /mob/living/simple_animal/sheep/female,80),
		list("pig boar", /mob/living/simple_animal/pig_boar,100),
		list("pig gilt", /mob/living/simple_animal/pig_gilt,100),
		list("hen", /mob/living/simple_animal/chicken,50),
		list("rooster", /mob/living/simple_animal/rooster,50),
		list("horse", /mob/living/simple_animal/horse,200),
		list("foederati soldier", /mob/living/simple_animal/hostile/human/barbarian/friendly,250),
	)

/obj/structure/pepelsibirsk_radio/supply_radio/colonia/no_scam
	name = "secure import book"
	desc = "A high-security import book, for everyday use. Use this to request supplies to be delivered to the colony."
	can_scam = FALSE


/obj/structure/pepelsibirsk_radio/supply_radio/colonia/company(user)
	///VARS///
	var/catalogue = list()
	var/list/companies = list(
		"Cancel Purchase",
		"Roman Empire",
		"Local Tribes",
	)

	///PURCHASING LOGIC///
	var/choice = WWinput(user, "Pick a supplier:", "Supplier", "Cancel Purchase", companies) //Dialog box
	if (choice == "Cancel Purchase")
		///Giving your money back///
		if (money > 0 && money <= 3)
			var/obj/item/stack/money/coppercoin/NM = new/obj/item/stack/money/coppercoin(loc)
			NM.amount = money/NM.value
			if (NM.amount <= 0)
				qdel(NM)
		else if (money > 3 && money <= 40)
			var/obj/item/stack/money/silvercoin/NM = new/obj/item/stack/money/silvercoin(loc)
			NM.amount = money/NM.value
			if (NM.amount <= 0)
				qdel(NM)
		else
			var/obj/item/stack/money/goldcoin/NM = new/obj/item/stack/money/goldcoin(loc)
			NM.amount = money/NM.value
			if (NM.amount <= 0)
				qdel(NM)
		money = 0
		return
	if (choice == "Roman Empire")
		catalogue = civ_catalogue
		if (ROMAN_RELATIONS <= 25 )
			to_chat(user, "Your relations with this faction are too low!")
			return
	else if (choice == "Local Tribes")
		catalogue = mil_catalogue
		if (LOCAL_TRIBES_RELATIONS <= 25 )
			to_chat(user, "Your relations with this faction are too low!")
			return
	purchase(user, choice, catalogue)
	return

/obj/structure/pepelsibirsk_radio/supply_radio/colonia/purchase(user, choice, catalogue)
	///VARS///
	var/final_cost //The final cost of the purchased product
	var/list/final_list = list() //The details for the product to be purchased
	var/list/display = list() //The products to be displayed, includes name of crate and price
	var/list/scamornot = list (
		"No, we're honest.",
		"Yes, scam them!",
	)
	var/scam

	///Display the menu asking for what you want to purchase
	for (var/list/i in catalogue)
		display += "[i[1]], [i[3]] coins"
	display += "Cancel Purchase"
	var/choice2 = WWinput(user, "Current money: [money]", "Order a crate", "Cancel Purchase", display)
	if (choice2 == "Cancel Purchase")
		///Giving your money back///
		if (money > 0 && money <= 3)
			var/obj/item/stack/money/coppercoin/NM = new/obj/item/stack/money/coppercoin(loc)
			NM.amount = money/NM.value
			if (NM.amount <= 0)
				qdel(NM)
		else if (money > 3 && money <= 40)
			var/obj/item/stack/money/silvercoin/NM = new/obj/item/stack/money/silvercoin(loc)
			NM.amount = money/NM.value
			if (NM.amount <= 0)
				qdel(NM)
		else
			var/obj/item/stack/money/goldcoin/NM = new/obj/item/stack/money/goldcoin(loc)
			NM.amount = money/NM.value
			if (NM.amount <= 0)
				qdel(NM)
		money = 0
		return
	if(can_scam == FALSE)
		scam = "No, we're honest."
	else
		scam = WWinput(user, "Current money: [money]", "Shall we scam them?", "No, we're honest.", scamornot)
	var/list/choicename = splittext(choice2, ", ")
	///ACTUAL PURCHASING LOGIC///
	for(var/list/i2 in catalogue) //Goes through everything in the chosen catalogue
		if (i2[1]== choicename[1]) //Checks if each item it goes through is the correct item
			final_list = i2 //If it is, set that to final_list
			world.log << "A purchase has been made: [final_list[1]], [final_list[2]], [final_list[3]]"
			final_cost = (final_list[3]) //Set the cost of the item based on the cost value in the list
			if (final_list[3] <= money || scam == "Yes, scam them!" )
				if (scam != "Yes, scam them!")
					money -= final_cost
				update_cost(final_list, final_cost, choice, user, scam)
				if (money > 0 && money <= 3)
					var/obj/item/stack/money/coppercoin/NM = new/obj/item/stack/money/coppercoin(loc)
					NM.amount = money/NM.value
					if (NM.amount <= 0)
						qdel(NM)
				else if (money > 3 && money <= 40)
					var/obj/item/stack/money/silvercoin/NM = new/obj/item/stack/money/silvercoin(loc)
					NM.amount = money/NM.value
					if (NM.amount <= 0)
						qdel(NM)
				else
					var/obj/item/stack/money/goldcoin/NM = new/obj/item/stack/money/goldcoin(loc)
					NM.amount = money/NM.value
					if (NM.amount <= 0)
						qdel(NM)
				money = 0					
			else // you're broke
				if (money > 0 && money <= 3)
					var/obj/item/stack/money/coppercoin/NM = new/obj/item/stack/money/coppercoin(loc)
					NM.amount = money/NM.value
					if (NM.amount <= 0)
						qdel(NM)
				else if (money > 3 && money <= 40)
					var/obj/item/stack/money/silvercoin/NM = new/obj/item/stack/money/silvercoin(loc)
					NM.amount = money/NM.value
					if (NM.amount <= 0)
						qdel(NM)
				else
					var/obj/item/stack/money/goldcoin/NM = new/obj/item/stack/money/goldcoin(loc)
					NM.amount = money/NM.value
					if (NM.amount <= 0)
						qdel(NM)
				money = 0
				to_chat(user, "You don't have enough money for this item.")
			break
/obj/structure/pepelsibirsk_radio/export_radio/colonia
	name = "export book"
	desc = "Use this to export resources to the Romans."
	icon = 'icons/obj/structures.dmi'
	icon_state = "supplybook2"
	density = TRUE
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/pepelsibirsk_radio/export_radio/colonia/attackby(var/obj/item/W as obj, var/mob/living/human/user as mob)
	if (W.value == 0)
		to_chat(user, "There is no demand for this item.")
		return
	else
		if (ROMAN_RELATIONS >= 25)
			if (istype(W))
				marketval = W.value + rand(-round(W.value/10),round(W.value/10))
				moneyin = marketval*W.amount-((marketval*W.amount)*(export_tax_rate/100))
				var/exportChoice = WWinput(user, "Sell the whole stack for [moneyin] silver coins?", "Exporting", "Yes", list("Yes", "No"))
				if (exportChoice == "Yes")
					if (W && marketval > 0)
						new/obj/item/stack/money/silvercoin(loc, round(moneyin))	// Silver coins
						qdel(W)
						marketval = 0
						return
			else
				marketval = 0
				return
		else
			to_chat(user, "Your relations with the Romans are too low!")
			return

/obj/structure/pepelsibirsk_radio/supply_radio/colonia/update_cost(final_list, final_cost, choice, user, scam)
	if (choice == "Local Tribes" && scam != "Yes, scam them!")
		LOCAL_TRIBES_RELATIONS += final_cost*0.02
		ROMAN_RELATIONS -= final_cost*0.005 //The Romans don't like it when you trade with their rivals
	else if (choice == "Roman Empire" && scam != "Yes, scam them!")
		ROMAN_RELATIONS += final_cost*0.02
	else if (choice == "Roman Empire" && scam == "Yes, scam them!")
		ROMAN_RELATIONS -= final_cost*0.08
	else if (choice == "Local Tribes" && scam == "Yes, scam them!")
		LOCAL_TRIBES_RELATIONS -= final_cost*0.08
		ROMAN_RELATIONS += final_cost*0.005 //The Romans like it when you scam their rivals
	if (scam != "Yes, scam them!")
		to_chat(user, "Your item will arrive in 60 seconds. Relations with [choice] have increased by [final_cost*0.02].")
	else if (scam == "Yes, scam them!")
		to_chat(user, "Your item will arrive in 60 seconds. Relations with [choice] have decreased by [final_cost*0.08].")
	spawn(1 MINUTE)
		if(!src)
			return
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
