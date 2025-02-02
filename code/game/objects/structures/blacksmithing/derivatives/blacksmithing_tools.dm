//////////////////
/* Hand Bellows */
//////////////////

/obj/item/handbellows
	name = "\improper hand bellows"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "handbellows"
	var/nextuse = 0
	var/usedelay = 20

/obj/item/handbellows/proc/reset()
	nextuse = world.time + usedelay

/obj/item/handbellows/proc/ready()
	if(world.time - nextuse >= 0)
		reset()
		playsound(loc, 'sound/effects/woosh.ogg', 85, TRUE)
		return TRUE
	return FALSE



////////////////
/* Draw Plate */
////////////////

/obj/item/drawplate
	name = "drawplate"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "drawplate"
	w_class = ITEM_SIZE_SMALL

/obj/item/drawplate/attackby(obj/item/I, mob/user)
	if(istype(I, /obj/item/heatable/forged) || istype(I, /obj/item/heatable/forged/tongs))

		//-- Get Drawable Item --//
		var/obj/item/heatable/forged/FI
		//From Tongs
		if(istype(I, /obj/item/heatable/forged/tongs))
			var/obj/item/heatable/forged/tongs/T = I
			if(!T.holding)
				return ..()
			FI = T.holding
		//From Hand
		else
			FI = I
		if(!FI.draw_recipe)
			return ..()

		//-- Drawing the Item --//
		if(FI.temperature < 500)
			to_chat(user, "<span class='notice'>\The [FI] is too cold to work.</span>")
			return
		if(do_after(user, 30, target = src))
			if(FI.temperature < 500)
				to_chat(user, "<span class='notice'>Too slow dumbass, \the [FI] is too cold now.</span>")
			var/itemtype = FI.draw_recipe
			var/obj/item/newitem = new itemtype()
			newitem.forceMove(get_turf(src))
			//Transfer Values
			if(istype(newitem, /obj/item/heatable/forged))
				var/obj/item/heatable/forged/F = newitem
				F.ingottype = FI.ingottype
				F.temperature = FI.temperature
				F.matmultiplier = FI.matmultiplier
				F.namemodifier = FI.namemodifier
				F.ingotvalue = FI.ingotvalue
				F.iconmodifier = FI.iconmodifier
				F.updatestats()
				F.updatesprites()
				F.updatename()
			//Remove Item From Tongs
			if(istype(I, /obj/item/heatable/forged/tongs))
				var/obj/item/heatable/forged/tongs/T = I
				T.holding = null
				T.updatesprites()
			qdel(FI)



//////////////////
/* Metal Chisel */
//////////////////

/obj/item/chisel
	name = "metal chisel"
	icon = 'icons/obj/blacksmithing.dmi'
	icon_state = "chisel"
	w_class = ITEM_SIZE_SMALL