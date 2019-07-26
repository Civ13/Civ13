/obj/structure/gunbench
	name = "gunsmithing bench"
	desc = "A large wooden workbench. The gunsmith's main work tool. It has 0 steel and 0 wood on it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "gunbench1"
	density = TRUE
	anchored = TRUE
	var/wood_amt = 0
	var/steel_amt = 0
	var/using_wood = 0
	var/using_steel = 0
	not_movable = FALSE
	not_disassemblable = TRUE
	var/obj/item/weapon/gun/projectile/custom/current_gun = null

/obj/structure/gunbench/attackby(obj/item/P as obj, mob/user as mob)
	if (istype(P, /obj/item/stack/material/wood))
		user << "You begin cutting the wood..."
		playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
		if (do_after(user,35*P.amount,src))
			user << "<span class='notice'>You cut the wood.</span>"
			wood_amt += P.amount
			desc = "A large wooden workbench. The gunsmith's main work tool. It has [steel_amt] steel and [wood_amt] wood on it."
			qdel(P)
		return

	else if (istype(P, /obj/item/stack/material/steel))
		user << "You begin smithing the steel..."
		playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
		if (do_after(user,35*P.amount,src))
			user << "<span class='notice'>You smite the steel.</span>"
			steel_amt += P.amount
			desc = "A large wooden workbench. The gunsmith's main work tool. It has [steel_amt] steel and [wood_amt] wood on it."
			qdel(P)
		return


/obj/structure/gunbench/attack_hand(var/mob/user as mob)
	var/mob/living/carbon/human/H = user
	if (H.getStatCoeff("crafting") < 1.9 && map.civilizations)
		user << "You don't have the skills to use this."
		return FALSE
////////////////STOCK///////////////////////////////
	var/list/display = list("Cancel")
	if (map.ordinal_age == 5)
		display = list("Rifle Wooden Stock","Carbine Wooden Stock", "Pistol Grip", "Cancel")
	else if (map.ordinal_age == 6)
		display = list("Rifle Wooden Stock","Carbine Wooden Stock", "Pistol Grip", "Steel Stock", "Cancel")
	else if (map.ordinal_age >= 7)
		display = list("Rifle Wooden Stock","Carbine Wooden Stock", "Pistol Grip", "Steel Stock", "Folding Stock", "Cancel")
	var/choice_stock = WWinput(user, "Choose the Stock:", "Gunsmith - [steel_amt] steel, [wood_amt] wood", "Cancel", display)
	current_gun = new /obj/item/weapon/gun/projectile/custom(src)
	if (choice_stock == "Cancel")
		current_gun = null
		using_wood = 0
		using_steel = 0
		return FALSE
	else if (choice_stock == "Rifle Wooden Stock")
		using_wood = 7
	else if (choice_stock == "Carbine Wooden Stock")
		using_wood = 5
	else if (choice_stock == "Pistol Grip")
		using_steel = 3
	else if (choice_stock == "Steel Stock")
		using_steel = 5
	else if (choice_stock == "Folding Stock")
		using_steel = 7
	if (current_gun)
		current_gun.stock_type = choice_stock
		current_gun.step = 1
	else
		return

	if (using_wood > wood_amt || using_steel > steel_amt)
		user << "Not enough resources!"
		current_gun = null
		using_wood = 0
		using_steel = 0
		return FALSE
////////////////RECEIVER///////////////////////////////
	var/list/display2 = list("Cancel")
	if (map.ordinal_age == 5)
		display2 = list("Bolt-Action","Revolver", "Semi-Auto (small)", "Pump-Action", "Cancel")
	else if (map.ordinal_age == 6)
		display2 = list("Bolt-Action","Revolver", "Semi-Auto (small)", "Semi-Auto (large)","Open-Bolt (small)", "Open-Bolt (large)","Pump-Action", "Cancel")
	else if (map.ordinal_age >= 7)
		display2 = list("Bolt-Action","Revolver", "Semi-Auto (small)", "Semi-Auto (large)","Open-Bolt (small)", "Open-Bolt (large)","Pump-Action", "Dual Selective Fire", "Triple Selective Fire", "Cancel")
	var/choice_receiver = WWinput(user, "Choose the receiver:", "Gunsmith - [using_steel]/[steel_amt] steel, [using_wood]/[wood_amt] wood", "Cancel", display2)
	if (choice_receiver == "Cancel")
		current_gun = null
		using_wood = 0
		using_steel = 0
		return FALSE
	else if (choice_receiver == "Bolt-Action")
		using_steel += 5
	else if (choice_receiver == "Revolver")
		using_steel += 4
	else if (choice_receiver == "Semi-Auto (small)")
		using_steel += 6
	else if (choice_receiver == "Semi-Auto (large)")
		using_steel += 8
	else if (choice_receiver == "Open-Bolt (small)")
		using_steel += 8
	else if (choice_receiver == "Open-Bolt (large)")
		using_steel += 11
	else if (choice_receiver == "Dual Selective Fire")
		using_steel += 13
	else if (choice_receiver == "Triple Selective Fire")
		using_steel += 14
	else if (choice_receiver == "Pump-Action")
		using_steel += 5
	if (current_gun)
		current_gun.receiver_type = choice_receiver
		current_gun.step = 2
	else
		return

	if (using_wood > wood_amt || using_steel > steel_amt)
		user << "Not enough resources!"
		current_gun = null
		using_wood = 0
		using_steel = 0
		return FALSE

////////////////FEEDING/SYSTEM///////////////////////////////
	var/list/display3 = list("Cancel")
	if (map.ordinal_age == 5)
		display3 = list("Internal Magazine","Tubular", "Cancel")
	else if (map.ordinal_age >= 6)
		display3 = list("Internal Magazine","Tubular", "External Magazine","Large External Magazine","Open (Belt-Fed)", "Cancel")
	if (choice_receiver == "Pump-Action")
		display3 = list("Tubular", "Cancel")
	if (choice_receiver == "Revolver")
		display3 = list("Revolving", "Cancel")
	if (choice_receiver == "Bolt-Action" || choice_receiver =="Semi-Auto (small)" || choice_receiver =="Semi-Auto (large)" && map.ordinal_age >= 6)
		display3 = list("Internal Magazine","Tubular", "External Magazine","Large External Magazine", "Cancel")
	var/choice_feeding = WWinput(user, "Choose the feeding system:", "Gunsmith - [using_steel]/[steel_amt] steel, [using_wood]/[wood_amt] wood", "Cancel", display3)
	if (choice_feeding == "Cancel")
		current_gun = null
		using_wood = 0
		using_steel = 0
		return
	else if (choice_feeding == "Internal Magazine")
		using_steel += 4
	else if (choice_feeding == "Tubular")
		using_steel += 5
	else if (choice_feeding == "Revolving")
		using_steel += 3
	else if (choice_feeding == "External Magazine")
		using_steel += 8
	else if (choice_feeding == "Large External Magazine")
		using_steel += 10
	else if (choice_feeding == "Open (Belt-Fed)")
		using_steel += 6
	if (current_gun)
		current_gun.feeding_type = choice_feeding
		current_gun.step = 3
	else
		return

	if (using_wood > wood_amt || using_steel > steel_amt)
		user << "Not enough resources!"
		current_gun = null
		using_wood = 0
		using_steel = 0
		return

////////////////BARREL///////////////////////////////
	var/list/display4 = list("Cancel")
	if (map.ordinal_age == 5)
		display4 = list("Pistol Barrel","Rifle Barrel", "Long Rifle Barrel", "Cancel")
	else if (map.ordinal_age >= 6)
		display4 = list("Pistol Barrel","Carbine Barrel","Rifle Barrel", "Long Rifle Barrel","Air-Cooled Barrel", "Cancel")
	if (choice_feeding == "Open (Belt-Fed)")
		display4 = list("Air-Cooled Barrel","Cancel")
	var/choice_barrel = WWinput(user, "Choose the barrel:", "Gunsmith - [using_steel]/[steel_amt] steel, [using_wood]/[wood_amt] wood", "Cancel", display4)
	if (choice_barrel == "Cancel")
		current_gun = null
		using_wood = 0
		using_steel = 0
		return
	else if (choice_barrel == "Pistol Barrel")
		using_steel += 4
	else if (choice_barrel == "Carbine Barrel")
		using_steel += 5
	else if (choice_barrel == "Rifle Barrel")
		using_steel += 3
	else if (choice_barrel == "Long Rifle Barrel")
		using_steel += 8
	else if (choice_barrel == "Air-Cooled Barrel")
		using_steel += 10
	if (current_gun)
		current_gun.barrel_type = choice_barrel
		current_gun.step = 4
	else
		return

	if (using_wood > wood_amt || using_steel > steel_amt)
		user << "Not enough resources!"
		current_gun = null
		using_wood = 0
		using_steel = 0
		return
	var/list/caliberlist = list("Cancel")
	switch (choice_receiver)
		if ("Pump-Action")
			caliberlist = list("shotgun","Cancel")

		if ("Bolt-Action","Semi-Auto (large)")
			caliberlist = list("8mm large rifle","6.5mm small rifle","7.5mm intermediate rifle","5.5mm intermediate rifle","Cancel")

		if ("Open-Bolt (large)")
			caliberlist = list("7.5mm intermediate rifle","5.5mm intermediate rifle","Cancel")

		if ("Open-Bolt (small)","Revolver","Semi-Auto (small)")
			caliberlist = list("9mm pistol",".45 pistol","Cancel")

		if ("Dual Selective Fire", "Triple Selective Fire")
			caliberlist = list("7.5mm intermediate rifle","5.5mm intermediate rifle","Cancel")

	var/choice_caliber = WWinput(user, "Choose the caliber:", "Gunsmith - [using_steel]/[steel_amt] steel, [using_wood]/[wood_amt] wood", "Cancel", caliberlist)
	if (choice_caliber == "Cancel")
		current_gun = null
		using_wood = 0
		using_steel = 0
		return
	else if (choice_caliber == "shotgun")
		current_gun.caliber = "12gauge"
		current_gun.ammo_type = /obj/item/ammo_casing/shotgun

	else if (choice_caliber == "8mm large rifle")
		current_gun.caliber = "largerifle"
		current_gun.ammo_type = /obj/item/ammo_casing/largerifle

	else if (choice_caliber == "6.5mm small rifle")
		current_gun.caliber = "smallrifle"
		current_gun.ammo_type = /obj/item/ammo_casing/smallrifle

	else if (choice_caliber == ".45 pistol")
		current_gun.caliber = "pistol45"
		current_gun.ammo_type = /obj/item/ammo_casing/pistol45

	else if (choice_caliber == "9mm pistol")
		current_gun.caliber = "pistol9"
		current_gun.ammo_type = /obj/item/ammo_casing/pistol9

	else if (choice_caliber == "7.5mm intermediate rifle")
		current_gun.caliber = "intermediumrifle"
		current_gun.ammo_type = /obj/item/ammo_casing/intermediumrifle

	else if (choice_caliber == "5.5mm intermediate rifle")
		current_gun.caliber = "smallintermediumrifle"
		current_gun.ammo_type = /obj/item/ammo_casing/smallintermediumrifle
	if (choice_caliber != "Cancel" && choice_stock != "Cancel" && choice_barrel != "Cancel" && choice_receiver != "Cancel" && choice_feeding != "Cancel")
		wood_amt -= using_wood
		steel_amt -= using_steel
		using_wood = 0
		using_steel = 0
		var/named = input(user, "Choose a name for this gun (max 15 characters):", "Gunsmithing", "gun")
		if (named && named != "")
			named = sanitize(named,15)
			if (current_gun)
				current_gun.name = named
			else
				return
		else
			if (current_gun)
				current_gun.name = "gun"
			else
				return
		if (current_gun)
			current_gun.finish()
		var/obj/item/weapon/gun/projectile/custom/NEWGUN = current_gun
		NEWGUN.loc = get_turf(src)
		current_gun = null
		return TRUE
	else
		current_gun = null
		using_wood = 0
		using_steel = 0
		return

/////////////////////////////////////////////////////////
///////////////////THE CUSTOM GUN////////////////////////
/////////////////////////////////////////////////////////
#define SHORT_RANGE_STILL "short_range_still"
#define SHORT_RANGE_MOVING "short_range_moving"

#define MEDIUM_RANGE_STILL "medium_range_still"
#define MEDIUM_RANGE_MOVING "medium_range_moving"

#define LONG_RANGE_STILL "long_range_still"
#define LONG_RANGE_MOVING "long_range_moving"

#define VERY_LONG_RANGE_STILL "very_long_range_still"
#define VERY_LONG_RANGE_MOVING "very_long_range_moving"

#define KD_CHANCE_VERY_LOW 20
#define KD_CHANCE_LOW 40
#define KD_CHANCE_MEDIUM 60
#define KD_CHANCE_HIGH 80
/obj/item/weapon/gun/projectile/custom
	name = "unfinished gun"
	desc = "an unfinished gun"
	icon = 'icons/obj/gunsmithing.dmi'
	icon_state = "none"

	var/stock_type = "none"
	var/image/stock_img = null

	var/receiver_type = "none"
	var/image/receiver_img = null

	var/feeding_type = "none"
	var/image/feeding_img = null
	var/barrel_type = "none"
	var/image/barrel_img = null

	gun_safety = TRUE
	//bolt action
	var/step = 0
	var/bolt_open = FALSE
	var/check_bolt = FALSE //Keeps the bolt from being interfered with
	var/check_bolt_lock = FALSE //For locking the bolt. Didn't put this in with check_bolt to avoid issues
	var/bolt_safety = FALSE //If true, locks the bolt when gun is empty
	var/next_reload = -1
	var/jammed_until = -1
	var/jamcheck = 0
	var/last_fire = -1
	//revolver
	var/chamber_offset = FALSE //how many empty chambers in the cylinder until you hit a round
	var/single_action = FALSE
	var/cocked = FALSE
	var/base_icon = null
	var/folded = FALSE
	//shotgun
	var/recentpump = FALSE // to prevent spammage
	caliber = "caliber"
	ammo_type = /obj/item/ammo_casing
	magazine_type = /obj/item/ammo_magazine/emptypouch

/obj/item/weapon/gun/projectile/custom/New()
	..()
	loaded = list()
	chambered = null

/obj/item/weapon/gun/projectile/custom/proc/finish()
	if (step != 4)
		qdel(src)
		return

	if (stock_type == "none" || receiver_type == "none" || feeding_type == "none" || barrel_type == "none")
		qdel(src)
		return
	stock_img = image("icon" = src.icon, "icon_state" = src.stock_type)
	overlays += stock_img
	barrel_img = image("icon" = src.icon, "icon_state" = src.barrel_type)
	overlays += barrel_img
	receiver_img = image("icon" = src.icon, "icon_state" = src.receiver_type)
	overlays += receiver_img
	if (feeding_type == "Open (Belt-Fed)" || feeding_type == "External Magazine" || feeding_type == "Large External Magazine")
		feeding_img = image("icon" = src.icon, "icon_state" = "[src.feeding_type]_unloaded")
		overlays += feeding_img

	switch(stock_type)
		if ("Rifle Wooden Stock")
			equiptimer = 15
			effectiveness_mod = 1.1
		if ("Carbine Wooden Stock")
			equiptimer = 12
			effectiveness_mod = 1
		if ("Pistol Grip")
			equiptimer = 7
			effectiveness_mod = 0.80
		if ("Steel Stock")
			equiptimer = 11
			effectiveness_mod = 1
		if ("Folding Stock")
			equiptimer = 12
			effectiveness_mod = 0.92

	switch(receiver_type)
		if ("Bolt-Action")
			item_state = "mosin"
			w_class = 4
			force = 10
			throwforce = 20
			max_shells = 5
			slot_flags = SLOT_SHOULDER
			recoil = 2 //extra kickback
			handle_casings = HOLD_CASINGS
			load_method = SINGLE_CASING | SPEEDLOADER
			load_shell_sound = 'sound/weapons/clip_reload.ogg'
			accuracy = TRUE
			gun_type = GUN_TYPE_RIFLE
			attachment_slots = ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
			accuracy_increase_mod = 2.00
			accuracy_decrease_mod = 6.00
			KD_chance = KD_CHANCE_HIGH
			stat = "rifle"
			move_delay = 2
			fire_delay = 2
			accuracy_list = list(

				// small body parts: head, hand, feet
				"small" = list(
					SHORT_RANGE_STILL = 87,
					SHORT_RANGE_MOVING = 50,

					MEDIUM_RANGE_STILL = 77,
					MEDIUM_RANGE_MOVING = 47,

					LONG_RANGE_STILL = 63,
					LONG_RANGE_MOVING = 37,

					VERY_LONG_RANGE_STILL = 56,
					VERY_LONG_RANGE_MOVING = 30),

				// medium body parts: limbs
				"medium" = list(
					SHORT_RANGE_STILL = 88,
					SHORT_RANGE_MOVING = 44,

					MEDIUM_RANGE_STILL = 78,
					MEDIUM_RANGE_MOVING = 39,

					LONG_RANGE_STILL = 68,
					LONG_RANGE_MOVING = 34,

					VERY_LONG_RANGE_STILL = 58,
					VERY_LONG_RANGE_MOVING = 29),

				// large body parts: chest, groin
				"large" = list(
					SHORT_RANGE_STILL = 98,
					SHORT_RANGE_MOVING = 49,

					MEDIUM_RANGE_STILL = 90,
					MEDIUM_RANGE_MOVING = 50,

					LONG_RANGE_STILL = 77,
					LONG_RANGE_MOVING = 38,

					VERY_LONG_RANGE_STILL = 69,
					VERY_LONG_RANGE_MOVING = 31),
			)

			load_delay = 4
			aim_miss_chance_divider = 3.00
		if ("Revolver")
			stat = "pistol"
			w_class = 2
			slot_flags = SLOT_BELT|SLOT_POCKET|SLOT_HOLSTER
			handle_casings = CYCLE_CASINGS
			max_shells = 7
			unload_sound 	= 'sound/weapons/guns/interact/rev_magout.ogg'
			reload_sound 	= 'sound/weapons/guns/interact/rev_magin.ogg'
			cocked_sound 	= 'sound/weapons/guns/interact/rev_cock.ogg'
			fire_sound = 'sound/weapons/guns/fire/revolver_fire.ogg'
			magazine_based = FALSE
			gun_type = GUN_TYPE_PISTOL
			single_action = FALSE
			equiptimer -= 1
			accuracy_list = list(
				// small body parts: head, hand, feet
				"small" = list(
					SHORT_RANGE_STILL = 60,
					SHORT_RANGE_MOVING = 40,

					MEDIUM_RANGE_STILL = 53,
					MEDIUM_RANGE_MOVING = 35,

					LONG_RANGE_STILL = 45,
					LONG_RANGE_MOVING = 30,

					VERY_LONG_RANGE_STILL = 38,
					VERY_LONG_RANGE_MOVING = 25),

				// medium body parts: limbs
				"medium" = list(
					SHORT_RANGE_STILL = 64,
					SHORT_RANGE_MOVING = 42,

					MEDIUM_RANGE_STILL = 56,
					MEDIUM_RANGE_MOVING = 38,

					LONG_RANGE_STILL = 49,
					LONG_RANGE_MOVING = 32,

					VERY_LONG_RANGE_STILL = 41,
					VERY_LONG_RANGE_MOVING = 27),

				// large body parts: chest, groin
				"large" = list(
					SHORT_RANGE_STILL = 68,
					SHORT_RANGE_MOVING = 44,

					MEDIUM_RANGE_STILL = 60,
					MEDIUM_RANGE_MOVING = 40,

					LONG_RANGE_STILL = 53,
					LONG_RANGE_MOVING = 35,

					VERY_LONG_RANGE_STILL = 45,
					VERY_LONG_RANGE_MOVING = 30),
			)

			accuracy_increase_mod = 1.50
			accuracy_decrease_mod = 2.00
			KD_chance = KD_CHANCE_LOW
			aim_miss_chance_divider = 2.00
			load_delay = 6

		if ("Semi-Auto (small)")
			item_state = "pistol"
			stat = "pistol"
			move_delay = 1
			fire_delay = 3
			equiptimer -= 1
			gun_type = GUN_TYPE_PISTOL
			accuracy_list = list(
				// small body parts: head, hand, feet
				"small" = list(
					SHORT_RANGE_STILL = 60,
					SHORT_RANGE_MOVING = 40,

					MEDIUM_RANGE_STILL = 53,
					MEDIUM_RANGE_MOVING = 35,

					LONG_RANGE_STILL = 45,
					LONG_RANGE_MOVING = 30,

					VERY_LONG_RANGE_STILL = 38,
					VERY_LONG_RANGE_MOVING = 25),

				// medium body parts: limbs
				"medium" = list(
					SHORT_RANGE_STILL = 64,
					SHORT_RANGE_MOVING = 42,

					MEDIUM_RANGE_STILL = 56,
					MEDIUM_RANGE_MOVING = 38,

					LONG_RANGE_STILL = 49,
					LONG_RANGE_MOVING = 32,

					VERY_LONG_RANGE_STILL = 41,
					VERY_LONG_RANGE_MOVING = 27),

				// large body parts: chest, groin
				"large" = list(
					SHORT_RANGE_STILL = 68,
					SHORT_RANGE_MOVING = 44,

					MEDIUM_RANGE_STILL = 60,
					MEDIUM_RANGE_MOVING = 40,

					LONG_RANGE_STILL = 53,
					LONG_RANGE_MOVING = 35,

					VERY_LONG_RANGE_STILL = 45,
					VERY_LONG_RANGE_MOVING = 30),
			)
			w_class = 2
			slot_flags = SLOT_BELT|SLOT_POCKET||SLOT_HOLSTER
			accuracy_increase_mod = 1.50
			accuracy_decrease_mod = 2.00
			KD_chance = KD_CHANCE_LOW
			aim_miss_chance_divider = 2.00
		if ("Semi-Auto (large)")
			item_state = "g41"
			stat = "rifle"
			w_class = 4
			slot_flags = SLOT_SHOULDER
			accuracy_list = list(

				// small body parts: head, hand, feet
				"small" = list(
					SHORT_RANGE_STILL = 73,
					SHORT_RANGE_MOVING = 48,

					MEDIUM_RANGE_STILL = 63,
					MEDIUM_RANGE_MOVING = 42,

					LONG_RANGE_STILL = 53,
					LONG_RANGE_MOVING = 35,

					VERY_LONG_RANGE_STILL = 43,
					VERY_LONG_RANGE_MOVING = 28),

				// medium body parts: limbs
				"medium" = list(
					SHORT_RANGE_STILL = 78,
					SHORT_RANGE_MOVING = 51,

					MEDIUM_RANGE_STILL = 68,
					MEDIUM_RANGE_MOVING = 45,

					LONG_RANGE_STILL = 58,
					LONG_RANGE_MOVING = 38,

					VERY_LONG_RANGE_STILL = 48,
					VERY_LONG_RANGE_MOVING = 32),

				// large body parts: chest, groin
				"large" = list(
					SHORT_RANGE_STILL = 83,
					SHORT_RANGE_MOVING = 55,

					MEDIUM_RANGE_STILL = 73,
					MEDIUM_RANGE_MOVING = 48,

					LONG_RANGE_STILL = 63,
					LONG_RANGE_MOVING = 42,

					VERY_LONG_RANGE_STILL = 53,
					VERY_LONG_RANGE_MOVING = 35),
			)

			accuracy_increase_mod = 2.00
			accuracy_decrease_mod = 6.00
			KD_chance = KD_CHANCE_MEDIUM
			load_delay = 5
			aim_miss_chance_divider = 2.50
			headshot_kill_chance = 35
			KO_chance = 30
			load_method = SINGLE_CASING|SPEEDLOADER|MAGAZINE
			max_shells = 10
			weight = 3.85
			load_delay = 8
			firemodes = list(
				list(name="single shot",burst=1, move_delay=2, fire_delay=6)
				)
		if ("Open-Bolt (small)")
			item_state = "greasegun"
			stat = "mg"
			w_class = 3
			slot_flags = SLOT_SHOULDER|SLOT_BELT
			sel_mode = 1
			full_auto = TRUE
			attachment_slots = ATTACH_IRONSIGHTS
			firemodes = list(
				list(name="full auto",	burst=1, burst_delay=1, recoil=1, move_delay=5, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5))
				)
			load_method = MAGAZINE
			load_delay = 8
			equiptimer -= 1
			gun_type = GUN_TYPE_RIFLE
			accuracy_list = list(

				// small body parts: head, hand, feet
				"small" = list(
					SHORT_RANGE_STILL = 49,
					SHORT_RANGE_MOVING = 39,

					MEDIUM_RANGE_STILL = 39,
					MEDIUM_RANGE_MOVING = 31,

					LONG_RANGE_STILL = 14,
					LONG_RANGE_MOVING = 11,

					VERY_LONG_RANGE_STILL = 7,
					VERY_LONG_RANGE_MOVING = 6),

				// medium body parts: limbs
				"medium" = list(
					SHORT_RANGE_STILL = 59,
					SHORT_RANGE_MOVING = 47,

					MEDIUM_RANGE_STILL = 39,
					MEDIUM_RANGE_MOVING = 31,

					LONG_RANGE_STILL = 16,
					LONG_RANGE_MOVING = 13,

					VERY_LONG_RANGE_STILL = 9,
					VERY_LONG_RANGE_MOVING = 7),

				// large body parts: chest, groin
				"large" = list(
					SHORT_RANGE_STILL = 79,
					SHORT_RANGE_MOVING = 63,

					MEDIUM_RANGE_STILL = 59,
					MEDIUM_RANGE_MOVING = 47,

					LONG_RANGE_STILL = 39,
					LONG_RANGE_MOVING = 31,

					VERY_LONG_RANGE_STILL = 16,
					VERY_LONG_RANGE_MOVING = 13),
			)

			accuracy_increase_mod = 1.00
			accuracy_decrease_mod = 2.00
			KD_chance = KD_CHANCE_MEDIUM
			attachment_slots = ATTACH_IRONSIGHTS
		if ("Open-Bolt (large)")
			item_state = "negev"
			stat = "mg"
			w_class = 5
			heavy = TRUE
			attachment_slots = ATTACH_IRONSIGHTS
			firemodes = list(
				list(name="full auto",	burst=1, burst_delay=1.3, move_delay=8, dispersion = list(0.7, 1.1, 1.3, 1.4, 1.5), recoil = 2),
				)
			weight = 10
			slot_flags = 0
			force = 20
			nothrow = TRUE
			throwforce = 30
			equiptimer += 12
			load_delay = 50
			slowdown = 1
			load_delay = 12
			// not accurate at all
			accuracy_list = list(

				// small body parts: head, hand, feet
				"small" = list(
					SHORT_RANGE_STILL = 30,
					SHORT_RANGE_MOVING = 27,

					MEDIUM_RANGE_STILL = 21,
					MEDIUM_RANGE_MOVING = 19,

					LONG_RANGE_STILL = 11,
					LONG_RANGE_MOVING = 10,

					VERY_LONG_RANGE_STILL = 8,
					VERY_LONG_RANGE_MOVING = 7),

				// medium body parts: limbs
				"medium" = list(
					SHORT_RANGE_STILL = 38,
					SHORT_RANGE_MOVING = 34,

					MEDIUM_RANGE_STILL = 30,
					MEDIUM_RANGE_MOVING = 27,

					LONG_RANGE_STILL = 23,
					LONG_RANGE_MOVING = 21,

					VERY_LONG_RANGE_STILL = 11,
					VERY_LONG_RANGE_MOVING = 10),

				// large body parts: chest, groin
				"large" = list(
					SHORT_RANGE_STILL = 45,
					SHORT_RANGE_MOVING = 41,

					MEDIUM_RANGE_STILL = 38,
					MEDIUM_RANGE_MOVING = 34,

					LONG_RANGE_STILL = 30,
					LONG_RANGE_MOVING = 27,

					VERY_LONG_RANGE_STILL = 15,
					VERY_LONG_RANGE_MOVING = 14),
			)

			accuracy_increase_mod = 1.00
			accuracy_decrease_mod = 2.00
			KD_chance = KD_CHANCE_MEDIUM
			load_method = MAGAZINE
			sel_mode = 1
			full_auto = TRUE
			attachment_slots = ATTACH_IRONSIGHTS
		if ("Dual Selective Fire")
			item_state = "ak47"
			stat = "rifle"
			w_class = 3
			sel_mode = 1
			full_auto = TRUE
			fire_sound = 'sound/weapons/mosin_shot.ogg'
			weight = 3.47
			slot_flags = SLOT_SHOULDER
			firemodes = list(
				list(name="semi auto",	burst=1, burst_delay=0.8, recoil=0.7, move_delay=2, dispersion = list(0.3, 0.4, 0.5, 0.6, 0.7)),
				list(name="full auto",	burst=1, burst_delay=1.3, recoil=1.3, move_delay=4, dispersion = list(1.2, 1.2, 1.3, 1.4, 1.8)),
				)
			sel_mode = 1
			attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL
			load_delay = 8
			gun_type = GUN_TYPE_RIFLE
			accuracy_list = list(

				// small body parts: head, hand, feet
				"small" = list(
					SHORT_RANGE_STILL = 49,
					SHORT_RANGE_MOVING = 39,

					MEDIUM_RANGE_STILL = 39,
					MEDIUM_RANGE_MOVING = 31,

					LONG_RANGE_STILL = 14,
					LONG_RANGE_MOVING = 11,

					VERY_LONG_RANGE_STILL = 7,
					VERY_LONG_RANGE_MOVING = 6),

				// medium body parts: limbs
				"medium" = list(
					SHORT_RANGE_STILL = 59,
					SHORT_RANGE_MOVING = 47,

					MEDIUM_RANGE_STILL = 39,
					MEDIUM_RANGE_MOVING = 31,

					LONG_RANGE_STILL = 16,
					LONG_RANGE_MOVING = 13,

					VERY_LONG_RANGE_STILL = 9,
					VERY_LONG_RANGE_MOVING = 7),

				// large body parts: chest, groin
				"large" = list(
					SHORT_RANGE_STILL = 79,
					SHORT_RANGE_MOVING = 63,

					MEDIUM_RANGE_STILL = 59,
					MEDIUM_RANGE_MOVING = 47,

					LONG_RANGE_STILL = 39,
					LONG_RANGE_MOVING = 31,

					VERY_LONG_RANGE_STILL = 16,
					VERY_LONG_RANGE_MOVING = 13),
			)

			accuracy_increase_mod = 1.00
			accuracy_decrease_mod = 2.00
			KD_chance = KD_CHANCE_MEDIUM
			attachment_slots = ATTACH_IRONSIGHTS
		if ("Triple Selective Fire")
			item_state = "m16"
			stat = "rifle"
			w_class = 3
			sel_mode = 1
			full_auto = TRUE
			fire_sound = 'sound/weapons/mosin_shot.ogg'
			weight = 3.47
			slot_flags = SLOT_SHOULDER
			firemodes = list(
				list(name="semi auto",	burst=1, burst_delay=0.8, recoil=0.7, move_delay=2, dispersion = list(0.3, 0.4, 0.5, 0.6, 0.7)),
				list(name="burst fire",	burst=3, burst_delay=1.4, recoil=0.9, move_delay=3, dispersion = list(1, 1.1, 1.1, 1.3, 1.5)),
				list(name="full auto",	burst=1, burst_delay=1.3, recoil=1.3, move_delay=4, dispersion = list(1.2, 1.2, 1.3, 1.4, 1.8)),
				)
			sel_mode = 1
			attachment_slots = ATTACH_IRONSIGHTS|ATTACH_BARREL
			load_delay = 8
			gun_type = GUN_TYPE_RIFLE
			accuracy_list = list(

				// small body parts: head, hand, feet
				"small" = list(
					SHORT_RANGE_STILL = 49,
					SHORT_RANGE_MOVING = 39,

					MEDIUM_RANGE_STILL = 39,
					MEDIUM_RANGE_MOVING = 31,

					LONG_RANGE_STILL = 14,
					LONG_RANGE_MOVING = 11,

					VERY_LONG_RANGE_STILL = 7,
					VERY_LONG_RANGE_MOVING = 6),

				// medium body parts: limbs
				"medium" = list(
					SHORT_RANGE_STILL = 59,
					SHORT_RANGE_MOVING = 47,

					MEDIUM_RANGE_STILL = 39,
					MEDIUM_RANGE_MOVING = 31,

					LONG_RANGE_STILL = 16,
					LONG_RANGE_MOVING = 13,

					VERY_LONG_RANGE_STILL = 9,
					VERY_LONG_RANGE_MOVING = 7),

				// large body parts: chest, groin
				"large" = list(
					SHORT_RANGE_STILL = 79,
					SHORT_RANGE_MOVING = 63,

					MEDIUM_RANGE_STILL = 59,
					MEDIUM_RANGE_MOVING = 47,

					LONG_RANGE_STILL = 39,
					LONG_RANGE_MOVING = 31,

					VERY_LONG_RANGE_STILL = 16,
					VERY_LONG_RANGE_MOVING = 13),
			)

			accuracy_increase_mod = 1.00
			accuracy_decrease_mod = 2.00
			KD_chance = KD_CHANCE_MEDIUM
			attachment_slots = ATTACH_IRONSIGHTS
		if ("Pump-Action")
			item_state = "shotgun-f"
			stat = "rifle"
			gun_type = GUN_TYPE_SHOTGUN
			fire_sound = 'sound/weapons/guns/fire/shotgun_fire.ogg'
			// 15% more accurate than SMGs
			accuracy_list = list(

				// small body parts: head, hand, feet
				"small" = list(
					SHORT_RANGE_STILL = 56,
					SHORT_RANGE_MOVING = 45,

					MEDIUM_RANGE_STILL = 45,
					MEDIUM_RANGE_MOVING = 36,

					LONG_RANGE_STILL = 16,
					LONG_RANGE_MOVING = 13,

					VERY_LONG_RANGE_STILL = 8,
					VERY_LONG_RANGE_MOVING = 7),

				// medium body parts: limbs
				"medium" = list(
					SHORT_RANGE_STILL = 68,
					SHORT_RANGE_MOVING = 54,

					MEDIUM_RANGE_STILL = 45,
					MEDIUM_RANGE_MOVING = 36,

					LONG_RANGE_STILL = 18,
					LONG_RANGE_MOVING = 15,

					VERY_LONG_RANGE_STILL = 10,
					VERY_LONG_RANGE_MOVING = 8),

				// large body parts: chest, groin
				"large" = list(
					SHORT_RANGE_STILL = 91,
					SHORT_RANGE_MOVING = 72,

					MEDIUM_RANGE_STILL = 68,
					MEDIUM_RANGE_MOVING = 54,

					LONG_RANGE_STILL = 45,
					LONG_RANGE_MOVING = 36,

					VERY_LONG_RANGE_STILL = 18,
					VERY_LONG_RANGE_MOVING = 15),
			)

			accuracy_increase_mod = 1.00
			accuracy_decrease_mod = 1.00
			KD_chance = KD_CHANCE_HIGH
			max_shells = 6
			w_class = 4.0
			force = 10
			flags =  CONDUCT
			slot_flags = SLOT_SHOULDER
			caliber = "12gauge"
			load_method = SINGLE_CASING
			ammo_type = /obj/item/ammo_casing/shotgun
			handle_casings = HOLD_CASINGS
			stat = "rifle"
			move_delay = 4
			load_delay = 5
	switch(feeding_type)
		if ("Internal Magazine")
			handle_casings = HOLD_CASINGS
			load_method = SINGLE_CASING | SPEEDLOADER
			load_shell_sound = 'sound/weapons/clip_reload.ogg'
			max_shells = 5
			magazine_type = /obj/item/ammo_magazine/emptyclip
		if ("Tubular")
			handle_casings = HOLD_CASINGS
			load_method = SINGLE_CASING
			load_shell_sound = 'sound/weapons/clip_reload.ogg'
			max_shells = 8
		if ("Revolving")
			handle_casings = CYCLE_CASINGS
			max_shells = 6
		if ("External Magazine")
			load_method = MAGAZINE
			magazine_type = /obj/item/ammo_magazine/emptymagazine/small
			if (receiver_type == "Semi-Auto (small)")
				if (caliber == "pistol9")
					magazine_type = /obj/item/ammo_magazine/emptymagazine/pistol
				else
					magazine_type = /obj/item/ammo_magazine/emptymagazine/pistol/a45
		if ("Large External Magazine")
			load_method = MAGAZINE
			magazine_type = /obj/item/ammo_magazine/emptymagazine
		if ("Open (Belt-Fed)")
			load_method = MAGAZINE
			magazine_type = /obj/item/ammo_magazine/emptybelt

	switch(barrel_type)
		if ("Pistol Barrel")
			effectiveness_mod *= 0.8
			equiptimer -= 1
		if ("Carbine Barrel")
			effectiveness_mod *= 1
			slot_flags &= ~SLOT_HOLSTER
		if ("Rifle Barrel")
			effectiveness_mod *=1.1
			slot_flags &= ~SLOT_HOLSTER
			slot_flags &= ~SLOT_BELT
			equiptimer += 1
		if ("Long Rifle Barrel")
			effectiveness_mod *= 1.25
			slot_flags &= ~SLOT_HOLSTER
			slot_flags &= ~SLOT_BELT
			equiptimer += 3
		if ("Air-Cooled Barrel")
			effectiveness_mod *= 1.05
			slot_flags &= ~SLOT_HOLSTER
			slot_flags &= ~SLOT_BELT
			equiptimer += 5
	var/tempdesc = ""
	switch(caliber)
		if ("12gauge")
			tempdesc = "12 gauge"

		if ("largerifle")
			tempdesc = "8mm large rifle rounds"

		if ("smallrifle")
			tempdesc = "6.5mm small rifle rounds"

		if ("pistol45")
			tempdesc = ".45 pistol rounds"

		if ("pistol9")
			tempdesc = "9mm pistol rounds"

		if ("intermediumrifle")
			tempdesc = "7.5mm intermediate rifle rounds"

		if ("smallintermediumrifle")
			tempdesc = "5.5mm intermediate rifle rounds"

	desc = "A gun chambered in [tempdesc]. The feed system is [lowertext(feeding_type)]."
	if (!firemodes.len)
		firemodes += new firemode_type
	else
		for (var/i in 1 to firemodes.len)
			firemodes[i] = new firemode_type(firemodes[i])

	for (var/datum/firemode/FM in firemodes)
		if (FM.fire_delay == -1)
			FM.fire_delay = fire_delay
/obj/item/weapon/gun/projectile/custom/update_icon()
	if (stock_type == "Folding Stock")
		if (!folded)
			stock_img = image("icon" = src.icon, "icon_state" = "[src.stock_type]")
		else
			stock_img = image("icon" = src.icon, "icon_state" = "none")
	if (feeding_type == "Open (Belt-Fed)" || feeding_type == "External Magazine" || feeding_type == "Large External Magazine")
		if (ammo_magazine)
			feeding_img = image("icon" = src.icon, "icon_state" = "[src.feeding_type]_loaded")
		else
			feeding_img = image("icon" = src.icon, "icon_state" = "[src.feeding_type]_unloaded")
	else
		feeding_img = image("icon" = src.icon, "icon_state" = "none")
	overlays.Cut()
	overlays += stock_img
	overlays += barrel_img
	overlays += receiver_img
	overlays += feeding_img
	update_held_icon()



/obj/item/weapon/gun/projectile/custom/special_check(mob/user)
	if (gun_safety && safetyon)
		user << "<span class='warning'>You can't fire \the [src] while the safety is on!</span>"
		return FALSE
	if (!user.has_empty_hand(both = FALSE) && (receiver_type != "Revolver" && receiver_type != "Semi-Auto (small)"))
		user << "<span class='warning'>You need both hands to fire \the [src]!</span>"
		return FALSE
	if (bolt_open && receiver_type == "Bolt-Action")
		user << "<span class='warning'>You can't fire [src] while the bolt is open!</span>"
		return FALSE
	if (jammed_until > world.time)
		user << "<span class = 'danger'>\The [src] has jammed! You can't fire it until it has unjammed.</span>"
		return FALSE
	return TRUE


/obj/item/weapon/gun/projectile/custom/handle_post_fire()
	..()

	if (receiver_type == "Semi-Auto (large)" || receiver_type == "Semi-Auto (small)" )
		if (world.time - last_fire > 50)
			jamcheck = 0
		else
			if (barrel_type == "Air-Cooled Barrel")
				jamcheck += 0.2
			else
				jamcheck += 0.6

		if (prob(jamcheck))
			jammed_until = max(world.time + (jamcheck * 4), 40)
			jamcheck = 0

		last_fire = world.time

	else if (receiver_type == "Bolt-Action")
		if (last_fire != -1)
			if (world.time - last_fire <= 7)
				jamcheck += 4
			else if (world.time - last_fire <= 10)
				jamcheck += 3
			else if (world.time - last_fire <= 20)
				jamcheck += 2
			else if (world.time - last_fire <= 30)
				++jamcheck
			else if (world.time - last_fire <= 40)
				++jamcheck
			else if (world.time - last_fire <= 50)
				++jamcheck
			else
				jamcheck = 0
		else
			++jamcheck

		if (prob(jamcheck))
			jammed_until = max(world.time + (jamcheck * 5), 50)
			jamcheck = 0
		if (blackpowder)
			spawn (1)
				new/obj/effect/effect/smoke/chem(get_step(src, dir))
		last_fire = world.time

	else if (receiver_type == "Revolver")
		cocked = TRUE
	else if (receiver_type == "Open-Bolt (small)" || receiver_type == "Dual Selective Fire" || receiver_type == "Triple Selective Fire")
		if (world.time - last_fire > 50)
			jamcheck = 0
		else
			if (barrel_type == "Air-Cooled Barrel")
				jamcheck += 0.1
			else
				jamcheck += 0.3

		if (prob(jamcheck))
			jammed_until = max(world.time + (jamcheck * 4), 45)
			jamcheck = 0

		last_fire = world.time
	else if (receiver_type == "Open-Bolt (large)")
		if (world.time - last_fire > 50)
			jamcheck = 0
		else
			if (barrel_type =="Air-Cooled Barrel")
				jamcheck += 0.1
			else
				jamcheck += 0.6

		if (prob(jamcheck))
			jammed_until = max(world.time + (jamcheck * 5), 50)
			jamcheck = 0

		last_fire = world.time



/obj/item/weapon/gun/projectile/custom/attack_self(mob/user)
	if (receiver_type == "Pump-Action")
		if (world.time >= recentpump + 10)
			pump(user)
			recentpump = world.time
	else if (receiver_type == "Bolt-Action")
		if (!check_bolt)//Keeps people from spamming the bolt
			check_bolt++
			if (!do_after(user, 2, src, FALSE, TRUE, INCAPACITATION_DEFAULT, TRUE))//Delays the bolt
				check_bolt--
				return
		else return
		if (check_bolt_lock)
			user << "<span class='notice'>The bolt won't move, the gun is empty!</span>"
			check_bolt--
			return
		bolt_open = !bolt_open
		if (bolt_open)
			if (chambered)
				playsound(loc, 'sound/weapons/bolt_open.ogg', 50, TRUE)
				user << "<span class='notice'>You work the bolt open, ejecting [chambered]!</span>"
				chambered.loc = get_turf(src)
				chambered.randomrotation()
				loaded -= chambered
				chambered = null
				if (bolt_safety)
					if (!loaded.len)
						check_bolt_lock++
						user << "<span class='notice'>The bolt is locked!</span>"
			else
				playsound(loc, 'sound/weapons/bolt_open.ogg', 50, TRUE)
				user << "<span class='notice'>You work the bolt open.</span>"
		else
			playsound(loc, 'sound/weapons/bolt_close.ogg', 50, TRUE)
			user << "<span class='notice'>You work the bolt closed.</span>"
			bolt_open = FALSE
		add_fingerprint(user)
		update_icon()
		check_bolt--
	else
		..()

/obj/item/weapon/gun/projectile/custom/load_ammo(var/obj/item/A, mob/user)
	if (receiver_type == "Bolt-Action")
		if (!bolt_open)
			return
		if (check_bolt_lock)
			--check_bolt_lock // preincrement is superior
	if (receiver_type == "Revolver")
		chamber_offset = 0
	..()

/obj/item/weapon/gun/projectile/custom/unload_ammo(mob/user, var/allow_dump=1)
	if (receiver_type == "Bolt-Action")
		if (!bolt_open)
			return
	if (receiver_type == "Revolver")
		if (loaded.len)
			//presumably, if it can be speed-loaded, it can be speed-unloaded.
			if (allow_dump && (load_method & SPEEDLOADER))
				var/count = FALSE
				var/turf/T = get_turf(user)
				if (T)
					for (var/obj/item/ammo_casing/C in loaded)
						C.loc = T
						count++
					loaded.Cut()
				if (count)
					visible_message("[user] unloads [src].", "<span class='notice'>You unload [count] round\s from [src].</span>")
					if (bulletinsert_sound) playsound(loc, bulletinsert_sound, 75, TRUE)
			else if (load_method & SINGLE_CASING)
				var/obj/item/ammo_casing/C = loaded[loaded.len]
				loaded.len--
				user.put_in_hands(C)
				visible_message("[user] removes \a [C] from [src].", "<span class='notice'>You remove \a [C] from [src].</span>")
				if (istype(src, /obj/item/weapon/gun/projectile/boltaction))
					var/obj/item/weapon/gun/projectile/boltaction/B = src
					if (B.bolt_safety && !B.loaded.len)
						B.check_bolt_lock++
				if (bulletinsert_sound) playsound(loc, bulletinsert_sound, 75, TRUE)
		else
			user << "<span class='warning'>[src] is empty.</span>"

	..()

/obj/item/weapon/gun/projectile/custom/consume_next_projectile(var/check = FALSE)
	if (receiver_type == "Revolver")
		if (chamber_offset)
			chamber_offset--
			return
		return ..()
	if (receiver_type == "Pump-Action")
		if (chambered)
			return chambered.BB
		return null
	//get the next casing
	if (loaded.len)
		chambered = loaded[1] //load next casing.
		if (handle_casings != HOLD_CASINGS)
			loaded -= chambered
			if (infinite_ammo)
				loaded += new chambered.type

	else if (ammo_magazine && ammo_magazine.stored_ammo.len)
		chambered = ammo_magazine.stored_ammo[1]
		if (handle_casings != HOLD_CASINGS)
			ammo_magazine.stored_ammo -= chambered
			if (infinite_ammo)
				ammo_magazine.stored_ammo += new chambered.type

	if (chambered)
		if (gibs)
			chambered.BB.gibs = TRUE
		if (crushes)
			chambered.BB.crushes = TRUE
		return chambered.BB
	return null

/obj/item/weapon/gun/projectile/custom/attack_hand(mob/user as mob)
	if (receiver_type == "Revolver")
		if (user.get_inactive_hand() == src)
			unload_ammo(user, allow_dump=0)
		else
			return ..()
	..()


/obj/item/weapon/gun/projectile/custom/proc/pump(mob/M as mob)
	if (receiver_type == "Pump-Action")
		playsound(M, 'sound/weapons/shotgunpump.ogg', 60, TRUE)

		if (chambered)//We have a shell in the chamber
			chambered.loc = get_turf(src)//Eject casing
			chambered.randomrotation()
			chambered = null

		if (loaded.len)
			var/obj/item/ammo_casing/AC = loaded[1] //load next casing.
			loaded -= AC //Remove casing from loaded list.
			chambered = AC

/obj/item/weapon/gun/projectile/custom/attackby(obj/W as obj, mob/user as mob)
	if (receiver_type == "Revolver" || receiver_type == "Semi-Auto (small)")
		if (istype(W, /obj/item/weapon/attachment/bayonet))
			user << "<span class = 'danger'>That won't fit on there.</span>"
			return FALSE
		else
			return ..()
	..()

/obj/item/weapon/gun/projectile/custom/verb/fold()
	set name = "Toggle Stock"
	set category = null
	set src in usr

	if (stock_type == "Folding Stock")
		if (folded)
			folded = FALSE
			usr << "You extend the stock on \the [src]."
			equiptimer +=5
			set_stock()
			update_icon()
		else
			folded = TRUE
			base_icon = "akms_folded"
			usr << "You collapse the stock on \the [src]."
			equiptimer -= 5
			set_stock()
			update_icon()
	else
		usr << "\The [src] has no stock to toggle."

/obj/item/weapon/gun/projectile/custom/proc/set_stock()
	if (folded)
		slot_flags = SLOT_SHOULDER|SLOT_BELT
		effectiveness_mod *= 0.87
	else
		slot_flags = SLOT_SHOULDER
		effectiveness_mod /= 0.87