/////////////
//Workpiece//
/////////////

/obj/item/heatable/workpiece
	name = "\improper unforged"
	icon = 'icons/obj/resources.dmi'
	icon_state = "wroughtiron-1"
	item_state = "sheet-metal"
	var/result = null		// Type path of the result.
	var/hammerblows = 1		// Number of hammer impacts to finish recipe.
	var/ingottype			// Type path of the ingot used to make this item.
	var/ingotvalue			// Number of ingots that have gone into making this item.
	var/last_act = 0
	var/forgetime = 15		// How long one hammer blow takes in deciseconds (seconds / 10)
	var/matmultiplier = 1	// Multiplier for force, workspeed, and such.
	var/iconmodifier		// Material string for the icon state of the result if it's a "/obj/item/heatable/forged" object.
	var/namemodifier		// Name modifier from the material used to craft this item (Ex: "unforged >>wrought iron<< hammer").
	var/count = 1			// Quantity of "result" produced.

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
				if(ispath(result, /obj/item/stack/material))
					var/obj/item/stack/S = result
					new S(loc, count)
				else if(ispath(result, /obj/item/heatable/ingot))
					var/obj/item/heatable/ingot/ingot = result
					new ingot(loc, count)
				else
					while(count > 0)
						var/obj/O = new result(loc)
						if(ispath(O, /obj/item/heatable/ingot))
							var/obj/item/heatable/ingot/ingot = O
							ingot.temperature = temperature
							ingot.update_icon()
						if(istype(O, /obj/item/heatable/forged))
							var/obj/item/heatable/forged/F = O
							F.update_values(ingottype, temperature, matmultiplier, namemodifier, ingotvalue, iconmodifier)
						count--
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
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_weapons.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_weapons.dmi',
		)
	item_state = "ammo_can"
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

/obj/item/heatable/forged/examine(mob/user)
	..()
	if(handleable && !handled)
		to_chat(user, "\The [src] has no handle!")
	if(quenchable)
		to_chat(user, "\The [src] has [quenched ? "been quenched" : "not been quenched"].")

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
	throwforce = initial(throwforce) * getmultiplier()
	tool_multiplier = initial(tool_multiplier) * getmultiplier()

/obj/item/heatable/forged/proc/updatename()
	name = "\improper [namemodifier] [initial(name)]"

/obj/item/heatable/forged/proc/getmultiplier()
	var/multiplier = matmultiplier
	if(quenchable && !quenched)
		multiplier /= 2
	if(handleable && !handled)
		multiplier /= 2
	return multiplier

/obj/item/heatable/forged/process()
	if(temperature >= 500)
		handled = FALSE
		quenched = FALSE
		updatestats()
	..()