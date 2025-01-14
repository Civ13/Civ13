/obj/structure/anvil/copper
	name = "copper anvil"
	icon_state = "copperanvil"
	forgemodifier = 0.5

/obj/structure/anvil
	density = TRUE
	anchored = TRUE
	name = "iron anvil"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "anvil"
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
	//Placing Items on the Anvil
	if(istype(I, /obj/item/heatable) && !istype(I, /obj/item/heatable/ingot) && !istype(I, /obj/item/heatable/forged/tongs))
		user.drop_from_inventory(I)
		I.forceMove(loc)
	//Creating Unforged Items
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
		var/list/paths[0]
		//Choice Creation
		for(var/F in X.forgeable)
			if(X.amount >= X.forgeable[F]["cost"])
				choices[X.forgeable[F]["name"]] = image(X.forgeable[F]["icon"], icon_state = X.forgeable[F]["icon_state"])
				paths[X.forgeable[F]["name"]] = F
		//Choice Selected
		if(choices.len > 0)
			var/list/choice = show_radial_menu(user, src, choices, require_near = TRUE)
			if(choice != null)
				if(X.amount < X.forgeable[paths[choice]]["cost"])
					to_chat(user, "<span class='notice'>Nice try.</span>")
					return
				var/obj/item/heatable/workpiece/W = new /obj/item/heatable/workpiece(loc)
				W.result = text2path(paths[choice])
				W.hammerblows = min(X.forgeable[paths[choice]]["cost"]*3, 9)
				W.ingotvalue = X.forgeable[paths[choice]]["cost"]
				W.ingottype = X.type
				W.matmultiplier = X.multiplier
				W.name = "[W.name] [format_text(X.name)] [X.forgeable[paths[choice]]["name"]]"
				W.temperature = X.temperature
				W.iconmodifier = X.iconmodifier
				W.namemodifier = X.namemodifier
				W.icon = X.icon
				W.icon_state = "[initial(X.icon_state)]-[X.forgeable[paths[choice]]["cost"]]"
				//Ingot updates
				X.amount -= X.forgeable[paths[choice]]["cost"]
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

	else
		..()