#define SOLID TRUE
#define LIQUID 2
#define GAS 3

#define chemical_dispenser_ENERGY_COST	0.1	//How many energy points do we use per unit of chemical?
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
//	use_power = FALSE
//	idle_power_usage = 40
	var/ui_title = "Chemical Dispenser"
	var/energy = 100
	var/max_energy = 100
	var/amount = 30
	var/accept_glass = FALSE //At FALSE ONLY accepts glass containers. Kinda misleading varname.
	var/atom/beaker = null
	var/hackedcheck = FALSE
	var/list/dispensable_reagents = list("lithium","carbon","ammonia","acetone",
	"sodium","aluminum","silicon","phosphorus","sulfur","hclacid","potassium","iron",
	"copper","mercury","radium","water","ethanol","sugar","sacid","tungsten")
	var/stat = 0
	not_movable = FALSE
	not_disassemblable = TRUE

/obj/structure/chemical_dispenser/New()
	..()
	processing_objects += src

/obj/structure/chemical_dispenser/proc/recharge()
	if (stat & BROKEN)
		return
	if (!processes.obj)
		return
	var/addenergy = 1
	var/oldenergy = energy
	energy = min(energy + addenergy, max_energy)
	if (energy != oldenergy)
//		use_power(CHEM_SYNTH_ENERGY / chemical_dispenser_ENERGY_COST) // This thing uses up "alot" of power (this is still low as shit for creating reagents from thin air)
		nanomanager.update_uis(src) // update all UIs attached to src

/*
/obj/structure/chemical_dispenser/power_change()
	..()
	nanomanager.update_uis(src) // update all UIs attached to src
*/

/obj/structure/chemical_dispenser/process()
	recharge()

	if (stat & BROKEN)
		icon_state = "dispenser_broken"
	else
		icon_state = initial(icon_state)

/obj/structure/chemical_dispenser/New()
	..()
	recharge()
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
	if (stat & (BROKEN|NOPOWER)) return
	if (user.stat || user.restrained()) return
	var/mob/living/carbon/human/H = user
	if (istype(H) && H.getStatCoeff("medical") < GET_MIN_STAT_COEFF(STAT_MEDIUM_HIGH))
		H << "<span class = 'danger'>This machinery is too complex for you to understand.</span>"
		return
	// this is the data which will be sent to the ui
	var/data[0]
	data["amount"] = amount
	data["energy"] = round(energy)
	data["maxEnergy"] = round(max_energy)
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
			var/added_amount = min(amount, energy / chemical_dispenser_ENERGY_COST, space)
			R.add_reagent(href_list["dispense"], added_amount)
			energy = max(energy - added_amount * chemical_dispenser_ENERGY_COST, FALSE)

	if (href_list["ejectBeaker"])
		if (beaker)
			var/obj/item/weapon/reagent_containers/B = beaker
			B.loc = loc
			beaker = null

	add_fingerprint(usr)
	return TRUE // update UIs attached to this object

/obj/structure/chemical_dispenser/attackby(var/obj/item/weapon/reagent_containers/B as obj, var/mob/user as mob)
	if (beaker)
		user << "Something is already loaded into the machine."
		return
	if (istype(B, /obj/item/weapon/reagent_containers/glass) || istype(B, /obj/item/weapon/reagent_containers/food))
		if (!accept_glass && istype(B,/obj/item/weapon/reagent_containers/food))
			user << "<span class='notice'>This machine only accepts beakers</span>"
		beaker =  B
		user.drop_item()
		B.loc = src
		user << "You set [B] on the machine."
		nanomanager.update_uis(src) // update all UIs attached to src
		return

/obj/structure/chemical_dispenser/attack_hand(mob/user as mob)
	if (stat & BROKEN)
		return
	ui_interact(user)