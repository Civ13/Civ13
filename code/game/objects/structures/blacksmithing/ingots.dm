////////////////////////////
/* Parent Class of Ingots */
////////////////////////////
// See blacksmithing/_recipes to edit recipes

/obj/item/heatable/ingot
	name = "\improper debug steel"
	icon = 'icons/obj/resources.dmi'
	icon_state = "wroughtiron"
	var/stacklimit = 4
	var/multiplier = 1
	var/iconmodifier
	var/namemodifier
	var/meltingpoint = 1000

/obj/item/heatable/ingot/New(var/loc, var/_amount = 0)
	..()
	if(_amount)
		amount = _amount
	for(var/obj/item/heatable/ingot/I in loc)
		if(istype(I, type))
			var/change = min(amount, I.stacklimit - I.amount)
			I.add(change)
			consume(change)
			if(amount <= 0)
				break

/obj/item/heatable/ingot/attackby(obj/item/I, mob/user, params)
	if(I.type == type)
		var/obj/item/heatable/ingot/X = I
		var/change = min(amount, X.stacklimit - X.amount)
		X.temperature = ((X.temperature * X.amount) + (temperature * change)) / (X.amount + change)
		X.amount += change
		amount -= change
		X.updatesprites()
		processing_objects |= src
		if(amount <= 0)
			qdel(src)
		else
			updatesprites()
	else
		..()

/obj/item/heatable/ingot/updatesprites()
	icon_state = "[initial(icon_state)]-[amount]"
	..()

/obj/item/heatable/ingot/proc/consume(var/use)
	amount -= use
	if(amount <= 0)
		if(usr)
			usr.remove_from_mob(src)
		qdel(src)
		return
	updatesprites()

/obj/item/heatable/ingot/proc/add(var/add)
	if(add <= 0)
		return

	if(add > stacklimit)
		var/src_add = min(stacklimit - amount, add)
		amount += src_add
		var/extra = add - src_add
		while(extra > 0)
			var/obj/item/heatable/ingot/ingot = new type(get_turf(src))
			var/q = min(extra, stacklimit)
			ingot.amount = q
			ingot.updatesprites()
			extra -= q
	else
		amount += add

	updatesprites()