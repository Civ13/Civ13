#define SOLID TRUE
#define LIQUID 2
#define GAS 3

#define BOTTLE_SPRITES list("bottle-1", "bottle-2", "bottle-3", "bottle-4") //list of available bottle sprites
#define REAGENTS_PER_SHEET 20


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


/obj/structure/chemical_dispenser
	name = "chem dispenser"
	density = TRUE
	anchored = TRUE
	icon = 'icons/obj/chemical.dmi'
	icon_state = "dispenser"
	var/ui_title = "Chemical Dispenser"
	var/amount = 30
	var/accept_glass = FALSE //At FALSE ONLY accepts glass containers. Kinda misleading varname.
	var/atom/beaker = null
	var/list/dispensable_reagents = list("lithium","carbon","ammonia","acetone",
	"sodium","aluminum","silicon","phosphorus","sulfur","hclacid","potassium","iron",
	"copper","mercury","radium","water","ethanol","sugar","sacid","tungsten")
	var/stat = 0
	not_movable = FALSE
	not_disassemblable = TRUE

/obj/structure/chemical_dispenser/New()
	..()
	dispensable_reagents = sortList(dispensable_reagents)

/obj/structure/chemical_dispenser/ex_act(severity)
	switch(severity)
		if (1.0)
			del(src)
			return
		if (2.0)
			if (prob(50))
				del(src)
				return


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
	var/mob/living/carbon/human/H = user
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
	for (var/re in dispensable_reagents)
		var/datum/reagent/temp = chemical_reagents_list[re]
		if (temp)
			chemicals.Add(list(list("title" = temp.name, "id" = temp.id, "commands" = list("dispense" = temp.id)))) // list in a list because Byond merges the first list...
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
	if (stat & (NOPOWER|BROKEN))
		return FALSE // don't update UIs attached to this object

	if (href_list["amount"])
		amount = round(text2num(href_list["amount"]), 5) // round to nearest 5
		if (amount < 0) // Since the user can actually type the commands himself, some sanity checking
			amount = FALSE
		if (amount > 120)
			amount = 120

	if (href_list["dispense"])
		if (dispensable_reagents.Find(href_list["dispense"]) && beaker != null && beaker.is_open_container())
			var/obj/item/weapon/reagent_containers/B = beaker
			var/datum/reagents/R = B.reagents
			var/space = R.maximum_volume - R.total_volume

			//uses TRUE energy per 10 units.
			var/added_amount = min(amount, space)
			R.add_reagent(href_list["dispense"], added_amount)
	if (href_list["ejectBeaker"])
		if (beaker)
			var/obj/item/weapon/reagent_containers/B = beaker
			B.loc = loc
			beaker = null

	add_fingerprint(usr)
	return TRUE // update UIs attached to this object

/obj/structure/chemical_dispenser/attackby(var/obj/item/weapon/reagent_containers/B as obj, var/mob/user as mob)
	if (beaker)
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

/obj/structure/chemical_dispenser/attack_hand(mob/user as mob)
	ui_interact(user)

/obj/structure/lab_distillery
	name = "laboratory distiller"
	desc = "A professional laboratory distillery, used to separate chemicals in a solution."
	density = FALSE
	anchored = FALSE
	icon = 'icons/obj/chemical.dmi'
	icon_state = "distill_empty_nocol"
	not_movable = FALSE
	not_disassemblable = TRUE
	var/on = FALSE
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
	if (on)
		icon_state = "distill_on"

/obj/structure/lab_distillery/attack_hand(var/mob/living/carbon/human/H)
	if (istype(H) && H.getStatCoeff("medical") < GET_MIN_STAT_COEFF(STAT_MEDIUM_HIGH))
		H << "<span class = 'danger'>These chemicals are too complex for you to understand.</span>"
		return
	if (reagents.total_volume <= 0)
		H << "The distiller is empty."
		return
	if (!collector && !on)
		H << "You cannot turn the distiller on without a collector."
		return
	if (collector && !on)
		H << "You turn the distiller on."
		on = TRUE
		update_icon()
		process_distillery()
	..()
/obj/structure/lab_distillery/attackby(var/obj/item/weapon/reagent_containers/B as obj, var/mob/living/carbon/human/H as mob)
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

	if (on)
		usr << "<span class = 'danger'>You cannot remove the beaker while the distiller is running!</span>"
		return

	if (collector && !on)
		visible_message("You remove \the [collector].","[usr] removes \the [collector] from \the [src].")
		collector.loc = get_turf(src)
		collector = null
		return

	return

/obj/structure/lab_distillery/proc/process_distillery()
	if (!on)
		return
	else
		spawn(150)
			var/largest = reagents.get_master_reagent_id()
			var/voltotransf = min(collector.reagents.get_free_space(),reagents.get_reagent_amount(largest))
			collector.reagents.add_reagent(largest,voltotransf)
			reagents.remove_reagent(largest,voltotransf)
			on = FALSE
			update_icon()
			visible_message("\The [src] finishes distilling.")