////////////////
/* Clay Molds */
////////////////

/obj/item/claymold
	name = "\improper debug mold"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "axemold"
	var/fired = TRUE
	var/obj/mold_result = /obj/item/heatable/ingot
	var/ingot_value = 1
	var/list/allowed_metals = list()
	var/cool_time = 30
	var/metal_contained = null			// Type path of material ingot as string

/obj/item/claymold/New()
	..()
	update_icon()

/obj/item/claymold/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/heatable/forged/tongs))
		var/obj/item/heatable/forged/tongs/T = I
		if(istype(T.holding, /obj/item/heatable/crucible))
			attackby(T.holding, user)
		return
	else if(istype(I, /obj/item/heatable/crucible))
		//-- Checks --//
		if(!fired)
			to_chat(user, "<span class='notice'>\The [src] is too wet for casting.</span>")
			return
		if(metal_contained)
			to_chat(user, "<span class='notice'>\The [src] is full.</span>")
			return
		//-- Metals Contained in the Crucible --//
		var/obj/item/heatable/crucible/C = I
		var/list/metals = list()
		for(var/M in C.contained)
			if(C.contained[M]*C.meltProgress[M] >= ingot_value && allowed_metals.Find(M))
				metals.Add(M)
		if(!metals.len)
			to_chat(user, "<span class='notice'>\The [I] does not contain enough fluid to fill \the [src].</span>")
			return
		//-- Add Result to Mold and Begin Processing --//
		var/textType = metals[1]
		C.useMetal(ingot_value, textType, TRUE)
		metal_contained = textType
		processing_objects |= src
		update_icon()
		to_chat(user, "<span class='notice'>Metal pours out of \the [I], splattering audibly.</span>")
		playsound(loc, 'sound/effects/casting.ogg', 80, TRUE)
		return
	..()

/obj/item/claymold/process()
	if(cool_time <= 0)
		processing_objects -= src
		return
	cool_time--
	update_icon()

/obj/item/claymold/attack_hand(mob/living/user)
	if(metal_contained)
		if(cool_time > 0)
			to_chat(user, "<span class='italics'>You burn your hands on \the [src].</span>")
			playsound(loc, 'sound/machines/hiss.ogg', 70, 1)
			user.apply_damage(rand(1, 8), BURN, (user.hand ? "l_hand" : "r_hand"))
		else
			var/obj/item/I = result()
			to_chat(user, "<span class='notice'>\The [I] falls out of \the [src].</span>")
		return
	..()

/obj/item/claymold/proc/result()
	var/new_item
	if(ispath(mold_result, /obj/item/heatable/forged))
		var/obj/item/heatable/ingot/I = text2path(metal_contained)
		var/obj/item/heatable/forged/F = new mold_result(get_turf(src))
		F.update_values(text2path(metal_contained), initial(I.temperature), initial(I.multiplier),
						initial(I.namemodifier), ingot_value, initial(I.iconmodifier))
		new_item = F
	else if(ispath(mold_result, /obj/item/heatable/ingot))
		new_item = new metal_contained(get_turf(src))
	else
		new_item = new mold_result(get_turf(src))
	metal_contained = null
	cool_time = initial(cool_time)
	update_icon()
	return new_item

/obj/item/claymold/update_icon()
	..()
	if(fired)
		icon_state = "[initial(icon_state)]-fired"
	overlays = null
	if(metal_contained)
		var/i = icon(icon, "[initial(icon_state)]-overlay")
		var/cooled = cool_time / initial(cool_time)
		i += rgb(400*cooled, 200*cooled*cooled, 100*cooled*cooled)
		overlays += i
