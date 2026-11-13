// Smokeless powder: a cheaper cartridge propellant that needs no sulfur per batch.
//
// Cotton is nitrated with saltpeter in a sulphuric acid bath. The acid is not
// used up, so one flask of it nitrates batch after batch. Guncotton is then
// gelatinized with alcohol into smokeless powder (Poudre B, 1884). A unit of
// smokeless powder charges a brass casing like two units of black powder;
// handloading it needs the Cartridge Firearms research. Muzzleloaders, cannons
// and the old powder recipes keep using black powder.

#define SMOKELESS_CHARGE_PER_UNIT 2
#define SMOKELESS_RESEARCH "cartridge_ammo"

/datum/reagent/guncotton
	name = "Guncotton"
	id = "guncotton"
	description = "Nitrated cotton. Gelatinize it with alcohol to make smokeless powder."
	taste_description = "bitter cotton"
	reagent_state = SOLID
	color = "#F2EEDC"

/datum/reagent/smokeless_powder
	name = "Smokeless powder"
	id = "smokeless_powder"
	description = "Gelatinized guncotton flakes. It burns cleanly and twice as strongly as black powder in a cartridge."
	taste_description = "varnish"
	reagent_state = SOLID
	color = "#8A8F6A"

// Cotton and saltpeter in sulphuric acid. Put the acid in first: without it,
// cotton and saltpeter still flash off as before.
/datum/chemical_reaction/guncotton
	name = "Guncotton"
	id = "guncotton"
	result = "guncotton"
	required_reagents = list("cotton" = 2, "potassium" = 1)
	catalysts = list("sacid" = 5)
	result_amount = 2
	priority = 1
	log_is_important = TRUE

// A lab with nitric acid can nitrate cotton without any sulfur.
/datum/chemical_reaction/guncotton_nitric
	name = "Guncotton"
	id = "guncotton_nitric"
	result = "guncotton"
	required_reagents = list("cotton" = 2, "nitric_acid" = 1)
	result_amount = 2
	log_is_important = TRUE

/datum/chemical_reaction/smokeless_powder
	name = "Smokeless powder"
	id = "smokeless_powder"
	result = "smokeless_powder"
	required_reagents = list("guncotton" = 2, "ethanol" = 1)
	result_amount = 3
	log_is_important = TRUE

// Pours smokeless powder from RC into a casing stack. Returns the charge added,
// 0 when there was none to pour, or -1 when the user cannot use it yet.
/obj/item/stack/ammopart/casing/proc/handload_pour_smokeless(obj/item/weapon/reagent_containers/RC, mob/user, needed)
	var/available = RC.reagents ? RC.reagents.get_reagent_amount("smokeless_powder") : 0
	if (available <= 0 || needed <= 0)
		return 0
	if (!research_node_known(user, SMOKELESS_RESEARCH))
		return -1
	var/units = min(available, needed / SMOKELESS_CHARGE_PER_UNIT)
	RC.reagents.remove_reagent("smokeless_powder", units)
	var/charge = units * SMOKELESS_CHARGE_PER_UNIT
	gunpowder += charge
	return charge

#undef SMOKELESS_CHARGE_PER_UNIT
#undef SMOKELESS_RESEARCH
