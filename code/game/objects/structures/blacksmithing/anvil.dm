// Anvil //

/obj/structure/anvil
	density = TRUE
	anchored = TRUE
	name = "iron anvil"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "wiron-anvil"
	desc = "A heavy, flat, metal surface for hitting other metal chunks on."
	var/fuel = 0
	var/fuellimit = 40
	var/active = FALSE
	var/forgemodifier = 1

/obj/structure/anvil/proc/check_menu(mob/living/user)
	if(!istype(user))
		return FALSE
	if(user.incapacitated() || !user.Adjacent(src))
		return FALSE
	return TRUE

/obj/structure/anvil/attackby(obj/item/I, mob/user, params)
	// Toggle Anchoring
	if(istype(I, /obj/item/weapon/wrench))
		to_chat(user, SPAN_NOTICE("You begin to [anchored ? "unsecure" : "secure"] \the [src]..."))
		if (do_after(user, 20, src))
			playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
			anchored = !anchored
			user.visible_message(SPAN_NOTICE("[user] has [anchored ? "secured" : "unsecured"] \the [src]"), \
				SPAN_NOTICE("You begin to [anchored ? "secure" : "unsecure"] \the [src]."))
		return
	// Placing Items on the Anvil
	if(istype(I, /obj/item/heatable) && !istype(I, /obj/item/heatable/ingot) && !istype(I, /obj/item/heatable/forged/tongs))
		user.drop_from_inventory(I)
		I.forceMove(loc)
	// Creating Unforged Items
	else if(istype(I, /obj/item/heatable/ingot) || istype(I, /obj/item/heatable/forged/tongs))

		//-- Get Rod Item --//
		var/obj/item/heatable/ingot/X
		//From Tongs
		if(istype(I, /obj/item/heatable/forged/tongs))
			var/obj/item/heatable/forged/tongs/T = I
			//Placing non-ingot items on the Anvil
			if(!T.holding)
				return
			if(!istype(T.holding, /obj/item/heatable/ingot))
				T.holding.forceMove(loc)
				T.holding = null
				T.updatesprites()
				return
			X = T.holding
		//From Hand
		else
			X = I

		//-- Choice Selection --//
		var/list/choices[0]

		//-- Create Choices (Items & Categories) --//
		for(var/iname in GLOB.forged_recipes["[X.type]"])
			if(!GLOB.forged_recipes["[X.type]"][iname].Find("type"))
				var/empty_cat = TRUE
				for(var/ack in GLOB.forged_recipes["[X.type]"][iname])
					if(ack == "icon" || ack == "icon_state")
						continue
					if(map.ordinal_age < GLOB.forged_recipes["[X.type]"][iname][ack]["first_age"] || map.ordinal_age > GLOB.forged_recipes["[X.type]"][iname][ack]["final_age"])
						continue
					empty_cat = FALSE
					break
				if(empty_cat)
					continue
			choices[iname] = image(GLOB.forged_recipes["[X.type]"][iname]["icon"], icon_state = GLOB.forged_recipes["[X.type]"][iname]["icon_state"])
		if(!choices.len)
			return

		//-- Select Choice --//
		var/choice = show_radial_menu(user, src, choices, require_near = TRUE)
		if(choice)
			var/list/selected = null
			var/selected_name = null

			//-- Categories (Only runs IF the item is a category), ELSE it's an Item --//
			if(!GLOB.forged_recipes["[X.type]"][choice].Find("type"))
				choices = list()

				// Create Choices
				for(var/iname in GLOB.forged_recipes["[X.type]"][choice])
					if(iname == "icon" || iname == "icon_state")
						continue
					if(map.ordinal_age < GLOB.forged_recipes["[X.type]"][choice][iname]["first_age"] || map.ordinal_age > GLOB.forged_recipes["[X.type]"][choice][iname]["final_age"])
						continue
					choices[iname] = image(GLOB.forged_recipes["[X.type]"][choice][iname]["icon"], icon_state = GLOB.forged_recipes["[X.type]"][choice][iname]["icon_state"])
				if(!choices.len)
					return

				// Select Choice
				var/_choice = show_radial_menu(user, src, choices, require_near = TRUE)
				if(_choice)
					selected = GLOB.forged_recipes["[X.type]"][choice][_choice]
					selected_name = _choice
				else
					return
			else
				selected = GLOB.forged_recipes["[X.type]"][choice]
				selected_name = choice

			// Create Workpiece
			if(X.amount < selected["cost"])
				to_chat(user, "<span class='notice'>You do not have enough materials to make this ([X.amount]/[selected["cost"]]).</span>")
				return
			var/obj/item/heatable/workpiece/W = new /obj/item/heatable/workpiece(loc)
			W.result = selected["type"]
			W.hammerblows = min(selected["cost"]*3, 9)
			W.ingotvalue = selected["cost"]
			W.ingottype = X.type
			W.matmultiplier = X.multiplier
			W.name = "[W.name] [format_text(X.name)] [selected_name]"
			W.temperature = X.temperature
			W.iconmodifier = X.iconmodifier
			W.namemodifier = X.namemodifier
			W.icon = X.icon
			W.icon_state = "[initial(X.icon_state)]-[selected["cost"]]"
			W.count = selected["count"]

			// Ingot Updates
			X.amount -= selected["cost"]
			if(istype(I, /obj/item/heatable/forged/tongs))
				var/obj/item/heatable/forged/tongs/T = I
				if(X.amount <= 0)
					T.holding = null
					qdel(X)
				else
					T.holding.updatesprites()
				T.updatesprites()
			else if(X.amount <= 0)
				qdel(X)
			else
				X.updatesprites()
		return
	..()



// Anvil Subtypes //

/obj/structure/anvil/copper
	name = "copper anvil"
	icon_state = "copper-anvil"
	forgemodifier = 0.75

/obj/structure/anvil/bronze
	name = "bronze anvil"
	icon_state = "bronze-anvil"
	forgemodifier = 0.8

/obj/structure/anvil/steel
	name = "steel anvil"
	icon_state = "steel-anvil"
	forgemodifier = 1.2