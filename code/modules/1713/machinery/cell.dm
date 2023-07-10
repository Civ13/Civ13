/obj/item/weapon/cell
	name = "power cell"
	desc = "A rechargable electrochemical power cell."
	icon = 'icons/obj/machines/power.dmi'
	icon_state = "cell"
	item_state = "cell"
	force = 5.0
	throwforce = 5.0
	throw_speed = 3
	throw_range = 5
	w_class = ITEM_SIZE_NORMAL
	var/charge // Current charge
	var/maxcharge = 1000 // Capacity in Wh
	var/overlay_state

/obj/item/weapon/cell/New()
	if(isnull(charge))
		charge = maxcharge
	..()

/obj/item/weapon/cell/initialize()
	. = ..()
	update_icon()

/obj/item/weapon/cell/drain_power(var/drain_check, var/surge, var/power = 0)

	if(drain_check)
		return 1

	if(charge <= 0)
		return 0

	var/cell_amt = power * (1/(3600/2))

	return use(cell_amt) / (1/(3600/2))

/obj/item/weapon/cell/update_icon()

	var/new_overlay_state = null
	if(percent() >= 95)
		new_overlay_state = "cell-o2"
	else if(charge >= 0.05)
		new_overlay_state = "cell-o1"

	if(new_overlay_state != overlay_state)
		overlay_state = new_overlay_state
		overlays.Cut()
		if(overlay_state)
			overlays += image('icons/obj/machines/power.dmi', overlay_state)

/obj/item/weapon/cell/proc/percent() // return % charge of cell
	return maxcharge && (100.0*charge/maxcharge)

/obj/item/weapon/cell/proc/fully_charged()
	return (charge == maxcharge)

// checks if the power cell is able to provide the specified amount of charge
/obj/item/weapon/cell/proc/check_charge(var/amount)
	return (charge >= amount)

// use power from a cell, returns the amount actually used
/obj/item/weapon/cell/proc/use(var/amount)
	var/used = min(charge, amount)
	charge -= used
	update_icon()
	return used

// Checks if the specified amount can be provided. If it can, it removes the amount
// from the cell and returns 1. Otherwise does nothing and returns 0.
/obj/item/weapon/cell/proc/checked_use(var/amount)
	if(!check_charge(amount))
		return 0
	use(amount)
	return 1

/obj/item/weapon/cell/proc/give(var/amount)
	if(maxcharge < amount)	return 0
	var/amount_used = min(maxcharge-charge,amount)
	charge += amount_used
	update_icon()
	return amount_used

/obj/item/weapon/cell/examine(mob/user)
	. = ..()
	to_chat(user, "The label states it's capacity is [maxcharge] Wh")
	to_chat(user, "The charge meter reads [round(src.percent(), 0.1)]%")

/obj/item/weapon/cell/standard
	name = "standard power cell"
	desc = "A standard and relatively cheap power cell, commonly used."
	maxcharge = 250