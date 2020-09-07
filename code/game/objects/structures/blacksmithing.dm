/obj/structure/anvil
	name = "iron anvil"
	desc = "A heavy iron anvil. The blacksmith's main work tool. It has 0 hot iron bars on it."
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "iron_anvil"
	density = TRUE
	anchored = TRUE
	var/iron_amt = 0
	var/bronze_amt = 0
	var/steel_amt = 0
	var/kevlar_amt = 0
	var/base_icon = "iron"
	not_movable = FALSE
	not_disassemblable = TRUE
obj/structure/anvil/New()
	..()
	desc = "A heavy iron anvil. The blacksmith's main work tool. It has [iron_amt] hot iron bars on it."

/obj/structure/anvil/attackby(obj/item/P as obj, mob/user as mob)
	var/mob/living/human/H = user
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
			icon_state = "[base_icon]_anvil_use"
			playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
			if (do_after(user,15*P.amount,src))
				user << "<span class='notice'>You smite the iron.</span>"
				iron_amt += P.amount
				desc = "A heavy iron anvil. The blacksmith's main work tool. It has [iron_amt] hot iron bars on it."
				icon_state = "[base_icon]_anvil_use2"
				qdel(P)
		else if (istype(P, /obj/item/stack/material/iron) && steel_amt > 0)
			user << "<span class='notice'>You can't smelt iron while there is steel on the anvil! Finish the steel first.</span>"
			return
		else if (istype(P, /obj/item/stack/material/steel) && iron_amt == 0 && map.ordinal_age >= 2)
			user << "You begin smithing the steel..."
			icon_state = "[base_icon]_anvil_use"
			playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
			if (do_after(user,15*P.amount,src))
				user << "<span class='notice'>You smite the steel.</span>"
				steel_amt += P.amount
				desc = "A heavy iron anvil. The blacksmith's main work tool. It has [steel_amt] hot steel bars on it."
				icon_state = "[base_icon]_anvil_use2"
				qdel(P)
		else if (istype(P, /obj/item/stack/material/steel) && iron_amt > 0)
			user << "<span class='notice'>You can't smelt steel while there is iron on the anvil! Finish the iron first.</span>"
			return

/obj/structure/anvil/attack_hand(var/mob/user as mob)
	var/mob/living/human/H = user
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
		if (map.ordinal_age == 2)
			display = list("Swords", "Other Weapons", "Arabic Weapons", "Cancel")
		else if (map.ordinal_age == 3)
			display = list("Swords", "Other Weapons", "Arabic Weapons", "Cancel")
		else if (map.ordinal_age == 4)
			display = list("Swords", "Guns", "Other Weapons", "Arabic Weapons", "Cancel")
		else if (map.ordinal_age >= 5)
			display = list("Swords", "Guns", "Other Weapons", "Arabic Weapons", "Cancel")
		else if (map.ordinal_age >= 6)
			display = list("Guns", "Other Weapons", "Arabic Weapons", "Cancel")
		else if (map.ordinal_age >= 7)
			display = list("Guns", "Other Weapons", "Arabic Weapons", "Cancel")
		else if (map.ordinal_age >= 8)
			display = list("Guns", "Other Weapons", "Arabic Weapons", "Cancel")
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
				display2 = list("Small Sword (10)", "Longquan (12)", "Sabre (15)", "Cutlass (12)", "Spadroon (15)", "Rapier (18)", "Longsword (18)", "Katana (15)", "Wakazashi (10)" , "Tanto (5)", "Cancel")
			else if (map.ordinal_age <= 2)
				display2 = list("Small Sword (10)", "Longquan (12)", "Arming Sword (15)", "Katana (15)", "Wakazashi (10)" , "Tanto (5)", "Cancel")
		else if (choice == "Guns")
			if (map.ordinal_age == 4)
				display2 = list("Derringer M95 Pistol (15)", "Colt Peacemaker Revolver (25)", "Winchester Repeater (50)", "Evans Repeater (60)","Henry Repeater (60)", "Coach Gun (22)", "Sharps Rifle (30)","Martini-Henry Rifle (35)", "Gewehr71 (30)", "Cancel")
			if (map.ordinal_age == 8)
				display2 = list("Makeshift AK-47 (32)", "Cancel")
		else if (choice == "Other Weapons")
			if (map.ordinal_age == 8)
				display2 = list("Large Machetes", "Tanto (10)", "Wakazashi (20)", "Katana (30)","Cancel") //x2 rate of inflation on later era samurai weapons
			else if (map.ordinal_age == 7)
				display2 = list("Large Machetes", "Tanto (10)", "Wakazashi (20)", "Katana (30)","Cancel")
			else if (map.ordinal_age == 6)
				display2 = list("Large Machetes", "Tanto (10)", "Wakazashi (20)", "Katana (30)","Cancel")
			else if (map.ordinal_age == 5)
				display2 = list("Large Machetes", "Tanto (10)", "Wakazashi (20)", "Katana (30)","Cancel")
			else if (map.ordinal_age == 4)
				display2 = list("Large Machetes", "Tanto (10)", "Wakazashi (20)", "Katana (30)", "Cancel")
			else if (map.ordinal_age == 3)
				display2 = list("Boarding Axe (8)", "Halberd (14)", "Naginata (16)", "Cancel")
			else if (map.ordinal_age == 2)
				display2 = list("Halberd (14)", "Naginata (16)", "Pike (16)", "Cancel")
			if (H.orc)
				display2 = list("Cancel")
		else if (choice == "Arabic Weapons")
			if (map.ordinal_age == 8)
				display2 = list("Ceremonial Saif (20)", "Ceremonial Scimitar", "Cancel")
			else if (map.ordinal_age == 7)
				display2 = list("Ceremonial Saif (20)", "Ceremonial Scimitar", "Cancel")
			else if (map.ordinal_age == 6)
				display2 = list("Ceremonial Saif (20)", "Ceremonial Scimitar", "Cancel")
			else if (map.ordinal_age == 5)
				display2 = list("Ceremonial Saif (20)", "Ceremonial Scimitar", "Cancel")
			else if (map.ordinal_age == 4)
				display2 = list("Ceremonial Saif (20)", "Scimitar (20)", "Cancel")
			else if (map.ordinal_age == 3)
				display2 = list("Saif (15)", "Scimitar (12)", "Cancel")
			else if (map.ordinal_age == 2)
				display2 = list("Saif (15)", "Scimitar (12)", "Cancel")
			if (H.orc)
				display2 = list("Cancel")
		var/choice2 = WWinput(user, "What do you want to make?", "Blacksmith - [steel_amt] steel", "Cancel", display2)
	/*	else if (choice == "Other")
		if(map.ordinal_age >= 4)
			display2 = list("Steel rods (2)", "Cancel")*/
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
						icon_state = "[base_icon]_anvil"
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
						icon_state = "[base_icon]_anvil"
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
						icon_state = "[base_icon]_anvil"
					new/obj/item/weapon/gun/projectile/boltaction/singleshot/martini_henry(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Winchester Repeater (50)")
			if (steel_amt >= 50)
				user << "You begin crafting a Winchester..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,220,src) && steel_amt >= 50)
					user << "You craft a Winchester."
					steel_amt -= 50
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					new/obj/item/weapon/gun/projectile/leveraction/winchester(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Evans Repeater (60)")
			if (steel_amt >= 65)
				user << "You begin crafting a Evans Repeater..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,220,src) && steel_amt >= 60)
					user << "You craft a Evans Repeater."
					steel_amt -= 60
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					new/obj/item/weapon/gun/projectile/leveraction/evansrepeater(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Henry Repeater (55)")
			if (steel_amt >= 55)
				user << "You begin crafting a Henry Repeater..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,220,src) && steel_amt >= 55)
					user << "You craft a Henry Repeater."
					steel_amt -= 55
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					new/obj/item/weapon/gun/projectile/leveraction/henryrepeater(user.loc)
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
						icon_state = "[base_icon]_anvil"
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
						icon_state = "[base_icon]_anvil"
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
						icon_state = "[base_icon]_anvil"
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
						icon_state = "[base_icon]_anvil"
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
						icon_state = "[base_icon]_anvil"
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
						icon_state = "[base_icon]_anvil"
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
						icon_state = "[base_icon]_anvil"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/cutlass(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Longquan (12)")
			if (steel_amt >= 12)
				user << "You begin crafting a longquan..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,100,src) && steel_amt >= 12)
					user << "You craft a longquan."
					steel_amt -= 12
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/longquan(user.loc)
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
						icon_state = "[base_icon]_anvil"
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
						icon_state = "[base_icon]_anvil"
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
						icon_state = "[base_icon]_anvil"
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
						icon_state = "[base_icon]_anvil"
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
						icon_state = "[base_icon]_anvil"
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
						icon_state = "[base_icon]_anvil"
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
						icon_state = "[base_icon]_anvil"
					var/obj/item/weapon/material/knife/SW = new/obj/item/weapon/material/knife/tanto(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return

/* Additional & Price Inflated Weapons*/

		if (choice2 == "Katana (30)")
			if (steel_amt >= 30)
				user << "You begin crafting a katana..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,280,src) && steel_amt >= 30)
					user << "You craft a katana."
					steel_amt -= 30
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/katana(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return

		if (choice2 == "Wakazashi (20)")
			if (steel_amt >= 20)
				user << "You begin crafting a wakazashi..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,280,src) && steel_amt >= 20)
					user << "You craft a wakazashi."
					steel_amt -= 20
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/wakazashi(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return

		if (choice2 == "Tanto (10)")
			if (steel_amt >= 10)
				user << "You begin crafting a tanto..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,130,src) && steel_amt >= 10)
					user << "You craft a tanto."
					steel_amt -= 10
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					var/obj/item/weapon/material/knife/SW = new/obj/item/weapon/material/knife/tanto(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return

		if (choice2 == "Boarding Axe (8)")
			if (steel_amt >= 8)
				user << "You begin crafting the boarding axe..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,160,src) && steel_amt >= 8)
					user << "You craft the iron kanobo mace."
					steel_amt -= 8
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					new/obj/item/weapon/material/boarding_axe(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return

		if (choice2 == "Halberd (14)")
			if (steel_amt >= 14)
				user << "You begin crafting the halberd..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,130,src) && steel_amt >= 14)
					user << "You craft the halberd."
					steel_amt -= 14
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					new/obj/item/weapon/material/halberd/steel(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Pike (16)")
			if (steel_amt >= 16)
				user << "You begin crafting the pike..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,150,src) && steel_amt >= 16)
					user << "You craft the pike."
				steel_amt -= 16
				if (steel_amt <= 0)
					icon_state = "[base_icon]_anvil"
				new/obj/item/weapon/material/pike/steel(user.loc)
				return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return
		if (choice2 == "Naginata (16)")
			if (steel_amt >= 16)
				user << "You begin crafting the naginata..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,150,src) && steel_amt >= 16)
					user << "You craft the naginata."
				steel_amt -= 16
				if (steel_amt <= 0)
					icon_state = "[base_icon]_anvil"
				new/obj/item/weapon/material/naginata/steel(user.loc)
				return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return

		if (choice2 == "Large Machetes")
			var/list/display3 = list("Cancel")
			if (map.ordinal_age == 4)
				display3 = list("Bolo Machete (12)", "Kukri Machete (12)", "Cancel")//rate of steel inflation +4
			if (map.ordinal_age == 5)
				display3 = list("Bolo Machete (16)", "Kukri Machete (16)", "Cancel")
			if (map.ordinal_age == 6)
				display3 = list("Bolo Machete (16)", "Kukri Machete (16)", "Cancel")
			if (map.ordinal_age == 7)
				display3 = list("Bolo Machete (16)", "Kukri Machete (16)", "Cancel")
			if (map.ordinal_age == 8)
				display3 = list("Bolo Machete (16)", "Kukri Machete (16)", "Cancel")
			var/choice3 = WWinput(user, "Which varient?", "Blacksmith - [steel_amt] steel", "Cancel", display3)
			if (choice3 == "Cancel")
				return

			if (choice3 == "Bolo Machete (12)")
				if (steel_amt >= 12)
					user << "You begin crafting the bolo machete..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && steel_amt >= 12)
						user << "You craft the bolo machete."
					steel_amt -= 12
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					new/obj/item/weapon/material/sword/bolo(user.loc)
					return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return
			if (choice3 == "Kukri Machete (12)")
				if (steel_amt >= 12)
					user << "You begin crafting the kukri machete..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && steel_amt >= 12)
						user << "You craft the kukri machete."
					steel_amt -= 12
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					new/obj/item/weapon/material/sword/kukri(user.loc)
					return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return
			if (choice3 == "Bolo Machete (16)")
				if (steel_amt >= 16)
					user << "You begin crafting the bolo machete..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && steel_amt >= 16)
						user << "You craft the bolo machete."
					steel_amt -= 16
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					new/obj/item/weapon/material/sword/bolo(user.loc)
					return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return
			if (choice3 == "Kukri Machete (16)")
				if (steel_amt >= 16)
					user << "You begin crafting the kukri machete..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && steel_amt >= 16)
						user << "You craft the kukri machete."
					steel_amt -= 16
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					new/obj/item/weapon/material/sword/kukri(user.loc)
					return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

		if (choice2 == "Large Knives")
			var/list/display4 = list("Cancel")
			if (map.ordinal_age == 4)
				display4 = list("Bowie Knife (8)", "Cancel")
			if (map.ordinal_age == 5)
				display4 = list("Bowie Knife (8)", "Trench Knife (10)", "Cancel")
			if (map.ordinal_age == 6)
				display4 = list("Bowie Knife (8)", "Trench Knife (10)", "Military Knife (14)", "Cancel")
			if (map.ordinal_age == 7)
				display4 = list("Bowie Knife (12)", "Trench Knife (14)", "Military Knife (18)", "Cancel") //rate of steel inflation +4
			if (map.ordinal_age == 8)
				display4 = list("Bowie Knife (12)", "Military Knife (18)","Cancel")
			var/choice4 = WWinput(user, "Which varient?", "Blacksmith - [steel_amt] steel", "Cancel", display4)
			if (choice4 == "Cancel")
				return

			if (choice4 == "Bowie Knife (8)")
				if (steel_amt >= 8)
					user << "You begin crafting the bowie knife..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && steel_amt >= 8)
						user << "You craft the bowie knife."
					iron_amt -= 8
					if (iron_amt <= 0)
						icon_state = "[base_icon]_anvil"
					new/obj/item/weapon/material/kitchen/utensil/knife/bowie(user.loc)
					return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return
			if (choice4 == "Trench Knife (10)")
				if (steel_amt >= 10)
					user << "You begin crafting the trench knife..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && steel_amt >= 10)
						user << "You craft the trench knife."
					steel_amt -= 10
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					new/obj/item/weapon/material/kitchen/utensil/knife/trench(user.loc)
					return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return
			if (choice4 == "Military Knife (14)")
				if (steel_amt >= 14)
					user << "You begin crafting the military knife..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && iron_amt >= 14)
						user << "You craft the miltiary knife."
					iron_amt -= 14
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					new/obj/item/weapon/material/kitchen/utensil/knife/military(user.loc)
					return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return
			if (choice4 == "Bowie Knife (12)")
				if (steel_amt >= 12)
					user << "You begin crafting the bowie knife..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && steel_amt >= 12)
						user << "You craft the bowie knife."
					steel_amt -= 12
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					new/obj/item/weapon/material/kitchen/utensil/knife/bowie(user.loc)
					return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return
			if (choice4 == "Trench Knife (14)")
				if (steel_amt >= 10)
					user << "You begin crafting the trench knife..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && steel_amt >= 10)
						user << "You craft the trench knife."
					steel_amt -= 10
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					new/obj/item/weapon/material/kitchen/utensil/knife/trench(user.loc)
					return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return
			if (choice4 == "Military Knife (18)")
				if (steel_amt >= 18)
					user << "You begin crafting the military knife..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && steel_amt >= 18)
						user << "You craft the miltiary knife."
					steel_amt -= 18
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					new/obj/item/weapon/material/kitchen/utensil/knife/military(user.loc)
					return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return


/* Arabic Weapons & Ceremonial Price inflated weapons*/

		if (choice2 == "Scimitar (12)")
			if (steel_amt >= 12)
				user << "You begin crafting a scimitar..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,130,src) && steel_amt >= 12)
					user << "You craft a scimitar."
					steel_amt -= 12
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/scimitar(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return

		if (choice2 == "Saif (15)")
			if (steel_amt >= 5)
				user << "You begin crafting a saif..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,130,src) && steel_amt >= 15)
					user << "You craft a saif."
					steel_amt -= 15
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/saif(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return

		if (choice2 == "Scimitar (20)") //price inflated by +8
			if (steel_amt >= 20)
				user << "You begin crafting a scimitar..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,130,src) && steel_amt >= 20)
					user << "You craft a scimitar."
					steel_amt -= 20
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/scimitar(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return

		if (choice2 == "Ceremonial Saif (20)")
			if (steel_amt >= 20)
				user << "You begin crafting a ceremonial saif..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,130,src) && steel_amt >= 20)
					user << "You craft a ceremonial saif."
					steel_amt -= 20
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/arabsword(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return

		if (choice2 == "Ceremonial Scimitar (23)")
			if (steel_amt >= 23)
				user << "You begin crafting a scimitar..."
				playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
				if (do_after(user,130,src) && steel_amt >= 23)
					user << "You craft a scimitar."
					steel_amt -= 23
					if (steel_amt <= 0)
						icon_state = "[base_icon]_anvil"
					var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/arabsword2(user.loc)
					SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
					SW.health = SW.maxhealth
					SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
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
						icon_state = "[base_icon]_anvil"
					new/obj/item/stack/material/steelrods(user.loc)
					new/obj/item/stack/material/steelrods(user.loc)
					return
			else
				user << "<span class='notice'>You need more steel to make this!</span>"
				return*/
//iron smelting stuff.  //anvil timing list (8 iron 100 or less || <10 metal = 130 || <13 - 15 = 160 || 16 - 17 = 180 || 18 - 20 = 200 || 21 - 30 = 250)
	else if (iron_amt > 0)
		var/list/display = list("Swords", "Other Weapons", "Cancel")
		if (map.ordinal_age == 3)
			display = list("Swords","Guns", "Other Weapons", "Arabic Weapons", "Cancel")
		else if (map.ordinal_age == 2)
			display = list("Swords", "Shields & Tools", "Other Weapons", "Arabic Weapons", "Cancel")
		else
			display = list("Swords", "Shields & Tools", "Cancel")
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
							icon_state = "[base_icon]_anvil"
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
							icon_state = "[base_icon]_anvil"
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
							icon_state = "[base_icon]_anvil"
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
							icon_state = "[base_icon]_anvil"
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
							icon_state = "[base_icon]_anvil"
						var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/cutlass/iron(user.loc)
						SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
						SW.health = SW.maxhealth
						SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice2 == "Longquan (12)")
				if (iron_amt >= 12)
					user << "You begin crafting a longquan..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft a longquan."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/longquan/iron(user.loc)
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
							icon_state = "[base_icon]_anvil"
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
							icon_state = "[base_icon]_anvil"
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
							icon_state = "[base_icon]_anvil"
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
							icon_state = "[base_icon]_anvil"
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
							icon_state = "[base_icon]_anvil"
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
							icon_state = "[base_icon]_anvil"
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
							icon_state = "[base_icon]_anvil"
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
							icon_state = "[base_icon]_anvil"
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
							icon_state = "[base_icon]_anvil"
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
							icon_state = "[base_icon]_anvil"
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
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/gun/projectile/flintlock/pistol(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice3 == "Cancel")
				return


		else if (choice == "Shields & Tools")
			var/list/display4 = list("Cancel")
			if (map.ordinal_age == 2)
				if (H.orc)
					display4 = list( "Orkish Shield (16)", "Cancel")
				else
					display4 = list("Semi Oval Shield(16)", "Semi Oval Templar Shield(16)", "Cancel")
			else if (map.ordinal_age == 0)
				display4 = list("Cancel")
			else
				display4 = list("Classic Era Standards(10)", "Athenian Aspis Shield(13)", "Spartan Aspis Shield(13)", "Pegasus Aspis Shield(13)", "Owl Aspis Shield(13)", "Egyptian Shield(13)", "Scutum Shield(14)", "Roman Shields(14)", "Cancel")
			var/choice4 = WWinput(user, "What do you want to make?", "Blacksmith - [iron_amt] iron", "Cancel", display4)

			if (choice4 == "Classic Era Standards(10)")
				var/list/display5 = list("Cancel")
				if (map.ordinal_age == 1)
					display5 = list("Roman Standard(10)", "Greek Standard(10)", "Egyptian Standard(10)", "Cancel")
				var/choice5 = WWinput(user, "Which varient?", "Blacksmith - [iron_amt] iron", "Cancel", display5)

				if (choice5 == "Roman Standard(10)")
					if (iron_amt >= 10)
						user << "You begin crafting the roman standard..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,130,src) && iron_amt >= 10)
							user << "You craft the roman standard."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/material/roman_standard(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
				if (choice5 == "Greek Standard(10)")
					if (iron_amt >= 10)
						user << "You begin crafting the greek standard..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,130,src) && iron_amt >= 10)
							user << "You craft the greek standard."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/material/greek_standard(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
				if (choice5 == "Egyptian Standard(10)")
					if (iron_amt >= 10)
						user << "You begin crafting the egyptian standard..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,130,src) && iron_amt >= 10)
							user << "You craft the egyptian standard."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/material/egyptian_standard(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

				if (choice5 == "Cancel")
					return

			if (choice4 == "Athenian Aspis Shield(13)")
				if (iron_amt >= 13)
					user << "You begin crafting the athenian aspis shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 13)
						user << "You craft the athenian aspis shield."
						iron_amt -= 13
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/shield/nomads/aspis(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Spartan Aspis Shield(13)")
				if (iron_amt >= 13)
					user << "You begin crafting the spartan aspis shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 13)
						user << "You craft the athenian aspis shield."
						iron_amt -= 13
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/shield/nomads/spartan(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Pegasus Aspis Shield(13)")
				if (iron_amt >= 13)
					user << "You begin crafting the pegasus aspis shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 13)
						user << "You craft the pegasus aspis shield."
						iron_amt -= 13
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/shield/nomads/aspis/pegasus(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Owl Aspis Shield(13)")
				if (iron_amt >= 13)
					user << "You begin crafting the owl aspis shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 13)
						user << "You craft the owl aspis shield."
						iron_amt -= 13
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/shield/nomads/aspis/owl(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Egyptian Shield(13)")
				if (iron_amt >= 13)
					user << "You begin crafting the egyptian shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 13)
						user << "You craft the egyptian shield."
						iron_amt -= 13
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/shield/egyptian(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Scutum Shield(14)")
				if (iron_amt >= 14)
					user << "You begin crafting the scutum shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 14)
						user << "You craft the scutum shield."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/shield/scutum(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Roman Shields(14)")
				var/list/display6 = list("Cancel")
				if (map.ordinal_age == 1)
					display6 = list("Roman Shield(14)", "Blue Roman Shield(14)", "Praetorian Roman Shield(16)", "Cancel")
				var/choice6 = WWinput(user, "Which varient?", "Blacksmith - [iron_amt] iron", "Cancel", display6)
				if (choice6 == "Roman Shield(14)")
					if (iron_amt >= 14)
						user << "You begin crafting the roman shield..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,160,src) && iron_amt >= 14)
							user << "You craft the roman shield."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/shield/roman(user.loc)
						return
					else
						user << "<span class='notice'>You need more iron to make this!</span>"
						return
				if (choice6 == "Blue Roman Shield(14)")
					if (iron_amt >= 14)
						user << "You begin crafting the roman shield..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,160,src) && iron_amt >= 14)
							user << "You craft the roman shield."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/shield/roman/blue(user.loc)
						return
					else
						user << "<span class='notice'>You need more iron to make this!</span>"
						return
				if (choice6 == "Praetorian Roman Shield(16)")
					if (iron_amt >= 16)
						user << "You begin crafting the praetorian roman shield..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,180,src) && iron_amt >= 16)
							user << "You craft the praetorian roman shield."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/shield/roman/praetorian(user.loc)
						return
					else
						user << "<span class='notice'>You need more iron to make this!</span>"
						return

				if (choice6 == "Cancel")
					return

			if (choice4 == "Semi Oval Shield(16)")
				if (iron_amt >= 16)
					user << "You begin crafting the semi oval shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && iron_amt >= 16)
						user << "You craft the semi oval shield."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/shield/iron/nomads/semioval(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Semi Oval Templar Shield(16)")
				if (iron_amt >= 16)
					user << "You begin crafting the semi oval templar shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && iron_amt >= 16)
						user << "You craft the semi oval templar shield."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/shield/iron/nomads/semioval/templar(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Orkish Shield (16)")
				if (iron_amt >= 13)
					user << "You begin crafting the orkish shield..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 13)
						user << "You craft the orkish shield."
						iron_amt -= 13
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/shield/iron/orc(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

		else if (choice == "Other Weapons")
			var/list/display7 = list("Cancel")
			if (map.ordinal_age == 8)
				display7 = list("Large Machetes", "Large Knives", "Cancel")
			if (map.ordinal_age == 7)
				display7 = list("Large Machetes", "Large Knives", "Cancel")
			if (map.ordinal_age == 6)
				display7 = list("Large Machetes", "Large Knives", "Cancel")
			if (map.ordinal_age == 5)
				display7 = list("Large Machetes", "Large Knives", "Cancel")
			if (map.ordinal_age == 4)
				display7 = list("Large Machetes", "Large Knives", "Cancel")
			else if (map.ordinal_age == 3)
				display7 = list("Halberd (10)", "Naginata (15)", "Iron Whaling Harpoon (15)", "Cancel")
			else if (map.ordinal_age == 2)
				display7 = list("Halberd (10)", "Pike (12)", "Naginata (15)", "Cancel")
			if (H.orc)
				display7 = list("Pike (12)", "Iron Mace (12)", "Cancel")
			var/choice7 = WWinput(user, "What do you want to make?", "Blacksmith - [iron_amt] iron", "Cancel", display7)
			if (choice7 == "Cancel")
				return

			if (choice7 == "Naginata (15)")
				if (iron_amt >= 15)
					user << "You begin crafting the naginata..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 15)
						user << "You craft the naginata."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/material/naginata(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice7 == "Halberd (10)")
				if (iron_amt >= 10)
					user << "You begin crafting the halberd..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 10)
						user << "You craft the halberd."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/material/halberd(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice7 == "Pike (12)")
				if (iron_amt >= 12)
					user << "You begin crafting the pike..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft the halberd."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/material/pike(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice7 == "Large Machetes")
				var/list/display8 = list("Cancel")
				if (map.ordinal_age == 4)
					display8 = list("Cancel")
				if (map.ordinal_age == 5)
					display8 = list("Cancel")
				if (map.ordinal_age == 6)
					display8 = list("Cancel")
				if (map.ordinal_age == 7)
					display8 = list("Cancel")
				if (map.ordinal_age == 8)
					display8 = list("Cancel")
				var/choice8 = WWinput(user, "Which varient?", "Blacksmith - [iron_amt] iron", "Cancel", display8)
				if (choice8 == "Cancel")
					return

				if (choice8 == "Bolo Machete (12)")
					if (iron_amt >= 12)
						user << "You begin crafting the bolo machete..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,160,src) && iron_amt >= 12)
							user << "You craft the bolo machete."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/material/sword/bolo/iron(user.loc)
						return
					else
						user << "<span class='notice'>You need more iron to make this!</span>"
						return
				if (choice8 == "Kukri Machete (12)")
					if (iron_amt >= 12)
						user << "You begin crafting the kukri machete..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,180,src) && iron_amt >= 12)
							user << "You craft the kukri machete."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/material/sword/kukri/iron(user.loc)
						return
					else
						user << "<span class='notice'>You need more iron to make this!</span>"
						return

			if (choice7 == "Large Knives")
				var/list/display9 = list("Cancel")
				if (map.ordinal_age == 4)
					display9 = list("Bowie Knife (8)", "Cancel")
				if (map.ordinal_age == 5)
					display9 = list("Bowie Knife (8)", "Trench Knife (10)", "Cancel")
				if (map.ordinal_age == 6)
					display9 = list("Bowie Knife (8)", "Trench Knife (10)", "Military Knife (14)", "Cancel")
				if (map.ordinal_age == 7)
					display9 = list("Bowie Knife (8)", "Military Knife (14)", "Cancel")
				if (map.ordinal_age == 8)
					display9 = list("Bowie Knife (8)", "Military Knife (14)", "Cancel")
				var/choice9 = WWinput(user, "Which varient?", "Blacksmith - [iron_amt] iron", "Cancel", display9)
				if (choice9 == "Cancel")
					return

				if (choice9 == "Bowie Knife (8)")
					if (iron_amt >= 8)
						user << "You begin crafting the bowie knife..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,100,src) && iron_amt >= 8)
							user << "You craft the bowie knife."
						iron_amt -= 8
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/material/kitchen/utensil/knife/bowie/iron(user.loc)
						return
					else
						user << "<span class='notice'>You need more iron to make this!</span>"
						return
				if (choice9 == "Trench Knife (10)")
					if (iron_amt >= 10)
						user << "You begin crafting the trench knife..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,100,src) && iron_amt >= 10)
							user << "You craft the trench knife."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/material/kitchen/utensil/knife/trench/iron(user.loc)
						return
					else
						user << "<span class='notice'>You need more iron to make this!</span>"
						return
				if (choice9 == "Military Knife (14)")
					if (iron_amt >= 14)
						user << "You begin crafting the military knife..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,180,src) && iron_amt >= 14)
							user << "You craft the miltiary knife."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/material/kitchen/utensil/knife/military/iron(user.loc)
						return
					else
						user << "<span class='notice'>You need more iron to make this!</span>"
						return

			if (choice7 == "Iron Whaling Harpoon (15)")
				if (iron_amt >= 15)
					user << "You begin crafting the whaling harpoon..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,210,src) && iron_amt >= 15)
						user << "You craft the whaling harpoon."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						new/obj/item/weapon/material/harpoon/iron(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

		else if (choice == "Arabic Weapons")
			var/list/display10 = list("Cancel")
			if (map.ordinal_age == 3)
				display10 = list("Saif (15)", "Scimitar (12)", "Cancel")
			else if (map.ordinal_age == 2)
				display10 = list("Saif (15)", "Scimitar (12)", "Cancel")
			if (H.orc)
				display10 = list("Cancel")
			var/choice10 = WWinput(user, "What do you want to make?", "Blacksmith - [iron_amt] iron", "Cancel", display10)
			if (choice10 == "Cancel")
				return

			if (choice10 == "Scimitar (12)")
				if (iron_amt >= 12)
					user << "You begin crafting a scimitar..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft a scimitar."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/scimitar/iron(user.loc)
						SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
						SW.health = SW.maxhealth
						SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
						return
					else
						user << "<span class='notice'>You need more iron to make this!</span>"
						return

			if (choice10 == "Saif (15)")
				if (iron_amt >= 15)
					user << "You begin crafting a saif..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 15)
						user << "You craft a saif."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "[base_icon]_anvil"
						var/obj/item/weapon/material/sword/SW = new/obj/item/weapon/material/sword/saif/iron(user.loc)
						SW.maxhealth = SW.maxhealth*(H.getStatCoeff("Crafting")/2.2)
						SW.health = SW.maxhealth
						SW.crafting_quality = H.getStatCoeff("Crafting")/2.2
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
	if (bronze_amt > 0)
		var/obj/item/stack/material/bronze/emptyedbronze = new/obj/item/stack/material/bronze(src.loc)
		emptyedbronze.amount = bronze_amt
		bronze_amt = 0
	if (kevlar_amt > 0)
		var/obj/item/stack/material/kevlar/emptyedkevlar = new/obj/item/stack/material/kevlar(src.loc)
		emptyedkevlar.amount = kevlar_amt
		kevlar_amt = 0
	return

/* Armorbench*/

/obj/structure/anvil/armorbench
	name = "armorsmithing bench"
	desc = "A large wooden workbench. The armorsmith's main work tool. It has 0 iron and 0 bronze on it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "armorbench"
	density = TRUE
	anchored = TRUE
	bronze_amt = 0
	iron_amt = 0
	not_movable = FALSE
	not_disassemblable = FALSE
/obj/structure/anvil/armorbench/New()
	..()
	desc = "A large wooden workbench. The armorsmith's main work tool. It has [iron_amt] iron and [bronze_amt] bronze on it."

/obj/structure/anvil/armorbench/attackby(obj/item/P as obj, mob/user as mob)
	var/mob/living/human/H = user
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
		if (istype(P, /obj/item/stack/material/iron) && bronze_amt == 0)
			user << "You begin smiting the iron..."
			icon_state = "armorbench2"
			playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
			if (do_after(user,15*P.amount,src))
				user << "<span class='notice'>You smite the iron.</span>"
				iron_amt += P.amount
				desc = "A large wooden workbench. The armorsmith's main work tool. It has [iron_amt] iron on it."
				icon_state = "armorbench2"
				qdel(P)
		else if (istype(P, /obj/item/stack/material/iron) && bronze_amt > 0)
			user << "<span class='notice'>You can't work iron while there is bronze on the anvil! Finish the bronze first.</span>"
			return
		else if (istype(P, /obj/item/stack/material/bronze) && iron_amt == 0)
			user << "You begin smiting the steel..."
			icon_state = "armorbench1"
			playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
			if (do_after(user,15*P.amount,src))
				user << "<span class='notice'>You smite the bronze.</span>"
				bronze_amt += P.amount
				desc = "A large wooden workbench. The armorsmith's main work tool. It has [bronze_amt] bronze on it."
				icon_state = "armorbench1"
				qdel(P)
		else if (istype(P, /obj/item/stack/material/bronze) && iron_amt > 0)
			user << "<span class='notice'>You can't work bronze while there is iron on the bench! Finish the iron first.</span>"
			return
//timing list (8 metal = 100 or less || <10 metal = 130 || <13 - 15 = 160 || 16 - 17 = 180 || 18 - 20 = 200 || 21 - 30 = 250)

/obj/structure/anvil/armorbench/attack_hand(var/mob/user as mob)
	var/mob/living/human/H = user
	if (H.getStatCoeff("crafting") < 1.7)
		user << "You don't have the skills to use this."
		return
	if (!map.civilizations && map.ID != MAP_TRIBES && (user.original_job_title != "Blacksmith" && user.original_job_title != "Pioneer Blacksmith" && user.original_job_title != "Town Blacksmith" && user.original_job_title != "Ferreiro" && user.original_job_title != "Ferrero" && user.original_job_title != "Grofsmid" && user.original_job_title != "Forgeron" && user.original_job_title != "British Blacksmith" && user.original_job_title != "Marooned Pirate Crew" && user.original_job_title != "Schmied"))
		user << "You don't have the skills to use this. Ask a blacksmith."
		return
	if (map.ID == MAP_TRIBES && (H.gorillaman || H.ant || H.wolfman || H.lizard || H.crab))
		user << "You don't know how to use this."
		return
	else if (bronze_amt > 0)
		var/list/displaybronze = list("Cancel")
		if (map.ordinal_age == 1)
			displaybronze = list("Bronze Armor", "Bronze Helmets","Cancel")
		else if (map.ordinal_age == 2)
			displaybronze = list("Cancel")
		else if (map.ordinal_age == 3)
			displaybronze = list("Bronze Helmets", "Cancel")
		else if (map.ordinal_age == 4)
			displaybronze = list("Cancel")
		else if (map.ordinal_age >= 5)
			displaybronze = list("Cancel")
		else if (map.ordinal_age >= 6)
			displaybronze = list("Cancel")
		else if (map.ordinal_age >= 7)
			displaybronze = list("Cancel")
		else if (map.ordinal_age >= 8)
			displaybronze = list("Cancel")
		else if (map.ordinal_age == 0)
			displaybronze = list("Cancel")
		var/choice = WWinput(user, "What do you want to make?", "Blacksmith - [bronze_amt] bronze", "Cancel", displaybronze)
		if (choice == "Cancel")
			return

		else if (choice == "Bronze Armor")
			var/list/display2 = list("Cancel")
			if (map.ordinal_age == 8)
				display2 = list("Cancel")
			else if (map.ordinal_age == 6)
				display2 = list("Cancel")
			else if (map.ordinal_age == 5)
				display2 = list("Cancel")
			else if (map.ordinal_age == 4)
				display2 = list("Cancel")
			else if (map.ordinal_age == 3)
				display2 = list("Cancel")
			else if (map.ordinal_age == 1)
				display2 = list("Egyptian Lamellar Armor (8 Bronze)", "Chinese Lamellar Armor (8 Bronze)", "Cancel")
			else if (map.ordinal_age == 0)
				display2 = list("Cancel")
			else if (map.ordinal_age == 2)
				if (H.orc)
					display2 = list("Cancel")
				else
					display2 = list("Cancel")
			var/choice2 = WWinput(user, "What do you want to make?", "Blacksmith - [bronze_amt] bronze", "Cancel", display2)

			if (choice2 == "Egyptian Lamellar Armor (8 Bronze)")
				if (bronze_amt >= 8)
					user << "You begin crafting the egyptian lamellar armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && bronze_amt >= 8)
						user << "You craft the egyptian lamellar armor."
						bronze_amt -= 8
						if (bronze_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/ancient/bronze_lamellar(user.loc)
						return
				else
					user << "<span class='notice'>You need more bronze to make this!</span>"
					return
			if (choice2 == "Chinese Lamellar Armor (8 Bronze)")
				if (bronze_amt >= 8)
					user << "You begin crafting the chinese lamellar armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && bronze_amt >= 8)
						user << "You craft the chinese lamellar armor."
						bronze_amt -= 8
						if (bronze_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/ancient/bronze_lamellar/chinese(user.loc)
						return
				else
					user << "<span class='notice'>You need more bronze to make this!</span>"
					return


		else if (choice == "Bronze Helmets")
			var/list/display3 = list("Cancel")
			if (map.ordinal_age == 8)
				display3 = list("Cancel")
			else if (map.ordinal_age == 6)
				display3 = list("Cancel")
			else if (map.ordinal_age == 5)
				display3 = list("Cancel")
			else if (map.ordinal_age == 4)
				display3 = list("Cancel")
			else if (map.ordinal_age == 3)
				display3 = list("Dragoon Helmet (7 Bronze)", "Cancel")
			else if (map.ordinal_age == 1)
				display3 = list("Gladiator Helmet (10 Bronze)", "Chinese Warrior Helmet (10 Bronze)", "Greek Helmet (10 Bronze)", "Dimoerites helmet (14 Bronze)", "Lochagos helmet (14 Bronze)", "Anax helmet (18 Bronze)", "Egyptian War Headdress (11 Bronze)", "Cancel")
			else if (map.ordinal_age == 0)
				display3 = list("Cancel")
			else if (map.ordinal_age == 2)
				if (H.orc)
					display3 = list("Cancel")
				else
					display3 = list("Cancel")
			var/choice3 = WWinput(user, "What do you want to make?", "Blacksmith - [bronze_amt] bronze", "Cancel", display3)
			if (choice3 == "Dragoon Helmet (7 Bronze)")
				if (bronze_amt >= 7)
					user << "You begin crafting the gladiator helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && bronze_amt >= 7)
						user << "You craft the dragoon helmet."
						bronze_amt -= 7
						if (bronze_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/napoleonic/dragoon(user.loc)
						return
				else
					user << "<span class='notice'>You need more bronze to make this!</span>"
					return

			if (choice3 == "Gladiator Helmet (10 Bronze)")
				if (bronze_amt >= 10)
					user << "You begin crafting the gladiator helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && bronze_amt >= 10)
						user << "You craft the gladiator helmet."
						bronze_amt -= 10
						if (bronze_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/gladiator/nomads(user.loc)
						return
				else
					user << "<span class='notice'>You need more bronze to make this!</span>"
					return
			if (choice3 == "Chinese Warrior Helmet (10 Bronze)")
				if (bronze_amt >= 10)
					user << "You begin crafting the chinese warrior helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && bronze_amt >= 10)
						user << "You craft the chinese warrior helmet."
						bronze_amt -= 10
						if (bronze_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/chinese_warrior(user.loc)
						return
				else
					user << "<span class='notice'>You need more bronze to make this!</span>"
					return

			if (choice3 == "Greek Helmet (10 Bronze)")
				if (bronze_amt >= 10)
					user << "You begin crafting the greek helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && bronze_amt >= 10)
						user << "You craft the greek helmet."
						bronze_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/greek/nomads(user.loc)
						return
				else
					user << "<span class='notice'>You need more bronze to make this!</span>"
					return
			if (choice3 == "Dimoerites helmet (14 Bronze)")
				if (bronze_amt >= 14)
					user << "You begin crafting the dimoerites helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && bronze_amt >= 14)
						user << "You craft the dimoerites helmet."
						bronze_amt -= 14
						if (bronze_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/greek_sl/nomads(user.loc)
						return
				else
					user << "<span class='notice'>You need more bronze to make this!</span>"
					return
			if (choice3 == "Lochagos helmet (14 Bronze)")
				if (bronze_amt >= 14)
					user << "You begin crafting the lochagos helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && bronze_amt >= 14)
						user << "You craft the lochagos helmet."
						bronze_amt -= 14
						if (bronze_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/greek_commander/nomads(user.loc)
						return
				else
					user << "<span class='notice'>You need more bronze to make this!</span>"
					return
			if (choice3 == "Anax helmet (18 Bronze)")
				if (bronze_amt >= 18)
					user << "You begin crafting the anax helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,200,src) && bronze_amt >= 18)
						user << "You craft the anax helmet."
						bronze_amt -= 18
						if (bronze_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/anax(user.loc)
						return
				else
					user << "<span class='notice'>You need more bronze to make this!</span>"
					return

			if (choice3 == "Egyptian War Headdress (11 Bronze)")
				if (bronze_amt >= 11)
					user << "You begin crafting the egyptian war headdress..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && bronze_amt >= 11)
						user << "You craft the egyptian war headdress."
						bronze_amt -= 11
						if (bronze_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/egyptian/nomads(user.loc)
						return
				else
					user << "<span class='notice'>You need more bronze to make this!</span>"
					return

	else if (iron_amt > 0)
		var/list/displayiron = list("Cancel")
		if (map.ordinal_age == 1)
			displayiron = list("Iron Armor", "Iron Helmets", "Cancel")
		else if (map.ordinal_age == 2)
			displayiron = list("Iron Armor", "Iron Helmets", "Additional Armor", "Japanese Armor & Masks", "Cancel")
		else if (map.ordinal_age == 3)
			displayiron = list("Iron Armor", "Iron Helmets", "Additional Armor", "Japanese Armor & Masks", "Cancel")
		else if (map.ordinal_age == 4)
			displayiron = list("Iron Helmets", "Cancel")
		else if (map.ordinal_age >= 8)
			displayiron = list("Iron Armor & Helmets", "Cancel")
		else if (map.ordinal_age == 0)
			displayiron = list("Cancel")
		var/choice = WWinput(user, "What do you want to make?", "Blacksmith - [iron_amt] iron", "Cancel", displayiron)
		if (choice == "Cancel")
			return

		else if (choice == "Iron Helmets")
			var/list/display4 = list("Cancel")
			if (map.ordinal_age == 8)
				display4 = list("Scrap Helmet (15 iron)", "Cancel")
			else if (map.ordinal_age == 4)
				display4 = list("Picklehaube (7 Iron)", "Pith (7 Iron)", "Cancel")
			else if (map.ordinal_age == 3)
				display4 = list("Conical Helmet (6 Iron)", "Protective Conical Helmet (10 Iron)", "Morion Helmet (10 Iron)", "Cancel")
			else if (map.ordinal_age == 1)
				display4 = list("Roman Helmet (10 Iron)", "Centurion Helmet (14 Iron)", "Decurion Helmet (14 Iron)", "Sol Invictus Helmet (18 Iron)", "Horned Helmet (10 Iron)", "Winged Helmet (10 Iron)", "Conspicious Gaelic Helmet (14 Iron)", "Cancel")
			else if (map.ordinal_age == 0)
				display4 = list("Cancel")
			else if (map.ordinal_age == 2)
				if (H.orc)
					display4 = list("Grunt Helmet (10 Iron)", "Spearman Helmet (12 Iron)", "Berserker Helmet (15 Iron)", "Cancel")
				else
					display4 = list("Conical Helmet (6 Iron)", "Kettle Helmet (8 Iron)", "Protective Conical Helmet (10 Iron)", "Sallet Helmets (12 Iron)", "Coif and Helmet (12 Iron)", "Crusader Helmet (15 Iron)", "Knight Helmet (15)", "Hounskull Bascinet (15 Iron)", "Cancel")
			var/choice4 = WWinput(user, "What do you want to make?", "Blacksmith - [iron_amt] iron", "Cancel", display4)

			if (choice4 == "Roman Helmet (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the roman helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the roman helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/roman/nomads(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Centurion Helmet (14 Iron)")
				if (iron_amt >= 14)
					user << "You begin crafting the centurion helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 14)
						user << "You craft the centurion helmet."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/roman_centurion/nomads(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Decurion Helmet (14 Iron)")
				if (iron_amt >= 14)
					user << "You begin crafting the decurion helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 14)
						user << "You craft the decurion helmet."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/roman_decurion/nomads(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Sol Invictus Helmet (18 Iron)")
				if (iron_amt >= 18)
					user << "You begin crafting the sol invictus helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,200,src) && iron_amt >= 18)
						user << "You craft the sol invictus helmet."
						iron_amt -= 18
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/solinvictus(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Horned Helmet (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the horned helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the horned helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/horned(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Winged Helmet (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the horned helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the horned helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/horned(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Conspicious Gaelic Helmet (14 Iron)")
				if (iron_amt >= 14)
					user << "You begin crafting the gaelic helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 14)
						user << "You craft the gaelic helmet."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/asterix/conspicious(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Conical Helmet (6 Iron)")
				if (iron_amt >= 6)
					user << "You begin crafting the conical helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 6)
						user << "You craft the conical helmet."
						iron_amt -= 6
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/medieval/helmet3(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Kettle Helmet (8 Iron)")
				if (iron_amt >= 8)
					user << "You begin crafting the kettle helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 8)
						user << "You craft the kettle helmet."
						iron_amt -= 8
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/medieval/helmet2(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Protective Conical Helmet (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the protective conical helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the protective conical helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/medieval/helmet1(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Sallet Helmets (12 Iron)")
				var/list/display5 = list("Cancel")
				if (map.ordinal_age == 2)
					display5 = list("Italian Sallet Helmet (12 Iron)", "German Sallet Helmet (12 Iron)", "Burgundian Sallet Helmet (12)", "Cancel")
				var/choice5 = WWinput(user, "Which varient?", "Blacksmith - [iron_amt] iron", "Cancel", display5)
				if (choice5 == "Cancel")
					return

				if (choice5 == "Italian Sallet Helmet (12 Iron)")
					if (iron_amt >= 12)
						user << "You begin crafting the italian sallet helmet..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,130,src) && iron_amt >= 12)
							user << "You craft the italian sallet helmet."
							iron_amt -= 12
							if (iron_amt <= 0)
								icon_state = "armorbench"
							new/obj/item/clothing/head/helmet/sallet/italian(user.loc)
							return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

				if (choice5 == "German Sallet Helmet (12 Iron)")
					if (iron_amt >= 12)
						user << "You begin crafting the german sallet helmet..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,130,src) && iron_amt >= 12)
							user << "You craft the german sallet helmet."
							iron_amt -= 12
							if (iron_amt <= 0)
								icon_state = "armorbench"
							new/obj/item/clothing/head/helmet/sallet/german(user.loc)
							return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

				if (choice5 == "Burgundian Sallet Helmet (12)")
					if (iron_amt >= 12)
						user << "You begin crafting the burgundian sallet helmet..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,130,src) && iron_amt >= 12)
							user << "You craft the burgundian sallet helmet."
							iron_amt -= 12
							if (iron_amt <= 0)
								icon_state = "[base_icon]_anvil"
							new/obj/item/clothing/head/helmet/sallet/burg(user.loc)
							return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Morion Helmet (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the morion helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the morion helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/imperial/morion(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Coif (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the iron coif..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the iron coif."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/medieval/coif(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Coif and Helmet (12 Iron)")
				if (iron_amt >= 12)
					user << "You begin crafting the iron coif and helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft the iron coif."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/medieval/coif_helmet(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Crusader Helmet (15 Iron)")
				if (iron_amt >= 15)
					user << "You begin crafting the crusader helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the crusader helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/medieval/crusader(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Knight Helmet (15 Iron)")
				if (iron_amt >= 15)
					user << "You begin crafting the knight helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the knight helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/medieval(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Hounskull Bascinet (15 Iron)")
				if (iron_amt >= 15)
					user << "You begin crafting the hounskull bascinet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the hounskull bascinet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/bascinet(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Berserker Helmet (15 Iron)")
				if (iron_amt >= 15)
					user << "You begin crafting the helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/orc_beserker(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Spearman Helmet (12 Iron)")
				if (iron_amt >= 12)
					user << "You begin crafting the helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft the helmet."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/orc_spearman(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice4 == "Grunt Helmet (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/orc_grunt(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Pickelhaube (7 Iron)")
				if (iron_amt >= 7)
					user << "You begin crafting the pickelhaube..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 7)
						user << "You craft the pickelhaube."
						iron_amt -= 7
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/modern/pickelhaube(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Pith (7 Iron)")
				if (iron_amt >= 7)
					user << "You begin crafting the pith helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 7)
						user << "You craft the pith helmet."
						iron_amt -= 7
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/modern/pith(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice4 == "Scrap Helmet (15 Iron)")
				if (iron_amt >= 15)
					user << "You begin crafting the scrap metal helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,150,src) && iron_amt >= 15)
						user << "You craft the scrap metal helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/scrap(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

		else if (choice == "Iron Armor")
			var/list/display6 = list("Cancel")
			if (map.ordinal_age == 8)
				display6 = list("Scrap Armor (16 Iron)", "Cancel")
			else if (map.ordinal_age == 6)
				display6 = list("Cancel")
			else if (map.ordinal_age == 5)
				display6 = list("Cancel")
			else if (map.ordinal_age == 4)
				display6 = list("Cancel")
			else if (map.ordinal_age == 3)
				display6 = list("Imperial Chestplate(14 Iron)", "Cancel")
			else if (map.ordinal_age == 1)
				display6 = list("Scale Armor (14 Iron)", "Cancel")
			else if (map.ordinal_age == 0)
				display6 = list("Cancel")
			else if (map.ordinal_age == 2)
				if (H.orc)
					display6 = list("Grunt Armor (10 Iron)", "Urukhai Armor (12 Iron)", "Orkish Gauntlets (10 Iron)", "Orkish Sabatons (10 Iron)","Cancel")
				else
					display6 = list("Chainmail (10 Iron)", "Hauberk (12 Iron)", "Iron Chestplate (12 Iron)", "Plated Armor (16 Iron)", "Gauntlets (10 Iron)", "Plated Boots (10 Iron)", "Cancel")
			var/choice6 = WWinput(user, "What do you want to make?", "Blacksmith - [iron_amt] iron", "Cancel", display6)
			if (choice6 == "Scale Armor (14 Iron)")
				if (iron_amt >= 14)
					user << "You begin crafting the scale armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 14)
						user << "You craft the scale armor."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/ancient/scale(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice6 == "Chainmail (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the chainmail..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the chainmail."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/medieval/chainmail(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice6 == "Hauberk (12 Iron)")
				if (iron_amt >= 12)
					user << "You begin crafting the hauberk..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft the hauberk."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/medieval/hauberk(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice6 == "Gauntlets (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the gauntlets..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the gauntlets."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/gloves/gauntlets(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice6 == "Plated Boots (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the armored boots..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the armored boots."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/shoes/medieval/knight(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice6 == "Iron Chestplate (12 Iron)")
				if (iron_amt >= 12)
					user << "You begin crafting the iron chestplate..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft the iron chestplate."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/medieval/iron_chestplate(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice6 == "Emirate Armor (14 Iron)")
				if (iron_amt >= 14)
					user << "You begin crafting the emirate armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 14)
						user << "You craft the emirate armor."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/medieval/emirate(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice6 == "Imperial Chestplate(14 Iron)")
				if (iron_amt >= 14)
					user << "You begin crafting the imperial chestplate..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 14)
						user << "You craft the imperial chestplate."
						iron_amt -= 14
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/imperial/imperial_chestplate(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice6 == "Plated Armor (16 Iron)")
				if (iron_amt >= 16)
					user << "You begin crafting the plated armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && iron_amt >= 16)
						user << "You craft the plated armor."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/medieval(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice6 == "Urukhai Armor (12 Iron)")
				if (iron_amt >= 12)
					user << "You begin crafting the armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft the armor."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/ork_urukhai(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice6 == "Grunt Armor (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the armor."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/ork_grunt(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice6 == "Orkish Gauntlets (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the gauntlets..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the gauntlets."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/gloves/gauntlets/orc(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice6 == "Orkish Sabatons (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the sabatons..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the sabatons."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/shoes/orc(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice6 == "Scrap Armor (16 Iron)")
				if (iron_amt >= 16)
					user << "You begin crafting the scrap metal armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,150,src) && iron_amt >= 16)
						user << "You craft the scrap metal armor."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/scrap(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

		else if (choice == "Additional Armor")
			var/list/display7 = list("Cancel")
			if (map.ordinal_age == 3)
				display7 = list("Imperial Chinese Armor (10 Iron, 3 bronze)", "Cancel")
			else if (map.ordinal_age == 0)
				display7 = list("Cancel")
			else if (map.ordinal_age == 2)
				if (H.orc)
					display7 = list("Horned Helmet (10 Iron)", "Boss Jaw (7 Iron)", "Cancel")
				else
					display7 = list("Varangian Lamellar Armor (12 Iron)", "Imperial Chinese Armor (10 Iron, 3 bronze)", "Viking Helmet (10 Iron)", "Valkyrie Helmet (10 Iron)", "Imperial Chinese Helmet (10 Iron)", "Mamluk Conical Helmet (8 Iron, 2 Bronze)", "Mamluk Coif Helmet(9 Iron, 3 Bronze)", "Arabic Long Helmet (10 Iron, 5 Bronze)", "Varangian Helmet (15 Iron)", "Cancel")
			var/choice7 = WWinput(user, "What do you want to make?", "Blacksmith - [iron_amt] iron", "Cancel", display7)
			if (choice7 == "Varangian Lamellar Armor (12 Iron)")
				if (iron_amt >= 12)
					user << "You begin crafting the varangian lamellar armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft the varangian lamellar armor."
						iron_amt -= 12
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/medieval/varangian(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice7 == "Imperial Chinese Armor (13 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the imperial chinese armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 10)
						user << "You craft the imperial chinese armor."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/medieval/imperial_chinese(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice7 == "Horned Helmet (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the horned helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >=10)
						user << "You craft the horned helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/horned(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice7 == "Boss Jaw (7 Iron)")
				if (iron_amt >= 7)
					user << "You begin crafting the boss jaw mask..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 7)
						user << "You craft the boss jaw mask."
						iron_amt -= 7
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/mask/bossjaw(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice7 == "Viking Helmet (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the viking helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the viking helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/medieval/viking(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice7 == "Valkyrie Helmet (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the valkyrie helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the valkyrie helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/medieval/viking/valkyrie(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice7 == "Mamluk Conical Helmet (10 Iron)")
				if (iron_amt >= 8)
					user << "You begin crafting the mamluk conical helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the mamluk conical helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/medieval/mamluk/helmet(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice7 == "Mamluk Coif Helmet(12 Iron)")
				if (iron_amt >= 12)
					user << "You begin crafting the mamluk coif helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 12)
						user << "You craft the mamluk coif helmet."
						iron_amt -= 9
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/medieval/mamluk/coif(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice7 == "Arabic Long Helmet (15 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the arabic long helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the arabic long helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/medieval/nomads/longarab(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice7 == "Varangian Helmet (15 Iron)")
				if (iron_amt >= 15)
					user << "You begin crafting the varangian helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the varangian helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/medieval/viking/varangian(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice7 == "Imperial Chinese Helmet (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the imperial chinese helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the imperial chinese helmet."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/medieval/imperial_chinese(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return


		else if (choice == "Japanese Armor & Masks")
			var/list/display8 = list("Cancel")
			if (map.ordinal_age == 3)
				display8 = list("Kote Bracer Gauntlets (10 Iron)", "Tsuranuki Shinguard Boots (10 Iron)", "Metal Samurai Helmet (15 Iron)", "Red Metal Samurai Helmet (15 Iron)", "Blue Metal Samurai Helmet (15 Iron)", "Black Metal Samurai Helmet (15 Iron)", "Samurai Mask (8 Iron)", "Red Samurai Mask (8 Iron)", "Blue Samurai Mask (8 Iron)", "Metal Samurai Armor (16 Iron)", "Red Metal Samurai Armor (16 Iron)", "Blue Metal Samurai Armor (16 Iron)", "Black Metal Samurai Armor (16 Iron)", "Cancel")
			else if (map.ordinal_age == 0)
				display8 = list("Cancel")
			else if (map.ordinal_age == 2)
				if (H.orc)
					display8 = list("Cancel")
				else
					display8 = list("Kote Bracer Gauntlets (10 Iron)", "Tsuranuki Shinguard Boots (10 Iron)", "Samurai Helmet (15 Iron)", "Red Samurai Helmet (15)", "Blue Samurai Helmet (15 Iron)", "Black Samurai Helmet (15 Iron)", "Samurai Mask (8 Iron)", "Red Samurai Mask (8 Iron)", "Blue Samurai Mask (8 Iron)", "Metal Samurai Armor (16 Iron)", "Red Metal Samurai Armor (16 Iron)", "Blue Metal Samurai Armor (16 Iron)", "Black Metal Samurai Armor (16 Iron)", "Cancel")
			var/choice8 = WWinput(user, "What do you want to make?", "Blacksmith - [iron_amt] iron", "Cancel", display8)
			if (choice8 == "Kote Bracer Gauntlets (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the kote gauntlets..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the kote gauntlets."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/gloves/gauntlets/kote(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice8 == "Tsuranuki Shinguard Boots (10 Iron)")
				if (iron_amt >= 10)
					user << "You begin crafting the tsuranuki boots..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && iron_amt >= 10)
						user << "You craft the tsuranuki boots."
						iron_amt -= 10
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/shoes/tsuranuki(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if(choice8 == "Samurai Helmet (15 Iron)")
				if (iron_amt >= 15)
					user << "You begin crafting the samurai helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the samurai helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/samurai/guard(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if(choice8 == "Red Samurai Helmet (15 Iron)")
				if (iron_amt >= 15)
					user << "You begin crafting the samurai helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the samurai helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/samurai/guard/red(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if(choice8 == "Blue Samurai Helmet (15 Iron)")
				if (iron_amt >= 15)
					user << "You begin crafting the samurai helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the samurai helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/samurai/guard/blue(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if(choice8 == "Black Samurai Helmet (15 Iron)")
				if (iron_amt >= 15)
					user << "You begin crafting the samurai helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,160,src) && iron_amt >= 15)
						user << "You craft the samurai helmet."
						iron_amt -= 15
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/head/helmet/samurai/guard/black(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice8 == "Samurai Mask (8 Iron)")
				if (iron_amt >= 8)
					user << "You begin crafting the samurai mask..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 8)
						user << "You craft the samurai mask."
						iron_amt -= 8
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/mask/samurai(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice8 == "Red Samurai Mask (8 Iron)")
				if (iron_amt >= 8)
					user << "You begin crafting the samurai mask..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 8)
						user << "You craft the samurai mask."
						iron_amt -= 8
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/mask/samurai/red(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice8 == "Blue Samurai Mask (8 Iron)")
				if (iron_amt >= 8)
					user << "You begin crafting the samurai mask..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && iron_amt >= 8)
						user << "You craft the samurai mask."
						iron_amt -= 8
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/mask/samurai/blue(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return

			if (choice8 == "Metal Samurai Armor (16 Iron)")
				if (iron_amt >= 16)
					user << "You begin crafting the samurai armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && iron_amt >= 16)
						user << "You craft the samurai armor."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/samurai(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice8 == "Red Metal Samurai Armor (16 Iron)")
				if (iron_amt >= 16)
					user << "You begin crafting the samurai armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && iron_amt >= 16)
						user << "You craft the samurai armor."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/samurai/red(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice8 == "Blue Metal Samurai Armor (16 Iron)")
				if (iron_amt >= 16)
					user << "You begin crafting the samurai armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && iron_amt >= 16)
						user << "You craft the samurai armor."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/samurai/blue(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return
			if (choice8 == "Black Metal Samurai Armor (16 Iron)")
				if (iron_amt >= 16)
					user << "You begin crafting the samurai armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,180,src) && iron_amt >= 16)
						user << "You craft the samurai armor."
						iron_amt -= 16
						if (iron_amt <= 0)
							icon_state = "armorbench"
						new/obj/item/clothing/suit/armor/samurai/black(user.loc)
						return
				else
					user << "<span class='notice'>You need more iron to make this!</span>"
					return


/* Kevlar & Steel Advanced Armorbench*/

/obj/structure/anvil/armorbench/specialist
	name = "specialist armor bench"
	desc = "A large metal desk littered with powertools for careful construction of kevlar & steel objects. It has 0 steel and 0 kevlar on it."
	icon = 'icons/obj/structures.dmi'
	icon_state = "specialist_armor_bench"
	density = TRUE
	anchored = TRUE
	bronze_amt = 0
	iron_amt = 0
	not_movable = FALSE
	not_disassemblable = FALSE
/obj/structure/anvil/armorbench/specialist/New()
	..()
	desc = "A large metal desk littered with powertools for careful construction of kevlar & steel plated armor. It has [steel_amt] steel and [iron_amt] iron on it."

/obj/structure/anvil/armorbench/specialist/attackby(obj/item/P as obj, mob/user as mob)
	var/mob/living/human/H = user
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
		if (istype(P, /obj/item/stack/material/steel) && kevlar_amt == 0)
			user << "You begin smiting the steel..."
			icon_state = "specialist_armor_bench"
			playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
			if (do_after(user,15*P.amount,src))
				user << "<span class='notice'>You smite the steel.</span>"
				steel_amt += P.amount
				desc = "A large metal desk littered with powertools for careful construction of kevlar & steel objects. It has [steel_amt] steel on it."
				icon_state = "specialist_armor_bench2"
				qdel(P)
		else if (istype(P, /obj/item/stack/material/iron) && kevlar_amt > 0)
			user << "<span class='notice'>You can't work steel while there is kevlar on the bench! Finish the kevlar first.</span>"
			return
		else if (istype(P, /obj/item/stack/material/kevlar) && steel_amt == 0)
			user << "You begin working the kevlar..."
			icon_state = "specialist_armor_bench"
			playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
			if (do_after(user,15*P.amount,src))
				user << "<span class='notice'>You work the kevlar.</span>"
				kevlar_amt += P.amount
				desc = "A large metal desk littered with powertools for careful construction of kevlar & steel objects. It has [kevlar_amt] kevlar on it."
				icon_state = "specialist_armor_bench1"
				qdel(P)
		else if (istype(P, /obj/item/stack/material/kevlar) && steel_amt > 0)
			user << "<span class='notice'>You can't work kevlar while there is steel on the bench! Finish the kevlar first.</span>"
			return
//timing list (8 metal = 100 or less || <10 metal = 130 || <13 - 15 = 160 || 16 - 17 = 180 || 18 - 20 = 200 || 21 - 30 = 250)

/obj/structure/anvil/armorbench/specialist/attack_hand(var/mob/user as mob)
	var/mob/living/human/H = user
	if (H.getStatCoeff("crafting") < 1.7)
		user << "You don't have the skills to use this."
		return
	if (!map.civilizations && map.ID != MAP_TRIBES && (user.original_job_title != "Blacksmith" && user.original_job_title != "Pioneer Blacksmith" && user.original_job_title != "Town Blacksmith" && user.original_job_title != "Ferreiro" && user.original_job_title != "Ferrero" && user.original_job_title != "Grofsmid" && user.original_job_title != "Forgeron" && user.original_job_title != "British Blacksmith" && user.original_job_title != "Marooned Pirate Crew" && user.original_job_title != "Schmied"))
		user << "You don't have the skills to use this. Ask a blacksmith."
		return
	if (map.ID == MAP_TRIBES && (H.gorillaman || H.ant || H.wolfman || H.lizard || H.crab))
		user << "You don't know how to use this."
		return
	else if (kevlar_amt > 0)
		var/list/displaykevlar = list("Cancel")
		if (map.ordinal_age >= 7)
			displaykevlar = list("Kevlar Armor", "Kevlar Helmets", "Cancel")
		else if (map.ordinal_age >= 8)
			displaykevlar = list("Kevlar Armor", "Kevlar Helmets", "Cancel")
		var/choice = WWinput(user, "What do you want to make?", "Blacksmith - [kevlar_amt] kevlar", "Cancel", displaykevlar)
		if (choice == "Cancel")
			return

		else if (choice == "Kevlar Armor")
			var/list/display2 = list("Cancel")
			if (map.ordinal_age == 8)
				display2 = list("Police Bullet-Proof Vest (10 Kevlar)", "Standard Kevlar Vest (14 Kevlar)", "SWAT Heavy Vest (16 Kevlar)", "Cancel")
			else if (map.ordinal_age == 7)
				display2 = list("PASGT Armor", "Police Bullet-Proof Vest (10 Kevlar)", "Standard Kevlar Vest (14 Kevlar)", "Cancel")
			var/choice2 = WWinput(user, "What do you want to make?", "Blacksmith - [kevlar_amt] kevlar", "Cancel", display2)
			if (choice2 == "Police Bullet-Proof Vest (10 Kevlar)")
				if (kevlar_amt >= 10)
					user << "You begin crafting the police bullet-proof vest..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && kevlar_amt >= 10)
						user << "You craft the police bullet-proof vest."
						kevlar_amt -= 10
						if (kevlar_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/suit/police(user.loc)
						return
				else
					user << "<span class='notice'>You need more kevlar to make this!</span>"
					return

			if (choice2 == "Standard Kevlar Vest (14 Kevlar)")
				if (kevlar_amt >= 14)
					user << "You begin crafting the kevlar vest..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && kevlar_amt >= 14)
						user << "You craft the kevlar vest."
						kevlar_amt -= 14
						if (kevlar_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/accessory/armor/nomads/kevlarblack(user.loc)
						return
				else
					user << "<span class='notice'>You need more kevlar to make this!</span>"
					return

			if (choice2 == "PASGT Armor")
				var/list/display3 = list("Cancel")
				if (map.ordinal_age == 7)
					display3 = list("Standard PASGT Armor (12 Kevlar)", "Khaki PASGT Armor (12 Kevlar)", "Cancel")
				var/choice3 = WWinput(user, "Which varient?", "Blacksmith - [kevlar_amt] kevlar", "Cancel", display3)
				if (choice3 == "Cancel")
					return

				if (choice3 == "Standard PASGT Armor (12 Kevlar)")
					if (kevlar_amt >= 12)
						user << "You begin crafting the standard PASGT armor..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,150,src) && kevlar_amt >= 10)
							user << "You craft the standard PASGT helmet."
							kevlar_amt -= 12
							if (kevlar_amt <= 0)
								icon_state = "specialist_armor_bench"
							new/obj/item/clothing/accessory/armor/coldwar/pasgt(user.loc)
							return
					else
						user << "<span class='notice'>You need more kevlar to make this!</span>"
						return
				if (choice3 == "Khaki PASGT Armor (12 Kevlar)")
					if (kevlar_amt >= 12)
						user << "You begin crafting the khaki PASGT helmet..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,150,src) && kevlar_amt >= 12)
							user << "You craft the khaki PASGT helmet."
							kevlar_amt -= 10
							if (kevlar_amt <= 0)
								icon_state = "specialist_armor_bench"
							new/obj/item/clothing/accessory/armor/coldwar/pasgt/khaki(user.loc)
							return
					else
						user << "<span class='notice'>You need more kevlar to make this!</span>"
						return

			if (choice2 == "SWAT Heavy Vest (16 Kevlar)")
				if (kevlar_amt >= 16)
					user << "You begin crafting the swat heavy vest..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,210,src) && kevlar_amt >= 16)
						user << "You craft the swat heavy vest."
						kevlar_amt -= 16
						if (kevlar_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/suit/swat(user.loc)
						return
				else
					user << "<span class='notice'>You need more kevlar to make this!</span>"
					return

		else if (choice == "Kevlar Helmets")
			var/list/display4 = list("Cancel")
			if (map.ordinal_age == 8)
				display4 = list("Kevlar Helmet (10 Kevlar)", "SWAT Helmet (12 Kevlar)", "Tactical Helmet (14 Kevlar)", "Cancel")
			else if (map.ordinal_age == 7)
				display4 = list("Kevlar Helmet (10 Kevlar)", "PASGT helmets", "SWAT Helmet (12 Kevlar)", "Cancel")
			var/choice4 = WWinput(user, "What do you want to make?", "Blacksmith - [kevlar_amt] kevlar", "Cancel", display4)
			if (choice4 == "Kevlar Helmet (10 Kevlar)")
				if (kevlar_amt >= 10)
					user << "You begin crafting the kevlar helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && kevlar_amt >= 10)
						user << "You craft the Kevlar helmet."
						kevlar_amt -= 10
						if (kevlar_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/head/helmet/kevlarhelmet(user.loc)
						return
				else
					user << "<span class='notice'>You need more kevlar to make this!</span>"
					return

			if (choice4 == "PASGT helmets")
				var/list/display5 = list("Cancel")
				if (map.ordinal_age == 7)
					display5 = list("Standard PASGT helmet (10 Kevlar)", "Desert PASGT helmet (10 Kevlar)", "Cancel")
				var/choice5 = WWinput(user, "Which varient?", "Blacksmith - [iron_amt] iron", "Cancel", display5)
				if (choice5 == "Cancel")
					return

				if (choice5 == "Standard PASGT helmet (10 Kevlar)")
					if (steel_amt >= 10)
						user << "You begin crafting the standard PASGT helmet..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,130,src) && steel_amt >= 10)
							user << "You craft the standard PASGT helmet."
							kevlar_amt -= 10
							if (kevlar_amt <= 0)
								icon_state = "specialist_armor_bench"
							new/obj/item/clothing/head/helmet/modern/pasgt(user.loc)
							return
					else
						user << "<span class='notice'>You need more steel to make this!</span>"
						return
				if (choice5 == "Desert PASGT helmet (10 Kevlar)")
					if (kevlar_amt >= 10)
						user << "You begin crafting the desert PASGT helmet..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,130,src) && kevlar_amt >= 10)
							user << "You craft the desert PASGT helmet."
							kevlar_amt -= 10
							if (kevlar_amt <= 0)
								icon_state = "specialist_armor_bench"
							new/obj/item/clothing/head/helmet/modern/pasgt/desert(user.loc)
							return
					else
						user << "<span class='notice'>You need more kevlar to make this!</span>"
						return

			if (choice4 == "US LWT Helmets")
				var/list/display6 = list("Cancel")
				if (map.ordinal_age == 8)
					display6 = list("Standard US LWT Helmet (10 Kevlar)", "Black US LWT Helmet (12 Kevlar)", "Cancel")
				var/choice6 = WWinput(user, "Which varient?", "Blacksmith - [kevlar_amt] kevlar", "Cancel", display6)
				if (choice6 == "Cancel")
					return

				if (choice6 == "Standard US LWT Helmet (12 Kevlar)")
					if (steel_amt >= 12)
						user << "You begin crafting the standard PASGT helmet..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,150,src) && steel_amt >= 12)
							user << "You craft the standard PASGT helmet."
							kevlar_amt -= 12
							if (kevlar_amt <= 0)
								icon_state = "specialist_armor_bench"
							new/obj/item/clothing/head/helmet/modern/lwh(user.loc)
							return
					else
						user << "<span class='notice'>You need more steel to make this!</span>"
						return
				if (choice6 == "Black US LWT Helmet (12 Kevlar)")
					if (kevlar_amt >= 12)
						user << "You begin crafting the US LWT helmet..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,150,src) && kevlar_amt >= 12)
							user << "You craft the US LWT helmet."
							kevlar_amt -= 12
							if (kevlar_amt <= 0)
								icon_state = "specialist_armor_bench"
							new/obj/item/clothing/head/helmet/modern/lwh/black(user.loc)
							return
					else
						user << "<span class='notice'>You need more kevlar to make this!</span>"
						return

			if (choice4 == "SWAT Helmet (12 Kevlar)")
				if (kevlar_amt >= 12)
					user << "You begin crafting the SWAT helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,150,src) && kevlar_amt >= 12)
						user << "You craft the SWAT helmet."
						kevlar_amt -= 12
						if (kevlar_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/head/helmet/swat(user.loc)
						return
				else
					user << "<span class='notice'>You need more kevlar to make this!</span>"
					return
			if (choice4 == "Tactical Helmet (14 Kevlar)")
				if (kevlar_amt >= 14)
					user << "You begin crafting the tactical helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,175,src) && kevlar_amt >= 14)
						user << "You craft the tactical helmet."
						kevlar_amt -= 12
						if (kevlar_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/head/helmet/tactical(user.loc)
						return
				else
					user << "<span class='notice'>You need more kevlar to make this!</span>"
					return

	else if (steel_amt > 0)
		var/list/displaysteel = list("Cancel")
		if (map.ordinal_age >= 5)
			displaysteel = list("Steel Armor", "Steel Helmets", "Cancel")
		else if (map.ordinal_age >= 6)
			displaysteel = list("Steel Helmets", "Cancel")
		else if (map.ordinal_age >= 7)
			displaysteel = list("Steel Helmets", "Cancel")
		else if (map.ordinal_age >= 8)
			displaysteel = list("Steel Helmets", "Cancel")
		var/choice = WWinput(user, "What do you want to make?", "Blacksmith - [steel_amt] steel", "Cancel", displaysteel)
		if (choice == "Cancel")
			return

		else if (choice == "Steel Helmets")
			var/list/display7 = list("Cancel")
			if (map.ordinal_age == 8)
				display7 = list("Modern US M1 Helmet (12 Steel)", "Russian ZSh-2 helmet (14 Steel)", "Cancel")
			else if (map.ordinal_age == 7)
				display7 = list("USSR Heavy Visored Helmets", "USSR SSh-68 helmet (10 Steel)", "Korean War US M1 Helmet (12 Steel)", "Russian ZSh-1 helmet (12 Steel)", "Cancel")
			else if (map.ordinal_age == 6)
				display7 = list("Mk2 Brodie (9 Steel)", "Stahlhelm (9 Steel)","Type 92 Helmet (10 Iron)", "Soviet Helmet (10 Iron)", "M1 Helmet (10 Steel)", "M26 Adrian (10 Iron)", "Cancel")
			else if (map.ordinal_age == 5)
				display7 = list("Pickelhaube (6 Steel)","Mesh Pickelhaube (6 Steel)", "Mk1 Brodie (9 Steel)", "Stahlhelm (9 Steel)", "M15 Adrian Helmet (9 Steel)", "Cancel")
			var/choice7 = WWinput(user, "What do you want to make?", "Blacksmith - [steel_amt] steel", "Cancel", display7)

			if (choice7 == "Pickelhaube (6 Steel)")
				if (steel_amt >= 6)
					user << "You begin crafting the pickelhaube..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && steel_amt >= 6)
						user << "You craft the pickelhaube."
						steel_amt -= 6
						if (steel_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/head/helmet/modern/pickelhaube(user.loc)
						return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return
			if (choice7 == "Mesh Pickelhaube (6 Steel)")
				if (steel_amt >= 6)
					user << "You begin crafting the pickelhaube..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,100,src) && steel_amt >= 6)
						user << "You craft the pickelhaube."
						steel_amt -= 6
						if (steel_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/head/helmet/ww/pickelhaube2(user.loc)
						return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return

			if (choice7 == "Stahlhelm (9 Steel)")
				if (steel_amt >= 9)
					user << "You begin crafting the stahlhelm..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && steel_amt >= 9)
						user << "You craft the stahlhelm."
						steel_amt -= 9
						if (steel_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/head/helmet/modern/stahlhelm(user.loc)
						return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return

			if (choice7 == "Type 92 Helmet (9 Steel)")
				if (steel_amt >= 9)
					user << "You begin crafting the type 92..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && steel_amt >= 9)
						user << "You craft the type 92."
						steel_amt -= 9
						if (steel_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/head/helmet/ww2/japhelm(user.loc)
						return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return

			if (choice7 == "M1 Helmet (9 Steel)")
				if (steel_amt >= 9)
					user << "You begin crafting the M1..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && steel_amt >= 9)
						user << "You craft the M1."
						steel_amt -= 9
						if (steel_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/head/helmet/ww2/usm1(user.loc)
						return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return

			if (choice7 == "Soviet Helmet (9 Steel)")
				if (steel_amt >= 9)
					user << "You begin crafting the soviet helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && steel_amt >= 9)
						user << "You craft the soviet helmet."
						steel_amt -= 9
						if (steel_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/head/helmet/ww2/soviet(user.loc)
						return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return

			if (choice7 == "Mk2 Brodie (9 Steel)")
				if (steel_amt >= 9)
					user << "You begin crafting the brodie..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && steel_amt >= 9)
						user << "You craft the Mk2 Brodie."
						steel_amt -= 9
						if (steel_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/head/helmet/ww/mk2brodieog(user.loc)
						return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return

			if (choice7 == "M26 Adrian (9 Steel)")
				if (steel_amt >= 9)
					user << "You begin crafting the M26 Adrian..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && steel_amt >= 9)
						user << "You craft the M26 Adrian."
						steel_amt -= 9
						if (steel_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/head/helmet/ww2/adrianm26(user.loc)
						return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return

			if (choice7 == "M15 Adrian Helmet (9 Steel)")
				var/list/display8 = list("Cancel")
				if (map.ordinal_age == 5)
					display8 = list("Standard M15 Adrian", "Russian M15 Adrian", "Greek M15 Adrian", "Cancel")
				var/choice8 = WWinput(user, "Which varient?", "Blacksmith - [iron_amt] iron", "Cancel", display8)
				if (choice8 == "Cancel")
					return

				if (choice8 == "Standard M15 Adrian")
					if (steel_amt >= 9)
						user << "You begin crafting the M15 Adrian..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,130,src) && steel_amt >= 9)
							user << "You craft the M15 Adrian."
							steel_amt -= 9
							if (steel_amt <= 0)
								icon_state = "specialist_armor_bench"
							new/obj/item/clothing/head/helmet/ww/adrian(user.loc)
							return
					else
						user << "<span class='notice'>You need more steel to make this!</span>"
						return
				if (choice8 == "Russian M15 Adrian")
					if (steel_amt >= 9)
						user << "You begin crafting the M15 Adrian..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,130,src) && steel_amt >= 9)
							user << "You craft the M15 Adrian."
							steel_amt -= 9
							if (steel_amt <= 0)
								icon_state = "specialist_armor_bench"
							new/obj/item/clothing/head/helmet/ww/adriansoviet(user.loc)
							return
					else
						user << "<span class='notice'>You need more steel to make this!</span>"
						return
				if (choice8 == "Greek M15 Adrian")
					if (steel_amt >= 9)
						user << "You begin crafting the M15 Adrian..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,130,src) && steel_amt >= 9)
							user << "You craft the M15 Adrian."
							steel_amt -= 9
							if (steel_amt <= 0)
								icon_state = "specialist_armor_bench"
							new/obj/item/clothing/head/helmet/ww/adriangreek(user.loc)
							return
					else
						user << "<span class='notice'>You need more steel to make this!</span>"
						return


			if (choice7 == "Mk1 Brodie (9 Steel)")
				var/list/display9 = list("Cancel")
				if (map.ordinal_age == 5)
					display9 = list("Mk1 Brodie (Apple Green)", "Mk1 Brodie (Duck Egg Blue)", "Cancel")
				var/choice9 = WWinput(user, "Which varient?", "Blacksmith - [steel_amt] steel", "Cancel", display9)
				if (choice9 == "Cancel")
					return

				if (choice9 == "Mk1 Brodie (Apple Green)")
					if (steel_amt >= 9)
						user << "You begin crafting the Mk1 Brodie..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,130,src) && steel_amt >= 9)
							user << "You craft the Mk1 Brodie."
							steel_amt -= 9
							if (steel_amt <= 0)
								icon_state = "specialist_armor_bench"
							new/obj/item/clothing/head/helmet/ww/mk1brodieag(user.loc)
							return
					else
						user << "<span class='notice'>You need more steel to make this!</span>"
						return
				if (choice9 == "Mk1 Brodie (Duck Egg Blue)")
					if (steel_amt >= 9)
						user << "You begin crafting the Mk1 Brodie..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,130,src) && steel_amt >= 9)
							user << "You craft the Mk1 Brodie."
							steel_amt -= 9
							if (steel_amt <= 0)
								icon_state = "specialist_armor_bench"
							new/obj/item/clothing/head/helmet/ww/mk1brodiedeb(user.loc)
							return
					else
						user << "<span class='notice'>You need more steel to make this!</span>"
						return

			if (choice7 == "USSR Heavy Visored Helmets")
				var/list/display10 = list("Cancel")
				if (map.ordinal_age == 7)
					display10 = list("USSR MASKA1 Helmet (15 Steel)", "USSR K6-3 Helmet (16 Steel)", "Cancel")
				var/choice10 = WWinput(user, "Which varient?", "Blacksmith - [steel_amt] iron", "Cancel", display10)
				if (choice10 == "Cancel")
					return

				if (choice10 == "USSR MASKA1 Helmet (15 Steel)")
					if (steel_amt >= 16)
						user << "You begin crafting the USSR MASKA1 helmet..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,210,src) && steel_amt >= 16)
							user << "You craft the the USSR MASKA1 helmet."
							steel_amt -= 16
							if (steel_amt <= 0)
								icon_state = "specialist_armor_bench"
							new/obj/item/clothing/head/helmet/modern/sovietfacehelmet/nomads(user.loc)
							return
					else
						user << "<span class='notice'>You need more steel to make this!</span>"
						return
				if (choice10 == "USSR K6-3 Helmet (16 Steel)") //purely becuase its eye-protective.
					if (steel_amt >= 16)
						user << "You begin crafting the USSR K6-3 helmet..."
						playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
						if (do_after(user,210,src) && steel_amt >= 16)
							user << "You craft the the USSR K6-3 helmet."
							steel_amt -= 16
							if (steel_amt <= 0)
								icon_state = "specialist_armor_bench"
							new/obj/item/clothing/head/helmet/modern/sovietfacehelmet/nomads(user.loc)
							return
					else
						user << "<span class='notice'>You need more steel to make this!</span>"
						return

			if (choice7 == "USSR SSh-68 helmet (10 Steel)")
				if (steel_amt >= 10)
					user << "You begin crafting the USSR SSh-68 helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,130,src) && steel_amt >= 10)
						user << "You craft the the USSR SSh-68 helmet."
						steel_amt -= 10
						if (steel_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/head/helmet/modern/ssh_68(user.loc)
						return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return

			if (choice7 == "Korean War US M1 Helmet (12 Steel)")
				if (steel_amt >= 12)
					user << "You begin crafting the korean war M1 helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,150,src) && steel_amt >= 9)
						user << "You craft the the korean war M1 helmet."
						steel_amt -= 12
						if (steel_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/head/helmet/korean/usm1(user.loc)
						return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return

			if (choice7 == "Modern US M1 Helmet (12 Steel)")
				if (steel_amt >= 12)
					user << "You begin crafting the modern M1 helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,150,src) && steel_amt >= 9)
						user << "You craft the the modern M1 helmet."
						steel_amt -= 12
						if (steel_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/head/helmet/modern/ushelmet(user.loc)
						return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return
			if (choice7 == "Russian ZSh-1 helmet (12 Steel)")
				if (steel_amt >= 12)
					user << "You begin crafting the russian ZSh-1 helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,150,src) && steel_amt >= 12)
						user << "You craft the the russian ZSh-1 helmet."
						steel_amt -= 12
						if (steel_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/head/helmet/modern/zsh1(user.loc)
						return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return

			if (choice7 == "Russian ZSh-2 helmet (14 Steel)")
				if (steel_amt >= 14)
					user << "You begin crafting the russian ZSh-2 helmet..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,175,src) && steel_amt >= 14)
						user << "You craft the the russian ZSh-2 helmet."
						steel_amt -= 14
						if (steel_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/head/helmet/modern/a6b47(user.loc)
						return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return

		else if (choice == "Steel Armor")
			var/list/display11 = list("Cancel")
			if (map.ordinal_age == 5)
				display11 = list("Dayfield body armor (10 Steel)", "Breastplate Body Armor (12 Steel)", "Cancel")
			var/choice11 = WWinput(user, "What do you want to make?", "Blacksmith - [steel_amt] steel", "Cancel", display11)
			if (choice11 == "Dayfield body armor (10 Steel)")
				if (steel_amt >= 10)
					user << "You begin crafting a Dayfield body armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,150,src) && steel_amt >= 10)
						user << "You craft a Dayfield body armor."
						steel_amt -= 10
						if (steel_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/accessory/armor/modern/british(user.loc)
						return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return

			if (choice11 == "Breastplate Body Armor (12 Steel)")
				if (steel_amt >= 12)
					user << "You begin crafting the breastplate body armor..."
					playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
					if (do_after(user,150,src) && steel_amt >= 12)
						user << "You craft the breastplate body armor."
						steel_amt -= 12
						if (steel_amt <= 0)
							icon_state = "specialist_armor_bench"
						new/obj/item/clothing/accessory/armor/modern/plate(user.loc)
						return
				else
					user << "<span class='notice'>You need more steel to make this!</span>"
					return