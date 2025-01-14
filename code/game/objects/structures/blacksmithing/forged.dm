/////////////
//Workpiece//
/////////////

/obj/item/heatable/workpiece
	name = "\improper unforged"
	icon = 'icons/obj/resources.dmi'
	icon_state = "wroughtiron-1"
	item_state = "sheet-metal"
	var/result = null
	var/hammerblows = 1
	var/ingottype
	var/ingotvalue
	var/last_act = 0
	var/forgetime = 15 // How long one hammer blow takes in deciseconds (seconds / 10)
	var/matmultiplier = 1
	var/iconmodifier
	var/namemodifier

/obj/item/heatable/workpiece/attackby(obj/item/I, mob/user, params)
	//Forging
	if(istype(I, /obj/item/heatable/forged/hammer))

		//Spam Prevention
		if(last_act + forgetime > world.time)
			to_chat(user, "<span class='notice'>Slow your roll.</span>")
			return
		else
			last_act = world.time

		//Hammer Handle Check
		if(istype(I, /obj/item/heatable/forged/hammer))
			var/obj/item/heatable/forged/H = I
			if(!H.handled)
				to_chat(user, "<span class='notice'>A whole lot of good that hammer's gonna do you without a handle...</span>")
				return

		//Anvil Detection
		var/obj/structure/anvil/anvil = null
		for(var/C in loc.contents)
			if(istype(C, /obj/structure/anvil))
				anvil = C
				break
		var/anvilmodifier
		if(!anvil)
			anvilmodifier = 0.25
		else
			anvilmodifier = anvil.forgemodifier

		//Forging Action
		var/obj/item/heatable/forged/hammer/H = I
		if(do_after(user, forgetime, target = src))
			//Hammer Blows
			playsound(loc, 'sound/effects/clang.ogg', 70, 1)
			if(temperature < 550)
				to_chat(user, "<span class='italics'>You hit \the [src] but it is not hot enough to forge.</span>")
				return
			hammerblows -= anvilmodifier * H.getmultiplier()
			//Finished Product
			if(hammerblows <= 0)
				var/obj/O = new result(loc)
				if(istype(O, /obj/item/heatable/ingot))
					var/obj/item/heatable/ingot/ingot = O
					ingot.temperature = temperature
					ingot.update_icon()
				if(istype(O, /obj/item/stack/material))
					var/obj/item/stack/S = O
					S.amount = INGOT_VALUE
				if(istype(O, /obj/item/heatable/forged))
					var/obj/item/heatable/forged/F = O
					F.update_values(ingottype, temperature, matmultiplier, namemodifier, ingotvalue, iconmodifier)
				qdel(src)
			else
				attackby(I, user)
		return
	..()


////////////////////////////////////
//Parent Class of Forging Products//
////////////////////////////////////

/obj/item/heatable/forged
	name = "debug sword"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "hammer"
	force = 30
	slowdown = 0.3
	var/handled = FALSE
	var/handleable = FALSE
	var/quenched = FALSE
	var/quenchable = FALSE
	var/ingotvalue = 1
	var/iconmodifier = "wiron"
	var/namemodifier = "wrought iron"
	var/matmultiplier = 1
	var/ingottype = /obj/item/heatable/ingot/wroughtiron
	var/draw_recipe

/obj/item/heatable/forged/New()
	..()
	updatestats()
	updatesprites()
	updatename()

/obj/item/heatable/forged/updatesprites()
	icon_state = "[iconmodifier]-[initial(icon_state)]"
	if(handled)
		icon_state += "-handled"
	..()

/obj/item/heatable/forged/proc/update_values(var/_ingottype, var/_temperature, var/_matmultiplier,
											var/_namemodifier, var/_ingotvalue, var/_iconmodifier)
	ingottype = _ingottype
	temperature = _temperature
	matmultiplier = _matmultiplier
	namemodifier = _namemodifier
	ingotvalue = _ingotvalue
	iconmodifier = _iconmodifier
	updatestats()
	updatesprites()
	updatename()

/obj/item/heatable/forged/proc/updatestats()
	force = initial(force) * getmultiplier()

/obj/item/heatable/forged/proc/updatename()
	name = "\improper [namemodifier] [initial(name)]"


/obj/item/heatable/forged/attackby(obj/item/I, mob/user, params)
	if(handleable && !handled && istype(I, /obj/item/weapon/material/handle))
		if(temperature > 500)
			to_chat(user, "<span class='notice'>You would scorch the handle if you put it in right now.</span>")
			return
		qdel(I)
		handled = TRUE
		updatestats()
		updatesprites()
	else
		..()

/obj/item/heatable/forged/proc/getmultiplier()
	var/multiplier = matmultiplier
	if(handleable && !handled)
		multiplier /= 2
	if(quenchable && !quenched)
		multiplier /= 2
	return multiplier

/obj/item/heatable/forged/process()
	if(temperature >= 500)
		handled = FALSE
		quenched = FALSE
		updatestats()
	..()

/////////
//Tools//
/////////

//Hammer
/obj/item/heatable/forged/hammer
	name = "hammer"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "hammer"
	force = 15
	quenchable = FALSE
	handleable = TRUE

//Pickaxe
/obj/item/heatable/forged/pickaxe
	name = "pickaxe"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "pickaxe"
	force = 15
	quenchable = FALSE
	handleable = TRUE

//Tongs
/obj/item/heatable/forged/tongs
	name = "tongs"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "tongs"
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