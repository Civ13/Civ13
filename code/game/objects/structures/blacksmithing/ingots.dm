////////////////////////////
/* Parent Class of Ingots */
////////////////////////////

/obj/item/heatable/ingot
	name = "\improper debug steel"
	icon = 'icons/obj/resources.dmi'
	icon_state = "wroughtiron"
	var/stacklimit = 4
	var/multiplier = 1
	var/iconmodifier
	var/namemodifier
	var/meltingpoint = 1000
	var/list/forgeable[]

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

//////////////////
/* Wrought Iron */
//////////////////

/obj/item/heatable/ingot/wroughtiron
	name = "\improper wrought iron ingot"
	icon_state = "wroughtiron"
	multiplier = 1
	meltingpoint = 1540
	iconmodifier = "wiron"
	namemodifier = "wrought iron"
	forgeable = list(
		"/obj/item/heatable/forged/hammer" = list("name" = "hammer", "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-hammer-handled", "cost" = 1),
		"/obj/item/heatable/forged/sledge" = list("name" = "sledge", "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-sledge-handled", "cost" = 2),
		"/obj/item/heatable/forged/woodaxe" = list("name" = "wood axe", "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-woodaxe-handled", "cost" = 1),
		"/obj/item/heatable/forged/pickaxe" = list("name" = "pickaxe", "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-pickaxe-handled", "cost" = 2),
		"/obj/item/heatable/forged/tongs" = list("name" = "tongs", "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "wiron-tongs", "cost" = 1),
		"/obj/item/stack/sheet/ironwire" = list("name" = "iron wire", "icon" = 'icons/obj/resources.dmi', "icon_state" = "ironwire", "cost" = 1),
		"/obj/item/stack/sheet/metal" = list("name" = "metal sheet", "icon" = 'icons/obj/resources.dmi', "icon_state" = "ironplate", "cost" = 1),
		)



////////////
/* Copper */
////////////

/obj/item/heatable/ingot/copper
	name = "\improper copper ingot"
	icon_state = "copperingot"
	multiplier = 0.5
	meltingpoint = 1084
	iconmodifier = "copper"
	namemodifier = "copper"
	forgeable = list(
		"/obj/item/heatable/forged/hammer" = list("name" = "hammer", "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "copper-hammer-handled", "cost" = 1),
		"/obj/item/heatable/forged/sledge" = list("name" = "sledge", "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "copper-sledge-handled", "cost" = 2),
		"/obj/item/heatable/forged/tongs" = list("name" = "tongs", "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "copper-tongs", "cost" = 1),
		"/obj/item/heatable/forged/woodaxe" = list("name" = "wood axe", "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "copper-woodaxe-handled", "cost" = 1),
		"/obj/item/heatable/forged/pickaxe" = list("name" = "pickaxe", "icon" = 'icons/obj/blacksmithing.dmi', "icon_state" = "copper-pickaxe-handled", "cost" = 2),
		)

/////////
/* Tin */
/////////

/obj/item/heatable/ingot/tin
	name = "\improper tin ingot"
	icon_state = "tiningot"
	multiplier = 0.1
	meltingpoint = 231
	iconmodifier = "tin"
	namemodifier = "tin"
	forgeable = list()

////////////
/* Bronze */
////////////

/obj/item/heatable/ingot/brass
	name = "\improper brass ingot"
	icon_state = "brassingot"
	multiplier = 0.3
	meltingpoint = 900
	iconmodifier = "brass"
	namemodifier = "brass"
	forgeable = list()

///////////
/* Steel */
///////////

/obj/item/heatable/ingot/blistersteel
	name = "\improper blister steel ingot"
	icon_state = "blistersteel"
	multiplier = 0.5
	meltingpoint = 1250
	iconmodifier = "blistersteel"
	namemodifier = "blister steel"
	forgeable = list(
		"/obj/item/heatable/ingot/steel" = list("name" = "steel", "icon" = 'icons/obj/resources.dmi', "icon_state" = "steelingot-1", "cost" = 1),
		)

/obj/item/heatable/ingot/steel
	name = "\improper steel ingot"
	icon_state = "steelingot"
	multiplier = 1.5
	meltingpoint = 1250
	iconmodifier = "steelingot"
	namemodifier = "steel"
	forgeable = list(
		"/obj/item/stack/sheet/steel" = list("name" = "steel sheet", "icon" = 'icons/obj/resources.dmi', "icon_state" = "steelplate", "cost" = 1),
		)