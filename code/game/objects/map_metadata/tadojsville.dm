/obj/map_metadata/tadojsville
	ID = MAP_TADOJSVILLE
	title = "Tadojsville Siege"
	lobby_icon = "icons/lobby/tadojsville.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/jungle,/area/caribbean/no_mans_land/invisible_wall/jungle/one)
	respawn_delay = 300
	no_winner ="No warband has captured the clinic yet."
	no_hardcore = TRUE
	faction_organization = list(
		CIVILIAN,
		INDIANS)
	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/russian/land/inside,
		list(INDIANS) = /area/caribbean/colonies,
		)
	age = "1962"
	ordinal_age = 7
	artillery_count = 3
	valid_artillery = list("Explosive")
	faction_distribution_coeffs = list(CIVILIAN = 0.4, INDIANS = 0.6)
	battle_name = "The Siege of Tadojsville"
	mission_start_message = "<font size=4><b>The Katnegwa Mercenaries</b> have been hired together to capture the local clinic! It will take <b>5 minutes</b> for the Warbands to capture the clinic but the <b>United Nations Peacekeepers</b> garrisoned there will be reinforced and drive off the attackers if they manage to hold out for 35 minutes. <br> The Warbands will start to cross the river in <b>6 minutes!</b></font>"
	faction1 = CIVILIAN
	faction2 = INDIANS
	ambience = list('sound/ambience/jungle1.ogg')
	gamemode = "Siege"
	grace_wall_timer = 3600
	valid_weather_types = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
	songs = list(
		"The Hygrades - Rough Rider:1" = "sound/music/roughrider.ogg",)

/obj/map_metadata/tadojsville/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_un)
		. = TRUE
	else if (J.is_warlords)
		if (J.is_tadoj)
			if (J.title != "Mercenary (do not use)")
				. = TRUE
		else
			. = FALSE
	else
		. = FALSE

/obj/map_metadata/tadojsville/roundend_condition_def2name(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "United Nations"
		if (INDIANS)
			return "Warband Mercenary"

/obj/map_metadata/tadojsville/roundend_condition_def2army(define)
	..()
	switch (define)
		if (CIVILIAN)
			return "United Nations"
		if (INDIANS)
			return "Warband Mercenaries"

/obj/map_metadata/tadojsville/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/tadojsville/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 3000 // 5 minutes

/obj/map_metadata/tadojsville/update_win_condition()
	if (world.time >= 21000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		var/message = "The United Nations troops have managed to defend the clinic!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
	if ((current_winner && current_loser && world.time > next_win) && no_loop_rom == FALSE)
		ticker.finished = TRUE
		var/message = "The Warband Mercenaries have captured the clinic! The remaining United Nations troops have surrendered!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		no_loop_rom = TRUE
		return FALSE
	// German major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Warband Mercenaries have control over most of the clinic! They will win in {time} minutes."
				next_win = world.time +  short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// German minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Warband Mercenaries have control over most of the clinic!! They will win in {time} minutes."
				next_win = world.time +  short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[1][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[2][1])
	// Soviet major
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.33, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.33))
			if (last_win_condition != win_condition.hash)
				current_win_condition =  "The Warband Mercenaries have control over most of the clinic! They will win in {time} minutes."
				next_win = world.time +  short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	// Soviet minor
	else if (win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[1]]), roundend_condition_sides[2], roundend_condition_sides[1], 1.01, TRUE))
		if (!win_condition.check(typesof(roundend_condition_sides[roundend_condition_sides[2]]), roundend_condition_sides[1], roundend_condition_sides[2], 1.01))
			if (last_win_condition != win_condition.hash)
				current_win_condition = "The Warband Mercenaries have control over most of the clinic! They will win in {time} minutes."
				next_win = world.time + short_win_time(CIVILIAN)
				announce_current_win_condition()
				current_winner = roundend_condition_def2army(roundend_condition_sides[2][1])
				current_loser = roundend_condition_def2army(roundend_condition_sides[1][1])
	else
		if (current_win_condition != no_winner && current_winner && current_loser)
			world << "<font size = 3>The United Nations troops have recaptured the clinic!</font>"
			current_winner = null
			current_loser = null
		next_win = -1
		current_win_condition = no_winner
		win_condition.hash = 0
	last_win_condition = win_condition.hash
	return TRUE

/obj/map_metadata/tadojsville/short_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 2400 // 5 minutes

/obj/map_metadata/tadojsville/long_win_time(faction)
	if (!(alive_n_of_side(faction1)) || !(alive_n_of_side(faction2)))
		return 600
	else
		return 2400 // 5 minutes

/obj/map_metadata/tadojsville/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall/jungle))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/jungle/one))
			if (H.faction_text == faction1)
				return TRUE
			return !faction1_can_cross_blocks()
			return !faction2_can_cross_blocks()
	return FALSE

/obj/map_metadata/tadojsville/cross_message(faction)
	if (faction == INDIANS)
		return "<font size = 4>The Warbands have recieved the attack order! Cross the river and attack the clinic!</font>"
	else if (faction == CIVILIAN)
		return "<font size = 4>Warband Mercenaries are crossing the river to attack!</font>"
	else
		return "<font size = 4>Warband Mercenaries are attacking from across the river!"

/obj/map_metadata/tadojsville/reverse_cross_message(faction)
	if (faction == INDIANS)
		return "<span class = 'userdanger'>The Warbands have been ordered to halt! No forces may cross the river until the order is given!</span>"
	else if (faction == CIVILIAN)
		return "<font size = 4>Warband Mercenaries have halted the river crossing!</font>"
	else
		return "<font size = 4>Warband Mercenaries have halted the river crossing!</font>"

///////////map specific objs/////////
/obj/structure/altar/darkstone/unsacrifice
	name = "shaman's altar"
	icon_state = "blood_altar"
	flammable = FALSE
	health = 1000000
	not_movable = TRUE
	var/faction = "none"

/obj/structure/altar/darkstone/unsacrifice/attackby(obj/item/W, mob/living/human/user)
	if (istype(W, /obj/item/organ/external/head) && map.ID == MAP_TADOJSVILLE)
		if (!W)
			user << "This is not even a head, it is worthless. Only Peacekeeper heads will do."
			return
		var/obj/item/organ/external/head/HD = W
		var/head_nationality = HD.nationality
		qdel(W)
		if (head_nationality != "United Nations")
			user << "This head is worthless, only Peacekeeper heads will do."

		else
			user << "You place the Peacekeeper's head on the shaman's altar."
			if(prob(20))
				var/randmed = rand(1,3)
				switch (randmed)
					if (1)
						new/obj/item/weapon/reagent_containers/food/drinks/bottle/small/healing/minor(user.loc)
					if (2)
						new/obj/item/weapon/reagent_containers/food/drinks/bottle/small/stamina/minor(user.loc)
					if (3)
						new/obj/item/weapon/storage/firstaid/adv(user.loc)
			else if (prob (20))
				var/randcloth = rand(1,8)
				switch(randcloth)
					if (1)
						new/obj/item/clothing/head/pimphat(user.loc)
						new/obj/item/clothing/suit/pimpsuit(user.loc)
					if (2)
						new/obj/item/clothing/suit/storage/ghillie(user.loc)
						new/obj/item/clothing/head/ghillie(user.loc)
					if (3)
						new/obj/item/clothing/head/gatorpelt(user.loc)
						new/obj/item/clothing/suit/storage/coat/ww2/biker/gator_jacket(user.loc)
					if (4)
						new/obj/item/clothing/head/laurelcrown/gold(user.loc)
						new/obj/item/clothing/suit/storage/jacket/regal(user.loc)
					if (5)
						new/obj/item/clothing/head/lionpelt(user.loc)
						new/obj/item/clothing/suit/zulu_mbata(user.loc)
						new/obj/item/clothing/mask/wooden/african(user.loc)
					if (6)
						new/obj/item/clothing/head/top_hat(user.loc)
						new/obj/item/clothing/suit/storage/jacket/vict_tailcoat(user.loc)
					if (7)
						new/obj/item/clothing/under/victorian_dress/red(user.loc)
						new/obj/item/clothing/head/kerchief(user.loc)
					if (8)
						new/obj/item/clothing/head/ten_gallon(user.loc)
						new/obj/item/clothing/suit/storage/jacket/texan(user.loc)
			else if (prob (25))
				var/randgun = rand(1,10)
				switch(randgun)
					if (1)
						new/obj/item/weapon/gun/projectile/submachinegun/ak74/aks74(user.loc)
						new/obj/item/ammo_magazine/ak74(user.loc)
						new/obj/item/ammo_magazine/ak74(user.loc)
						new/obj/item/ammo_magazine/ak74(user.loc)
					if (2)
						new/obj/item/weapon/gun/projectile/submachinegun/ak47/gold(user.loc)
						new/obj/item/ammo_magazine/ak47/drum(user.loc)
						new/obj/item/ammo_magazine/ak47/drum(user.loc)
					if (3)
						new/obj/item/weapon/gun/projectile/submachinegun/saiga12(user.loc)
						new/obj/item/ammo_magazine/saiga12/slug(user.loc)
						new/obj/item/ammo_magazine/saiga12/slug(user.loc)
						new/obj/item/ammo_magazine/saiga12(user.loc)
					if (4)
						new/obj/item/weapon/gun/projectile/pistol/deagle(user.loc)
						new/obj/item/ammo_magazine/deagle(user.loc)
						new/obj/item/ammo_magazine/deagle(user.loc)
						new/obj/item/ammo_magazine/deagle(user.loc)
					if (5)
						new/obj/item/weapon/macuahuitl(user.loc)
						new/obj/item/weapon/material/thrown/throwing_axe(user.loc)
						new/obj/item/weapon/material/thrown/throwing_axe(user.loc)
					if (6)
						new/obj/item/weapon/gun/projectile/automatic/madsen(user.loc)
						new/obj/item/ammo_magazine/madsen(user.loc)
						new/obj/item/ammo_magazine/madsen(user.loc)
						new/obj/item/ammo_magazine/madsen(user.loc)
					if (7)
						new/obj/item/weapon/gun/projectile/submachinegun/mac10(user.loc)
						new/obj/item/ammo_magazine/mac10(user.loc)
						new/obj/item/ammo_magazine/mac10(user.loc)
						new/obj/item/ammo_magazine/mac10(user.loc)
					if (8)
						new/obj/item/weapon/gun/projectile/bow/compoundbow(user.loc)
						new/obj/item/weapon/storage/backpack/quiver/modern(user.loc)
					if (9)
						new/obj/item/weapon/gun/projectile/shotgun/pump/remington870(user.loc)
						new/obj/item/ammo_magazine/shellbox/slug(user.loc)
						new/obj/item/ammo_magazine/shellbox/slug(user.loc)
						new/obj/item/ammo_magazine/shellbox(user.loc)
					if (10)
						new/obj/item/weapon/gun/projectile/boltaction/singleshot/barrett/sniper(user.loc)
						new/obj/item/ammo_magazine/a50cal(user.loc)
						new/obj/item/ammo_magazine/a50cal(user.loc)
						new/obj/item/ammo_magazine/a50cal(user.loc)
			else if (prob (20))
				new/obj/item/weapon/grenade/modern/f1(user.loc)
				new/obj/item/weapon/grenade/modern/f1(user.loc)
			else if (prob (15))
				new/obj/item/weapon/grenade/incendiary/anm14(user.loc)
				new/obj/item/weapon/grenade/incendiary/anm14(user.loc)
			else if (prob (15))
				new/obj/item/weapon/gun/projectile/semiautomatic/svd(user.loc)
				new /obj/item/ammo_magazine/svd(user.loc)
				new /obj/item/ammo_magazine/svd(user.loc)
				new /obj/item/ammo_magazine/svd(user.loc)
			else if (prob (15))
				new/obj/item/weapon/gun/launcher/rocket/rpg7(user.loc)
				new/obj/item/ammo_casing/rocket/og7v(user.loc)
				new/obj/item/ammo_casing/rocket/og7v(user.loc)
			return
