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

/obj/structure/gunbench/attackby(obj/item/P as obj, mob/living/human/user as mob)
	desc = "A large wooden workbench. The gunsmith's main work tool. It has [steel_amt] steel and [wood_amt] wood on it."
	if (istype(P, /obj/item/stack/material/wood))
		user << "You begin cutting the wood..."
		playsound(loc, 'sound/effects/woodfile.ogg', 100, TRUE)
		if (do_after(user,15*P.amount,src))
			user << "<span class='notice'>You cut the wood.</span>"
			wood_amt += P.amount
			desc = "A large wooden workbench. The gunsmith's main work tool. It has [steel_amt] steel and [wood_amt] wood on it."
			qdel(P)
		return

	else if (istype(P, /obj/item/stack/material/steel))
		user << "You begin smithing the steel..."
		playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
		if (do_after(user,15*P.amount,src))
			user << "<span class='notice'>You smite the steel.</span>"
			steel_amt += P.amount
			desc = "A large wooden workbench. The gunsmith's main work tool. It has [steel_amt] steel and [wood_amt] wood on it."
			qdel(P)
		return

	else if (istype(P, /obj/item/weapon/gun/projectile))
		if (!istype(P, /obj/item/weapon/gun/projectile/ancient) && !istype(P, /obj/item/weapon/gun/projectile/bow) && !istype(P, /obj/item/weapon/gun/projectile/capnball) && !istype(P, /obj/item/weapon/gun/projectile/flintlock))
			rechamber_gun(P, user)
			return
	else if (istype(P, /obj/item/blueprint/gun) && user.getStatCoeff("crafting") >= 1.5)
		assemble_from_blueprint(user,P)
		return
	else if (user.getStatCoeff("crafting") < 1.5)
		user << "<span class='warning'>You are not skilled enough to do this.</span>"
		return
/obj/item/weapon/gun/projectile
	var/rechambered = FALSE

/obj/structure/gunbench/proc/rechamber_gun(var/obj/item/weapon/gun/projectile/P, var/mob/living/human/H)
	var/list/caliber_options = list("Cancel")
	//custom guns:
	if (istype(P, /obj/item/weapon/gun/projectile/custom))
		var/obj/item/weapon/gun/projectile/custom/PC = P
		if (map.ID == MAP_NOMADS_KARAFUTO)
			switch (PC.receiver_type)
				if ("Pump-Action")
					caliber_options = list("shotgun","Cancel")

				if ("Bolt-Action","Semi-Auto (large)")
					caliber_options = list("7.7x58mm arisaka","6.5x50mm arisaka","7.62x54mmR","8x53mm murata","Cancel")

				if ("Open-Bolt (large)")
					caliber_options = list("7.7x58mm arisaka","6.5x50mm arisaka","7.62x54mmR","Cancel")

				if ("Open-Bolt (small)","Revolver","Semi-Auto (small)")
					caliber_options = list("9x19 Parabellum","9x18 Makarov","8x22mmB nambu","9x22mm nambu", "7.62x38mmR",".45 Colt","Cancel")

				if ("Dual Selective Fire", "Triple Selective Fire")
					caliber_options = list("7.7x58mm arisaka","6.5x50mm arisaka","7.62x54mmR","Cancel")

			if (PC.feeding_type == "Internal Magazine (Removable)")
				caliber_options = list("9x19 Parabellum","9x18 Makarov","8x22mmB nambu","9x22mm nambu", "7.62x38mmR",".45 Colt","Cancel")
		else
			switch (PC.receiver_type)
				if ("Pump-Action")
					caliber_options = list("shotgun","Cancel")

				if ("Bolt-Action","Semi-Auto (large)")
					caliber_options = list("7.92x57mm Mauser","6.5x50mm small rifle","7.62x39mm intermediate rifle","5.56x45mm intermediate rifle","Cancel")

				if ("Open-Bolt (large)")
					caliber_options = list("7.62x39mm intermediate rifle","5.56x45mm intermediate rifle","Cancel")

				if ("Open-Bolt (small)","Revolver","Semi-Auto (small)")
					caliber_options = list("9x19 Parabellum","9x18 Makarov",".45 Colt","Cancel")

				if ("Dual Selective Fire", "Triple Selective Fire")
					caliber_options = list("7.62x39mm intermediate rifle","5.56x45mm intermediate rifle","Cancel")

			if (PC.feeding_type == "Internal Magazine (Removable)")
				caliber_options = list("9x19 Parabellum","9x18 Makarov",".45 Colt","Cancel")
	//others
	if (map.ID == MAP_NOMADS_KARAFUTO)
		if (istype(P, /obj/item/weapon/gun/projectile/automatic))
			caliber_options = list("7.7x58mm arisaka","6.5x50mm arisaka","7.62x54mmR","Cancel")
		else if (istype(P, /obj/item/weapon/gun/projectile/boltaction))
			caliber_options = list("7.7x58mm arisaka","6.5x50mm arisaka","7.62x54mmR","8x53mm murata","Cancel")
		else if (istype(P, /obj/item/weapon/gun/projectile/leveraction))
			caliber_options = list("6.5x50mm arisaka","7.62x54mmR", "Cancel")
		else if (istype(P, /obj/item/weapon/gun/projectile/pistol) || istype(P, /obj/item/weapon/gun/projectile/revolver) || istype(P, /obj/item/weapon/gun/projectile/revolving))
			caliber_options = list("9x19 Parabellum","9x18 Makarov","8x22mmB nambu","9x22mm nambu", "7.62x38mmR",".45 Colt","Cancel")
		else if (istype(P, /obj/item/weapon/gun/projectile/semiautomatic))
			caliber_options = list("7.7x58mm arisaka","6.5x50mm arisaka","7.62x54mmR", "Cancel")
		else if (istype(P, /obj/item/weapon/gun/projectile/special) || istype(P, /obj/item/weapon/gun/projectile/submachinegun))
			caliber_options = list("9x19 Parabellum","9x18 Makarov","8x22mmB nambu","9x22mm nambu", "7.62x38mmR",".45 Colt","Cancel")
		else
			caliber_options = list("Cancel")
	else
		if (istype(P, /obj/item/weapon/gun/projectile/automatic))
			caliber_options = list("7.62x39mm intermediate rifle","5.56x45mm intermediate rifle","Cancel")
		else if (istype(P, /obj/item/weapon/gun/projectile/boltaction))
			caliber_options = list("7.92x57mm Mauser","6.5x50mm small rifle","7.62x39mm intermediate rifle","5.56x45mm intermediate rifle","Cancel")
		else if (istype(P, /obj/item/weapon/gun/projectile/leveraction))
			caliber_options = list("6.5x50mm small rifle","5.56x45mm intermediate rifle","Cancel")
		else if (istype(P, /obj/item/weapon/gun/projectile/pistol) || istype(P, /obj/item/weapon/gun/projectile/revolver) || istype(P, /obj/item/weapon/gun/projectile/revolving))
			caliber_options = list("9x19 Parabellum","9x18 Makarov",".45 Colt","Cancel")
		else if (istype(P, /obj/item/weapon/gun/projectile/semiautomatic))
			caliber_options = list("7.92x57mm Mauser","6.5x50mm small rifle","7.62x39mm intermediate rifle","5.56x45mm intermediate rifle","Cancel")
		else if (istype(P, /obj/item/weapon/gun/projectile/special) || istype(P, /obj/item/weapon/gun/projectile/submachinegun))
			caliber_options = list("7.62x39mm intermediate rifle","5.56x45mm intermediate rifle","Cancel")
		else
			caliber_options = list("Cancel")

	var/choice = WWinput(H, "Which caliber do you want to convert \the [P] into? Be aware that this will permanently reduce accuracy by around 10%!", "Firearm Rechambering", "Cancel", caliber_options)
	if (choice == "Cancel")
		return
	else
		H << "You start converting \the [P] into [choice]..."
		playsound(loc, 'sound/effects/gunbench.ogg', 100, TRUE)
		if (do_after(H, 100, src))
			switch (choice)
				if ("7.92x57mm Mauser")
					P.caliber = "a792x57"
					P.ammo_type = /obj/item/ammo_casing/a792x57
				if ("6.5x50mm small rifle")
					P.caliber = "a65x50"
					P.ammo_type = /obj/item/ammo_casing/a65x50
					
				if (".45 Colt")
					P.caliber = "a45"
					P.ammo_type = /obj/item/ammo_casing/a45
				if ("9x19 Parabellum")
					P.caliber = "a9x19"
					P.ammo_type = /obj/item/ammo_casing/a9x19
				if ("9x18 Makarov")
					P.caliber = "a9x18"
					P.ammo_type = /obj/item/ammo_casing/a9x18

				if ("7.62x39mm intermediate rifle")
					P.caliber = "a762x39"
					P.ammo_type = /obj/item/ammo_casing/a762x39
				if ("5.56x45mm intermediate rifle")
					P.caliber = "a556x45"
					P.ammo_type = /obj/item/ammo_casing/a556x45

				if ("7.7x58mm arisaka")
					P.caliber = "a77x58"
					P.ammo_type = /obj/item/ammo_casing/a77x58
				if ("6.5x50mm arisaka")
					P.caliber = "a65x50"
					P.ammo_type = /obj/item/ammo_casing/a65x50
				if ("7.62x54mmR")
					P.caliber = "a762x54"
					P.ammo_type = /obj/item/ammo_casing/a762x54
				if ("8x53mm murata")
					P.caliber = "a8x53"
					P.ammo_type = /obj/item/ammo_casing/a8x53
				if ("8x22mmB nambu")
					P.caliber = "c8mmnambu"
					P.ammo_type = /obj/item/ammo_casing/c8mmnambu
				if ("9x22mm nambu")
					P.caliber = "c9mm_jap_revolver"
					P.ammo_type = /obj/item/ammo_casing/c9mm_jap_revolver
				if ("7.62x38mmR")
					P.caliber = "a762x38"
					P.ammo_type = /obj/item/ammo_casing/a762x38

			H << "You successfully convert \the [P]."
			P.effectiveness_mod *= 0.9
			if (!findtext(P.name,"(rechambered)"))
				P.name = "[P.name] (rechambered)"
			if (!findtext(P.desc,". Rechambered into"))
				P.desc = "[P.desc]. Rechambered into [choice]."
			else
				var/list/split_desc = splittext(P.desc, ". Rechambered into")
				P.desc = "[split_desc[1]]. Rechambered into [choice]."

/obj/structure/gunbench/attack_hand(var/mob/user as mob)
	var/mob/living/human/H = user
	desc = "A large wooden workbench. The gunsmith's main work tool. It has [steel_amt] steel and [wood_amt] wood on it."
	if (H.getStatCoeff("crafting") < 2.5 && map.civilizations)
		user << "You don't have the skills to design a new gun! Use an existing blueprint."
		return FALSE
	var/found = FALSE
	if (istype(user.l_hand, /obj/item/stack/money))
		var/obj/item/stack/money/M = user.l_hand
		if (M.value*M.amount >= 20)
			found = TRUE
	else if (istype(user.r_hand, /obj/item/stack/money))
		var/obj/item/stack/money/M = user.r_hand
		if (M.value*M.amount >= 20)
			found = TRUE
	if (!found)
		user << "You don't have enough money to make a new blueprint! You need 50 gold or equivalent in one of your hands."
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
	switch (choice_stock)
		if ("Cancel")
			current_gun = null
			using_wood = 0
			using_steel = 0
			return FALSE
		if ("Rifle Wooden Stock")
			using_wood = 7
		if ("Carbine Wooden Stock")
			using_wood = 5
		if ("Pistol Grip")
			using_steel = 3
		if ("Steel Stock")
			using_steel = 5
		if ("Folding Stock")
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
	switch (choice_receiver)
		if ("Cancel")
			current_gun = null
			using_wood = 0
			using_steel = 0
			return FALSE
		if ("Bolt-Action")
			using_steel += 5
		if ("Pump-Action")
			using_steel += 5
		if ("Revolver")
			using_steel += 4
		if ("Semi-Auto (small)")
			using_steel += 6
		if ("Semi-Auto (large)")
			using_steel += 8
		if ("Open-Bolt (small)")
			using_steel += 8
		if ("Open-Bolt (large)")
			using_steel += 11
		if ("Dual Selective Fire")
			using_steel += 13
		if ("Triple Selective Fire")
			using_steel += 14

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
		display3 = list("Internal Magazine","Tubular")
	else if (map.ordinal_age >= 6)
		display3 = list("Internal Magazine", "Tubular", "External Magazine","Large External Magazine","Open (Belt-Fed)")
	if (choice_receiver == "Pump-Action")
		display3 = list("Tubular")
	if (choice_receiver == "Revolver")
		display3 = list("Revolving")
	if (choice_receiver =="Semi-Auto (small)")
		display3 = list("Internal Magazine (Removable)")
	if (choice_receiver == "Open-Bolt (large)" && map.ordinal_age >= 6)
		display3 = list("Internal Magazine", "External Magazine","Large External Magazine","Open (Belt-Fed)")
	if (choice_receiver == "Bolt-Action" || choice_receiver =="Semi-Auto (large)" && map.ordinal_age >= 6)
		display3 = list("Internal Magazine", "Tubular", "External Magazine","Large External Magazine")	
	display3 += "Cancel"
	var/choice_feeding = WWinput(user, "Choose the feeding system:", "Gunsmith - [using_steel]/[steel_amt] steel, [using_wood]/[wood_amt] wood", "Cancel", display3)
	switch (choice_feeding)
		if ("Cancel")
			current_gun = null
			using_wood = 0
			using_steel = 0
			return
		if ("Internal Magazine")
			using_steel += 4
		if ("Internal Magazine (Removable)")
			using_steel += 6
		if ("Tubular")
			using_steel += 5
		if ("Revolving")
			using_steel += 3
		if ("External Magazine")
			using_steel += 8
		if ("Large External Magazine")
			using_steel += 10
		if ("Open (Belt-Fed)")
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
	if (choice_feeding == "Semi-Auto (small)")
		display4 = list("Pistol Barrel","Cancel")
	if (choice_feeding == "Open (Belt-Fed)")
		display4 = list("Air-Cooled Barrel","Cancel")
	var/choice_barrel = WWinput(user, "Choose the barrel:", "Gunsmith - [using_steel]/[steel_amt] steel, [using_wood]/[wood_amt] wood", "Cancel", display4)
	switch (choice_barrel)
		if ("Cancel")
			current_gun = null
			using_wood = 0
			using_steel = 0
			return
		if ("Pistol Barrel")
			using_steel += 4
		if ("Carbine Barrel")
			using_steel += 5
		if ("Rifle Barrel")
			using_steel += 3
		if ("Long Rifle Barrel")
			using_steel += 8
		if ("Air-Cooled Barrel")
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
	var/caliberlist = list("Cancel")
	if(map.ID == MAP_NOMADS_KARAFUTO)
		switch (choice_receiver)
			if ("Pump-Action")
				caliberlist = list("shotgun","Cancel")

			if ("Bolt-Action","Semi-Auto (large)")
				caliberlist = list("7.7x58mm arisaka","6.5x50mm arisaka","7.62x54mmR","8x53mm murata","Cancel")

			if ("Open-Bolt (small)","Revolver","Semi-Auto (small)")
				caliberlist = list("9x19 Parabellum","9x18 Makarov","8x22mmB nambu","9x22mm nambu","7.62x38mmR",".45 Colt","Cancel")
			
			if ("Open-Bolt (large)")
				caliberlist = list("7.7x58mm arisaka","6.5x50mm arisaka","7.62x54mmR","Cancel")

			if ("Dual Selective Fire", "Triple Selective Fire")
				caliberlist = list("7.7x58mm arisaka","6.5x50mm arisaka","7.62x54mmR","Cancel")

		if (choice_feeding == "Internal Magazine (Removable)")
			caliberlist = list("9x19 Parabellum","9x18 Makarov","8x22mmB nambu","9x22mm nambu", "7.62x38mmR",".45 Colt","Cancel")
	else
		switch (choice_receiver)
			if ("Pump-Action")
				caliberlist = list("shotgun","Cancel")

			if ("Bolt-Action","Semi-Auto (large)")
				caliberlist = list("7.92x57mm Mauser","6.5x50mm small rifle","7.62x39mm intermediate rifle","5.56x45mm intermediate rifle","Cancel")

			if ("Open-Bolt (small)","Revolver","Semi-Auto (small)")
				caliberlist = list("9x19 Parabellum","9x18 Makarov",".45 Colt","Cancel")
			
			if ("Open-Bolt (large)")
				caliberlist = list("7.62x39mm intermediate rifle","5.56x45mm intermediate rifle","Cancel")

			if ("Dual Selective Fire", "Triple Selective Fire")
				caliberlist = list("7.62x39mm intermediate rifle","5.56x45mm intermediate rifle","Cancel")

		if (choice_feeding == "Internal Magazine (Removable)")
			caliberlist = list("9x19 Parabellum","9x18 Makarov",".45 Colt","Cancel")

	var/choice_caliber = WWinput(user, "Choose the caliber:", "Gunsmith - [using_steel]/[steel_amt] steel, [using_wood]/[wood_amt] wood", "Cancel", caliberlist)
	switch (choice_caliber)
		if ("Cancel")
			current_gun = null
			using_wood = 0
			using_steel = 0
			return
		if ("shotgun")
			current_gun.caliber = "12gauge"
			current_gun.ammo_type = /obj/item/ammo_casing/shotgun
		if ("7.92x57mm Mauser")
			current_gun.caliber = "a792x57"
			current_gun.ammo_type = /obj/item/ammo_casing/a792x57
		if ("6.5x50mm small rifle")
			current_gun.caliber = "a65x50"
			current_gun.ammo_type = /obj/item/ammo_casing/a65x50
		if (".45 Colt")
			current_gun.caliber = "a45"
			current_gun.ammo_type = /obj/item/ammo_casing/a45
		if ("9x19 Parabellum")
			current_gun.caliber = "a9x19"
			current_gun.ammo_type = /obj/item/ammo_casing/a9x19
		if ("9x18 Makarov")
			current_gun.caliber = "a9x18"
			current_gun.ammo_type = /obj/item/ammo_casing/a9x18
		if ("7.62x39mm intermediate rifle")
			current_gun.caliber = "a762x39"
			current_gun.ammo_type = /obj/item/ammo_casing/a762x39
		if ("5.56x45mm intermediate rifle")
			current_gun.caliber = "a556x45"
			current_gun.ammo_type = /obj/item/ammo_casing/a556x45
		if ("7.7x58mm arisaka")
			current_gun.caliber = "a77x58"
			current_gun.ammo_type = /obj/item/ammo_casing/a77x58
		if ("6.5x50mm arisaka")
			current_gun.caliber = "a65x50"
			current_gun.ammo_type = /obj/item/ammo_casing/a65x50
		if ("7.62x54mmR")
			current_gun.caliber = "a762x54"
			current_gun.ammo_type = /obj/item/ammo_casing/a762x54
		if ("8x53mm murata")
			current_gun.caliber = "a8x53"
			current_gun.ammo_type = /obj/item/ammo_casing/a8x53
		if ("9x19 Parabellum")
			current_gun.caliber = "a9x19"
			current_gun.ammo_type = /obj/item/ammo_casing/a9x19
		if ("9x18 Makarov")
			current_gun.caliber = "a9x18"
			current_gun.ammo_type = /obj/item/ammo_casing/a9x18
		if ("8x22mmB nambu")
			current_gun.caliber = "c8mmnambu"
			current_gun.ammo_type = /obj/item/ammo_casing/c8mmnambu
		if ("9x22mm nambu")
			current_gun.caliber = "c9mm_jap_revolver"
			current_gun.ammo_type = /obj/item/ammo_casing/c9mm_jap_revolver
		if ("7.62x38mmR")
			current_gun.caliber = "a762x38"
			current_gun.ammo_type = /obj/item/ammo_casing/a762x38

	var/do_skn_override = WWinput(user, "Do you want to give this gun a different appearance or keep the default look?", "Gunsmithing", "Keep", list("Keep","Change"))
	if (do_skn_override == "Change")
		var/list/possible_list = list("Cancel")
		switch (choice_receiver)
			if ("Pump-Action")
				current_gun.override_icon = 'icons/obj/guns/rifles.dmi'
				possible_list = list("Cancel", "shotgun", "remington870", "remington11", "winchester1873")
			if ("Bolt-Action")
				current_gun.override_icon = 'icons/obj/guns/rifles.dmi'
				possible_list = list("Cancel", "gewehr71", "gewehr98", "lebel", "mosin", "murata", "enfield", "p14enfield", "carcano", "arisaka30", "arisaka35")
				if (map.ordinal_age >= 6)
					possible_list = list("Cancel", "gewehr71", "gewehr98", "kar98k", "lebel", "mosin", "mosin30", "murata", "enfield", "p14enfield", "carcano", "springfieldww2", "arisaka30", "arisaka35", "arisaka38", "arisaka99")
			if("Semi-Auto (large)")
				current_gun.override_icon = 'icons/obj/guns/rifles.dmi'
				possible_list = list("Cancel", "svt", "g41", "g43", "m1garand")
				if (map.ordinal_age >= 7)
					possible_list += "m14"
					possible_list += "sks"
			if ("Open-Bolt (small)")
				current_gun.override_icon = 'icons/obj/guns/automatic.dmi'
				possible_list = list("Cancel", "pps", "ppsh", "mp40", "greasegun", "tommygun", "thompson", "avtomat")
				if (map.ordinal_age >= 8)
					possible_list += "victor"
					possible_list += "p90"
			if ("Open-Bolt (large)")
				current_gun.override_icon = 'icons/obj/guns/mgs.dmi'
				possible_list = list("Cancel", "madsen", "mg34", "type99lmg", "bar", "dp")
				if (map.ordinal_age >= 7)
					possible_list += "pkmp"
					possible_list += "negev"
					possible_list += "m60"
			if ("Revolver")
				current_gun.override_icon = 'icons/obj/guns/pistols.dmi'
				possible_list = list("Cancel", "revolver", "t26revolver", "nagant", "panther", "detective", "detective_leopard", "detective_gold", "goldrevolver", "mateba", "peacemaker", "colt1877", "dragoon", "coltnewpolice", "enfield02", "smithwesson32", "graysonfito", "magnum58", "webley4", "m1892")
			if ("Semi-Auto (small)")
				current_gun.override_icon = 'icons/obj/guns/pistols.dmi'
				possible_list = list("Cancel", "p220", "nambu", "mauser", "luger", "borchardt", "colt", "m9beretta", "tanm9", "black1911","tt30","makarov", "waltherp38", "jericho941", "glock17", "coltpockethammerles", "tarusg3", "mp443", "chinese_ms14", "chinese_plastic", "pl14", "sig250")
			if ("Dual Selective Fire")
				current_gun.override_icon = 'icons/obj/guns/assault_rifles.dmi'
				possible_list = list("Cancel", "stg", "g3", "ar12", "ak47", "ak74", "aks74", "akms", "ak74m", "vz58", "whitevz58", "blackvz58", "chinese_assault_rifle", "c7")
			if ("Triple Selective Fire")
				current_gun.override_icon = 'icons/obj/guns/assault_rifles.dmi'
				possible_list = list("Cancel", "m16","m16a2","m16a4","m4", "m4mws", "hk417", "scarl", "scarh", "ar15", "mk18", "mk18tan", "sigsauer")
		var/dst = WWinput(user, "Choose the gun's look:", "Gunsmithing", "Cancel", possible_list)
		if (dst != "Cancel" && dst != null)
			current_gun.override_sprite = dst
			current_gun.base_icon = current_gun.override_sprite

	if (choice_caliber && choice_stock && choice_barrel && choice_receiver && choice_feeding)
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
		var/foundm = FALSE
		if (istype(user.l_hand, /obj/item/stack/money))
			var/obj/item/stack/money/M = user.l_hand
			if (M.value*M.amount >= 200)
				foundm = TRUE
				M.amount -= 200/M.value
				if (M.amount <= 0)
					qdel(M)
		else if (istype(user.r_hand, /obj/item/stack/money))
			var/obj/item/stack/money/M = user.r_hand
			if (M.value*M.amount >= 200)
				foundm = TRUE
				M.amount -= 200/M.value
				if (M.amount <= 0)
					qdel(M)
		if (foundm)
			var/obj/item/blueprint/gun/newgunbp = new/obj/item/blueprint/gun(loc)
			newgunbp.name = "[current_gun.name] blueprint"
			newgunbp.caliber = current_gun.caliber
			newgunbp.ammo_type = current_gun.ammo_type
			newgunbp.custom_name = current_gun.name
			newgunbp.custom_name = replacetext(newgunbp.name, " blueprint", "")
			if (choice_caliber == "shotgun")
				newgunbp.desc = "A blueprint for a gun chambered in 12 gauge. The feed system is [lowertext(current_gun.feeding_type)]. It has a [lowertext(current_gun.stock_type)] and a [lowertext(current_gun.barrel_type)]."
			else
				newgunbp.desc = "A blueprint for a gun chambered in [choice_caliber]. The feed system is [lowertext(current_gun.feeding_type)]. It has a [lowertext(current_gun.stock_type)] and a [lowertext(current_gun.barrel_type)]."
			newgunbp.receiver_type = current_gun.receiver_type
			newgunbp.stock_type = current_gun.stock_type
			newgunbp.barrel_type = current_gun.barrel_type
			newgunbp.feeding_type = current_gun.feeding_type
			newgunbp.override_sprite = current_gun.override_sprite
			newgunbp.base_icon = current_gun.override_sprite
			newgunbp.override_icon = current_gun.override_icon
			newgunbp.cost_wood = using_wood
			newgunbp.cost_steel = using_steel
		else
			user << "<span class='warning'>You do not have enough money to finish the blueprint!</span>"
			qdel(current_gun)
			return
		if (current_gun)
			current_gun.finish()
			wood_amt -= using_wood
			steel_amt -= using_steel
			using_wood = 0
			using_steel = 0
			var/obj/item/weapon/gun/projectile/custom/NEWGUN = current_gun
			NEWGUN.loc = get_turf(src)
			current_gun = null
			return TRUE
		else
			using_wood = 0
			using_steel = 0
			current_gun = null
			user << "Canceled gun crafting."
			return

	else
		using_wood = 0
		using_steel = 0
		current_gun = null
		user << "Canceled gun crafting."
		return

/obj/structure/gunbench/proc/assemble_from_blueprint(var/mob/living/user = null, var/obj/item/blueprint/gun/bpsource = null)
	if (!bpsource)
		return
	if (wood_amt < bpsource.cost_wood)
		if (user)
			user << "Not enough wood!"
		return
	if (steel_amt < bpsource.cost_steel)
		if (user)
			user << "Not enough steel!"
		return

	using_wood = bpsource.cost_wood
	using_steel = bpsource.cost_steel
	user << "You begin crafting the [bpsource.custom_name]..."
	playsound(loc, 'sound/effects/gunbench.ogg', 100, TRUE)
	if (do_after(user,200,src))
		if (!bpsource)
			return
		if (wood_amt < bpsource.cost_wood)
			if (user)
				user << "Not enough wood!"
			return
		if (steel_amt < bpsource.cost_steel)
			if (user)
				user << "Not enough steel!"
			return
		wood_amt -= using_wood
		steel_amt -= using_steel
		using_wood = 0
		using_steel = 0
		var/obj/item/weapon/gun/projectile/custom/NEWGUN = new/obj/item/weapon/gun/projectile/custom(src.loc)
		NEWGUN.name = bpsource.custom_name
		NEWGUN.caliber = bpsource.caliber
		NEWGUN.ammo_type = bpsource.ammo_type
		NEWGUN.receiver_type = bpsource.receiver_type
		NEWGUN.stock_type = bpsource.stock_type
		NEWGUN.barrel_type = bpsource.barrel_type
		NEWGUN.feeding_type = bpsource.feeding_type
		NEWGUN.base_icon = bpsource.base_icon
		NEWGUN.override_sprite = bpsource.override_sprite
		NEWGUN.override_icon = bpsource.override_icon
		NEWGUN.step = 4
		NEWGUN.finish()

		if (user)
			user << "You assemble a new [NEWGUN.name]."
		return

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

	var/override_sprite = null
	var/override_icon = 'icons/obj/guns/gun.dmi'

	gun_safety = TRUE
	caliber = "caliber"
	ammo_type = /obj/item/ammo_casing
	magazine_type = /obj/item/ammo_magazine/emptypouch
	good_mags = list()

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
	if (!override_sprite)
		stock_img = image("icon" = src.icon, "icon_state" = src.stock_type)
		overlays += stock_img
		barrel_img = image("icon" = src.icon, "icon_state" = src.barrel_type)
		overlays += barrel_img
		receiver_img = image("icon" = src.icon, "icon_state" = src.receiver_type)
		overlays += receiver_img
		if (feeding_type == "Open (Belt-Fed)" || feeding_type == "External Magazine" || feeding_type == "Large External Magazine")
			feeding_img = image("icon" = src.icon, "icon_state" = "[src.feeding_type]_unloaded")
			overlays += feeding_img
	else
		icon = override_icon
		icon_state = override_sprite
	switch (stock_type)
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

	switch (receiver_type)
		if ("Bolt-Action")
			item_state = "mosin"
			gtype = "rifle"
			w_class = ITEM_SIZE_LARGE
			force = 10
			throwforce = 20
			max_shells = 5
			slot_flags = SLOT_SHOULDER
			recoil = 2 //extra kickback
			handle_casings = HOLD_CASINGS
			load_method = SINGLE_CASING | SPEEDLOADER
			load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
			accuracy = TRUE
			gun_type = GUN_TYPE_RIFLE
			attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_SCOPE|ATTACH_BARREL
			accuracy_increase_mod = 2.00
			accuracy_decrease_mod = 6.00
			KD_chance = KD_CHANCE_HIGH
			stat = "rifle"
			move_delay = 2
			fire_delay = 2
			good_mags = list(/obj/item/ammo_magazine/emptyclip)
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
			item_state = "revolver"
			gtype = "revolver"
			stat = "pistol"
			w_class = ITEM_SIZE_SMALL
			slot_flags = SLOT_BELT|SLOT_POCKET|SLOT_HOLSTER
			handle_casings = CYCLE_CASINGS
			max_shells = 7
			unload_sound 	= 'sound/weapons/guns/interact/rev_magout.ogg'
			reload_sound 	= 'sound/weapons/guns/interact/rev_magin.ogg'
			cocked_sound 	= 'sound/weapons/guns/interact/rev_cock.ogg'
			fire_sound 		= 'sound/weapons/guns/fire/revolver.ogg'
			magazine_based = FALSE
			gun_type = GUN_TYPE_PISTOL
			single_action = FALSE
			equiptimer -= 1
			slot_flags = SLOT_HOLSTER
			good_mags = list(/obj/item/ammo_magazine/emptyspeedloader)
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
			gtype = "pistol"
			move_delay = 1
			fire_delay = 3
			equiptimer -= 1
			gun_type = GUN_TYPE_PISTOL
			slot_flags = SLOT_BELT | SLOT_HOLSTER
			good_mags = list(/obj/item/ammo_magazine/emptymagazine/pistol)
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
			w_class = ITEM_SIZE_SMALL
			slot_flags = SLOT_BELT|SLOT_POCKET|SLOT_HOLSTER
			accuracy_increase_mod = 1.50
			accuracy_decrease_mod = 2.00
			KD_chance = KD_CHANCE_LOW
			aim_miss_chance_divider = 2.00
		if ("Semi-Auto (large)")
			item_state = "g41"
			stat = "rifle"
			gtype = "rifle"
			w_class = ITEM_SIZE_LARGE
			slot_flags = SLOT_SHOULDER
			good_mags = list(/obj/item/ammo_magazine/emptymagazine/rifle)
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
				list(name = "single shot",burst=1, move_delay=2, fire_delay=6)
				)
		if ("Open-Bolt (small)")
			item_state = "pps"
			stat = "machinegun"
			gtype = "smg"
			w_class = ITEM_SIZE_NORMAL
			slot_flags = SLOT_SHOULDER|SLOT_BELT
			sel_mode = 1
			full_auto = TRUE
			attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS
			good_mags = list(/obj/item/ammo_magazine/emptymagazine,/obj/item/ammo_magazine/emptymagazine/rifle)
			firemodes = list(
				list(name = "full auto",	burst=1, burst_delay=1, recoil=1, move_delay=5, dispersion = list(0.7, 1.2, 1.2, 1.3, 1.5))
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
		if ("Open-Bolt (large)")
			item_state = "negev"
			stat = "machinegun"
			gtype = "mg"
			w_class = ITEM_SIZE_HUGE
			heavy = TRUE
			attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS
			good_mags = list(/obj/item/ammo_magazine/emptybelt)
			firemodes = list(
				list(name = "full auto",	burst=1, burst_delay=1.3, recoil = 1.6, move_delay=8, dispersion = list(0.7, 1.1, 1.3, 1.4, 1.5)),
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
		if ("Dual Selective Fire")
			good_mags = list(/obj/item/ammo_magazine/emptymagazine,/obj/item/ammo_magazine/emptymagazine/rifle)
			item_state = "ak47"
			gtype = "rifle"
			stat = "rifle"
			w_class = ITEM_SIZE_NORMAL
			sel_mode = 1
			full_auto = TRUE
			fire_sound = 'sound/weapons/guns/fire/rifle.ogg'
			weight = 3.47
			slot_flags = SLOT_SHOULDER
			firemodes = list(
				list(name = "semi auto",	burst=1, burst_delay=0.8, recoil=0.7, move_delay=2, dispersion = list(0.3, 0.4, 0.5, 0.6, 0.7)),
				list(name = "full auto",	burst=1, burst_delay=1.3, recoil=1.3, move_delay=4, dispersion = list(1.2, 1.2, 1.3, 1.4, 1.8)),
				)
			sel_mode = 1
			attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
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
		if ("Triple Selective Fire")
			good_mags = list(/obj/item/ammo_magazine/emptymagazine,/obj/item/ammo_magazine/emptymagazine/rifle)
			item_state = "m16"
			gtype = "rifle"
			stat = "rifle"
			w_class = ITEM_SIZE_NORMAL
			sel_mode = 1
			full_auto = TRUE
			fire_sound = 'sound/weapons/guns/fire/rifle.ogg'
			weight = 3.47
			slot_flags = SLOT_SHOULDER
			firemodes = list(
				list(name = "semi auto",	burst=1, burst_delay=0.8, recoil=0.7, move_delay=2, dispersion = list(0.3, 0.4, 0.5, 0.6, 0.7)),
				list(name = "burst fire",	burst=3, burst_delay=1.4, recoil=0.9, move_delay=3, dispersion = list(1, 1.1, 1.1, 1.3, 1.5)),
				list(name = "full auto",	burst=1, burst_delay=1.3, recoil=1.3, move_delay=4, dispersion = list(1.2, 1.2, 1.3, 1.4, 1.8)),
				)
			sel_mode = 1
			attachment_slots = ATTACH_SILENCER|ATTACH_IRONSIGHTS|ATTACH_BARREL
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
		if ("Pump-Action")
			item_state = "shotgun"
			stat = "rifle"
			gtype = "shotgun"
			gun_type = GUN_TYPE_SHOTGUN
			fire_sound = 'sound/weapons/guns/fire/shotgun.ogg'
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
			w_class = ITEM_SIZE_LARGE
			force = 10
			flags =  CONDUCT
			slot_flags = SLOT_SHOULDER
			caliber = "12gauge"
			load_method = SINGLE_CASING
			ammo_type = /obj/item/ammo_casing/shotgun
			magazine_type = /obj/item/ammo_magazine/shellbox
			handle_casings = HOLD_CASINGS
			move_delay = 4
			load_delay = 5

	switch (feeding_type)
		if ("Internal Magazine")
			handle_casings = EJECT_CASINGS
			load_method = SINGLE_CASING | SPEEDLOADER
			load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
			max_shells = 5
			magazine_type = /obj/item/ammo_magazine/emptyclip
		if ("Internal Magazine (Removable)")
			handle_casings = EJECT_CASINGS
			load_method = MAGAZINE
			if (receiver_type == "Semi-Auto (small)")
				magazine_type = /obj/item/ammo_magazine/emptymagazine/pistol
				good_mags = list(/obj/item/ammo_magazine/emptymagazine/pistol)
			else
				magazine_type = /obj/item/ammo_magazine/emptymagazine/pistol/a45
				good_mags = list(/obj/item/ammo_magazine/emptymagazine/pistol/a45)
		if ("Tubular")
			handle_casings = EJECT_CASINGS
			load_method = SINGLE_CASING
			load_shell_sound = 'sound/weapons/guns/interact/clip_reload.ogg'
			max_shells = 8
			slot_flags &= ~SLOT_HOLSTER
		if ("Revolving")
			handle_casings = CYCLE_CASINGS
			max_shells = 6
		if ("External Magazine")
			handle_casings = EJECT_CASINGS
			load_method = MAGAZINE
			slot_flags &= ~SLOT_HOLSTER
			if (receiver_type == "Semi-Auto (small)")
				magazine_type = /obj/item/ammo_magazine/emptymagazine/pistol
				good_mags = list(/obj/item/ammo_magazine/emptymagazine/pistol)
			else
				magazine_type = /obj/item/ammo_magazine/emptymagazine/rifle
				good_mags = list(/obj/item/ammo_magazine/emptymagazine/rifle)
		if ("Large External Magazine")
			load_method = MAGAZINE
			magazine_type = /obj/item/ammo_magazine/emptymagazine
			good_mags = list(/obj/item/ammo_magazine/emptymagazine,/obj/item/ammo_magazine/emptymagazine/rifle)
			slot_flags &= ~SLOT_HOLSTER
		if ("Open (Belt-Fed)")
			load_method = MAGAZINE
			magazine_type = /obj/item/ammo_magazine/emptybelt
			good_mags = list(/obj/item/ammo_magazine/emptybelt)

	switch (barrel_type)
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
	switch (caliber)
		if ("12gauge")
			tempdesc = "12 gauge"
		if ("a792x57")
			tempdesc = "7.92x57mm Mauser rifle rounds"
		if ("a65x50")
			tempdesc = "6.5x50mm small rifle rounds"
		if ("a45")
			tempdesc = ".45 Colt rounds"
		if ("a9x19")
			tempdesc = "9x19 Parabellum rounds"
		if ("a9x18")
			tempdesc = "9x18 Makarov rounds"
		if ("a762x39")
			tempdesc = "7.62x39mm intermediate rifle rounds"
		if ("a556x45")
			tempdesc = "5.56x45mm intermediate rifle rounds"
		if ("a762x38")
			tempdesc = "7.62x38mmR rifle rounds"

		if ("a77x58")
			tempdesc = "7.7x58mm arisaka rifle rounds"
		if ("a762x54")
			tempdesc = "7.62x54mmR rifle rounds"
		if ("a8x53")
			tempdesc = "8x53mm murata rifle rounds"
		if ("c8mmnambu")
			tempdesc = "8x22mmB nambu rounds"
		if ("c9mm_jap_revolver")
			tempdesc = "9x22mm nambu rounds"

	desc = "A gun chambered in [tempdesc] with a [lowertext(feeding_type)]. It has a [lowertext(stock_type)] and a [lowertext(barrel_type)]."
	if (!firemodes.len)
		firemodes += new firemode_type
	else
		for (var/i in 1 to firemodes.len)
			firemodes[i] = new firemode_type(firemodes[i])

	for (var/datum/firemode/FM in firemodes)
		if (FM.fire_delay == -1)
			FM.fire_delay = fire_delay
	update_icon()

/obj/item/weapon/gun/projectile/custom/update_icon()
	if (!override_sprite)
		if (stock_type == "Folding Stock")
			if (!folded)
				stock_img = image("icon" = src.icon, "icon_state" = "[src.stock_type]")
			else
				stock_img = image("icon" = src.icon, "icon_state" = "none")
		if (ammo_magazine)
			feeding_img = image("icon" = src.icon, "icon_state" = "[src.feeding_type]_loaded")
		else
			feeding_img = image("icon" = src.icon, "icon_state" = "[src.feeding_type]_unloaded")
		overlays.Cut()
		overlays += stock_img
		overlays += barrel_img
		overlays += receiver_img
		overlays += feeding_img
		update_held_icon()
	else if (override_sprite)
		if (receiver_type == "Pump-Action" || receiver_type == "Revolver")
			return

		if (feeding_type == "Bolt-Action")
			if (!bolt_open)
				icon_state = "[base_icon]"
			else
				icon_state = "[base_icon]_open"

		if (receiver_type == "Semi-Auto (large)" || receiver_type == "Semi-Auto (small)")
			if (!ammo_magazine)
				icon_state = "[base_icon]_open"
			else
				icon_state = "[base_icon]"

		if (receiver_type == "Dual Selective Fire" || receiver_type == "Triple Selective Fire")
			if (!ammo_magazine)
				icon_state = "[base_icon]_open"
			else
				icon_state = "[base_icon]"

		if (receiver_type == "Open-Bolt (large)" || receiver_type == "Open-Bolt (small)")
			if (!ammo_magazine)
				icon_state = "[base_icon]_open"
			else
				icon_state = "[base_icon]"
	..()


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
	update_icon()
	return TRUE


/obj/item/weapon/gun/projectile/custom/handle_post_fire()
	..()
	var/reverse_health_percentage = (1-(health/maxhealth)+0.25)*100
	if (receiver_type == "Semi-Auto (large)" || receiver_type == "Semi-Auto (small)" )
		if (world.time - last_fire > 50)
			jamcheck = 0
		else
			if (barrel_type == "Air-Cooled Barrel")
				jamcheck += 0.2
			else
				jamcheck += 0.6

		if (prob(jamcheck*reverse_health_percentage))
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

		if (prob(jamcheck*reverse_health_percentage))
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

		if (prob(jamcheck*reverse_health_percentage))
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

		if (prob(jamcheck*reverse_health_percentage))
			jammed_until = max(world.time + (jamcheck * 5), 50)
			jamcheck = 0

		last_fire = world.time
	update_icon()


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
				playsound(loc, 'sound/weapons/guns/interact/bolt_open.ogg', 50, TRUE)
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
				playsound(loc, 'sound/weapons/guns/interact/bolt_open.ogg', 50, TRUE)
				user << "<span class='notice'>You work the bolt open.</span>"
		else
			playsound(loc, 'sound/weapons/guns/interact/bolt_close.ogg', 50, TRUE)
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
	update_icon()
	if (istype(A, /obj/item/ammo_magazine))
		var/obj/item/ammo_magazine/AM = A
		if (caliber != AM.caliber && !AM in src.good_mags)
			return // incompatible
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
	update_icon()
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
			update_icon()
		else
			return ..()
	..()


/obj/item/weapon/gun/projectile/custom/proc/pump(mob/M as mob)
	if (receiver_type == "Pump-Action")
		playsound(M, 'sound/weapons/guns/interact/shotgun_pump.ogg', 60, TRUE)

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
	if (istype(W, /obj/item/ammo_magazine) || istype(W, /obj/item/ammo_casing))
		if (istype(W, /obj/item/ammo_magazine) && !magazine_type)
			return
		else
			load_ammo(W, user)

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
	update_icon()

/obj/item/weapon/gun/projectile/custom/proc/set_stock()
	if (folded)
		slot_flags = SLOT_SHOULDER|SLOT_BELT
		effectiveness_mod *= 0.92
	else
		slot_flags = SLOT_SHOULDER
		effectiveness_mod /= 0.92

