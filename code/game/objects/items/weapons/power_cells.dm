/obj/item/weapon/cell
	name = "power cell"
	desc = "A rechargable electrochemical power cell."
	icon = 'icons/obj/power.dmi'
	icon_state = "cell"
	item_state = "cell"
//	origin_tech = list(TECH_POWER = TRUE)
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	throw_speed = 3
	throw_range = 5
	w_class = 3.0
	var/charge = FALSE	// note %age conveted to actual charge in New
	var/maxcharge = 1000
	var/rigged = FALSE		// true if rigged to explode
	var/minor_fault = FALSE //If not 100% reliable, it will build up faults.
	matter = list(DEFAULT_WALL_MATERIAL = 700, "glass" = 50)

//currently only used by energy-type guns, that may change in the future.
/obj/item/weapon/cell/device
	name = "device power cell"
	desc = "A small power cell designed to power handheld devices."
	icon_state = "cell" //placeholder
	w_class = 2
	force = WEAPON_FORCE_HARMLESS
	throw_speed = 5
	throw_range = 7
	maxcharge = 1000
	matter = list("metal" = 350, "glass" = 50)

/obj/item/weapon/cell/device/variable/New(newloc, charge_amount)
	..(newloc)
	maxcharge = charge_amount
	charge = maxcharge

/obj/item/weapon/cell/crap
	name = "\improper rechargable AA battery"
	desc = "You can't top the plasma top." //TOTALLY TRADEMARK INFRINGEMENT
//	origin_tech = list(TECH_POWER = FALSE)
	maxcharge = 500
	matter = list(DEFAULT_WALL_MATERIAL = 700, "glass" = 40)

/obj/item/weapon/cell/crap/empty/New()
	..()
	charge = FALSE

/obj/item/weapon/cell/secborg
	name = "security borg rechargable D battery"
//	origin_tech = list(TECH_POWER = FALSE)
	maxcharge = 600	//600 max charge / 100 charge per shot = six shots
	matter = list(DEFAULT_WALL_MATERIAL = 700, "glass" = 40)

/obj/item/weapon/cell/secborg/empty/New()
	..()
	charge = FALSE

/obj/item/weapon/cell/apc
	name = "heavy-duty power cell"
//	origin_tech = list(TECH_POWER = TRUE)
	maxcharge = 5000
	matter = list(DEFAULT_WALL_MATERIAL = 700, "glass" = 50)

/obj/item/weapon/cell/high
	name = "high-capacity power cell"
//	origin_tech = list(TECH_POWER = 2)
	icon_state = "hcell"
	maxcharge = 10000
	matter = list(DEFAULT_WALL_MATERIAL = 700, "glass" = 60)

/obj/item/weapon/cell/mecha
	name = "exosuit-grade power cell"
//	origin_tech = list(TECH_POWER = 3)
	icon_state = "hcell"
	maxcharge = 15000
	matter = list(DEFAULT_WALL_MATERIAL = 700, "glass" = 70)

/obj/item/weapon/cell/high/empty/New()
	..()
	charge = FALSE

/obj/item/weapon/cell/super
	name = "super-capacity power cell"
//	origin_tech = list(TECH_POWER = 5)
	icon_state = "scell"
	maxcharge = 20000
	matter = list(DEFAULT_WALL_MATERIAL = 700, "glass" = 70)

/obj/item/weapon/cell/super/empty/New()
	..()
	charge = FALSE

/obj/item/weapon/cell/hyper
	name = "hyper-capacity power cell"
//	origin_tech = list(TECH_POWER = 6)
	icon_state = "hpcell"
	maxcharge = 30000
	matter = list(DEFAULT_WALL_MATERIAL = 700, "glass" = 80)

/obj/item/weapon/cell/hyper/empty/New()
	..()
	charge = FALSE

/obj/item/weapon/cell/infinite
	name = "infinite-capacity power cell!"
	icon_state = "icell"
//	origin_tech =  null
	maxcharge = 30000 //determines how badly mobs get shocked
	matter = list(DEFAULT_WALL_MATERIAL = 700, "glass" = 80)

	check_charge()
		return TRUE
	use()
		return TRUE
/*
/obj/item/weapon/cell/potato
	name = "potato battery"
	desc = "A rechargable starch based power cell."
//	origin_tech = list(TECH_POWER = TRUE)
	icon = 'icons/obj/power.dmi' //'icons/obj/harvest.dmi'
	icon_state = "potato_cell" //"potato_battery"
	charge = 100
	maxcharge = 300
	minor_fault = TRUE
*/