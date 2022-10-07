/obj/structure/anvil
	name = "iron anvil"
	desc = "A heavy iron anvil. The blacksmith's main work tool. It has 0 hot iron bars on it."
	icon = 'icons/obj/metallurgy.dmi'
	icon_state = "iron_anvil"
	density = TRUE
	anchored = TRUE
	var/base_icon = "iron"
	not_movable = FALSE
	not_disassemblable = TRUE
	var/list/accepted_materials = list("copper", "tin", "gold", "silver","bronze", "iron")

/obj/structure/anvil/New()
	..()
	desc = "A heavy iron anvil. The blacksmith's main work tool."

/obj/structure/anvil/update_icon()
	if (in_use)
		icon_state = "[base_icon]_anvil_use"
	else
		icon_state = "[base_icon]_anvil"

/obj/structure/anvil/attackby(obj/item/P as obj, mob/user as mob)
	var/mob/living/human/H = user
	if (istype(P,/obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << (anchored ? "<span class='notice'r>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
	if (H.getStatCoeff("crafting") < 1.7)
		user << "You don't have the skills to use this."
		return
	if (!map.civilizations && map.ID != MAP_TRIBES && map.ID != MAP_THREE_TRIBES && map.ID != MAP_FOUR_KINGDOMS && map.ID !=MAP_GULAG13 && (user.original_job_title != "Blacksmith" && user.original_job_title != "Pioneer Blacksmith" && user.original_job_title != "Town Blacksmith" && user.original_job_title != "Ferreiro" && user.original_job_title != "Ferrero" && user.original_job_title != "Grofsmid" && user.original_job_title != "Forgeron" && user.original_job_title != "British Blacksmith" && user.original_job_title != "Marooned Pirate Crew" && user.original_job_title != "Schmied"))
		user << "You don't have the skills to use this. Ask a blacksmith."
		return
	if ((map.ID == MAP_TRIBES || map.ID == MAP_THREE_TRIBES || map.ID == MAP_FOUR_KINGDOMS) && (H.gorillaman || H.ant || H.wolfman || H.lizard || H.crab))
		user << "You don't know how to use this."
		return
	if (map.ID == MAP_FOUR_KINGDOMS && (H.gorillaman || H.ant || H.wolfman || H.lizard || H.crab))
		user << "You don't know how to use this."
		return
	else
		if (istype(P, /obj/item/stack/material))
			var/obj/item/stack/material/MTR = P
			if (!(MTR.default_type in accepted_materials))
				user << "<span class='warning'>You can't use this material on this anvil.</span>"
				return
		if (istype(P, /obj/item/stack/ore/iron_pig))
			if (!("iron" in accepted_materials))
				user << "<span class='warning'>You can't use this material on this anvil.</span>"
				return
			user << "You begin smithing the pig iron..."
			icon_state = "[base_icon]_anvil_use"
			in_use = TRUE
			update_icon()
			playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
			var/initial_amount = P.amount //no more speedhack
			if (do_after(user,15*initial_amount,src) && P.amount == initial_amount)
				user << "<span class='notice'>You smite the pig into steel.</span>"
				if (P && P.amount == initial_amount)
					var/amt = P.amount
					qdel(P)
					var/obj/item/stack/material/steel/I = new/obj/item/stack/material/steel(loc)
					I.amount = amt*0.8
				in_use = FALSE
			else
				in_use = FALSE
			update_icon()
		else if (istype(P, /obj/item/stack/ore/iron_sponge))
			user << "You begin smithing the sponge iron..."
			icon_state = "[base_icon]_anvil_use"
			in_use = TRUE
			update_icon()
			playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
			var/initial_amount = P.amount //no more speedhack
			if (do_after(user,15*initial_amount,src) && P.amount == initial_amount)
				user << "<span class='notice'>You smite the sponge iron into wrought iron.</span>"
				if (P && P.amount == initial_amount)
					var/amt = P.amount
					qdel(P)
					var/obj/item/stack/material/iron/I = new/obj/item/stack/material/iron(loc)
					I.amount = amt
				in_use = FALSE
			else
				in_use = FALSE
			update_icon()
/////////IRON//////////
		else if (istype(P, /obj/item/stack/material/iron))
			var/list/optlist = list("cancel")
			if (H.orc)
				optlist = list("cancel", "orkish shields", "orkish headwear", "orkish helmets", "orkish armor")
				var/choice = WWinput(H, "What do you want to craft?", "Anvil", "cancel", optlist)
				if (choice == "cancel")
					return
				var/list/newlist = list("Cancel")
				for(var/i in anvil_recipes)
					if (anvil_recipes[i])
						if (anvil_recipes[i][2] == choice && map.ordinal_age >= anvil_recipes[i][3] && map.ordinal_age <= anvil_recipes[i][4] && anvil_recipes[i][6] > 0)
							newlist += "[anvil_recipes[i][1]] - [anvil_recipes[i][6]] iron"
				var/choice2 = WWinput(H, "What do you want to craft?", "Anvil", "Cancel", newlist)
				if (choice2 == "Cancel")
					return
				var/list/parsed_choice2 = splittext(choice2," - ")
				if (anvil_recipes[parsed_choice2[1]])
					if (P.amount >= anvil_recipes[parsed_choice2[1]][6])
						user << "You begin crafting \the [parsed_choice2[1]]..."
						in_use = TRUE
						update_icon()
						if (do_after(user,10*anvil_recipes[parsed_choice2[1]][6],src,can_move=FALSE))
							if (P.amount >= anvil_recipes[parsed_choice2[1]][6])
								P.amount -= anvil_recipes[parsed_choice2[1]][6]
								if (P.amount <= 0)
									qdel(P)
								user << "You finish crafting \the [parsed_choice2[1]]."
								var/rtype = anvil_recipes[parsed_choice2[1]][9]
								new rtype (loc,"iron")
							in_use = FALSE
						else
							in_use = FALSE
						update_icon()
						return
			else
				if (map.ordinal_age <= 1)
					optlist = list("cancel","shields","helmets","armor")
				else if (map.ordinal_age == 2)
					optlist = list("cancel","shields","helmets","other helmets","armor","other armor","other weapons","sallet helmets","japanese armor","japanese helmets","japanese headwear")
				else if (map.ordinal_age == 3)
					optlist = list("cancel","guns","helmets","other helmets","armor","other armor","other weapons","sallet helmets","japanese armor","japanese helmets","japanese headwear")
				else if (map.ordinal_age == 4)
					optlist = list("cancel","helmets")
				else if (map.ordinal_age == 5)
					optlist = list("cancel","helmets")
				else if (map.ordinal_age == 8)
					optlist = list("cancel","armor")
				var/choice = WWinput(H, "What do you want to craft?", "Anvil", "cancel", optlist)
				if (choice == "cancel")
					return
				var/list/newlist = list("Cancel")
				for(var/i in anvil_recipes)
					if (anvil_recipes[i])
						if (anvil_recipes[i][2] == choice && map.ordinal_age >= anvil_recipes[i][3] && map.ordinal_age <= anvil_recipes[i][4] && anvil_recipes[i][6] > 0)
							newlist += "[anvil_recipes[i][1]] - [anvil_recipes[i][6]] iron"
				var/choice2 = WWinput(H, "What do you want to craft?", "Anvil", "Cancel", newlist)
				if (choice2 == "Cancel")
					return
				var/list/parsed_choice2 = splittext(choice2," - ")
				if (anvil_recipes[parsed_choice2[1]])
					if (P.amount >= anvil_recipes[parsed_choice2[1]][6])
						user << "You begin crafting \the [parsed_choice2[1]]..."
						in_use = TRUE
						update_icon()
						if (do_after(user,10*anvil_recipes[parsed_choice2[1]][6],src,can_move=FALSE))
							if (P.amount >= anvil_recipes[parsed_choice2[1]][6])
								P.amount -= anvil_recipes[parsed_choice2[1]][6]
								if (P.amount <= 0)
									qdel(P)
								user << "You finish crafting \the [parsed_choice2[1]]."
								var/rtype = anvil_recipes[parsed_choice2[1]][9]
								new rtype (loc,"iron")
							in_use = FALSE
						else
							in_use = FALSE
						update_icon()
						return
/////////STEEL//////////
		else if (istype(P, /obj/item/stack/material/steel))
			var/list/optlist = list("cancel")
			if (H.orc)
				//optlist = list("cancel", "orkish shields", "orkish headwear", "orkish helmets") //disabled for now, as no Orkish armour and weapons require steel at the moment
				var/choice = WWinput(H, "What do you want to craft?", "Anvil", "cancel", optlist)
				if (choice == "cancel")
					return
				var/list/newlist = list("Cancel")
				for(var/i in anvil_recipes)
					if (anvil_recipes[i])
						if (anvil_recipes[i][2] == choice && map.ordinal_age >= anvil_recipes[i][3] && map.ordinal_age <= anvil_recipes[i][4] && anvil_recipes[i][5] > 0)
							newlist += "[anvil_recipes[i][1]] - [anvil_recipes[i][5]] steel"
				var/choice2 = WWinput(H, "What do you want to craft?", "Anvil", "Cancel", newlist)
				if (choice2 == "Cancel")
					return
				var/list/parsed_choice2 = splittext(choice2," - ")
				if (anvil_recipes[parsed_choice2[1]])
					if (P.amount >= anvil_recipes[parsed_choice2[1]][5])
						user << "You begin crafting \the [parsed_choice2[1]]..."
						in_use = TRUE
						update_icon()
						if (do_after(user,10*anvil_recipes[parsed_choice2[1]][5],src,can_move=FALSE))
							if (P.amount >= anvil_recipes[parsed_choice2[1]][5])
								P.amount -= anvil_recipes[parsed_choice2[1]][5]
								if (P.amount <= 0)
									qdel(P)
								user << "You finish crafting \the [parsed_choice2[1]]."
								var/rtype = anvil_recipes[parsed_choice2[1]][9]
								new rtype (loc,"steel")
							in_use = FALSE
						else
							in_use = FALSE
						update_icon()
						return
			else
				if (map.ordinal_age == 2)
					optlist = list("cancel","japanese armor","japanese helmets","japanese headwear", "other weapons")
				else if (map.ordinal_age == 3)
					optlist = list("cancel","japanese armor","japanese helmets","japanese headwear", "other weapons")
				else if (map.ordinal_age == 4)
					optlist = list("cancel","guns")
				else if (map.ordinal_age == 5)
					optlist = list("cancel","helmets","mk1 brodie","m15 adrian")
				else if (map.ordinal_age == 6)
					optlist = list("cancel","helmets")
				else if (map.ordinal_age == 7)
					optlist = list("cancel","helmets","ussr heavy visored helmets","guns")
				else if (map.ordinal_age == 8)
					optlist = list("cancel","helmets","guns")

				var/choice = WWinput(H, "What do you want to craft?", "Anvil", "cancel", optlist)
				if (choice == "cancel")
					return
				var/list/newlist = list("Cancel")
				for(var/i in anvil_recipes)
					if (anvil_recipes[i])
						if (anvil_recipes[i][2] == choice && map.ordinal_age >= anvil_recipes[i][3] && map.ordinal_age <= anvil_recipes[i][4] && anvil_recipes[i][5] > 0)
							newlist += "[anvil_recipes[i][1]] - [anvil_recipes[i][5]] steel"
				var/choice2 = WWinput(H, "What do you want to craft?", "Anvil", "Cancel", newlist)
				if (choice2 == "Cancel")
					return
				var/list/parsed_choice2 = splittext(choice2," - ")
				if (anvil_recipes[parsed_choice2[1]])
					if (P.amount >= anvil_recipes[parsed_choice2[1]][5])
						user << "You begin crafting \the [parsed_choice2[1]]..."
						in_use = TRUE
						update_icon()
						if (do_after(user,10*anvil_recipes[parsed_choice2[1]][5],src,can_move=FALSE))
							if (P.amount >= anvil_recipes[parsed_choice2[1]][5])
								P.amount -= anvil_recipes[parsed_choice2[1]][5]
								if (P.amount <= 0)
									qdel(P)
								user << "You finish crafting \the [parsed_choice2[1]]."
								var/rtype = anvil_recipes[parsed_choice2[1]][9]
								new rtype (loc,"steel")

							in_use = FALSE
						else
							in_use = FALSE
						update_icon()
						return
///////////////KEVLAR//////////////
		else if (istype(P, /obj/item/stack/material/kevlar))
			var/list/optlist = list("cancel")
			if (map.ordinal_age >= 7)
				optlist = list("cancel","helmets","us lwt helmets","pasgt helmets","pasgt armor","armor")

			var/choice = WWinput(H, "What do you want to craft?", "Anvil", "cancel", optlist)
			if (choice == "cancel")
				return
			var/list/newlist = list("Cancel")
			for(var/i in anvil_recipes)
				if (anvil_recipes[i])
					if (anvil_recipes[i][2] == choice && map.ordinal_age >= anvil_recipes[i][3] && map.ordinal_age <= anvil_recipes[i][4] && anvil_recipes[i][8] > 0)
						newlist += "[anvil_recipes[i][1]] - [anvil_recipes[i][8]] kevlar"
			var/choice2 = WWinput(H, "What do you want to craft?", "Anvil", "Cancel", newlist)
			if (choice2 == "Cancel")
				return
			var/list/parsed_choice2 = splittext(choice2," - ")
			if (anvil_recipes[parsed_choice2[1]])
				if (P.amount >= anvil_recipes[parsed_choice2[1]][8])
					user << "You begin crafting \the [parsed_choice2[1]]..."
					in_use = TRUE
					update_icon()
					if (do_after(user,10*anvil_recipes[parsed_choice2[1]][8],src,can_move=FALSE))
						if (P.amount >= anvil_recipes[parsed_choice2[1]][8])
							P.amount -= anvil_recipes[parsed_choice2[1]][8]
							if (P.amount <= 0)
								qdel(P)
							user << "You finish crafting \the [parsed_choice2[1]]."
							var/rtype = anvil_recipes[parsed_choice2[1]][9]
							new rtype (loc,"kevlar")

						in_use = FALSE
					else
						in_use = FALSE
					update_icon()
					return
/////////BRONZE//////////
		else if (istype(P, /obj/item/stack/material/bronze))
			var/list/optlist = list("cancel")
			if (map.ordinal_age <= 2)
				optlist = list("cancel","shields","helmets","armor")
			else if (map.ordinal_age == 3)
				optlist = list("cancel","helmets")

			var/choice = WWinput(H, "What do you want to craft?", "Anvil", "cancel", optlist)
			if (choice == "cancel")
				return
			var/list/newlist = list("Cancel")
			for(var/i in anvil_recipes)
				if (anvil_recipes[i])
					if (anvil_recipes[i][2] == choice && map.ordinal_age >= anvil_recipes[i][3] && map.ordinal_age <= anvil_recipes[i][4] && anvil_recipes[i][7] > 0)
						newlist += "[anvil_recipes[i][1]] - [anvil_recipes[i][7]] bronze"
			var/choice2 = WWinput(H, "What do you want to craft?", "Anvil", "Cancel", newlist)
			if (choice2 == "Cancel")
				return
			var/list/parsed_choice2 = splittext(choice2," - ")
			if (anvil_recipes[parsed_choice2[1]])
				if (P.amount >= anvil_recipes[parsed_choice2[1]][7])
					user << "You begin crafting \the [parsed_choice2[1]]..."
					in_use = TRUE
					update_icon()
					if (do_after(user,10*anvil_recipes[parsed_choice2[1]][7],src,can_move=FALSE))
						if (P.amount >= anvil_recipes[parsed_choice2[1]][7])
							P.amount -= anvil_recipes[parsed_choice2[1]][7]
							if (P.amount <= 0)
								qdel(P)
							user << "You finish crafting \the [parsed_choice2[1]]."
							var/rtype = anvil_recipes[parsed_choice2[1]][9]
							new rtype (loc,"bronze")

						in_use = FALSE
					else
						in_use = FALSE
					update_icon()
					return
		else if (istype(P, /obj/item/weapon/clay/mold))
			var/obj/item/weapon/clay/mold/ML = P
			if (!ML.fired)
				user << "<span class='warning'>This mold is not fired!</span>"
				return
			else if (ML.capacity <= 0 || ML.current_material == null)
				user << "<span class='warning'>This mold is empty!</span>"
				return
			else if (!(ML.current_material in accepted_materials))
				user << "<span class='warning'>You can't use this material on this anvil.</span>"
				return
			else if (ML.craftable_classes)
				switch(ML.craftable_classes)
					if ("ingots")
						user << "You begin crafting the ingot..."
						in_use = TRUE
						update_icon()
						if (do_after(user,10*ML.capacity,src,can_move=FALSE))
							if (ML && ML.capacity)
								switch(ML.current_material)
									if ("copper")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										var/obj/item/stack/material/copper/NM = new/obj/item/stack/material/copper(loc)
										NM.amount = tamt
										user << "You finish crafting the ingot."
									if ("bronze")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										var/obj/item/stack/material/bronze/NM = new/obj/item/stack/material/bronze(loc)
										NM.amount = tamt
										user << "You finish crafting the ingot."
									if ("tin")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										var/obj/item/stack/material/tin/NM = new/obj/item/stack/material/tin(loc)
										NM.amount = tamt
										user << "You finish crafting the ingot."
									if ("gold")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										var/obj/item/stack/material/gold/NM = new/obj/item/stack/material/gold(loc)
										NM.amount = tamt
										user << "You finish crafting the ingot."
									if ("silver")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										var/obj/item/stack/material/silver/NM = new/obj/item/stack/material/silver(loc)
										NM.amount = tamt
										user << "You finish crafting the ingot."
									if ("lead")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										var/obj/item/stack/material/lead/NM = new/obj/item/stack/material/lead(loc)
										NM.amount = tamt
										user << "You finish crafting the ingot."
									if ("iron")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										var/obj/item/stack/material/iron/NM = new/obj/item/stack/material/iron(loc)
										NM.amount = tamt
										user << "You finish crafting the ingot."
									if ("steel")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										var/obj/item/stack/material/steel/NM = new/obj/item/stack/material/steel(loc)
										NM.amount = tamt
										user << "You finish crafting the steel sheet."
								ML.update_icon()

							in_use = FALSE
						else
							in_use = FALSE
						update_icon()
						return
					if ("knives")
						var/list/newlist = list("Cancel")
						var/mat = 0
						for(var/i in anvil_recipes)
							if (anvil_recipes[i])
								mat = 0
								if (ML.current_material == "bronze")
									mat = anvil_recipes[i][7]
								if (ML.current_material == "copper")
									mat = anvil_recipes[i][7]*1.2
								if (ML.current_material == "tin")
									mat = anvil_recipes[i][7]*1.4
								if (ML.current_material == "gold")
									mat = anvil_recipes[i][5]
								if (ML.current_material == "silver")
									mat = anvil_recipes[i][5]
								if (ML.current_material == "lead")
									mat = anvil_recipes[i][5]
								if (ML.current_material == "iron")
									mat = anvil_recipes[i][6]
								if (ML.current_material == "steel")
									mat = anvil_recipes[i][5]
								if (anvil_recipes[i][2] == "knives" && map.ordinal_age >= anvil_recipes[i][3] && map.ordinal_age <= anvil_recipes[i][4] && mat > 0)
									newlist += "[anvil_recipes[i][1]] - [mat] [ML.current_material]"
						var/choice2 = WWinput(H, "What do you want to craft?", "Anvil", "Cancel", newlist)
						if (choice2 == "Cancel")
							return
						var/list/parsed_choice2 = splittext(choice2," - ")
						if (anvil_recipes[parsed_choice2[1]])
							if (ML.current_material == "bronze")
								mat = anvil_recipes[parsed_choice2[1]][7]
							if (ML.current_material == "copper")
								mat = anvil_recipes[parsed_choice2[1]][7]*1.2
							if (ML.current_material == "tin")
								mat = anvil_recipes[parsed_choice2[1]][7]*1.4
							if (ML.current_material == "gold")
								mat = anvil_recipes[parsed_choice2[1]][5]
							if (ML.current_material == "silver")
								mat = anvil_recipes[parsed_choice2[1]][5]
							if (ML.current_material == "lead")
								mat = anvil_recipes[parsed_choice2[1]][5]
							if (ML.current_material == "iron")
								mat = anvil_recipes[parsed_choice2[1]][6]
							if (ML.current_material == "steel")
								mat = anvil_recipes[parsed_choice2[1]][5]
							if (ML.capacity >= mat)
								user << "You begin crafting \the [parsed_choice2[1]]..."
								in_use = TRUE
								update_icon()
								if (do_after(user,10*mat,src,can_move=FALSE))
									if (ML.capacity >= mat)
										ML.capacity -= mat
										user << "You finish crafting \the [parsed_choice2[1]]."
										var/obj/item/weapon/material/rtype = anvil_recipes[parsed_choice2[1]][9]
										new rtype (loc,ML.current_material)
										if (ML.capacity < 1)
											ML.current_material = null
											ML.capacity = 0
											ML.update_icon()

									in_use = FALSE
								else
									in_use = FALSE
								update_icon()
								return
					if ("axes")
						var/list/newlist = list("Cancel")
						var/mat = 0
						for(var/i in anvil_recipes)
							if (anvil_recipes[i])
								mat = 0
								if (ML.current_material == "bronze")
									mat = anvil_recipes[i][7]
								if (ML.current_material == "copper")
									mat = anvil_recipes[i][7]*1.2
								if (ML.current_material == "tin")
									mat = anvil_recipes[i][7]*1.4
								if (ML.current_material == "gold")
									mat = anvil_recipes[i][5]
								if (ML.current_material == "silver")
									mat = anvil_recipes[i][5]
								if (ML.current_material == "lead")
									mat = anvil_recipes[i][5]
								if (ML.current_material == "iron")
									mat = anvil_recipes[i][6]
								if (ML.current_material == "steel")
									mat = anvil_recipes[i][5]
								if (anvil_recipes[i][2] == "axes" && map.ordinal_age >= anvil_recipes[i][3] && map.ordinal_age <= anvil_recipes[i][4] && mat > 0)
									newlist += "[anvil_recipes[i][1]] - [mat] [ML.current_material]"
						var/choice2 = WWinput(H, "What do you want to craft?", "Anvil", "Cancel", newlist)
						if (choice2 == "Cancel")
							return
						var/list/parsed_choice2 = splittext(choice2," - ")
						if (anvil_recipes[parsed_choice2[1]])
							if (ML.current_material == "bronze")
								mat = anvil_recipes[parsed_choice2[1]][7]
							if (ML.current_material == "copper")
								mat = anvil_recipes[parsed_choice2[1]][7]*1.2
							if (ML.current_material == "tin")
								mat = anvil_recipes[parsed_choice2[1]][7]*1.4
							if (ML.current_material == "gold")
								mat = anvil_recipes[parsed_choice2[1]][5]
							if (ML.current_material == "silver")
								mat = anvil_recipes[parsed_choice2[1]][5]
							if (ML.current_material == "lead")
								mat = anvil_recipes[parsed_choice2[1]][5]
							if (ML.current_material == "iron")
								mat = anvil_recipes[parsed_choice2[1]][6]
							if (ML.current_material == "steel")
								mat = anvil_recipes[parsed_choice2[1]][5]
							if (ML.capacity >= mat)
								user << "You begin crafting \the [parsed_choice2[1]]..."
								in_use = TRUE
								update_icon()
								if (do_after(user,10*mat,src,can_move=FALSE))
									if (ML.capacity >= mat)
										ML.capacity -= mat
										user << "You finish crafting \the [parsed_choice2[1]]."
										var/obj/item/weapon/material/rtype = anvil_recipes[parsed_choice2[1]][9]
										new rtype (loc,ML.current_material)
										if (ML.capacity < 1)
											ML.current_material = null
											ML.capacity = 0
											ML.update_icon()

									in_use = FALSE
								else
									in_use = FALSE
								update_icon()
								return
					if ("swords")
						var/list/optlist = list("cancel")
						if (H.orc)
							optlist = list("cancel", "orkish weapons")
						else
							if (map.ordinal_age >= 4)
								optlist = list("cancel", "machetes", "swords")
							else
								optlist = list("cancel", "swords")

						var/choice = WWinput(H, "What do you want to craft?", "Anvil", "cancel", optlist)
						if (choice == "cancel")
							return
						var/list/newlist = list("Cancel")
						var/mat = 0
						for(var/i in anvil_recipes)
							if (anvil_recipes[i])
								mat = 0
								if (ML.current_material == "bronze")
									mat = anvil_recipes[i][7]
								if (ML.current_material == "copper")
									mat = anvil_recipes[i][7]*1.2
								if (ML.current_material == "iron")
									mat = anvil_recipes[i][6]
								if (ML.current_material == "steel")
									mat = anvil_recipes[i][5]
								if (anvil_recipes[i][2] == choice && map.ordinal_age >= anvil_recipes[i][3] && map.ordinal_age <= anvil_recipes[i][4] && mat > 0)
									newlist += "[anvil_recipes[i][1]] - [mat] [ML.current_material]"
						var/choice2 = WWinput(H, "What do you want to craft?", "Anvil", "Cancel", newlist)
						if (choice2 == "Cancel")
							return
						var/list/parsed_choice2 = splittext(choice2," - ")
						if (anvil_recipes[parsed_choice2[1]])
							if (ML.current_material == "bronze")
								mat = anvil_recipes[parsed_choice2[1]][7]
							if (ML.current_material == "copper")
								mat = anvil_recipes[parsed_choice2[1]][7]*1.2
							if (ML.current_material == "iron")
								mat = anvil_recipes[parsed_choice2[1]][6]
							if (ML.current_material == "steel")
								mat = anvil_recipes[parsed_choice2[1]][5]
							if (ML.capacity >= mat)
								user << "You begin crafting \the [parsed_choice2[1]]..."
								in_use = TRUE
								update_icon()
								if (do_after(user,10*mat,src,can_move=FALSE))
									if (ML.capacity >= mat)
										ML.capacity -= mat
										user << "You finish crafting \the [parsed_choice2[1]]."
										var/obj/item/weapon/material/rtype = anvil_recipes[parsed_choice2[1]][9]
										new rtype (loc,ML.current_material)
										if (ML.capacity < 1)
											ML.current_material = null
											ML.capacity = 0
											ML.update_icon()

									in_use = FALSE
								else
									in_use = FALSE
								update_icon()
								return
					if ("spearheads")
						user << "You begin crafting the [ML.current_material] spearheads..."
						in_use = TRUE
						update_icon()
						if (do_after(user,10*ML.capacity,src,can_move=FALSE))
							if (ML && ML.capacity)
								var/tamt = Floor(ML.capacity/3)
								if (tamt >= 1)
									ML.capacity = 0
									ML.update_icon()
									for (var/i=1, i<=tamt, i++)
										new/obj/item/weapon/material/part/spearhead(loc,ML.current_material)
									ML.current_material = null
									user << "You finish crafting the [ML.current_material] spearheads."

							in_use = FALSE
						else
							in_use = FALSE
						update_icon()
						return

					if ("pickaxes")
						user << "You begin crafting the [ML.current_material] pickaxe heads..."
						in_use = TRUE
						update_icon()
						if (do_after(user,10*ML.capacity,src,can_move=FALSE))
							if (ML && ML.capacity)
								var/tamt = Floor(ML.capacity/3)
								if (tamt >= 1)
									ML.capacity = 0
									ML.update_icon()
									for (var/i=1, i<=tamt, i++)
										new/obj/item/weapon/material/part/pickaxe(loc,ML.current_material)
									ML.current_material = null
									user << "You finish crafting the [ML.current_material] pickaxe heads."

							in_use = FALSE
						else
							in_use = FALSE
						update_icon()
						return
					if ("shovels")
						user << "You begin crafting the [ML.current_material] shovel head..."
						in_use = TRUE
						update_icon()
						if (do_after(user,10*ML.capacity,src,can_move=FALSE))
							if (ML && ML.capacity)
								var/tamt = Floor(ML.capacity/2)
								if (tamt >= 1)
									ML.capacity = 0
									ML.update_icon()
									for (var/i=1, i<=tamt, i++)
										new/obj/item/weapon/material/part/shovel(loc,ML.current_material)
									ML.current_material = null
									user << "You finish crafting the [ML.current_material] shovel head."

							in_use = FALSE
						else
							in_use = FALSE
						update_icon()
						return
					if ("arrowheads")
						if (ML.current_material in list("copper", "bronze", "iron", "steel"))
							user << "You begin crafting the [ML.current_material] arrowheads..."
							in_use = TRUE
							update_icon()
							if (do_after(user,10*ML.capacity,src,can_move=FALSE))
								if (ML && ML.capacity)
									var/tamt = ML.capacity
									ML.capacity = 0
									switch(ML.current_material)
										if ("copper")
											var/obj/item/stack/arrowhead/copper/AH = new/obj/item/stack/arrowhead/copper(loc)
											AH.amount = tamt*3
										if ("iron")
											var/obj/item/stack/arrowhead/iron/AH = new/obj/item/stack/arrowhead/iron(loc)
											AH.amount = tamt*3
										if ("steel")
											var/obj/item/stack/arrowhead/steel/AH = new/obj/item/stack/arrowhead/steel(loc)
											AH.amount = tamt*3
										if ("bronze")
											var/obj/item/stack/arrowhead/bronze/AH = new/obj/item/stack/arrowhead/bronze(loc)
											AH.amount = tamt*3
									ML.current_material = null
									ML.update_icon()
									user << "You finish crafting the [ML.current_material] arrowheads."

								in_use = FALSE
							else
								in_use = FALSE
							update_icon()
							return
					if ("keys")
						var/list/newlist = list("Cancel")
						var/mat = 0
						for(var/i in anvil_recipes)
							if (anvil_recipes[i])
								mat = 0
								if (ML.current_material == "bronze")
									mat = anvil_recipes[i][7]
								if (ML.current_material == "copper")
									mat = anvil_recipes[i][7]*1.2
								if (ML.current_material == "tin")
									mat = anvil_recipes[i][7]*1.4
								if (ML.current_material == "gold")
									mat = anvil_recipes[i][5]
								if (ML.current_material == "silver")
									mat = anvil_recipes[i][5]
								if (ML.current_material == "lead")
									mat = anvil_recipes[i][5]
								if (ML.current_material == "iron")
									mat = anvil_recipes[i][6]
								if (ML.current_material == "steel")
									mat = anvil_recipes[i][5]
								if (anvil_recipes[i][2] == "keys" && map.ordinal_age >= anvil_recipes[i][3] && map.ordinal_age <= anvil_recipes[i][4] && mat > 0)
									newlist += "[anvil_recipes[i][1]] - [mat] [ML.current_material]"
						var/choice2 = WWinput(H, "What do you want to craft?", "Anvil", "Cancel", newlist)
						if (choice2 == "Cancel")
							return
						var/list/parsed_choice2 = splittext(choice2," - ")
						if (anvil_recipes[parsed_choice2[1]])
							if (ML.current_material == "bronze")
								mat = anvil_recipes[parsed_choice2[1]][7]
							if (ML.current_material == "copper")
								mat = anvil_recipes[parsed_choice2[1]][7]*1.2
							if (ML.current_material == "tin")
								mat = anvil_recipes[parsed_choice2[1]][7]*1.4
							if (ML.current_material == "gold")
								mat = anvil_recipes[parsed_choice2[1]][5]
							if (ML.current_material == "silver")
								mat = anvil_recipes[parsed_choice2[1]][5]
							if (ML.current_material == "lead")
								mat = anvil_recipes[parsed_choice2[1]][5]
							if (ML.current_material == "iron")
								mat = anvil_recipes[parsed_choice2[1]][6]
							if (ML.current_material == "steel")
								mat = anvil_recipes[parsed_choice2[1]][5]
							if (ML.capacity >= mat)
								user << "You begin crafting \the [parsed_choice2[1]]..."
								in_use = TRUE
								update_icon()
								if (do_after(user,10*mat,src,can_move=FALSE))
									if (ML.capacity >= mat)
										ML.capacity -= mat
										user << "You finish crafting \the [parsed_choice2[1]]."
										var/obj/item/weapon/material/rtype = anvil_recipes[parsed_choice2[1]][9]
										new rtype (loc,ML.current_material)
										if (ML.capacity < 1)
											ML.current_material = null
											ML.capacity = 0
											ML.update_icon()

									in_use = FALSE
								else
									in_use = FALSE
								update_icon()
								return
/obj/structure/anvil/steel
	name = "steel anvil"
	desc = "An advanced steel anvil. The blacksmith's main work tool."
	icon_state = "steel_anvil"
	base_icon = "steel"
	accepted_materials = list("copper", "tin", "gold", "silver", "lead", "bronze", "iron", "steel", "kevlar")

/obj/structure/anvil/stone
	name = "stone anvil"
	desc = "A crude stone anvil. The blacksmith's main work tool."
	icon_state = "stone_anvil"
	base_icon = "stone"
	accepted_materials = list("copper", "tin", "bronze")
