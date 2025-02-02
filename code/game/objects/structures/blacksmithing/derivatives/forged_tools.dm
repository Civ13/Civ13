/////////////////////////
/* Blacksmithing Tools */
/////////////////////////

// Knife

// Hammer
/obj/item/heatable/forged/hammer
	name = "hammer"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "hammer"
	item_state = "bs_hammer"
	force = 15
	quenchable = FALSE
	handleable = TRUE
	tool_flags = TOOL_HAMMER
	slot_flags = SLOT_BACK | SLOT_BELT
	tool_multiplier = 1


//Wood Axe
/obj/item/heatable/forged/hatchet
	name = "hatchet"
	desc = "A very sharp axe blade upon a short wood handle. It has a long history of chopping things. This one is intended for chopping wood."
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "hatchet"
	item_state = "hatchet"
	force = 15
	quenchable = FALSE
	handleable = TRUE
	tool_flags = TOOL_AXE
	slot_flags = SLOT_BACK | SLOT_BELT
	tool_multiplier = 2.5


// Pickaxe
/obj/item/heatable/forged/pickaxe
	name = "pickaxe"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "pickaxe"
	item_state = "pickaxe"
	force = 15
	quenchable = FALSE
	handleable = TRUE
	tool_flags = TOOL_PICKAXE
	slot_flags = SLOT_BACK | SLOT_BELT
	tool_multiplier = 2.5


// Pickaxe
/obj/item/heatable/forged/shovel
	name = "pickaxe"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "shovel"
	item_state = "shovel"
	force = 15
	quenchable = FALSE
	handleable = TRUE
	tool_flags = TOOL_SHOVEL
	slot_flags = SLOT_BACK | SLOT_BELT


//Hammer
/obj/item/heatable/forged/sledge
	name = "sledge"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "sledge"
	force = 15
	quenchable = FALSE
	handleable = TRUE
	tool_flags = TOOL_SLEDGE
	slot_flags = SLOT_BACK | SLOT_BELT


// Tongs
/obj/item/heatable/forged/tongs
	name = "tongs"
	desc = "A set of tongs for picking up hot objects without getting burned."
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "tongs"
	item_state = "nullrod"
	force = 10
	quenchable = FALSE
	handleable = FALSE
	var/obj/item/heatable/holding = null

/obj/item/heatable/forged/tongs/attackby(obj/item/I, mob/user, params)
	if(holding)
		holding.forceMove(loc)
		holding = null
		updatesprites()
		to_chat(user, "<span class='italics'>You hit \the [holding] out of the tong's grip.</span>")
	else
		..()

/obj/item/heatable/forged/tongs/afterattack(atom/target, mob/user, proximity_flag)
	if(!proximity_flag)
		return ..()
	//Quenching
	if(istype(target, /obj/item/weapon/reagent_containers) && holding.temperature > 100)
		var/obj/item/weapon/reagent_containers/B = target
		var/check = FALSE
		for(var/reagent in B.reagents.reagent_list)
			var/datum/reagent/R = reagent
			if(R.id == "bwater" || R.id == "water" || R.id == "dwater")
				check = TRUE
				break
		if(check)
			if(holding.temperature > 500 && istype(holding, /obj/item/heatable/forged))
				var/obj/item/heatable/forged/F = holding
				F.quenched = TRUE
			to_chat(user, "<span class='italics'>You cool \the [holding].</span>")
			holding.temperature = 100
			playsound(loc, 'sound/machines/hiss.ogg', 70, 1)
			holding.updatesprites()
			updatesprites()
			return
	//Picking Up
	else if(istype(target, /obj/item/heatable))
		if(!holding)
			if(istype(target, /obj/item/heatable/forged/tongs))
				var/obj/item/heatable/forged/tongs/T = target
				if(T.holding)
					to_chat(user, "<span class='notice'>Why are you like this?</span>")
					return
			var/obj/item/heatable/H = target
			H.forceMove(src)
			holding = H
			H.pixel_x = 0
			H.pixel_y = 0
			updatesprites()
			processing_objects |= src
		else
			to_chat(user, "<span class='notice'>The tongs are already holding something.</span>")
		return
	..()

/obj/item/heatable/forged/tongs/attack_self(mob/living/user)
	if(holding)
		holding.forceMove(user.loc)
		holding = null
		updatesprites()
	else
		..()

/obj/item/heatable/forged/tongs/updatesprites()
	overlays = null
	if(holding)
		overlays += image(holding.icon, src, holding.icon_state)
	..()

/obj/item/heatable/forged/tongs/process()
	updatesprites()
	if(temperature > 20)
		temperature -= round(temperature * 0.04)
	else if(!holding)
		processing_objects -= src
		return
	else if(holding.temperature <= 20)
		processing_objects -= src
		return


// Wooden Tongs
/obj/item/heatable/forged/tongs/wooden
	name = "wooden tongs"
	desc = "Tongs for picking up hot stuff, but they're wooden so they wont last more than several uses."
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "tongs"
	var/use_counter = 3
	iconmodifier = "wood"
	namemodifier = "wood"
	ingottype = null

/obj/item/heatable/forged/tongs/wooden/attack_self(mob/living/user)
	var/check = holding
	..()
	if(check)
		use_counter--
	if(use_counter <= 0)
		to_chat(user, SPAN_WARNING("The tongs burn up and fall apart!"))
		qdel(src)

/obj/item/heatable/forged/tongs/wooden/process()
	if(temperature > 20)
		if(temperature > 100)
			processing_objects -= src
			qdel(src)
			return
		temperature -= round(temperature * 0.04)
	else
		processing_objects -= src
		return