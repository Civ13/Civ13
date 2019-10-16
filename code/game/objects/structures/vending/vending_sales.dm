/**
 *  A vending machine / market stall that actually charges per sale.
 */
/obj/structure/vending/sales
	name = "Vending Machine"
	desc = "A generic vending machine."
	icon = 'icons/obj/vending.dmi'
	icon_state = "apparel_british"
	layer = 2.9
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE

	var/moneyin = 0
	var/owner = null

/obj/structure/vending/ex_act(severity)
	return

/obj/structure/vending/sales/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/money))
		var/obj/item/stack/money/M = W
		moneyin += M.amount*M.value
		user << "You put \the [W] in the [src]."
		qdel(W)
		return
	if (istype(W, /obj/item/weapon/wrench))
		if (owner && (locate(user) in map.custom_company[owner]))
			playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
			if (anchored)
				user.visible_message("[user] begins unsecuring \the [src] from the floor.", "You start unsecuring \the [src] from the floor.")
			else
				user.visible_message("[user] begins securing \the [src] to the floor.", "You start securing \the [src] to the floor.")

			if (do_after(user, 20, src))
				if (!src) return
				user << "<span class='notice'>You [anchored? "un" : ""]secured \the [src]!</span>"
				anchored = !anchored
			return

	else
		if (owner && (locate(user) in map.custom_company[owner]))
			for (var/datum/data/vending_product/R in product_records)
				if (istype(W, R.product_path))
					stock(W, R, user)
					return TRUE
		..()

/obj/structure/vending/sales/vend(datum/data/vending_product/R, mob/user)
	vend_ready = FALSE //One thing at a time!!
	status_message = "Vending..."
	status_error = FALSE
	nanomanager.update_uis(src)

	spawn(vend_delay)
		R.get_product(get_turf(src))
		playsound(loc, 'sound/machines/vending_drop.ogg', 100, TRUE)
		status_message = ""
		status_error = FALSE
		vend_ready = TRUE
		currently_vending = null
		nanomanager.update_uis(src)

/**
 * Add item to the machine
 *
 * Checks if item is vendable in this machine should be performed before
 * calling. W is the item being inserted, R is the associated vending_product entry.
 */
/obj/structure/vending/sales/stock(obj/item/weapon/W, var/datum/data/vending_product/R, var/mob/user)
	if (!user.unEquip(W))
		return

	user << "<span class='notice'>You insert \the [W] in the rack.</span>"
	R.add_product(W)

	nanomanager.update_uis(src)