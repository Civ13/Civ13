#define BOTTLE_SPRITES list("bottle-1", "bottle-2", "bottle-3", "bottle-4") //list of available bottle sprites
#define REAGENTS_PER_SHEET 20


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/obj/structure/chemical_dispenser
	name = "chemical dispenser"
	density = TRUE
	anchored = TRUE
	icon = 'icons/obj/chemical.dmi'
	icon_state = "dispenser"
	var/ui_title = "Chemical Dispenser"
	var/amount = 30
	var/accept_glass = FALSE //At FALSE ONLY accepts glass containers. Kinda misleading varname.
	var/atom/beaker = null
	var/list/dispensable_reagents = list()
	var/stat = 0
	var/is_medical = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	flammable = TRUE

/obj/structure/chemical_dispenser/full
	New()
		..()
		var/list/elements = list("hydrogen", "helium", "lithium", "nitrogen", "oxygen", "fluorine", "sodium", "magnesium", "aluminum", "silicon", "phosphorus", "chlorine", "potassium", "calcium", "arsenic", "iodine", "tungsten", "radium", "thorium", "bromine")
		for (var/i in elements)
			dispensable_reagents += list(list(i,100))

/obj/structure/chemical_dispenser/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			if (prob(50))
				qdel(src)
				return

/obj/structure/chemical_dispenser/drugs
	New()
		..()
		var/list/elements = list("thc", "ketamine", "pervitin", "cocaine", "oxygen")
		for (var/i in elements)
			dispensable_reagents += list(list(i,100))

/obj/structure/chemical_dispenser/debug
	New()
		..()
		var/list/elements = list("thc", "ketamine", "pervitin", "cocaine", "hydrogen", "helium", "lithium", "nitrogen", "oxygen", "fluorine", "sodium", "magnesium", "aluminum", "silicon", "phosphorus", "chlorine", "potassium", "calcium", "arsenic", "iodine", "tungsten", "radium", "thorium", "bromine", "blood", "phosgene_gas", "zyklon_b", "Chlorine Gas", "White Phosphorus Gas", "mustard_gas", "Xylyl Bromide", "plasticide", "amatoxin", "carpotoxin", "plasma", "cyanide", "cholera", "potassium_chloride", "potassium_chlorophoride", "zombiepowder", "fertilizer", "eznutrient", "left4zed", "robustharvest", "pacid", "lexorin", "stoxin", "chloralhydrate", "peyote", "serotrotium", "cryptobiolin", "impedrezene", "mindbreaker", "psilocybin", "nicotine", "bleach", "solanine", "nitroglycerin", "gunpowder", "lube", "biodiesel", "diesel", "gasoline", "petroleum", "luminol", "glue", "cleaner", "adminordrazine", "adrenaline", "anti_toxin", "charcoal", "tricordrazine", "paracetamol", "tramadol", "oxycodone", "synaptizine", "alkysine", "imidazoline", "peridaxon", "hyperzine", "potassium_iodide", "penicillin", "prontosil", "opium", "methamphetamine", "paroxetine", "citalopram", "methylphenidate", "morphine", "pen_acid", "sal_acid")
		for (var/i in elements)
			dispensable_reagents += list(list(i,1000))

/obj/structure/chemical_dispenser/drinks
	is_medical = FALSE
	New()
		..()
		var/list/elements = list("honey", "cola", "mint", "banana", "grapejuice", "grapejuice", "milk", "coffee", "tonic", "milkshake", "cognac", "gin", "kahlua", "watermelonliquor", "rum", "tequilla", "vodka", "whiskey")
		for (var/i in elements)
			dispensable_reagents += list(list(i,400))

/obj/structure/chemical_dispenser/soda
	name = "soda dispenser"
	icon_state = "soda_dispenser"
	ui_title = "Soda Dispenser"
	accept_glass = TRUE
	is_medical = FALSE
	New()
		..()
		var/list/elements = list("ice","water","cola","lemonade","lemonjuice","limejuice","orangejuice","applejuice","tomatojuice","tonic")
		for (var/i in elements)
			dispensable_reagents += list(list(i,400))

/obj/structure/chemical_dispenser/juice
	name = "juice dispenser"
	icon_state = "soda_dispenser"
	ui_title = "Juice Dispenser"
	accept_glass = TRUE
	is_medical = FALSE
	New()
		..()
		var/list/elements = list("banana", "grapejuice", "berryjuice","carrotjuice","lemonjuice","limejuice","orangejuice","applejuice","tomatojuice","watermelonjuice")
		for (var/i in elements)
			dispensable_reagents += list(list(i,400))

/obj/structure/chemical_dispenser/alcohol
	name = "alcoholic beverages dispenser"
	icon_state = "booze_dispenser"
	ui_title = "Alcoholic Beverages Dispenser"
	accept_glass = TRUE
	is_medical = FALSE
	New()
		..()
		var/list/elements = list("ice","ale","beer","wheatbeer","cider","cognac", "gin", "kahlua", "watermelonliquor", "rum", "tequilla", "vodka", "whiskey","mezcal","vermouth")
		for (var/i in elements)
			dispensable_reagents += list(list(i,400))

/obj/structure/chemical_dispenser/coffee
	name = "coffee dispenser"
	icon_state = "coffee_dispenser"
	ui_title = "Coffee Dispenser"
	accept_glass = TRUE
	is_medical = FALSE
	New()
		..()
		var/list/elements = list("ice","coffee","tea","hot_coco","milkshake","milk","cream")
		for (var/i in elements)
			dispensable_reagents += list(list(i,400))
 /**
  * The ui_interact proc is used to open and update Nano UIs
  * If ui_interact is not used then the UI will not update correctly
  * ui_interact is currently defined for /atom/movable
  *
  * @param user /mob The mob who is interacting with this ui
  * @param ui_key string A string key to use for this ui. Allows for multiple unique uis on one obj/mob (defaut value "main")
  *
  * @return nothing
  */
/obj/structure/chemical_dispenser/ui_interact(mob/user, ui_key = "main",var/datum/nanoui/ui = null, var/force_open = TRUE)
	if (user.stat || user.restrained()) return
	var/mob/living/human/H = user
	if (src.is_medical)
		if (istype(H) && H.getStatCoeff("medical") < GET_MIN_STAT_COEFF(STAT_MEDIUM_HIGH))
			H << "<span class = 'danger'>These chemicals are too complex for you to understand.</span>"
			return
	// this is the data which will be sent to the ui
	var/data[0]
	data["amount"] = amount
	data["isBeakerLoaded"] = beaker ? TRUE : FALSE
	data["glass"] = accept_glass
	var beakerContents[0]
	var beakerCurrentVolume = FALSE
	if (beaker && beaker:reagents && beaker:reagents.reagent_list.len)
		for (var/datum/reagent/R in beaker:reagents.reagent_list)
			beakerContents.Add(list(list("name" = R.name, "volume" = R.volume))) // list in a list because Byond merges the first list...
			beakerCurrentVolume += R.volume
	data["beakerContents"] = beakerContents

	if (beaker)
		data["beakerCurrentVolume"] = beakerCurrentVolume
		data["beakerMaxVolume"] = beaker:volume
	else
		data["beakerCurrentVolume"] = null
		data["beakerMaxVolume"] = null

	var chemicals[0]
	for (var/list/re in dispensable_reagents)
		if (re[2] > 0)
			var/datum/reagent/temp = chemical_reagents_list[re[1]]
			if (temp)
				chemicals.Add(list(list("title" = "[temp.name] ([re[2]])", "id" = temp.id, "commands" = list("dispense" = temp.id)))) // list in a list because Byond merges the first list...
	data["chemicals"] = chemicals

	// update the ui if it exists, returns null if no ui is passed/found
	ui = nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		// the ui does not exist, so we'll create a new() one
		// for a list of parameters and their descriptions see the code docs in \code\modules\nano\nanoui.dm
		ui = new(user, src, ui_key, "chem_disp.tmpl", ui_title, 390, 655)
		// when the ui is first opened this is the data it will use
		ui.set_initial_data(data)
		// open the new ui window
		ui.open()

/obj/structure/chemical_dispenser/Topic(href, href_list)

	if (href_list["amount"])
		amount = round(text2num(href_list["amount"]), 5) // round to nearest 5
		if (amount < 0) // Since the user can actually type the commands himself, some sanity checking
			amount = FALSE
		if (amount > 120)
			amount = 120

	if (href_list["dispense"])
		if (beaker != null && beaker.is_open_container())
			for (var/list/l in dispensable_reagents)
				if (l[1] == href_list["dispense"] && l[2] > 0)
					var/obj/item/weapon/reagent_containers/B = beaker
					var/datum/reagents/R = B.reagents
					var/space = R.maximum_volume - R.total_volume
					var/added_amount = min(min(amount, space),l[2])
					l[2] -= added_amount
					R.add_reagent(href_list["dispense"], added_amount)
					sanitize_reagents()
	if (href_list["ejectBeaker"])
		if (beaker)
			var/obj/item/weapon/reagent_containers/B = beaker
			B.loc = loc
			beaker = null

	add_fingerprint(usr)
	return TRUE // update UIs attached to this object

/obj/structure/chemical_dispenser/attackby(var/obj/item/weapon/reagent_containers/B as obj, var/mob/user as mob)
	if (beaker)
		if (B && B.reagents && B.reagents.reagent_list.len)
			user << "You transfer the reagents to the dispenser."
			for(var/datum/reagent/R in B.reagents.reagent_list)
				var/done = FALSE
				for (var/list/r in dispensable_reagents)
					if (R.id == r[1])
						r[2] += B.reagents.get_reagent_amount(R.id)
						done = TRUE
						break
				if (!done)
					dispensable_reagents += list(list(R.id, B.reagents.get_reagent_amount(R.id)))
			B.reagents.clear_reagents()
			sanitize_reagents()
			return
		else
			user << "A beaker is already placed in the dispenser."
			return
	if (istype(B, /obj/item/weapon/reagent_containers/glass) || istype(B, /obj/item/weapon/reagent_containers/food))
		if (!accept_glass && istype(B,/obj/item/weapon/reagent_containers/food))
			user << "<span class='notice'>You should only use beakers to manage chemicals.</span>"
		beaker =  B
		user.drop_item()
		B.loc = src
		user << "You place [B] in the dispenser."
		nanomanager.update_uis(src) // update all UIs attached to src
		return
	..()

/obj/structure/chemical_dispenser/attack_hand(mob/user as mob)
	sanitize_reagents()
	ui_interact(user)

/obj/structure/chemical_dispenser/proc/sanitize_reagents()
	var/list/temp_dr = list()
	for (var/list/r in dispensable_reagents)
		if (r[2] > 0)
			temp_dr += list(list(r[1],r[2]))
	dispensable_reagents = temp_dr
	return


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/obj/structure/lab_distillery
	name = "laboratory distiller"
	desc = "A professional laboratory distillery, used to separate chemicals in a solution."
	density = FALSE
	anchored = FALSE
	icon = 'icons/obj/chemical.dmi'
	icon_state = "distill_empty_nocol"
	not_movable = FALSE
	not_disassemblable = TRUE
	var/active = FALSE
	var/obj/item/weapon/reagent_containers/glass/beaker/collector = null
/obj/structure/lab_distillery/New()
	..()
	reagents = new /datum/reagents(80)

/obj/structure/lab_distillery/update_icon()
	..()
	if (reagents.total_volume > 0)
		if (collector)
			icon_state = "distill"
		else
			icon_state = "distill_nocol"
	else
		if (collector)
			icon_state = "distill_empty"
		else
			icon_state = "distill_empty_nocol"
	if (active)
		icon_state = "distill_active"

/obj/structure/lab_distillery/attack_hand(var/mob/living/human/H)
	if (istype(H) && H.getStatCoeff("medical") < GET_MIN_STAT_COEFF(STAT_MEDIUM_HIGH))
		H << "<span class = 'danger'>These chemicals are too complex for you to understand.</span>"
		return
	if (reagents.total_volume <= 0)
		H << "The distiller is empty."
		return
	if (!collector && !active)
		H << "You cannot turn the distiller active without a collector."
		return
	if (collector && !active)
		H << "You turn the distiller active."
		active = TRUE
		update_icon()
		process_machine()
	..()

/obj/structure/lab_distillery/attackby(var/obj/item/weapon/reagent_containers/B as obj, var/mob/living/human/H as mob)
	if (istype(H) && H.getStatCoeff("medical") < GET_MIN_STAT_COEFF(STAT_MEDIUM_HIGH))
		H << "<span class = 'danger'>These chemicals are too complex for you to understand.</span>"
		return
	if (B.reagents)
		if (B.reagents.total_volume > 0)
			var/tamt = B.reagents.trans_to_holder(src.reagents, 10, TRUE, FALSE)
			H << "You pour [tamt] units from \the [B] into the distiller."
			update_icon()
			return
	if (istype(B, /obj/item/weapon/reagent_containers/glass/beaker) && !collector)
		if (B.reagents.total_volume > 0)
			H << "The collector must be empty!"
			return
		else
			H << "You place [B] as the collector for the distiller."
			collector =  B
			H.drop_item()
			B.loc = src
			update_icon()
			return
	..()

/obj/structure/lab_distillery/verb/empty()
	set category = null
	set name = "Remove Beaker"
	set src in range(1, usr)

	if (!collector)
		usr << "There is no beaker to remove from \the [src]."
		return

	if (active)
		usr << "<span class = 'danger'>You cannot remove the beaker while the distiller is running!</span>"
		return

	if (collector && !active)
		visible_message("You remove \the [collector].","[usr] removes \the [collector] from \the [src].")
		collector.loc = get_turf(src)
		collector = null
		return

	return

/obj/structure/lab_distillery/proc/process_machine()
	if (!active)
		return
	else
		spawn(15 SECONDS)
			var/largest = reagents.get_master_reagent_id()
			var/voltotransf = min(collector.reagents.get_free_space(),reagents.get_reagent_amount(largest))
			var/chems_got_back_div = 1 // Divider for how many chems you get back vs how much you put in (0.1, you get a tenth of the chems back)
			var/topick // What chems you got back

			switch (largest)
				if ("water")
					topick = pick("hydrogen","oxygen")
					chems_got_back_div = 10

			collector.reagents.add_reagent(topick,voltotransf / chems_got_back_div)
			reagents.remove_reagent(largest,voltotransf)
			active = FALSE
			update_icon()
			visible_message("\The [src] finishes distilling.")


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/obj/structure/centrifuge
	name = "laboratory centrifuge"
	desc = "A professional laboratory centrifuge, used to separate chemicals in a solution."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "centrifuge"
	density = TRUE
	anchored = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/active = FALSE
	powerneeded = 5
	var/obj/item/weapon/reagent_containers/glass/beaker/collector = null

/obj/structure/centrifuge/New()
	..()
	reagents = new /datum/reagents(80)

/obj/structure/centrifuge/proc/check_power()
	if (!powersource || !powerneeded)
		powered = FALSE
		return FALSE
	else
		powered = TRUE
		if (powersource.powered && ((powersource.powerflow-powersource.currentflow) >= powerneeded))
			if (!active)
				powersource.update_power(powerneeded,1)
				powersource.currentflow += powerneeded
				powersource.lastupdate2 = world.time
			return TRUE
		else
			if (active)
				powersource.update_power(powerneeded,1)
				active = FALSE
				powersource.currentflow -= powerneeded
				powersource.lastupdate2 = world.time
			return FALSE

/obj/structure/centrifuge/update_icon()
	..()
	if (powered)
		icon_state = "centrifuge_powered"
	else
		icon_state = "centrifuge"
	if (active)
		icon_state = "centrifuge_active"

/obj/structure/centrifuge/attack_hand(var/mob/living/human/H)
	if (!anchored)
		H << SPAN_NOTICE("Fix \the [src] in place with a wrench first.")
		return
	else if (istype(H) && H.getStatCoeff("medical") < GET_MIN_STAT_COEFF(STAT_MEDIUM_HIGH))
		H << SPAN_DANGER("These chemicals are too complex for you to understand.")
		return
	else if (!check_power())
		H << SPAN_WARNING("\The [src] doesn't have any power!")
		return
	else if (reagents.total_volume <= 0)
		H << SPAN_NOTICE("\The [src] is empty.")
		return
	else if (!collector && !active)
		H << SPAN_NOTICE("You cannot turn \the [src] active without a collector.")
		return
	else if (collector && !active)
		H << SPAN_NOTICE("You turn \the [src] active.")
		active = TRUE
		update_icon()
		process_machine()
	..()

/obj/structure/centrifuge/attackby(obj/item/W as obj, var/mob/living/human/user as mob)
	..()

	if (!anchored)
		user << SPAN_NOTICE("Fix \the [src] in place with a wrench first.")
		return

	else if (istype(W,/obj/item/weapon/reagent_containers))
		if (istype(user) && user.getStatCoeff("medical") < GET_MIN_STAT_COEFF(STAT_MEDIUM_HIGH))
			user << SPAN_DANGER("These chemicals are too complex for you to understand")
			return
		var/obj/item/weapon/reagent_containers/B = W
		if (B.reagents)
			if (B.reagents.total_volume > 0)
				var/tamt = B.reagents.trans_to_holder(src.reagents, 10, TRUE, FALSE)
				user << "You pour [tamt] units from \the [B] into \the [src]."
				update_icon()
				return
		if (istype(B, /obj/item/weapon/reagent_containers/glass/beaker/vial) && !collector)
			if (B.reagents.total_volume > 0)
				user << "The collector must be empty!"
				return
			else
				user << "You place [B] as the collector for \the [src]."
				collector =  B
				user.drop_item()
				B.loc = src
				update_icon()
				return
	
	else if (istype(W, /obj/item/stack/cable_coil))
		connect_cable(user,W)
		return

/obj/structure/centrifuge/verb/empty()
	set category = null
	set name = "Remove Vial"
	set src in range(1, usr)

	if (!collector)
		usr << "There is no vial to remove from \the [src]."
		return

	if (active)
		usr << "<span class = 'danger'>You cannot remove the vial while \the [src] is running!</span>"
		return

	if (collector && !active)
		visible_message("You remove \the [collector].","[usr] removes \the [collector] from \the [src].")
		collector.loc = get_turf(src)
		collector = null
		return
	return

/obj/structure/centrifuge/proc/process_machine()
	if (!check_power())
		visible_message(SPAN_WARNING("\The [src] abruptly stops it's cycle and powers down."))
		return
	else
		spawn(15 SECONDS)
			if (!check_power())
				visible_message(SPAN_WARNING("\The [src] abruptly stops it's cycle and powers down."))
				return
			var/largest = reagents.get_master_reagent_id()
			var/voltotransf = min(collector.reagents.get_free_space(),reagents.get_reagent_amount(largest))
			var/chems_got_back_div = 1 // Divider for how many chems you get back vs how much you put in (0.1, you get a tenth of the chems back)
			var/topick // What chems you got back

			switch (largest)
				if ("blood")
					topick = pick("blood_plasma", "red_blood_cells", "white_blood_cells")
					chems_got_back_div = 5
				if ("sodiumchloride")
					topick = pick("sodium", "chlorine")
					chems_got_back_div = 2

			collector.reagents.add_reagent(topick,voltotransf / chems_got_back_div)
			reagents.remove_reagent(largest,voltotransf)
			active = FALSE
			update_icon()
			visible_message("\The [src] stops it's cycle.")
			playsound(loc, 'sound/machines/ping.ogg', 100, TRUE)

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/obj/structure/grinder
	name = "grinder"
	desc = "A professional grinder used to grind certain objects into a pulp."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "grinder"
	density = TRUE
	anchored = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/active = FALSE
	powerneeded = 5
	var/obj/item/stack/inserted = null

/obj/structure/grinder/proc/check_power()
	if (!powersource || !powerneeded)
		powered = FALSE
		return FALSE
	else
		powered = TRUE
		if (powersource.powered && ((powersource.powerflow-powersource.currentflow) >= powerneeded))
			if (!active)
				powersource.update_power(powerneeded,1)
				powersource.currentflow += powerneeded
				powersource.lastupdate2 = world.time
			return TRUE
		else
			if (active)
				powersource.update_power(powerneeded,1)
				active = FALSE
				powersource.currentflow -= powerneeded
				powersource.lastupdate2 = world.time
			return FALSE

/obj/structure/grinder/update_icon()
	..()
	if (powered)
		icon_state = "grinder_powered"
	else
		icon_state = "grinder"
	if (active)
		icon_state = "grinder_active"

/obj/structure/grinder/attack_hand(var/mob/living/human/H)
	if (!anchored)
		H << SPAN_NOTICE("Fix \the [src] in place with a wrench first.")
		return
	else if (!check_power())
		H << SPAN_WARNING("\The [src] doesn't have any power!")
		return
	else if (!inserted && !active)
		H << SPAN_NOTICE("\The [src] is empty.")
		return
	else if (inserted && !active)
		H << SPAN_NOTICE("You turn \the [src] active.")
		active = TRUE
		update_icon()
		process_machine()
		return
	..()

/obj/structure/grinder/attackby(var/obj/item/W as obj, var/mob/living/human/user as mob)
	..()

	if (!anchored)
		user << SPAN_NOTICE("Fix \the [src] in place with a wrench first.")
		return

	else if (istype(W, /obj/item/stack/cable_coil))
		connect_cable(user,W)
		return

	if (istype(W, /obj/item/stack) && !inserted)
		user << "You place \the [W] in \the [src] for grinding."
		inserted =  W
		user.drop_item()
		W.loc = src
		update_icon()
		return

/obj/structure/grinder/verb/empty()
	set category = null
	set name = "Remove Inserted"
	set src in range(1, usr)

	if (!inserted)
		usr << "There is no object to remove from \the [src]."
		return

	if (active)
		usr << SPAN_DANGER(">You cannot remove \the [inserted] while \the [src] is running!</span>")
		return

	if (inserted && !active)
		visible_message("You remove \the [inserted].","[usr] removes \the [inserted] from \the [src].")
		inserted.loc = get_turf(src)
		inserted = null
		return
	return

/obj/structure/grinder/proc/process_machine()
	if (!check_power())
		visible_message(SPAN_WARNING("\The [src] abruptly stops grinding and powers down."))
		return
	else
		spawn(10 SECONDS)
			playsound(loc, 'sound/machines/grinder.ogg', 100, TRUE)
			spawn (5 SECONDS)
				if (!check_power())
					visible_message(SPAN_WARNING("\The [src] abruptly stops grinding and powers down."))

				var/obj/item/stack/tospawn

				if (istype(inserted, /obj/item/stack/material/wood))
					tospawn = /obj/item/stack/material/wood
					tospawn.amount = inserted.amount/5
				else
					active = FALSE
					update_icon()
					visible_message(SPAN_WARNING("\The [src] cannot grind this item."))
					playsound(loc, 'sound/machines/buzz-sigh.ogg', 50, TRUE)
					inserted.loc = get_turf(src)
					inserted = null
					return

				new tospawn(src)
				active = FALSE
				qdel (inserted)
				inserted = null
				update_icon()
				visible_message("\The [src] stops grinding.")

////////////////////////////////////////////////////////////////////////////////////////////////////////

/obj/structure/chem_master
	name = "pill maker"
	desc = "Makes pills out of reagents."
	density = TRUE
	anchored = TRUE
	icon = 'icons/obj/chemical.dmi'
	icon_state = "mixer0b"
//	use_power = TRUE
//	idle_power_usage = 20
	var/beaker = null
	var/obj/item/weapon/storage/pill_bottle/loaded_pill_bottle = null
	var/mode = FALSE
	var/condi = FALSE
	var/useramount = 30 // Last used amount
	var/pillamount = 10
	var/bottlesprite = "bottle"
	var/pillsprite = "1"
	var/client/has_sprites = list()
	var/max_pill_count = 20
	flags = OPENCONTAINER

/obj/structure/chem_master/New()
	..()
	var/datum/reagents/R = new/datum/reagents(120)
	reagents = R
	R.my_atom = src

/obj/structure/chem_master/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			if (prob(50))
				qdel(src)
				return

/obj/structure/chem_master/attackby(var/obj/item/weapon/B as obj, var/mob/user as mob)

	if (istype(B, /obj/item/weapon/reagent_containers/glass))

		if (beaker)
			user << "A beaker is already loaded into the machine."
			return
		beaker = B
		user.drop_item()
		B.loc = src
		user << "You add the beaker to the machine!"
		updateUsrDialog()
		icon_state = "mixer1b"

	else if (istype(B, /obj/item/weapon/storage/pill_bottle))

		if (loaded_pill_bottle)
			user << "A pill bottle is already loaded into the machine."
			return

		loaded_pill_bottle = B
		user.drop_item()
		B.loc = src
		user << "You add the pill bottle into the dispenser slot!"
		updateUsrDialog()
	return

/obj/structure/chem_master/Topic(href, href_list)
	if (..())
		return TRUE

	if (href_list["ejectp"])
		if (loaded_pill_bottle)
			loaded_pill_bottle.loc = loc
			loaded_pill_bottle = null
	else if (href_list["close"])
		usr << browse(null, "window=chemmaster")
		usr.unset_using_object()
		return

	if (beaker)
		var/datum/reagents/R = beaker:reagents
		if (href_list["analyze"])
			var/dat = ""
			if (!condi)
				if (href_list["name"] == "Blood")
					var/datum/reagent/blood/G
					for (var/datum/reagent/F in R.reagent_list)
						if (F.name == href_list["name"])
							G = F
							break
					var/A = G.name
					var/B = G.data["blood_type"]
					var/C = G.data["blood_DNA"]
					dat += "<TITLE>Pill Maker</TITLE>Chemical infos:<BR><BR>Name:<BR>[A]<BR><BR>Description:<BR>Blood Type: [B]<br>DNA: [C]<BR><BR><BR><A href='?src=\ref[src];main=1'>(Back)</A>"
				else
					dat += "<TITLE>Pill Maker</TITLE>Chemical infos:<BR><BR>Name:<BR>[href_list["name"]]<BR><BR>Description:<BR>[href_list["desc"]]<BR><BR><BR><A href='?src=\ref[src];main=1'>(Back)</A>"
			else
				dat += "<TITLE>Condimaster 3000</TITLE>Condiment infos:<BR><BR>Name:<BR>[href_list["name"]]<BR><BR>Description:<BR>[href_list["desc"]]<BR><BR><BR><A href='?src=\ref[src];main=1'>(Back)</A>"
			usr << browse(dat, "window=chem_master;size=575x400")
			return

		else if (href_list["add"])

			if (href_list["amount"])
				var/id = href_list["add"]
				var/amount = Clamp((text2num(href_list["amount"])), FALSE, 200)
				R.trans_id_to(src, id, amount)

		else if (href_list["addcustom"])

			var/id = href_list["addcustom"]
			useramount = input("Select the amount to transfer.", 30, useramount) as num
			useramount = Clamp(useramount, FALSE, 200)
			Topic(null, list("amount" = "[useramount]", "add" = "[id]"))

		else if (href_list["remove"])

			if (href_list["amount"])
				var/id = href_list["remove"]
				var/amount = Clamp((text2num(href_list["amount"])), FALSE, 200)
				if (mode)
					reagents.trans_id_to(beaker, id, amount)
				else
					reagents.remove_reagent(id, amount)


		else if (href_list["removecustom"])

			var/id = href_list["removecustom"]
			useramount = input("Select the amount to transfer.", 30, useramount) as num
			useramount = Clamp(useramount, FALSE, 200)
			Topic(null, list("amount" = "[useramount]", "remove" = "[id]"))

		else if (href_list["toggle"])
			mode = !mode

		else if (href_list["main"])
			attack_hand(usr)
			return
		else if (href_list["eject"])
			if (beaker)
				beaker:loc = loc
				beaker = null
				reagents.clear_reagents()
				icon_state = "mixer0b"
		else if (href_list["createpill"] || href_list["createpill_multiple"])
			var/count = TRUE

			if (reagents.total_volume/count < 1) //Sanity checking.
				return

			if (href_list["createpill_multiple"])
				count = input("Select the number of pills to make.", "Max [max_pill_count]", pillamount) as num
				count = Clamp(count, TRUE, max_pill_count)

			if (reagents.total_volume/count < 1) //Sanity checking.
				return

			var/amount_per_pill = reagents.total_volume/count
			if (amount_per_pill > 60) amount_per_pill = 60

			var/name = sanitizeSafe(input(usr,"Name:","Name your pill!","[reagents.get_master_reagent_name()] ([amount_per_pill] units)"), MAX_NAME_LEN)

			if (reagents.total_volume/count < 1) //Sanity checking.
				return
			while (count--)
				var/obj/item/weapon/reagent_containers/pill/P = new/obj/item/weapon/reagent_containers/pill(loc)
				if (!name) name = reagents.get_master_reagent_name()
				P.name = "[name] pill"
				P.pixel_x = rand(-7, 7) //random position
				P.pixel_y = rand(-7, 7)
				P.icon_state = "pill"+pillsprite
				reagents.trans_to_obj(P,amount_per_pill)
				if (loaded_pill_bottle)
					if (loaded_pill_bottle.contents.len < loaded_pill_bottle.storage_slots)
						P.loc = loaded_pill_bottle
						updateUsrDialog()

		else if (href_list["createbottle"])
			if (!condi)
				var/name = sanitizeSafe(input(usr,"Name:","Name your bottle!",reagents.get_master_reagent_name()), MAX_NAME_LEN)
				var/obj/item/weapon/reagent_containers/glass/bottle/P = new/obj/item/weapon/reagent_containers/glass/bottle(loc)
				if (!name) name = reagents.get_master_reagent_name()
				P.name = "[name] bottle"
				P.pixel_x = rand(-7, 7) //random position
				P.pixel_y = rand(-7, 7)
				P.icon_state = bottlesprite
				reagents.trans_to_obj(P,60)
				P.update_icon()
			else
				var/obj/item/weapon/reagent_containers/food/condiment/P = new/obj/item/weapon/reagent_containers/food/condiment(loc)
				reagents.trans_to_obj(P,50)
		else if (href_list["change_pill"])
			#define MAX_PILL_SPRITE 20 //max icon state of the pill sprites
			var/dat = "<table>"
			for (var/i = TRUE to MAX_PILL_SPRITE)
				dat += "<tr><td><a href=\"?src=\ref[src]&pill_sprite=[i]\"><img src=\"pill[i].png\" /></a></td></tr>"
			dat += "</table>"
			usr << browse(dat, "window=chem_master")
			return
		else if (href_list["change_bottle"])
			var/dat = "<table>"
			for (var/sprite in BOTTLE_SPRITES)
				dat += "<tr><td><a href=\"?src=\ref[src]&bottle_sprite=[sprite]\"><img src=\"[sprite].png\" /></a></td></tr>"
			dat += "</table>"
			usr << browse(dat, "window=chem_master")
			return
		else if (href_list["pill_sprite"])
			pillsprite = href_list["pill_sprite"]
		else if (href_list["bottle_sprite"])
			bottlesprite = href_list["bottle_sprite"]

	playsound(loc, 'sound/machines/button.ogg', 100, TRUE)
	updateUsrDialog()
	return

/obj/structure/chem_master/attack_hand(mob/user as mob)
	user.set_using_object(src)
	if (!(user.client in has_sprites))
		spawn()
			has_sprites += user.client
			for (var/i = TRUE to MAX_PILL_SPRITE)
				usr << browse_rsc(icon('icons/obj/chemical.dmi', "pill" + num2text(i)), "pill[i].png")
			for (var/sprite in BOTTLE_SPRITES)
				usr << browse_rsc(icon('icons/obj/chemical.dmi', sprite), "[sprite].png")
	var/dat = ""
	if (!beaker)
		dat = "Please insert beaker.<BR>"
		if (loaded_pill_bottle)
			dat += "<A href='?src=\ref[src];ejectp=1'>Eject Pill Bottle \[[loaded_pill_bottle.contents.len]/[loaded_pill_bottle.storage_slots]\]</A><BR><BR>"
		else
			dat += "No pill bottle inserted.<BR><BR>"
		dat += "<A href='?src=\ref[src];close=1'>Close</A>"
	else
		var/datum/reagents/R = beaker:reagents
		dat += "<A href='?src=\ref[src];eject=1'>Eject beaker and Clear Buffer</A><BR>"
		if (loaded_pill_bottle)
			dat += "<A href='?src=\ref[src];ejectp=1'>Eject Pill Bottle \[[loaded_pill_bottle.contents.len]/[loaded_pill_bottle.storage_slots]\]</A><BR><BR>"
		else
			dat += "No pill bottle inserted.<BR><BR>"
		if (!R.total_volume)
			dat += "Beaker is empty."
		else
			dat += "Add to buffer:<BR>"
			for (var/datum/reagent/G in R.reagent_list)
				dat += "[G.name] , [G.volume] Units - "
				dat += "<A href='?src=\ref[src];analyze=1;desc =[G.description];name =[G.name]'>(Analyze)</A> "
				dat += "<A href='?src=\ref[src];add=[G.id];amount=1'>(1)</A> "
				dat += "<A href='?src=\ref[src];add=[G.id];amount=5'>(5)</A> "
				dat += "<A href='?src=\ref[src];add=[G.id];amount=10'>(10)</A> "
				dat += "<A href='?src=\ref[src];add=[G.id];amount=[G.volume]'>(All)</A> "
				dat += "<A href='?src=\ref[src];addcustom=[G.id]'>(Custom)</A><BR>"

		dat += "<HR>Transfer to <A href='?src=\ref[src];toggle=1'>[(!mode ? "disposal" : "beaker")]:</A><BR>"
		if (reagents.total_volume)
			for (var/datum/reagent/N in reagents.reagent_list)
				dat += "[N.name] , [N.volume] Units - "
				dat += "<A href='?src=\ref[src];analyze=1;desc =[N.description];name =[N.name]'>(Analyze)</A> "
				dat += "<A href='?src=\ref[src];remove=[N.id];amount=1'>(1)</A> "
				dat += "<A href='?src=\ref[src];remove=[N.id];amount=5'>(5)</A> "
				dat += "<A href='?src=\ref[src];remove=[N.id];amount=10'>(10)</A> "
				dat += "<A href='?src=\ref[src];remove=[N.id];amount=[N.volume]'>(All)</A> "
				dat += "<A href='?src=\ref[src];removecustom=[N.id]'>(Custom)</A><BR>"
		else
			dat += "Empty<BR>"
		if (!condi)
			dat += "<HR><BR><A href='?src=\ref[src];createpill=1'>Create pill (60 units max)</A><a href=\"?src=\ref[src]&change_pill=1\"><img src=\"pill[pillsprite].png\" /></a><BR>"
			dat += "<A href='?src=\ref[src];createpill_multiple=1'>Create multiple pills</A><BR>"
			dat += "<A href='?src=\ref[src];createbottle=1'>Create bottle (60 units max)<a href=\"?src=\ref[src]&change_bottle=1\"><img src=\"[bottlesprite].png\" /></A>"
		else
			dat += "<A href='?src=\ref[src];createbottle=1'>Create bottle (50 units max)</A>"
	if (!condi)
		user << browse("<TITLE>Pill Maker</TITLE>Chemmaster menu:<BR><BR>[dat]", "window=chem_master;size=575x400")
	else
		user << browse("<TITLE>Pill Maker</TITLE>Condimaster menu:<BR><BR>[dat]", "window=chem_master;size=575x400")
	onclose(user, "chem_master")
	return

//////////////ETHANOL REFINERY/////////////////

/obj/structure/distillery
	name = "alcohol distiller"
	desc = "A alcohol distiller. Turns any alcoholic drink into pure ethanol."
	density = FALSE
	anchored = FALSE
	icon = 'icons/obj/structures.dmi'
	icon_state = "distillery"
	not_movable = FALSE
	not_disassemblable = TRUE
	var/active = FALSE
	var/obj/item/weapon/reagent_containers/glass/collector = null
/obj/structure/distillery/New()
	..()
	reagents = new /datum/reagents(80)
/obj/structure/distillery/update_icon()
	..()
	if (active)
		icon_state = "distillery1"
	else
		icon_state = "distillery"

/obj/structure/distillery/attack_hand(var/mob/living/human/H)
	if (istype(H) && H.getStatCoeff("medical") < GET_MIN_STAT_COEFF(STAT_NORMAL))
		H << "<span class = 'danger'>These chemicals are too complex for you to understand.</span>"
		return
	if (reagents.total_volume <= 0)
		H << "The distiller is empty."
		return
	if (!collector && !active)
		H << "You cannot turn the distiller active without a collector."
		return
	if (collector && !active)
		H << "You turn the distiller active."
		active = TRUE
		update_icon()
		process_machine()
	..()
/obj/structure/distillery/attackby(var/obj/item/weapon/reagent_containers/B as obj, var/mob/living/human/H as mob)
	if (istype(H) && H.getStatCoeff("medical") < GET_MIN_STAT_COEFF(STAT_MEDIUM_HIGH))
		H << "<span class = 'danger'>These chemicals are too complex for you to understand.</span>"
		return
	if (B.reagents)
		if (B.reagents.total_volume > 0 && collector && collector.reagents.get_free_space() > 0)
			var/amt_transf = collector.reagents.get_free_space()
			var/tamt = B.reagents.trans_to_holder(src.reagents, min(10, amt_transf), TRUE, FALSE)
			H << "You pour [tamt] units from \the [B] into the distiller."
			update_icon()
			return
	if (istype(B, /obj/item/weapon/reagent_containers/glass/) && !collector)
		if (B.reagents.total_volume > 0)
			H << "The collector must be empty!"
			return
		else
			H << "You place [B] as the collector for the distiller."
			collector =  B
			H.drop_item()
			B.loc = src
			update_icon()
			return
	..()

/obj/structure/distillery/verb/empty()
	set category = null
	set name = "Remove Collector"
	set src in range(1, usr)

	if (!collector)
		usr << "There is nothing to remove from \the [src]."
		return

	if (active)
		usr << "<span class = 'danger'>You cannot remove the [collector] while the distiller is running!</span>"
		return

	if (collector && !active)
		visible_message("You remove \the [collector].","[usr] removes \the [collector] from \the [src].")
		collector.loc = get_turf(src)
		collector = null
		return

	return

/obj/structure/distillery/proc/process_machine()
	if (!active)
		return
	else
		spawn(150)
			var/ethanol_sum = 0
			for (var/datum/reagent/r in reagents.reagent_list)
				if (istype(r, /datum/reagent/ethanol))
					ethanol_sum += reagents.get_reagent_amount(r.id)*(1-(r.strength/100))
					reagents.remove_reagent(r.id,reagents.get_reagent_amount(r.id))
				else
					reagents.remove_reagent(r.id,reagents.get_reagent_amount(r.id))

			var/voltotransf = min(collector.reagents.get_free_space(),ethanol_sum)
			collector.reagents.add_reagent("ethanol",voltotransf)


			active = FALSE
			update_icon()
			visible_message("\The [src] finishes distilling.")
