/obj/structure/anvil
	name = "anvil"
	desc = "A heavy iron anvil. The blacksmith's main work tool. It has 0 hot iron bars on it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "anvil1"
	density = TRUE
	anchored = TRUE
	var/iron_amt = 0
	var/steel_amt = 0
	not_movable = FALSE
	not_disassemblable = TRUE
obj/structure/anvil/New()
	..()
	desc = "A heavy iron anvil. The blacksmith's main work tool. It has [iron_amt] hot iron bars on it."

/obj/structure/anvil/attackby(obj/item/P as obj, mob/user as mob)
	var/mob/living/carbon/human/H = user
	if (istype(P,/obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << (anchored ? "<span class='notice'r>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
	if (H.getStatCoeff("crafting") < 1.7)
		user << "You don't have the skills to use this."
		return
	if (!map.civilizations && map.ID != MAP_TRIBES && (user.original_job_title != "Blacksmith" && user.original_job_title != "Pioneer Blacksmith" && user.original_job_title != "Town Blacksmith" && user.original_job_title != "Ferreiro" && user.original_job_title != "Ferrero" && user.original_job_title != "Grofsmid" && user.original_job_title != "Forgeron" && user.original_job_title != "British Blacksmith" && user.original_job_title != "Marooned Pirate Crew" && user.original_job_title != "Schmied"))
		user << "You don't have the skills to use this. Ask a blacksmith."
		return
	if (map.ID == MAP_TRIBES && (H.gorillaman || H.ant || H.wolfman || H.lizard || H.crab))
		user << "You don't know how to use this."
		return
	else
		if (istype(P, /obj/item/stack/material/iron) && steel_amt == 0)
			user << "You begin smithing the iron..."
			icon_state = "anvil2"
			playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
			if (do_after(user,15*P.amount,src))
				user << "<span class='notice'>You smite the iron.</span>"
				iron_amt += P.amount
				desc = "A heavy iron anvil. The blacksmith's main work tool. It has [iron_amt] hot iron bars on it."
				icon_state = "anvil3"
				qdel(P)
		else if (istype(P, /obj/item/stack/material/iron) && steel_amt > 0)
			user << "<span class='notice'>You can't smelt iron while there is steel on the anvil! Finish the steel first.</span>"
			return
		else if (istype(P, /obj/item/stack/material/steel) && iron_amt == 0 && map.ordinal_age >= 2)
			user << "You begin smithing the steel..."
			icon_state = "anvil2"
			playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
			if (do_after(user,15*P.amount,src))
				user << "<span class='notice'>You smite the steel.</span>"
				steel_amt += P.amount
				desc = "A heavy iron anvil. The blacksmith's main work tool. It has [steel_amt] hot steel bars on it."
				icon_state = "anvil3"
				qdel(P)
		else if (istype(P, /obj/item/stack/material/steel) && iron_amt > 0)
			user << "<span class='notice'>You can't smelt steel while there is iron on the anvil! Finish the iron first.</span>"
			return

/obj/structure/anvil/attack_hand(var/mob/user as mob)
	var/mob/living/carbon/human/H = user
	if (H.getStatCoeff("crafting") < 1.7)
		user << "You don't have the skills to use this."
		return
	if (!map.civilizations && map.ID != MAP_TRIBES && (user.original_job_title != "Blacksmith" && user.original_job_title != "Pioneer Blacksmith" && user.original_job_title != "Town Blacksmith" && user.original_job_title != "Ferreiro" && user.original_job_title != "Ferrero" && user.original_job_title != "Grofsmid" && user.original_job_title != "Forgeron" && user.original_job_title != "British Blacksmith" && user.original_job_title != "Marooned Pirate Crew" && user.original_job_title != "Schmied"))
		user << "You don't have the skills to use this. Ask a blacksmith."
		return
	if (map.ID == MAP_TRIBES && (H.gorillaman || H.ant || H.wolfman || H.lizard || H.crab))
		user << "You don't know how to use this."
		return
	else if (steel_amt > 0)
		var/list/display = list("Swords", "Cancel")
		if (map.ordinal_age == 3)
			display = list("Swords", "Cancel")
		else if (map.ordinal_age == 4)
			display = list("Swords", "Guns", "Cancel")
		else if (map.ordinal_age >= 5)
			display = list("Swords", "Guns", "Armor", "Cancel")
		var/choice = WWinput(user, "What do you want to make?", "Blacksmith - [steel_amt] steel", "Cancel", display)
		var/list/display2 = list("Cancel")
		if (choice == "Cancel")
			return
		else if (choice == "Swords")
			if (map.ordinal_age >= 5)
				display2 = list("Rapier (18)", "Katana (15)", "Wakazashi (10)" , "Tanto (5)" , "Cancel")
			else if (map.ordinal_age == 4)
				display2 = list("Sabre (15)", "Rapier (18)", "Katana (15)", "Wakazashi (10)" , "Tanto (5)","Cancel")
			else if (map.ordinal_age == 3)
				display2 = list("Small Sword (10)", "Sabre (15)", "Cutlass (12)", "Spadroon (15)", "Rapier (18)", "Longsword (18)", "Katana (15)", "Wakazashi (10)" , "Tanto (5)", "Cancel")
			else if (map.ordinal_age <= 2)
				display2 = list("Small Sword (10)", "Arming Sword (15)", "Katana (15)", "Wakazashi (10)" , "Tanto (5)", "Cancel")
		else if (choice == "Guns")
			if (map.ordinal_age == 4)
				display2 = list("Derringer M95 Pistol (15)", "Colt Peacemaker Revolver (25)", "Winchester Rifle (50)", "Coach Gun (22)", "Sharps Rifle (30)","Martini-Henry Rifle (35)", "Gewehr71 (30)", "Cancel")
			if (map.ordinal_age == 8)
				display2 = list("Makeshift AK-47 (32)", "Cancel")
		else if (choice == "Armor")
			if (map.ordinal_age == 5)
				display2 = list("Dayfield body armor (10)", "breastplate body armor (12)","Cancel")
			else if (map.ordinal_age == 6)
				display2 = list("M-1952 Flak Jacket (12)","Cancel")
			else if (map.ordinal_age == 7)
				display2 = list("M-1969 Flak Jacket (12)","woodland PASGT (15)","khaki PASGT (15)", "Tan Carrier vest (12)", "Black Carrier vest (12)", "Civilian Kevlar Vest (10)", "Cancel")
			else if (map.ordinal_age == 8)
				display2 = list("Interceptor body armor (16)", "Tan Carrier vest (12)", "Black Carrier vest (12)", "Civilian Kevlar Vest (10)", "Cancel")
		//else if (choice == "Other")
			//if (map.ordinal_age >= 4)
			//	display2 = list("Steel rods (2)", "Cancel")
		var/choice2 = WWinput(user, "What do you want to make?", "Blacksmith - [steel_amt] steel", "Cancel", display2)
		if (choice2 == "Cancel")
			return

		if (choice2 == "Derringer M95 Pistol (15)")
			if (steel_amt >= 15)
				user << "You begin crafting a Derringer..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,220,src) && steel_amt >= 15)
					user << "You craft a Derringer."
					steel_amt -= 15
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/weapon/gun/projectile/revolver/derringer(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Colt Peacemaker Revolver (25)")
			if (steel_amt >= 25)
				user << "You begin crafting a Colt Peacemaker..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,220,src) && steel_amt >= 25)
					user << "You craft a Colt Peacemaker."
					steel_amt -= 25
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/weapon/gun/projectile/revolver/peacemaker(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Martini-Henry Rifle (35)")
			if (steel_amt >= 35)
				user << "You begin crafting a Martini-Henry..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,170,src) && steel_amt >= 35)
					user << "You craft a Martini-Henry."
					steel_amt -= 35
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/weapon/gun/projectile/boltaction/singleshot/martini_henry(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Winchester Rifle (50)")
			if (steel_amt >= 50)
				user << "You begin crafting a Winchester..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,220,src) && steel_amt >= 50)
					user << "You craft a Winchester."
					steel_amt -= 50
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/weapon/gun/projectile/leveraction/winchester(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Sharps Rifle (30)")
			if (steel_amt >= 30)
				user << "You begin crafting a Sharps Rifle..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,220,src) && steel_amt >= 30)
					user << "You craft a Sharps Rifle."
					steel_amt -= 30
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/weapon/gun/projectile/boltaction/singleshot(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Coach Gun (22)")
			if (steel_amt >= 22)
				user << "You begin crafting a Coach Gun..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,220,src) && steel_amt >= 22)
					user << "You craft a Coach Gun."
					steel_amt -= 22
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/weapon/gun/projectile/shotgun/coachgun(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return

		if (choice2 == "Gewehr 71 (30)")
			if (steel_amt >= 30)
				user << "You begin crafting a Gewehr 71..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,170,src) && steel_amt >= 30)
					user << "You craft a Gewehr 71."
					steel_amt -= 30
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/weapon/gun/projectile/boltaction/gewehr71(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return

//Makeshift AK for ungas

		if (choice2 == "Makeshift AK-47 (32)")
			if (steel_amt >= 32)
				user << "You begin crafting a Makeshift AK-47..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,170,src) && steel_amt >= 32)
					user << "You craft a Makeshift AK-47."
					steel_amt -= 32
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/weapon/gun/projectile/submachinegun/makeshiftak47(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return

//Swordz

		if (choice2 == "Small Sword (10)")
			if (steel_amt >= 10)
				user << "You begin crafting a small sword..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,90,src) && steel_amt >= 10)
					user << "You craft a small sword."
					steel_amt -= 10
					if (steel_amt <= 0)
						icon_state = "anvil1"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/smallsword(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Sabre (15)")
			if (steel_amt >= 15)
				user << "You begin crafting a sabre..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,120,src) && steel_amt >= 15)
					user << "You craft a sabre."
					steel_amt -= 15
					if (steel_amt <= 0)
						icon_state = "anvil1"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/sabre(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Cutlass (12)")
			if (steel_amt >= 12)
				user << "You begin crafting a cutlass..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,100,src) && steel_amt >= 12)
					user << "You craft a cutlass."
					steel_amt -= 12
					if (steel_amt <= 0)
						icon_state = "anvil1"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/cutlass(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Rapier (18)")
			if (steel_amt >= 18)
				user << "You begin crafting a rapier..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,150,src) && steel_amt >= 18)
					user << "You craft a rapier."
					steel_amt -= 18
					if (steel_amt <= 0)
						icon_state = "anvil1"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/rapier(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Spadroon (15)")
			if (steel_amt >= 15)
				user << "You begin crafting a spadroon..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,120,src) && steel_amt >= 15)
					user << "You craft a spadroon."
					steel_amt -= 15
					if (steel_amt <= 0)
						icon_state = "anvil1"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/spadroon(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Arming Sword (15)")
			if (steel_amt >= 15)
				user << "You begin crafting an arming sword..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,120,src) && steel_amt >= 15)
					user << "You craft an arming sword."
					steel_amt -= 15
					if (steel_amt <= 0)
						icon_state = "anvil1"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/armingsword(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Longsword (18)")
			if (steel_amt >= 18)
				user << "You begin crafting a longsword..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,150,src) && steel_amt >= 18)
					user << "You craft a longsword."
					steel_amt -= 18
					if (steel_amt <= 0)
						icon_state = "anvil1"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/longsword(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return

		if (choice2 == "Katana (15)")
			if (steel_amt >= 15)
				user << "You begin crafting a Katana..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,150,src) && steel_amt >= 15)
					user << "You craft a Katana."
					steel_amt -= 15
					if (steel_amt <= 0)
						icon_state = "anvil1"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/katana(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return

		if (choice2 == "Wakazashi (10)")
			if (steel_amt >= 10)
				user << "You begin crafting a wakazashi..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,150,src) && steel_amt >= 10)
					user << "You craft a wakazashi."
					steel_amt -= 10
					if (steel_amt <= 0)
						icon_state = "anvil1"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/wakazashi(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return

		if (choice2 == "Tanto (5)")
			if (steel_amt >= 5)
				user << "You begin crafting a tanto..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,150,src) && steel_amt >= 5)
					user << "You craft a tanto."
					steel_amt -= 5
					if (steel_amt <= 0)
						icon_state = "anvil1"
					var/obj/item/weapon/material/knife/SW = new/obj/item/weapon/material/knife/tanto(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
	//modern armor
		if (choice2 == "Dayfield body armor (10)")
			if (steel_amt >= 10)
				user << "You begin crafting a Dayfield body armor..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,150,src) && steel_amt >= 10)
					user << "You craft a Dayfield body armor."
					steel_amt -= 10
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/clothing/accessory/armor/modern/british(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "breastplate body armor (12)")
			if (steel_amt >= 12)
				user << "You begin crafting a breastplate body armor..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,150,src) && steel_amt >= 12)
					user << "You craft a breastplate body armor."
					steel_amt -= 12
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/clothing/accessory/armor/modern/plate(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "M-1952 Flak Jacket (12)")
			if (steel_amt >= 12)
				user << "You begin crafting a M-1952 flak jacket..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,150,src) && steel_amt >= 12)
					user << "You craft a M-1952 flak jacket."
					steel_amt -= 12
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/clothing/accessory/armor/coldwar/flakjacket(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "M-1969 Flak Jacket (12)")
			if (steel_amt >= 12)
				user << "You begin crafting a M-1969 flak jacket..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,150,src) && steel_amt >= 12)
					user << "You craft a M-1969 flak jacket."
					steel_amt -= 12
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/clothing/accessory/armor/coldwar/flakjacket(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "woodland PASGT (15)")
			if (steel_amt >= 15)
				user << "You begin crafting a woodland PASGT vest..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,150,src) && steel_amt >= 15)
					user << "You craft a woodland PASGT vest."
					steel_amt -= 15
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/clothing/accessory/armor/coldwar/pasgt(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "khaki PASGT (15)")
			if (steel_amt >= 15)
				user << "You begin crafting a khaki PASGT vest..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,150,src) && steel_amt >= 15)
					user << "You craft a khaki PASGT vest."
					steel_amt -= 15
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
			//, "Tan Carrier vest (12)", "Black Carrier vest (12)", "Civilian Kevlar Vest (10)",
		if (choice2 == "Tan Carrier vest (12)")
			if (steel_amt >= 12)
				user << "You begin crafting a Tan Carrier Vest..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,150,src) && steel_amt >= 12)
					user << "You craft a Tan Carrier Vest."
					steel_amt -= 12
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/clothing/accessory/armor/nomads/pcarriertan(user.loc)
					return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return
		if (choice2 == "Black Carrier vest (12)")
			if (steel_amt >= 12)
				user << "You begin crafting a Black Carrier Vest..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,150,src) && steel_amt >= 12)
					user << "You craft a Black Carrier Vest."
					steel_amt -= 12
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/clothing/accessory/armor/nomads/pcarrierblack(user.loc)
					return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return
		if (choice2 == "Civilian Kevlar Vest (10)")
			if (steel_amt >= 10)
				user << "You begin crafting a Civilian Kevlar Vest..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,150,src) && steel_amt >= 10)
					user << "You craft a Civilian Kevlar Vest."
					steel_amt -= 10
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/clothing/accessory/armor/nomads/civiliankevlar(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Interceptor body armor (16)")
			if (steel_amt >= 16)
				user << "You begin crafting a Interceptor body armor..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,150,src) && steel_amt >= 16)
					user << "You craft a Interceptor body armor."
					steel_amt -= 16
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/clothing/accessory/armor/coldwar/plates/interceptor(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
//Other crafting, more to add here later.
/*		if (choice2 == "Steel rods (2)")
			if (steel_amt >= 2)
				user << "You begin crafting some steel rods..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,40,src) && steel_amt >= 2)
					user << "You craft three steel rods!"
					steel_amt -= 2
					if (steel_amt <= 0)
						icon_state = "anvil1"
					new/obj/item/stack/material/steelrods(user.loc)
					new/obj/item/stack/material/steelrods(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return*/
//iron smelting stuff.  //anvil timing list (8 iron 100 or less || <10 metal = 130 || <13 - 15 = 160 || 16 - 17 = 180 || 18 - 20 = 200 || 21 - 30 = 250)
	else if (iron_amt > 0)
		var/list/display = list("Swords", "Armor", "Cancel")
		if (map.ordinal_age >= 5)
			display = list("Armor", "Cancel")
		else if (map.ordinal_age == 4)
			display = list("Swords","Cancel")
		else if (map.ordinal_age == 3)
			display = list("Swords","Guns", "Armor", "Japanese Armor & Masks", "Cancel")
		else if (map.ordinal_age == 2)
			display = list("Swords", "Armor", "Additional Cultural Armor", "Japanese Armor & Masks", "Shields & Tools", "Cancel")
		else
			display = list("Swords", "Armor", "Shields & Tools", "Cancel")
		var/choice = WWinput(user, "What do you want to make?", "Blacksmith - [iron_amt] iron", "Cancel", display)
		if (choice == "Cancel")
			return
		else if (choice == "Swords")
			var/list/display2 = list("Cancel")
			if (map.ordinal_age == 4)
				display2 = list("Sabre (15)", "Rapier (18)", "Katana (15)","Cancel")
			else if (map.ordinal_age == 3)
				display2 = list("Small Sword (10)", "Sabre (15)", "Cutlass (12)", "Spadroon (15)", "Rapier (18)", "Katana (15)", "Cancel")
			else if (map.ordinal_age == 2)
				display2 = list("Small Sword (10)", "Arming Sword (15)", "Longsword (18)", "Katana (15)", "Cancel")
			else if (map.ordinal_age == 1)
				display2 = list("Gladius (10)", "Xiphos (14)", "Cancel")
			else if (map.ordinal_age == 0)
				display2 = list("Cancel")
			if (H.orc)
				display2 = list("Uruk-Hai Scimitar (16)", "Cancel")

			var/choice2 = WWinput(user, "What do you want to make?", "Blacksmith - [iron_amt] iron", "Cancel", display2)
			if (choice2 == "Cancel")
				return
			if (choice2 == "Small Sword (10)")
				if (iron_amt >= 10)
					user << "You begin crafting a small sword..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft a small sword."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/smallsword/iron(user.loc)
						SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
						SW.health = SW.maxhealth
						SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice2 == "Gladius (10)")
				if (iron_amt >= 10)
					user << "You begin crafting a gladius..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft a gladius."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/gladius(user.loc)
						SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
						SW.health = SW.maxhealth
						SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice2 == "Xiphos (14)")
				if (iron_amt >= 14)
					user << "You begin crafting a xiphos..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 14)
						user << "You craft a xiphos."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "anvil1"
						var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/xiphos(user.loc)
						SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
						SW.health = SW.maxhealth
						SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice2 == "Sabre (15)")
				if (iron_amt >= 15)
					user << "You begin crafting a sabre..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft a sabre."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "anvil1"
						var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/sabre/iron(user.loc)
						SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
						SW.health = SW.maxhealth
						SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice2 == "Cutlass (12)")
				if (iron_amt >= 12)
					user << "You begin crafting a cutlass..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft a cutlass."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "anvil1"
						var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/cutlass/iron(user.loc)
						SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
						SW.health = SW.maxhealth
						SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice2 == "Rapier (18)")
				if (iron_amt >= 18)
					user << "You begin crafting a rapier..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,200,src) && iron_amt >= 18)
						user << "You craft a rapier."
						iron_amt -= 18
						if (iron_amt <= 0)
							icon_state = "anvil1"
						var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/rapier/iron(user.loc)
						SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
						SW.health = SW.maxhealth
						SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice2 == "Spadroon (15)")
				if (iron_amt >= 15)
					user << "You begin crafting a spadroon..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft a spadroon."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "anvil1"
						var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/spadroon/iron(user.loc)
						SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
						SW.health = SW.maxhealth
						SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice2 == "Uruk-Hai Scimitar (16)")
				if (iron_amt >= 16)
					user << "You begin crafting an uruk-hai scimitar..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && iron_amt >= 16)
						user << "You craft an uruk-hai scimitar."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "anvil1"
						var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/urukhaiscimitar(user.loc)
						SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
						SW.health = SW.maxhealth
						SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice2 == "Arming Sword (15)")
				if (iron_amt >= 15)
					user << "You begin crafting an arming sword..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft an arming sword."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "anvil1"
						var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/armingsword/iron(user.loc)
						SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
						SW.health = SW.maxhealth
						SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice2 == "Longsword (18)")
				if (iron_amt >= 18)
					user << "You begin crafting a longsword..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,200,src) && iron_amt >= 18)
						user << "You craft a longsword."
						iron_amt -= 18
						if (iron_amt <= 0)
							icon_state = "anvil1"
						var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/longsword/iron(user.loc)
						SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
						SW.health = SW.maxhealth
						SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice2 == "Katana (15)")
				if (iron_amt >= 15)
					user << "You begin crafting a Katana..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft a Katana."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "anvil1"
						var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/katana/iron(user.loc)
						SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
						SW.health = SW.maxhealth
						SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
		else if (choice == "Guns")
			var/list/display3 = list("Crude Musket (15)", "Flintlock Pistol (20)", "Flintlock Musketoon (25)", "Flintlock Musket (30)", "Flintlock Blunderbuss (25)", "Cancel")
			var/choice3 = WWinput(user, "What do you want to make?", "Blacksmith - [iron_amt] iron", "Cancel", display3)
			if (choice3 == "Crude Musket (15)")
				if (iron_amt >= 15)
					user << "You begin crafting a crude musket..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft a crude musket."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/gun/projectile/flintlock/crude(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice3 == "Flintlock Musket (30)")
				if (iron_amt >= 30)
					user << "You begin crafting a musket..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,250,src) && iron_amt >= 30)
						user << "You craft a musket."
						iron_amt -= 30
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/gun/projectile/flintlock/musket(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice3 == "Flintlock Musketoon (25)")
				if (iron_amt >= 25)
					user << "You begin crafting a musketoon..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,250,src) && iron_amt >= 25)
						user << "You craft a musketoon."
						iron_amt -= 25
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/gun/projectile/flintlock/musketoon(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice3 == "Flintlock Blunderbuss (25)")
				if (iron_amt >= 25)
					user << "You begin crafting a blunderbuss..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,250,src) && iron_amt >= 25)
						user << "You craft a blunderbuss."
						iron_amt -= 25
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/gun/projectile/flintlock/blunderbuss(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice3 == "Flintlock Pistol (20)")
				if (iron_amt >= 20)
					user << "You begin crafting a pistol..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,200,src) && iron_amt >= 20)
						user << "You craft a pistol."
						iron_amt -= 20
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/gun/projectile/flintlock/pistol(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice3 == "Cancel")
				return
		else if (choice == "Armor")
			var/list/display4 = list("Cancel")
			if (map.ordinal_age == 8)
				display4 = list("Scrap Armor (16)", "Scrap Helmet (15)", "Cancel")
			else if (map.ordinal_age == 6)
				display4 = list("Mk2 Brodie (10)", "Stahlhelm (10)","Type 92 Helmet (10)", "Soviet Helmet (10)", "M1 Helmet (10)", "M26 Adrian (10)", "Cancel")
			else if (map.ordinal_age == 5)
				display4 = list("Pickelhaube (7)","MesH Pickelhaube (7)", "Pith (7)", "Mk1 Brodie (10)", "Stahlhelm (10)", "M15 Adrian Helmet (10)", "Cancel")
			else if (map.ordinal_age == 4)
				display4 = list("Picklehaube (7)", "Pith (7)", "Cancel")
			else if (map.ordinal_age == 3)
				display4 = list("Iron Chestplate (12)", "Conical Helmet (6)", "Protective Conical Helmet (10)", "Cancel")
			else if (map.ordinal_age == 2)
				if (H.orc)
					display4 = list("Grunt Armor (10)", "Urukhai Armor (12)", "Grunt Helmet (10)", "Spearman Helmet (12)", "Berserker Helmet (15)", "Orkish Gauntlets (10)", "Orkish Sabatons (10)","Cancel")
				else
					display4 = list("Chainmail (10)", "Hauberk (12)", "Iron Chestplate (12)", "Plated Armor (16)", "Conical Helmet (6)", "Kettle Helmet (8)", "Coif (10)", "Protective Conical Helmet (10)", "Coif and Helmet (12)", "Crusader Helmet (15)", "Knight Helmet (15)", "Gauntlets (10)", "Plated Boots (10)", "Cancel")
			else if (map.ordinal_age == 0)
				display4 = list("Cancel")
			else
				display4 = list("Egyptian Lamellar Armor (8)", "Scale Armor (14)", "Roman Helmet (10)", "Centurion Helmet (14)", "Decurion Helmet (14)", "Gladiator Helmet (10)", "Sol Invictus Helmet (18)", "Greek Helmet (10)", "Dimoerites helmet (14)", "Lochagos helmet (14)", "Anax helmet (18)", "Egyptian War Headdress (11)", "Horned Helmet (10)", "Winged Helmet (10)", "Conspicious Gaelic Helmet (14)", "Cancel")
			var/choice4 = WWinput(user, "What do you want to make?", "Blacksmith - [iron_amt] iron", "Cancel", display4)
			if (choice4 == "Egyptian Lamellar Armor (8)")
				if (iron_amt >= 8)
					user << "You begin crafting the egyptian lamellar armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 8)
						user << "You craft the egyptian lamellar armor."
						iron_amt -= 8
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/suit/armor/ancient/bronze_lamellar(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Scale Armor (14)")
				if (iron_amt >= 14)
					user << "You begin crafting the scale armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 14)
						user << "You craft the scale armor."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/suit/armor/ancient/scale(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Roman Helmet (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the roman helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the roman helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/roman/nomads(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Centurion Helmet (14)")
				if (iron_amt >= 14)
					user << "You begin crafting the centurion helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 14)
						user << "You craft the centurion helmet."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/roman_centurion/nomads(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Decurion Helmet (14)")
				if (iron_amt >= 14)
					user << "You begin crafting the decurion helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 14)
						user << "You craft the decurion helmet."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/roman_decurion/nomads(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Gladiator Helmet (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the gladiator helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the gladiator helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/gladiator/nomads(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Sol Invictus Helmet (18)")
				if (iron_amt >= 18)
					user << "You begin crafting the sol invictus helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,200,src) && iron_amt >= 18)
						user << "You craft the sol invictus helmet."
						iron_amt -= 18
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/solinvictus(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Greek Helmet (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the greek helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the greek helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/greek/nomads(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Dimoerites helmet (14)")
				if (iron_amt >= 14)
					user << "You begin crafting the dimoerites helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 14)
						user << "You craft the dimoerites helmet."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/greek_sl/nomads(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Lochagos helmet (14)")
				if (iron_amt >= 14)
					user << "You begin crafting the lochagos helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 14)
						user << "You craft the lochagos helmet."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/greek_commander/nomads(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Anax helmet (18)")
				if (iron_amt >= 18)
					user << "You begin crafting the anax helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,200,src) && iron_amt >= 18)
						user << "You craft the anax helmet."
						iron_amt -= 18
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/anax(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Egyptian War Headdress (11)")
				if (iron_amt >= 11)
					user << "You begin crafting the egyptian war headdress..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 11)
						user << "You craft the anax helmet."
						iron_amt -= 11
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/egyptian/nomads(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Horned Helmet (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the horned helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the horned helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/horned(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Winged Helmet (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the horned helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the horned helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/horned(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Conspicious Gaelic Helmet (14)")
				if (iron_amt >= 14)
					user << "You begin crafting the gaelic helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 14)
						user << "You craft the gaelic helmet."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/asterix/conspicious(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Chainmail (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the chainmail..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the chainmail."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/suit/armor/medieval/chainmail(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Hauberk (12)")
				if (iron_amt >= 12)
					user << "You begin crafting the hauberk..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft the hauberk."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/suit/armor/medieval/hauberk(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Gauntlets (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the gauntlets..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the gauntlets."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/gloves/gauntlets(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Plated Boots (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the armored boots..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the armored boots."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/shoes/medieval/knight(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Iron Chestplate (12)")
				if (iron_amt >= 12)
					user << "You begin crafting the iron chestplate..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft the iron chestplate."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/suit/armor/medieval/iron_chestplate(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Emirate Armor (14)")
				if (iron_amt >= 14)
					user << "You begin crafting the emirate armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 14)
						user << "You craft the emirate armor."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/suit/armor/medieval/emirate(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Plated Armor (16)")
				if (iron_amt >= 16)
					user << "You begin crafting the plated armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && iron_amt >= 16)
						user << "You craft the plated armor."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/suit/armor/medieval(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Conical Helmet (6)")
				if (iron_amt >= 6)
					user << "You begin crafting the conical helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 6)
						user << "You craft the conical helmet."
						iron_amt -= 6
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/medieval/helmet3(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Kettle Helmet (8)")
				if (iron_amt >= 8)
					user << "You begin crafting the kettle helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 8)
						user << "You craft the kettle helmet."
						iron_amt -= 8
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/medieval/helmet2(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Protective Conical Helmet (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the protective conical helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the protective conical helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/medieval/helmet1(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Coif (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the iron coif..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the iron coif."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/medieval/coif(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Coif and Helmet (12)")
				if (iron_amt >= 12)
					user << "You begin crafting the iron coif and helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft the iron coif."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/medieval/coif_helmet(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Crusader Helmet (15)")
				if (iron_amt >= 15)
					user << "You begin crafting the crusader helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the crusader helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/medieval/crusader(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Knight Helmet (15)")
				if (iron_amt >= 15)
					user << "You begin crafting the knight helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the knight helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/medieval(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Berserker Helmet (15)")
				if (iron_amt >= 15)
					user << "You begin crafting the helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/orc_beserker(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Spearman Helmet (12)")
				if (iron_amt >= 12)
					user << "You begin crafting the helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft the helmet."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/orc_spearman(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Grunt Helmet (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/orc_grunt(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Urukhai Armor (12)")
				if (iron_amt >= 12)
					user << "You begin crafting the armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft the armor."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/suit/armor/ork_urukhai(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Grunt Armor (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the armor."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/suit/armor/ork_grunt(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Orkish Gauntlets (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the gauntlets..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the gauntlets."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/gloves/gauntlets/orc(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Orkish Sabatons (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the sabatons..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the sabatons."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/shoes/orc(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Pickelhaube (7)")
				if (iron_amt >= 7)
					user << "You begin crafting the pickelhaube..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 7)
						user << "You craft the pickelhaube."
						iron_amt -= 7
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/modern/pickelhaube(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Mesh Pickelhaube (7)")
				if (iron_amt >= 7)
					user << "You begin crafting the pickelhaube..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 7)
						user << "You craft the pickelhaube."
						iron_amt -= 7
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/ww/pickelhaube2(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Stahlhelm (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the stahlhelm..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the stahlhelm."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/modern/stahlhelm(user.loc)
						return


			if (choice4 == "Type 92 Helmet (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the type 92..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the type 92."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/ww2/japhelm(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return


			if (choice4 == "M1 Helmet (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the M1..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the M1."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/ww2/usm1(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Soviet Helmet (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the soviet helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the soviet helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/ww2/soviet(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Mk2 Brodie (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the brodie..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the Mk2 Brodie."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/ww/mk2brodieog(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "M26 Adrian (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the M26 Adrian..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the M26 Adrian."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/ww2/adrianm26(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return


			if (choice4 == "Pith (7)")
				if (iron_amt >= 7)
					user << "You begin crafting the pith helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 7)
						user << "You craft the pith helmet."
						iron_amt -= 7
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/modern/pith(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "M15 Adrian Helmet (10)")
				var/list/display5 = list("Cancel")
				if (map.ordinal_age == 5)
					display5 = list("Standard M15 Adrian", "Russian M15 Adrian", "Greek M15 Adrian", "Cancel")
				var/choice5 = WWinput(user, "Which varient?", "Blacksmith - [iron_amt] iron", "Cancel", display5)
				if (choice5 == "Standard M15 Adrian")
					if (iron_amt >= 10)
						user << "You begin crafting the M15 Adrian..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,150,src) && iron_amt >= 10)
							user << "You craft the M15 Adrian."
							iron_amt -= 10
							if (iron_amt <= 0)
								icon_state = "anvil1"
							new/obj/item/clothing/head/helmet/ww/adrian(user.loc)
							return
					else
						user << "<span class='notice'>You need more iron to make this!</span>"
						return
				if (choice5 == "Russian M15 Adrian")
					if (iron_amt >= 10)
						user << "You begin crafting the M15 Adrian..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,150,src) && iron_amt >= 10)
							user << "You craft the M15 Adrian."
							iron_amt -= 10
							if (iron_amt <= 0)
								icon_state = "anvil1"
							new/obj/item/clothing/head/helmet/ww/adriansoviet(user.loc)
							return
					else
						user << "<span class='notice'>You need more iron to make this!</span>"
						return
				if (choice5 == "Greek M15 Adrian")
					if (iron_amt >= 10)
						user << "You begin crafting the M15 Adrian..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,150,src) && iron_amt >= 10)
							user << "You craft the M15 Adrian."
							iron_amt -= 10
							if (iron_amt <= 0)
								icon_state = "anvil1"
							new/obj/item/clothing/head/helmet/ww/adriangreek(user.loc)
							return
					else
						user << "<span class='notice'>You need more iron to make this!</span>"
						return

					if (choice5 == "Cancel")
						return

			if (choice4 == "Mk1 Brodie (10)")
				var/list/display6 = list("Cancel")
				if (map.ordinal_age == 5)
					display6 = list("Mk1 Brodie (Apple Green)", "Mk1 Brodie (Duck Egg Blue)", "Cancel")
				var/choice6 = WWinput(user, "Which varient?", "Blacksmith - [iron_amt] iron", "Cancel", display6)
				if (choice6 == "Mk1 Brodie (Apple Green)")
					if (iron_amt >= 10)
						user << "You begin crafting the Mk1 Brodie..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,150,src) && iron_amt >= 10)
							user << "You craft the Mk1 Brodie."
							iron_amt -= 10
							if (iron_amt <= 0)
								icon_state = "anvil1"
							new/obj/item/clothing/head/helmet/ww/mk1brodieag(user.loc)
							return
					else
						user << "<span class='notice'>You need more iron to make this!</span>"
						return
				if (choice6 == "Mk1 Brodie (Duck Egg Blue)")
					if (iron_amt >= 10)
						user << "You begin crafting the Mk1 Brodie..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,150,src) && iron_amt >= 10)
							user << "You craft the Mk1 Brodie."
							iron_amt -= 10
							if (iron_amt <= 0)
								icon_state = "anvil1"
							new/obj/item/clothing/head/helmet/ww/mk1brodiedeb(user.loc)
							return
					else
						user << "<span class='notice'>You need more iron to make this!</span>"
						return

					if (choice6 == "Cancel")
						return

			//"Modern" Scrap Armor for Ungas
			if (choice4 == "Scrap Helmet (15)")
				if (iron_amt >= 15)
					user << "You begin crafting the scrap metal helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,150,src) && iron_amt >= 15)
						user << "You craft the scrap metal helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/scrap(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Scrap Armor (16)")
				if (iron_amt >= 16)
					user << "You begin crafting the scrap metal armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,150,src) && iron_amt >= 16)
						user << "You craft the scrap metal armor."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/suit/armor/scrap(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

		else if (choice == "Additional Cultural Armor")
			var/list/display7 = list("Cancel")
			if (map.ordinal_age == 0)
				display7 = list("Cancel")
			else if (map.ordinal_age == 2)
				if (H.orc)
					display7 = list("Horned Helmet (10)", "Boss Jaw (7)", "Cancel")
				else
					display7 = list("Varangian Lamellar Armor (12)", "Viking Helmet (10)", "Valkyrie Helmet (10)", "Mamluk Conical Helmet (10)", "Mamluk Coif Helmet(12)", "Arabic Long Helmet (15)", "Varangian Helmet (15)", "Cancel")
			var/choice7 = WWinput(user, "What do you want to make?", "Blacksmith - [iron_amt] iron", "Cancel", display7)
			if (choice7 == "Varangian Lamellar Armor (12)")
				if (iron_amt >= 12)
					user << "You begin crafting the varangian lamellar armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft the varangian lamellar armor."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/suit/armor/medieval/varangian(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice7 == "Horned Helmet (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the horned helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >=10)
						user << "You craft the horned helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/horned(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice7 == "Boss Jaw (7)")
				if (iron_amt >= 7)
					user << "You begin crafting the boss jaw mask..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 7)
						user << "You craft the boss jaw mask."
						iron_amt -= 7
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/mask/bossjaw(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice7 == "Viking Helmet (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the viking helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the viking helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/medieval/viking(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice7 == "Valkyrie Helmet (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the valkyrie helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the valkyrie helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/medieval/viking/valkyrie(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice7 == "Mamluk Conical Helmet (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the mamluk conical helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the mamluk conical helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/medieval/mamluk/helmet(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice7 == "Mamluk Coif Helmet(12)")
				if (iron_amt >= 12)
					user << "You begin crafting the mamluk coif helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft the mamluk coif helmet."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/medieval/mamluk/coif(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice7 == "Arabic Long Helmet (15)")
				if (iron_amt >= 15)
					user << "You begin crafting the arabic long helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the arabic long helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/medieval/nomads/longarab(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice7 == "Varangian Helmet (15)")
				if (iron_amt >= 15)
					user << "You begin crafting the varangian helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the varangian helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/medieval/viking/varangian(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

					if (choice7 == "Cancel")
						return

		else if (choice == "Shields & Tools")
			var/list/display8 = list("Cancel")
			if (map.ordinal_age == 2)
				if (H.orc)
					display8 = list( "Orkish Shield (16)", "Cancel")
				else
					display8 = list("Semi Oval Shield(16)", "Semi Oval Templar Shield(16)", "Cancel")
			else if (map.ordinal_age == 0)
				display8 = list("Cancel")
			else
				display8 = list("Classic Era Standards(10)", "Athenian Aspis Shield(13)", "Spartan Aspis Shield(13)", "Pegasus Aspis Shield(13)", "Owl Aspis Shield(13)", "Egyptian Shield(13)", "Scutum Shield(14)", "Roman Shields(14)", "Cancel")
			var/choice8 = WWinput(user, "What do you want to make?", "Blacksmith - [iron_amt] iron", "Cancel", display8)

			if (choice8 == "Classic Era Standards(10)")
				var/list/display9 = list("Cancel")
				if (map.ordinal_age == 1)
					display9 = list("Roman Standard(10)", "Greek Standard(10)", "Egyptian Standard(10)", "Cancel")
				var/choice9 = WWinput(user, "Which varient?", "Blacksmith - [iron_amt] iron", "Cancel", display9)
				if (choice9 == "Roman Standard(10)")
					if (iron_amt >= 10)
						user << "You begin crafting the roman standard..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,130,src) && iron_amt >= 10)
							user << "You craft the roman standard."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/material/roman_standard(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
				if (choice9 == "Greek Standard(10)")
					if (iron_amt >= 10)
						user << "You begin crafting the greek standard..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,130,src) && iron_amt >= 10)
							user << "You craft the greek standard."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/material/greek_standard(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
				if (choice9 == "Egyptian Standard(10)")
					if (iron_amt >= 10)
						user << "You begin crafting the egyptian standard..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,130,src) && iron_amt >= 10)
							user << "You craft the egyptian standard."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/material/egyptian_standard(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
				if (choice9 == "Cancel")
					return

			if (choice8 == "Athenian Aspis Shield(13)")
				if (iron_amt >= 13)
					user << "You begin crafting the athenian aspis shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 13)
						user << "You craft the athenian aspis shield."
						iron_amt -= 13
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/shield/nomads/aspis(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice8 == "Spartan Aspis Shield(13)")
				if (iron_amt >= 13)
					user << "You begin crafting the spartan aspis shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 13)
						user << "You craft the athenian aspis shield."
						iron_amt -= 13
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/shield/nomads/spartan(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice8 == "Pegasus Aspis Shield(13)")
				if (iron_amt >= 13)
					user << "You begin crafting the pegasus aspis shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 13)
						user << "You craft the pegasus aspis shield."
						iron_amt -= 13
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/shield/nomads/aspis/pegasus(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice8 == "Owl Aspis Shield(13)")
				if (iron_amt >= 13)
					user << "You begin crafting the owl aspis shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 13)
						user << "You craft the owl aspis shield."
						iron_amt -= 13
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/shield/nomads/aspis/owl(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice8 == "Egyptian Shield(13)")
				if (iron_amt >= 13)
					user << "You begin crafting the egyptian shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 13)
						user << "You craft the egyptian shield."
						iron_amt -= 13
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/shield/egyptian(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice8 == "Scutum Shield(14)")
				if (iron_amt >= 14)
					user << "You begin crafting the scutum shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 14)
						user << "You craft the scutum shield."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/shield/scutum(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice8 == "Roman Shields(14)")
				var/list/display10 = list("Cancel")
				if (map.ordinal_age == 1)
					display10 = list("Roman Shield(14)", "Blue Roman Shield(14)", "Praetorian Roman Shield(16)", "Cancel")
				var/choice10 = WWinput(user, "Which varient?", "Blacksmith - [iron_amt] iron", "Cancel", display10)
				if (choice10 == "Roman Shield(14)")
					if (iron_amt >= 14)
						user << "You begin crafting the roman shield..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,160,src) && iron_amt >= 14)
							user << "You craft the roman shield."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/shield/roman(user.loc)
						return
					else
						user << "<span class='notice'>You need more iron to make this!</span>"
						return
				if (choice10 == "Blue Roman Shield(14)")
					if (iron_amt >= 14)
						user << "You begin crafting the roman shield..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,160,src) && iron_amt >= 14)
							user << "You craft the roman shield."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/shield/roman/blue(user.loc)
						return
					else
						user << "<span class='notice'>You need more iron to make this!</span>"
						return
				if (choice10 == "Praetorian Roman Shield(16)")
					if (iron_amt >= 16)
						user << "You begin crafting the praetorian roman shield..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,180,src) && iron_amt >= 16)
							user << "You craft the praetorian roman shield."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/shield/roman/praetorian(user.loc)
						return
					else
						user << "<span class='notice'>You need more iron to make this!</span>"
						return

				if (choice10 == "Cancel")
					return

			if (choice8 == "Semi Oval Shield(16)")
				if (iron_amt >= 16)
					user << "You begin crafting the semi oval shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && iron_amt >= 16)
						user << "You craft the semi oval shield."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/shield/iron/nomads/semioval(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice8 == "Semi Oval Templar Shield(16)")
				if (iron_amt >= 16)
					user << "You begin crafting the semi oval templar shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && iron_amt >= 16)
						user << "You craft the semi oval templar shield."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/shield/iron/nomads/semioval/templar(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice8 == "Orkish Shield (16)")
				if (iron_amt >= 13)
					user << "You begin crafting the orkish shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 13)
						user << "You craft the orkish shield."
						iron_amt -= 13
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/weapon/shield/iron/orc(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice8 == "Cancel")
				return

		else if (choice == "Japanese Armor & Masks")
			var/list/display11 = list("Cancel")
			if (map.ordinal_age == 3)
				display11 = list("Kote Bracer Gauntlets (10)", "Tsuranuki Shinguard Boots (10)", "Metal Samurai Helmet (15)", "Red Metal Samurai Helmet (15)", "Blue Metal Samurai Helmet (15)", "Black Metal Samurai Helmet (15)", "Samurai Mask (8)", "Red Samurai Mask (8)", "Blue Samurai Mask (8)", "Metal Samurai Armor (16)", "Red Metal Samurai Armor (16)", "Blue Metal Samurai Armor (16)", "Black Metal Samurai Armor (16)", "Cancel")
			else if (map.ordinal_age == 0)
				display11 = list("Cancel")
			else if (map.ordinal_age == 2)
				if (H.orc)
					display11 = list("Cancel")
				else
					display11 = list("Kote Bracer Gauntlets (10)", "Tsuranuki Shinguard Boots (10)", "Samurai Helmet (15)", "Red Samurai Helmet (15)", "Blue Samurai Helmet (15)", "Black Samurai Helmet (15)", "Samurai Mask (8)", "Red Samurai Mask (8)", "Blue Samurai Mask (8)", "Metal Samurai Armor (16)", "Red Metal Samurai Armor (16)", "Blue Metal Samurai Armor (16)", "Black Metal Samurai Armor (16)", "Cancel")
			var/choice11 = WWinput(user, "What do you want to make?", "Blacksmith - [iron_amt] iron", "Cancel", display11)
			if (choice11 == "Kote Bracer Gauntlets (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the kote gauntlets..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the kote gauntlets."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/gloves/gauntlets/kote(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice11 == "Tsuranuki Shinguard Boots (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the tsuranuki boots..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the tsuranuki boots."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/shoes/tsuranuki(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if(choice11 == "Samurai Helmet (15)")
				if (iron_amt >= 15)
					user << "You begin crafting the samurai helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the samurai helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/samurai/guard(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if(choice11 == "Red Samurai Helmet (15)")
				if (iron_amt >= 15)
					user << "You begin crafting the samurai helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the samurai helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/samurai/guard/red(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if(choice11 == "Blue Samurai Helmet (15)")
				if (iron_amt >= 15)
					user << "You begin crafting the samurai helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the samurai helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/samurai/guard/blue(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if(choice11 == "Black Samurai Helmet (15)")
				if (iron_amt >= 15)
					user << "You begin crafting the samurai helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the samurai helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/head/helmet/samurai/guard/black(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice11 == "Samurai Mask (8)")
				if (iron_amt >= 8)
					user << "You begin crafting the samurai mask..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 8)
						user << "You craft the samurai mask."
						iron_amt -= 8
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/mask/samurai(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice11 == "Red Samurai Mask (8)")
				if (iron_amt >= 8)
					user << "You begin crafting the samurai mask..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 8)
						user << "You craft the samurai mask."
						iron_amt -= 8
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/mask/samurai/red(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice11 == "Blue Samurai Mask (8)")
				if (iron_amt >= 8)
					user << "You begin crafting the samurai mask..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 8)
						user << "You craft the samurai mask."
						iron_amt -= 8
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/mask/samurai/blue(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice11 == "Metal Samurai Armor (16)")
				if (iron_amt >= 16)
					user << "You begin crafting the samurai armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && iron_amt >= 16)
						user << "You craft the samurai armor."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/suit/armor/samurai(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice11 == "Red Metal Samurai Armor (16)")
				if (iron_amt >= 16)
					user << "You begin crafting the samurai armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && iron_amt >= 16)
						user << "You craft the samurai armor."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/suit/armor/samurai/red(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice11 == "Blue Metal Samurai Armor (16)")
				if (iron_amt >= 16)
					user << "You begin crafting the samurai armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && iron_amt >= 16)
						user << "You craft the samurai armor."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/suit/armor/samurai/blue(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice11 == "Black Metal Samurai Armor (16)")
				if (iron_amt >= 16)
					user << "You begin crafting the samurai armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && iron_amt >= 16)
						user << "You craft the samurai armor."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "anvil1"
						new/obj/item/clothing/suit/armor/samurai/black(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

	else if (iron_amt <= 0 || steel_amt <= 0)
		user << "There is no hot iron or steel on top of this anvil. Smite some first."
		return

/obj/structure/anvil/verb/empty()
	set category = null
	set name = "Empty"
	set src in range(1, usr)

	if (iron_amt > 0)
		var/obj/item/stack/material/iron/emptyediron = new/obj/item/stack/material/iron(src.loc)
		emptyediron.amount = iron_amt
		iron_amt = 0
	if (steel_amt > 0)
		var/obj/item/stack/material/steel/emptyedsteel = new/obj/item/stack/material/steel(src.loc)
		emptyedsteel.amount = steel_amt
		steel_amt = 0
	return
