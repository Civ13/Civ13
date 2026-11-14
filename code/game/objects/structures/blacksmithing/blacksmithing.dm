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
	var/list/accepted_materials = list("copper", "tin", "gold", "silver","bronze", "iron", "brass", "zinc")

/obj/structure/anvil/New()
	..()

/obj/structure/anvil/update_icon()
	if (in_use)
		icon_state = "[base_icon]_anvil_use"
	else
		icon_state = "[base_icon]_anvil"

/obj/structure/anvil/proc/forge_stack_recipe(obj/item/P, mob/user, mob/living/human/H, choice, material_index, material_name)
	var/list/newlist = list("Cancel")
	var/valid_recipes = FALSE // Tracking if any valid recipes are found
	for(var/i in anvil_recipes)
		if (anvil_recipes[i])
			if (anvil_recipes[i][2] == choice && map.ordinal_age >= anvil_recipes[i][3] && recipe_age_allowed(anvil_recipes[i][4]) && anvil_recipes[i][material_index] > 0)
				newlist += "[anvil_recipes[i][1]] - [anvil_recipes[i][material_index]] [material_name]" + crafting_recipe_manual_suffix(H, "[anvil_recipes[i][9]]")
				valid_recipes = TRUE // At least one valid recipe found
	if (!valid_recipes) // No valid recipes found
		to_chat(user, "There is nothing that you can craft of this type.")
		return
	var/choice2 = WWinput(H, "What do you want to craft?", "Anvil", "Cancel", newlist)
	if (choice2 == "Cancel")
		return
	var/list/parsed_choice2 = splittext(choice2," - ")
	if (anvil_recipes[parsed_choice2[1]] && crafting_recipe_allowed(H, "[anvil_recipes[parsed_choice2[1]][9]]"))
		if (P.amount >= anvil_recipes[parsed_choice2[1]][material_index] && crafting_recipe_allowed(H, "[anvil_recipes[parsed_choice2[1]][9]]"))
			to_chat(user, "You begin crafting \the [parsed_choice2[1]]...")
			in_use = TRUE
			update_icon()
			if (do_after(user,10*anvil_recipes[parsed_choice2[1]][material_index],src,can_move=FALSE))
				if (P.amount >= anvil_recipes[parsed_choice2[1]][material_index] && crafting_recipe_allowed(H, "[anvil_recipes[parsed_choice2[1]][9]]"))
					P.amount -= anvil_recipes[parsed_choice2[1]][material_index]
					if (P.amount <= 0)
						qdel(P)
					to_chat(user, "You finish crafting \the [parsed_choice2[1]].")
					var/rtype = anvil_recipes[parsed_choice2[1]][9]
					new rtype (loc,material_name)
					note_craft_practice(user, "[rtype]")
				in_use = FALSE
			else
				in_use = FALSE
			update_icon()
			return

// Poured mold metal pays anvil_mold_cost(); the menu, wait and payment mirror forge_stack_recipe.
/obj/structure/anvil/proc/forge_mold_recipe(obj/item/weapon/clay/mold/ML, mob/user, mob/living/human/H, category, list/materials = null)
	var/material = ML.current_material
	var/list/newlist = list("Cancel")
	if (!materials || (material in materials))
		for(var/i in anvil_recipes)
			var/mat = anvil_mold_cost(anvil_recipes[i], material)
			if (anvil_recipe_offered(anvil_recipes[i], category, mat))
				newlist += "[anvil_recipes[i][1]] - [mat] [material]" + crafting_recipe_manual_suffix(H, "[anvil_recipes[i][9]]")
	if (newlist.len <= 1)
		to_chat(user, "There is nothing that you can craft of this type.")
		return
	var/choice2 = WWinput(H, "What do you want to craft?", "Anvil", "Cancel", newlist)
	if (choice2 == "Cancel")
		return
	var/list/parsed_choice2 = splittext(choice2," - ")
	var/list/row = anvil_recipes[parsed_choice2[1]]
	if (!row || !crafting_recipe_allowed(H, "[row[9]]"))
		return
	var/mat = anvil_mold_cost(row, material)
	if (mat <= 0 || ML.capacity < mat)
		return
	to_chat(user, "You begin crafting \the [parsed_choice2[1]]...")
	in_use = TRUE
	update_icon()
	if (do_after(user,10*mat,src,can_move=FALSE))
		if (ML.current_material == material && ML.capacity >= mat && crafting_recipe_allowed(H, "[row[9]]"))
			ML.capacity -= mat
			to_chat(user, "You finish crafting \the [parsed_choice2[1]].")
			var/obj/item/weapon/material/rtype = row[9]
			new rtype (loc,material)
			note_craft_practice(user, "[rtype]")
			if (ML.capacity < 1)
				ML.current_material = null
				ML.capacity = 0
				ML.update_icon()
	in_use = FALSE
	update_icon()

/obj/structure/anvil/attackby(obj/item/P as obj, mob/user as mob)
	var/mob/living/human/H = user
	if (is_tool(P, TOOL_WRENCH))
		toggle_anchor(user)
	var/crafting_coefficient = H.getStatCoeff("crafting")
	if (crafting_coefficient < 1.2)
		to_chat(user, "This anvil requires an effective Crafting coefficient of at least 1.20x; yours is [num2text(crafting_coefficient, 9)]x. Check IC > Skill Progress for Crafting progress; mood and traits affect the effective coefficient.")
		return
	if (!map.civilizations && map.ID != MAP_TRIBES && map.ID != MAP_THREE_TRIBES && map.ID != MAP_FOUR_KINGDOMS && map.ID !=MAP_GULAG13 && (user.original_job_title != "Blacksmith" && user.original_job_title != "Pioneer Blacksmith" && user.original_job_title != "Town Blacksmith" && user.original_job_title != "Ferreiro" && user.original_job_title != "Ferrero" && user.original_job_title != "Grofsmid" && user.original_job_title != "Forgeron" && user.original_job_title != "British Blacksmith" && user.original_job_title != "Marooned Pirate Crew" && user.original_job_title != "Schmied"))
		to_chat(user, "Your job is not permitted to use this anvil on this map. Ask a blacksmith.")
		return
	if ((map.ID == MAP_TRIBES || map.ID == MAP_THREE_TRIBES || map.ID == MAP_FOUR_KINGDOMS) && (H.gorillaman || H.ant || H.wolfman || H.lizard || H.crab))
		to_chat(user, "You don't know how to use this.")
		return
	if (map.ID == MAP_FOUR_KINGDOMS && (H.gorillaman || H.ant || H.wolfman || H.lizard || H.crab))
		to_chat(user, "You don't know how to use this.")
		return
	else
		if (istype(P, /obj/item/stack/material))
			var/obj/item/stack/material/MTR = P
			if (!(MTR.default_type in accepted_materials))
				to_chat(user, "<span class='warning'>You can't use this material on this anvil.</span>")
				return
		if (istype(P, /obj/item/stack/ore/iron_pig))
			if (!("iron" in accepted_materials))
				to_chat(user, "<span class='warning'>You can't use this material on this anvil.</span>")
				return
			to_chat(user, "You begin smithing the pig iron...")
			icon_state = "[base_icon]_anvil_use"
			in_use = TRUE
			update_icon()
			playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
			var/initial_amount = P.amount //no more speedhack
			if (do_after(user,15*initial_amount,src) && P.amount == initial_amount)
				to_chat(user, "<span class='notice'>You smite the pig into steel.</span>")
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
			to_chat(user, "You begin smithing the sponge iron...")
			icon_state = "[base_icon]_anvil_use"
			in_use = TRUE
			update_icon()
			playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
			var/initial_amount = P.amount //no more speedhack
			if (do_after(user,15*initial_amount,src) && P.amount == initial_amount)
				to_chat(user, "<span class='notice'>You smite the sponge iron into wrought iron.</span>")
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
				if (blackpowder_part_options(P, H).len > 1)
					optlist += "flintlock parts"
				var/choice = WWinput(H, "What do you want to craft?", "Anvil", "cancel", optlist)
				if (choice == "flintlock parts")
					return forge_blackpowder_part(P, H)
				if (choice == "cancel")
					return
				return forge_stack_recipe(P, user, H, choice, 6, "iron")
			else
				optlist = era_pick(list(
					"0" = list("cancel","shields","helmets","armor"),
					"1" = list("cancel","shields","helmets","armor"),
					"2" = list("cancel","shields","helmets","other helmets","armor","other armor","other weapons","sallet helmets","japanese armor","japanese helmets","japanese headwear"),
					"3" = list("cancel","guns","helmets","other helmets","armor","other armor","other weapons","sallet helmets","japanese armor","japanese helmets","japanese headwear"),
					"4" = list("cancel","helmets"),
					"5" = list("cancel","helmets"),
					"8+" = list("cancel","armor")), optlist)
				if (blackpowder_part_options(P, H).len > 1)
					optlist += "flintlock parts"
				var/choice = WWinput(H, "What do you want to craft?", "Anvil", "cancel", optlist)
				if (choice == "flintlock parts")
					return forge_blackpowder_part(P, H)
				if (choice == "cancel")
					return
				return forge_stack_recipe(P, user, H, choice, 6, "iron")
/////////STEEL//////////
		else if (istype(P, /obj/item/stack/material/steel))
			var/list/optlist = list("cancel")
			if (H.orc)
				//optlist = list("cancel", "orkish shields", "orkish headwear", "orkish helmets") //disabled for now, as no Orkish armour and weapons require steel at the moment
				if (blackpowder_part_options(P, H).len > 1)
					optlist += "flintlock parts"
				var/choice = WWinput(H, "What do you want to craft?", "Anvil", "cancel", optlist)
				if (choice == "flintlock parts")
					return forge_blackpowder_part(P, H)
				if (choice == "cancel")
					return
				return forge_stack_recipe(P, user, H, choice, 5, "steel")
			else
				optlist = era_pick(list(
					"2" = list("cancel","japanese armor","japanese helmets","japanese headwear", "other weapons"),
					"3" = list("cancel","japanese armor","japanese helmets","japanese headwear", "other weapons"),
					"4" = list("cancel","guns"),
					"5" = list("cancel","helmets","mk1 brodie","m15 adrian","machine guns"),
					"6" = list("cancel","helmets","machine guns"),
					"7" = list("cancel","helmets","ussr heavy visored helmets","guns","machine guns"),
					"8+" = list("cancel","helmets","guns","machine guns")), optlist)

				if (blackpowder_part_options(P, H).len > 1)
					optlist += "flintlock parts"
				var/choice = WWinput(H, "What do you want to craft?", "Anvil", "cancel", optlist)
				if (choice == "flintlock parts")
					return forge_blackpowder_part(P, H)
				if (choice == "cancel")
					return
				return forge_stack_recipe(P, user, H, choice, 5, "steel")
///////////////KEVLAR//////////////
		else if (istype(P, /obj/item/stack/material/kevlar))
			var/list/optlist = list("cancel")
			if (map.ordinal_age >= 7)
				optlist = list("cancel","helmets","us lwt helmets","pasgt helmets","pasgt armor","armor")

			var/choice = WWinput(H, "What do you want to craft?", "Anvil", "cancel", optlist)
			if (choice == "cancel")
				return
			return forge_stack_recipe(P, user, H, choice, 8, "kevlar")
/////////BRONZE//////////
		else if (istype(P, /obj/item/stack/material/bronze))
			var/list/optlist = list("cancel")
			optlist = era_pick(list(
				"0" = list("cancel","shields","helmets","armor"),
				"1" = list("cancel","shields","helmets","armor"),
				"2" = list("cancel","shields","helmets","armor"),
				"3" = list("cancel","helmets")), optlist)

			var/choice = WWinput(H, "What do you want to craft?", "Anvil", "cancel", optlist)
			if (choice == "cancel")
				return
			return forge_stack_recipe(P, user, H, choice, 7, "bronze")
		else if (istype(P, /obj/item/weapon/clay/mold))
			var/obj/item/weapon/clay/mold/ML = P
			if (!ML.fired)
				to_chat(user, "<span class='warning'>This mold is not fired!</span>")
				return
			else if (ML.capacity <= 0 || ML.current_material == null)
				to_chat(user, "<span class='warning'>This mold is empty!</span>")
				return
			else if (!(ML.current_material in accepted_materials))
				to_chat(user, "<span class='warning'>You can't use this material on this anvil.</span>")
				return
			else if (ML.craftable_classes)
				switch(ML.craftable_classes)
					if ("ingots")
						to_chat(user, "You begin crafting the ingot...")
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
										to_chat(user, "You finish crafting the ingot.")
									if ("bronze")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										var/obj/item/stack/material/bronze/NM = new/obj/item/stack/material/bronze(loc)
										NM.amount = tamt
										to_chat(user, "You finish crafting the ingot.")
									if ("tin")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										var/obj/item/stack/material/tin/NM = new/obj/item/stack/material/tin(loc)
										NM.amount = tamt
										to_chat(user, "You finish crafting the ingot.")
									if ("brass")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										var/obj/item/stack/material/brass/NM = new/obj/item/stack/material/brass(loc)
										NM.amount = tamt
										to_chat(user, "You finish crafting the ingot.")
									if ("zinc")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										var/obj/item/stack/material/zinc/NM = new/obj/item/stack/material/zinc(loc)
										NM.amount = tamt
										to_chat(user, "You finish crafting the ingot.")
									if ("gold")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										var/obj/item/stack/material/gold/NM = new/obj/item/stack/material/gold(loc)
										NM.amount = tamt
										to_chat(user, "You finish crafting the ingot.")
									if ("silver")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										var/obj/item/stack/material/silver/NM = new/obj/item/stack/material/silver(loc)
										NM.amount = tamt
										to_chat(user, "You finish crafting the ingot.")
									if ("lead")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										var/obj/item/stack/material/lead/NM = new/obj/item/stack/material/lead(loc)
										NM.amount = tamt
										to_chat(user, "You finish crafting the ingot.")
									if ("iron")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										var/obj/item/stack/material/iron/NM = new/obj/item/stack/material/iron(loc)
										NM.amount = tamt
										to_chat(user, "You finish crafting the ingot.")
									if ("steel")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										var/obj/item/stack/material/steel/NM = new/obj/item/stack/material/steel(loc)
										NM.amount = tamt
										to_chat(user, "You finish crafting the steel sheet.")
								ML.update_icon()

							in_use = FALSE
						else
							in_use = FALSE
						update_icon()
						return
					if ("knives")
						return forge_mold_recipe(ML, user, H, "knives")
					if ("axes")
						return forge_mold_recipe(ML, user, H, "axes")
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
						return forge_mold_recipe(ML, user, H, choice, list("bronze", "copper", "iron", "steel"))
					if ("spearheads")
						if (!crafting_recipe_allowed(H, "/obj/item/weapon/material/part/spearhead")) return
						to_chat(user, "You begin crafting the [ML.current_material] spearheads...")
						in_use = TRUE
						update_icon()
						if (do_after(user,10*ML.capacity,src,can_move=FALSE))
							if (ML && ML.capacity && crafting_recipe_allowed(H, "/obj/item/weapon/material/part/spearhead"))
								var/tamt = Floor(ML.capacity/3)
								if (tamt >= 1)
									ML.capacity = 0
									ML.update_icon()
									for (var/i=1, i<=tamt, i++)
										new/obj/item/weapon/material/part/spearhead(loc,ML.current_material)
									ML.current_material = null
									to_chat(user, "You finish crafting the [ML.current_material] spearheads.")

							in_use = FALSE
						else
							in_use = FALSE
						update_icon()
						return

					if ("pickaxes")
						if (!crafting_recipe_allowed(H, "/obj/item/weapon/material/part/pickaxe")) return
						to_chat(user, "You begin crafting the [ML.current_material] pickaxe heads...")
						in_use = TRUE
						update_icon()
						if (do_after(user,10*ML.capacity,src,can_move=FALSE))
							if (ML && ML.capacity && crafting_recipe_allowed(H, "/obj/item/weapon/material/part/pickaxe"))
								var/tamt = Floor(ML.capacity/3)
								if (tamt >= 1)
									ML.capacity = 0
									ML.update_icon()
									for (var/i=1, i<=tamt, i++)
										new/obj/item/weapon/material/part/pickaxe(loc,ML.current_material)
									ML.current_material = null
									to_chat(user, "You finish crafting the [ML.current_material] pickaxe heads.")

							in_use = FALSE
						else
							in_use = FALSE
						update_icon()
						return
					if ("shovels")
						if (!crafting_recipe_allowed(H, "/obj/item/weapon/material/part/shovel")) return
						to_chat(user, "You begin crafting the [ML.current_material] shovel head...")
						in_use = TRUE
						update_icon()
						if (do_after(user,10*ML.capacity,src,can_move=FALSE))
							if (ML && ML.capacity && crafting_recipe_allowed(H, "/obj/item/weapon/material/part/shovel"))
								var/tamt = Floor(ML.capacity/2)
								if (tamt >= 1)
									ML.capacity = 0
									ML.update_icon()
									for (var/i=1, i<=tamt, i++)
										new/obj/item/weapon/material/part/shovel(loc,ML.current_material)
									ML.current_material = null
									to_chat(user, "You finish crafting the [ML.current_material] shovel head.")

							in_use = FALSE
						else
							in_use = FALSE
						update_icon()
						return
					if ("arrowheads")
						if (!crafting_recipe_allowed(H, "/obj/item/stack/arrowhead/[ML.current_material]")) return
						if (ML.current_material in list("copper", "bronze", "iron", "steel"))
							to_chat(user, "You begin crafting the [ML.current_material] arrowheads...")
							in_use = TRUE
							update_icon()
							if (do_after(user,10*ML.capacity,src,can_move=FALSE))
								if (ML && ML.capacity && crafting_recipe_allowed(H, "/obj/item/stack/arrowhead/[ML.current_material]"))
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
									to_chat(user, "You finish crafting the [ML.current_material] arrowheads.")

								in_use = FALSE
							else
								in_use = FALSE
							update_icon()
							return
					if ("keys")
						return forge_mold_recipe(ML, user, H, "keys")
/obj/structure/anvil/steel
	name = "steel anvil"
	desc = "An advanced steel anvil. The blacksmith's main work tool."
	icon_state = "steel_anvil"
	base_icon = "steel"
	accepted_materials = list("copper", "tin", "gold", "silver", "lead", "bronze", "iron", "steel", "kevlar", "brass", "zinc")

/obj/structure/anvil/stone
	name = "stone anvil"
	desc = "A crude stone anvil. The blacksmith's main work tool."
	icon_state = "stone_anvil"
	base_icon = "stone"
	accepted_materials = list("copper", "tin", "bronze", "brass", "zinc")
