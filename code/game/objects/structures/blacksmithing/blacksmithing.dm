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

/obj/structure/anvil/proc/forge_stack_recipe(obj/item/P, mob/user, mob/living/human/H, choice, material_index, material_name, picked = null)
	var/list/newlist = list("Cancel")
	var/valid_recipes = FALSE // Tracking if any valid recipes are found
	for(var/i in anvil_recipes)
		if (anvil_recipes[i])
			if (anvil_recipe_offered(anvil_recipes[i], choice, anvil_recipes[i][material_index], material_name))
				newlist += "[anvil_recipes[i][1]] - [anvil_recipes[i][material_index]] [material_name]" + crafting_recipe_manual_suffix(H, "[anvil_recipes[i][9]]")
				valid_recipes = TRUE // At least one valid recipe found
	if (!valid_recipes) // No valid recipes found
		to_chat(user, "There is nothing that you can craft of this type.")
		return
	// The Crafting window passes the row it already checked; everyone else is asked.
	var/choice2 = picked
	if (!choice2)
		choice2 = WWinput(H, "What do you want to craft?", "Anvil", "Cancel", newlist)
	if (choice2 == "Cancel")
		return
	var/list/parsed_choice2 = splittext(choice2," - ")
	if (anvil_recipes[parsed_choice2[1]] && crafting_recipe_allowed(H, "[anvil_recipes[parsed_choice2[1]][9]]"))
		if (P.amount >= anvil_recipes[parsed_choice2[1]][material_index] && crafting_recipe_allowed(H, "[anvil_recipes[parsed_choice2[1]][9]]"))
			to_chat(user, "You begin crafting \the [parsed_choice2[1]]...")
			in_use = TRUE
			update_icon()
			if (do_after(user,reference_build_time(H, "[anvil_recipes[parsed_choice2[1]][9]]", trade_time(user, forge_time(10*anvil_recipes[parsed_choice2[1]][material_index],anvil_recipes[parsed_choice2[1]][2]), "smith")),src,can_move=FALSE))
				if (P.amount >= anvil_recipes[parsed_choice2[1]][material_index] && crafting_recipe_allowed(H, "[anvil_recipes[parsed_choice2[1]][9]]"))
					P.amount -= anvil_recipes[parsed_choice2[1]][material_index]
					if (P.amount <= 0)
						qdel(P)
					to_chat(user, "You finish crafting \the [parsed_choice2[1]].")
					var/rtype = anvil_recipes[parsed_choice2[1]][9]
					if (!trial_craft_ruined(user, "[rtype]"))
						finish_forged_piece(apply_stock_grade(new rtype (loc,material_name), P), user, H, material_name)
						note_craft_practice(user, "[rtype]")
				in_use = FALSE
			else
				in_use = FALSE
			update_icon()
			return

// Hook for each piece forge_stack_recipe() makes from sheet metal, after its
// stock grade: quench_tub.dm clay-hardens and quenches it. Molds skip it.
/obj/structure/anvil/proc/finish_forged_piece(obj/item/made, mob/user, mob/living/human/H, material_name)
	return

// Poured mold metal pays anvil_mold_cost(); the menu, wait and payment mirror forge_stack_recipe.
/obj/structure/anvil/proc/forge_mold_recipe(obj/item/weapon/clay/mold/ML, mob/user, mob/living/human/H, category, list/materials = null)
	var/material = ML.current_material
	var/list/newlist = list("Cancel")
	if (!materials || (material in materials))
		for(var/i in anvil_recipes)
			var/mat = anvil_mold_cost(anvil_recipes[i], material)
			if (anvil_recipe_offered(anvil_recipes[i], category, mat, material, TRUE))
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
	if (!anvil_recipe_offered(row, category, mat, material, TRUE))
		return
	if (mat <= 0 || ML.capacity < mat)
		return
	to_chat(user, "You begin crafting \the [parsed_choice2[1]]...")
	in_use = TRUE
	update_icon()
	if (do_after(user,reference_build_time(H, "[row[9]]", trade_time(user, forge_time(10*mat,row[2]), "smith")),src,can_move=FALSE))
		if (ML.current_material == material && ML.capacity >= mat && crafting_recipe_allowed(H, "[row[9]]"))
			ML.capacity -= mat
			to_chat(user, "You finish crafting \the [parsed_choice2[1]].")
			var/obj/item/weapon/material/rtype = row[9]
			if (!trial_craft_ruined(user, "[rtype]"))
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
	if (!map.civilizations && !map.tribes && map.ID !=MAP_GULAG13 && (user.original_job_title != "Blacksmith" && user.original_job_title != "Pioneer Blacksmith" && user.original_job_title != "Town Blacksmith" && user.original_job_title != "Ferreiro" && user.original_job_title != "Ferrero" && user.original_job_title != "Grofsmid" && user.original_job_title != "Forgeron" && user.original_job_title != "British Blacksmith" && user.original_job_title != "Marooned Pirate Crew" && user.original_job_title != "Schmied"))
		to_chat(user, "Your job is not permitted to use this anvil on this map. Ask a blacksmith.")
		return
	if (map.tribes && (H.gorillaman || H.ant || H.wolfman || H.lizard || H.crab))
		to_chat(user, "You don't know how to use this.")
		return
	if (map.ID == MAP_FOUR_KINGDOMS && (H.gorillaman || H.ant || H.wolfman || H.lizard || H.crab))
		to_chat(user, "You don't know how to use this.")
		return
	else
		if (istype(P, /obj/item/stack/material))
			var/obj/item/stack/material/MTR = P
			// Steel sheets on a plain iron anvil weld on a steel face.
			if (istype(P, /obj/item/stack/material/steel) && type == /obj/structure/anvil)
				forge_steel_face(P, H)
				return
			if (!(MTR.default_type in accepted_materials))
				to_chat(user, "<span class='warning'>You can't use this material on this anvil.</span>")
				return
		if (istype(P, /obj/item/stack/ore/iron_pig))
			// Cast iron is too brittle to forge (steel_works.dm refines it).
			to_chat(user, SPAN_WARNING("Pig iron is too brittle to hammer: it shatters. Refine it into wrought iron in a finery forge or puddling furnace, or blow it into steel in a Bessemer converter."))
		else if (istype(P, /obj/item/stack/ore/iron_sponge/steely))
			sort_steely_bloom(P, user)
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
					spawn_stack(/obj/item/stack/material/iron, loc, amt)
				in_use = FALSE
			else
				in_use = FALSE
			update_icon()
		else if (istype(P, /obj/item/stack/material/steel/blister) && fold_blister_steel(P, H))
			return
/////////SHEET METALS//////////
		// The Crafting window lists everything this metal makes here; the pop-up menus below stay as its fallback.
		else if (anvil_window_shown(P, H))
			return
/////////IRON//////////
		else if (istype(P, /obj/item/stack/material/iron))
			var/list/optlist = stack_categories(P, H)
			var/choice = WWinput(H, "What do you want to craft?", "Anvil", "cancel", optlist)
			if (choice == "flintlock parts")
				return forge_blackpowder_part(P, H)
			if (choice == "cancel")
				return
			return forge_stack_recipe(P, user, H, choice, 6, "iron")
/////////STEEL//////////
		else if (istype(P, /obj/item/stack/material/steel))
			var/list/optlist = stack_categories(P, H)
			var/choice = WWinput(H, "What do you want to craft?", "Anvil", "cancel", optlist)
			if (choice == "flintlock parts")
				return forge_blackpowder_part(P, H)
			if (choice == "cancel")
				return
			return forge_stack_recipe(P, user, H, choice, 5, "steel")
///////////////KEVLAR//////////////
		else if (istype(P, /obj/item/stack/material/kevlar))
			var/list/optlist = stack_categories(P, H)
			var/choice = WWinput(H, "What do you want to craft?", "Anvil", "cancel", optlist)
			if (choice == "cancel")
				return
			return forge_stack_recipe(P, user, H, choice, 8, "kevlar")
/////////BRONZE//////////
		else if (istype(P, /obj/item/stack/material/bronze))
			var/list/optlist = stack_categories(P, H)
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
										spawn_stack(/obj/item/stack/material/copper, loc, tamt)
										to_chat(user, "You finish crafting the ingot.")
									if ("bronze")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										spawn_stack(/obj/item/stack/material/bronze, loc, tamt)
										to_chat(user, "You finish crafting the ingot.")
									if ("tin")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										spawn_stack(/obj/item/stack/material/tin, loc, tamt)
										to_chat(user, "You finish crafting the ingot.")
									if ("brass")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										spawn_stack(/obj/item/stack/material/brass, loc, tamt)
										to_chat(user, "You finish crafting the ingot.")
									if ("zinc")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										spawn_stack(/obj/item/stack/material/zinc, loc, tamt)
										to_chat(user, "You finish crafting the ingot.")
									if ("gold")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										spawn_stack(/obj/item/stack/material/gold, loc, tamt)
										to_chat(user, "You finish crafting the ingot.")
									if ("silver")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										spawn_stack(/obj/item/stack/material/silver, loc, tamt)
										to_chat(user, "You finish crafting the ingot.")
									if ("lead")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										spawn_stack(/obj/item/stack/material/lead, loc, tamt)
										to_chat(user, "You finish crafting the ingot.")
									if ("iron")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										spawn_stack(/obj/item/stack/material/iron, loc, tamt)
										to_chat(user, "You finish crafting the ingot.")
									if ("steel")
										var/tamt = ML.capacity
										ML.capacity = 0
										ML.current_material = null
										spawn_stack(/obj/item/stack/material/steel, loc, tamt)
										to_chat(user, "You finish crafting the steel sheet.")
								ML.update_icon()

							in_use = FALSE
						else
							in_use = FALSE
						update_icon()
						return
					if ("parts")
						return forge_mold_recipe(ML, user, H, "parts")
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
						if (!crafting_recipe_allowed(H, "/obj/item/weapon/material/part/spearhead"))
							to_chat(user, crafting_recipe_refusal(H, "/obj/item/weapon/material/part/spearhead"))
							return
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
									to_chat(user, "You finish crafting the [ML.current_material] spearheads.")
									ML.current_material = null

							in_use = FALSE
						else
							in_use = FALSE
						update_icon()
						return

					if ("pickaxes")
						if (!crafting_recipe_allowed(H, "/obj/item/weapon/material/part/pickaxe"))
							to_chat(user, crafting_recipe_refusal(H, "/obj/item/weapon/material/part/pickaxe"))
							return
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
									to_chat(user, "You finish crafting the [ML.current_material] pickaxe heads.")
									ML.current_material = null

							in_use = FALSE
						else
							in_use = FALSE
						update_icon()
						return
					if ("shovels")
						if (!crafting_recipe_allowed(H, "/obj/item/weapon/material/part/shovel"))
							to_chat(user, crafting_recipe_refusal(H, "/obj/item/weapon/material/part/shovel"))
							return
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
									to_chat(user, "You finish crafting the [ML.current_material] shovel head.")
									ML.current_material = null

							in_use = FALSE
						else
							in_use = FALSE
						update_icon()
						return
					if ("arrowheads")
						if (!(ML.current_material in list("copper", "bronze", "iron", "steel")))
							to_chat(user, "<span class='warning'>Arrowheads can only be cast from copper, bronze, iron or steel.</span>")
							return
						if (!crafting_recipe_allowed(H, "/obj/item/stack/arrowhead/[ML.current_material]"))
							to_chat(user, crafting_recipe_refusal(H, "/obj/item/stack/arrowhead/[ML.current_material]"))
							return
						to_chat(user, "You begin crafting the [ML.current_material] arrowheads...")
						in_use = TRUE
						update_icon()
						if (do_after(user,10*ML.capacity,src,can_move=FALSE))
							if (ML && ML.capacity && crafting_recipe_allowed(H, "/obj/item/stack/arrowhead/[ML.current_material]"))
								var/tamt = ML.capacity
								ML.capacity = 0
								switch(ML.current_material)
									if ("copper")
										spawn_stack(/obj/item/stack/arrowhead/copper, loc, tamt*3)
									if ("iron")
										spawn_stack(/obj/item/stack/arrowhead/iron, loc, tamt*3)
									if ("steel")
										spawn_stack(/obj/item/stack/arrowhead/steel, loc, tamt*3)
									if ("bronze")
										spawn_stack(/obj/item/stack/arrowhead/bronze, loc, tamt*3)
								to_chat(user, "You finish crafting the [ML.current_material] arrowheads.")
								ML.current_material = null
								ML.update_icon()

							in_use = FALSE
						else
							in_use = FALSE
						update_icon()
						return
					if ("keys")
						return forge_mold_recipe(ML, user, H, "keys")
// The cost column and name of a sheet metal the anvil works by hand, or null.
/obj/structure/anvil/proc/stack_metal(obj/item/P)
	if (istype(P, /obj/item/stack/material/iron))
		return list(6, "iron")
	if (istype(P, /obj/item/stack/material/steel))
		return list(5, "steel")
	if (istype(P, /obj/item/stack/material/kevlar))
		return list(8, "kevlar")
	if (istype(P, /obj/item/stack/material/bronze))
		return list(7, "bronze")
	return null

// The kinds of thing this anvil offers for a sheet metal in hand, "cancel"
// first, as the menus list them. One table for the menus and the Crafting window.
/obj/structure/anvil/proc/stack_categories(obj/item/P, mob/living/human/H)
	var/list/optlist = list("cancel")
	if (istype(P, /obj/item/stack/material/iron))
		if (H.orc)
			optlist = list("cancel", "orkish shields", "orkish headwear", "orkish helmets", "orkish armor")
		else
			optlist = era_pick(list(
				"0" = list("cancel","shields","helmets","armor"),
				"1" = list("cancel","shields","helmets","armor"),
				"2" = list("cancel","shields","helmets","other helmets","armor","other armor","other weapons","sallet helmets","japanese armor","japanese helmets","japanese headwear"),
				"3" = list("cancel","guns","helmets","other helmets","armor","other armor","other weapons","sallet helmets","japanese armor","japanese helmets","japanese headwear"),
				"4" = list("cancel","helmets"),
				"5" = list("cancel","helmets"),
				"8+" = list("cancel","armor")), optlist)
	else if (istype(P, /obj/item/stack/material/steel))
		// No Orkish armour or weapons need steel at the moment.
		if (!H.orc)
			optlist = era_pick(list(
				"2" = list("cancel","japanese armor","japanese helmets","japanese headwear", "other weapons"),
				"3" = list("cancel","japanese armor","japanese helmets","japanese headwear", "other weapons"),
				"4" = list("cancel","guns"),
				"5" = list("cancel","helmets","mk1 brodie","m15 adrian","machine guns"),
				"6" = list("cancel","helmets","machine guns"),
				"7" = list("cancel","helmets","ussr heavy visored helmets","guns","machine guns"),
				"8+" = list("cancel","helmets","guns","machine guns")), optlist)
	else if (istype(P, /obj/item/stack/material/kevlar))
		if (map.ordinal_age >= 7)
			optlist = list("cancel","helmets","us lwt helmets","pasgt helmets","pasgt armor","armor")
	else if (istype(P, /obj/item/stack/material/bronze))
		optlist = era_pick(list(
			"0" = list("cancel","shields","helmets","armor"),
			"1" = list("cancel","shields","helmets","armor"),
			"2" = list("cancel","shields","helmets","armor"),
			"3" = list("cancel","helmets")), optlist)
	else
		return null
	// Machine parts are forged in every era; orcs keep their own lists.
	if (!H.orc && (istype(P, /obj/item/stack/material/iron) || istype(P, /obj/item/stack/material/steel) || istype(P, /obj/item/stack/material/bronze)))
		optlist += "parts"
	// Only iron and steel have flintlock parts; the options proc says so for the rest.
	if (blackpowder_part_options(P, H).len > 1)
		optlist += "flintlock parts"
	return optlist

// Steel sheets an iron anvil needs to have a steel face forge-welded on.
#define ANVIL_STEEL_FACE_COST 5
// Knowing any one of these research nodes lets a smith forge-weld a steel face.
var/global/list/anvil_steel_face_nodes = list("steelmaking", "tatara_smelting", "crucible_steel")

// A wrought iron anvil with a hardened steel face, the way smiths worked steel
// for centuries before solid steel anvils: weld steel sheets onto an iron anvil.
/obj/structure/anvil/proc/forge_steel_face(obj/item/stack/material/steel/S, mob/living/human/H)
	if (in_use || !istype(S) || !istype(H))
		return FALSE
	// Names every chapter that would do, e.g. Steelmaking or Tatara Smelting.
	if (!crafting_nodes_allowed_or_warn(H, anvil_steel_face_nodes))
		return FALSE
	if (S.amount < ANVIL_STEEL_FACE_COST)
		to_chat(H, SPAN_WARNING("You need [ANVIL_STEEL_FACE_COST] steel sheets to forge-weld a steel face onto this iron anvil."))
		return FALSE
	to_chat(H, "You begin forge-welding a steel face onto the anvil...")
	in_use = TRUE
	update_icon()
	playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
	if (!do_after(H, 300 / max(H.getStatCoeff("crafting"), 0.5), src) || QDELETED(S) || S.amount < ANVIL_STEEL_FACE_COST)
		in_use = FALSE
		update_icon()
		return FALSE
	S.use(ANVIL_STEEL_FACE_COST)
	var/obj/structure/anvil/steel_faced/F = new(loc)
	F.dir = dir
	F.anchored = anchored
	to_chat(H, SPAN_NOTICE("The steel face takes. The anvil can now work steel."))
	qdel(src)
	return TRUE

#undef ANVIL_STEEL_FACE_COST

// Stack recipe guard: a solid steel anvil needs the Industrial Age. Earlier
// smiths forge-weld a steel face onto an iron anvil instead.
/datum/craft_guard/skill_gate/cast_steel_anvil
	order = 35
	message = "Solid steel anvils are cast only from the Industrial Age. Until then, forge-weld a steel face onto an iron anvil by using 5 steel sheets on it."

/datum/craft_guard/skill_gate/cast_steel_anvil/allowed(mob/living/human/H, result_type)
	return !ispath(result_type, /obj/structure/anvil/steel) || (map && map.ordinal_age >= 4)

/obj/structure/anvil/steel_faced
	name = "steel-faced anvil"
	desc = "A wrought iron anvil with a hardened steel face forge-welded onto it. Hard enough to work steel. The blacksmith's main work tool."
	icon_state = "steelfaced_anvil"
	base_icon = "steelfaced"
	accepted_materials = list("copper", "tin", "gold", "silver", "lead", "bronze", "iron", "steel", "brass", "zinc")

// A solid cast-steel anvil. Steel cheap enough to cast a whole anvil came only
// with the Industrial Age, so it is crafted from then on (craft guard above).
/obj/structure/anvil/steel
	name = "steel anvil"
	desc = "A solid cast-steel anvil. The blacksmith's main work tool."
	icon_state = "steel_anvil"
	base_icon = "steel"
	accepted_materials = list("copper", "tin", "gold", "silver", "lead", "bronze", "iron", "steel", "kevlar", "brass", "zinc")

/obj/structure/anvil/stone
	name = "stone anvil"
	desc = "A crude stone anvil. The blacksmith's main work tool."
	icon_state = "stone_anvil"
	base_icon = "stone"
	accepted_materials = list("copper", "tin", "bronze", "brass", "zinc")
