/**
 *  A vending machine
 */
/obj/structure/vending
	name = "Vendomat"
	desc = "A generic vending machine."
	icon = 'icons/obj/vending.dmi'
	icon_state = "apparel_british"
	layer = 2.9
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE

	// Vending-related
	var/active = TRUE //No sales pitches if off!
	var/vend_ready = TRUE //Are we ready to vend?? Is it time??
	var/vend_delay = 5 //How long does it take to vend?
	var/datum/data/vending_product/currently_vending = null // What we're requesting payment for right now
	var/status_message = "" // Status screen messages like "insufficient funds", displayed in NanoUI
	var/status_error = FALSE // Set to TRUE if status_message is an error

	/*
		Variables used to initialize the product list
		These are used for initialization only, and so are optional if
		product_records is specified
	*/
	var/list/products	= list() // For each, use the following pattern:
	var/list/prices	 = list() // Prices for each item, list(/type/path = price), items not in the list don't have a price.

	// List of vending_product items available.
	var/list/product_records = list()
	var/tmp/next_vending_row_key = 0


	// Variables used to initialize advertising
	var/product_slogans = "" //String of slogans spoken out loud, separated by semicolons
	var/product_ads = "" //String of small ad messages in the vending screen

	var/list/ads_list = list()

	// Stuff relating vocalizations
	var/list/slogan_list = list()
	var/last_slogan = FALSE //When did we last pitch?
	var/slogan_delay = 6000 //How long until we can pitch again?

	var/stat = 0

/obj/structure/vending/New()
	..()
	vending_machine_list += src
//	wires = new(src)
	spawn(4)
		if (product_slogans)
			slogan_list += splittext(product_slogans, ";")

			// So not all machines speak at the exact same time.
			// The first time this machine says something will be at slogantime + this random value,
			// so if slogantime is 10 minutes, it will say it at somewhere between 10 and 20 minutes after the machine is crated.
			last_slogan = world.time + rand(0, slogan_delay)

		if (product_ads)
			ads_list += splittext(product_ads, ";")

		// A loaded machine already has its saved records.
		if (!product_records.len)
			build_inventory()
//		power_change()

		return

	return

/obj/structure/vending/Destroy()
	vending_machine_list -= src
	..()

/**
 *  Build produdct_records from the products lists
 *
 *  products, contraband, premium, and prices allow specifying
 *  products that the vending machine is to carry without manually populating
 *  product_records.
 */
/obj/structure/vending/proc/build_inventory()

	for (var/entry in products)
		var/datum/data/vending_product/product = new/datum/data/vending_product(src, entry)

		product.price = (entry in prices) ? prices[entry] : FALSE
		product.amount = (products[entry]) ? products[entry] : TRUE

		product_records.Add(product)

/obj/structure/vending/Destroy()
	for (var/datum/data/vending_product/R in product_records)
		qdel(R)
	product_records.Cut()
	return ..()

/obj/structure/vending/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			if (prob(50))
				qdel(src)
				return
		if (3.0)
			if (prob(25))
				spawn(0)
			//		malfunction()
					return
				return
		else
	return


/obj/structure/vending/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (is_tool(W, TOOL_WRENCH))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		if (anchored)
			user.visible_message("[user] begins unsecuring \the [src] from the floor.", "You start unsecuring \the [src] from the floor.")
		else
			user.visible_message("[user] begins securing \the [src] to the floor.", "You start securing \the [src] to the floor.")

		if (do_after(user, 20, src))
			if (!src) return
			to_chat(user, "<span class='notice'>You [anchored? "un" : ""]secured \the [src]!</span>")
			anchored = !anchored
		return

	if (is_tool(W, TOOL_HAMMER))
		visible_message("<span class='warning'>[user] starts to deconstruct \the [src].</span>")
		playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
		if (do_after(user,50,src))
			visible_message("<span class='warning'>[user] deconstructs \the [src].</span>")
			qdel(src)
			return
	else
		if (istype(src, /obj/structure/vending/craftable))
			stock(W, null, user)
			return TRUE
		var/datum/data/vending_product/R = restock_record(W)
		if (R)
			stock(W, R, user)
			return TRUE
		..()

// An exact catalog entry wins over an earlier ancestor entry for a variant.
/obj/structure/vending/proc/restock_record(obj/item/W)
	var/datum/data/vending_product/fallback
	for (var/datum/data/vending_product/R in product_records)
		if (W.type == R.product_path)
			return R
		if (!fallback && istype(W, R.product_path))
			fallback = R
	return fallback

/obj/structure/vending/proc/vending_row_key(datum/data/vending_product/R)
	if (!R.base_vending_row_key)
		R.base_vending_row_key = ++next_vending_row_key
	return R.base_vending_row_key

/obj/structure/vending/proc/find_vending_row(key)
	if (!isnum(key) || key < 1 || key != round(key))
		return null
	for (var/datum/data/vending_product/R in product_records)
		if (!QDELETED(R) && R.base_vending_row_key == key && R.amount > 0)
			return R


/obj/structure/vending/attack_hand(mob/living/user as mob)
	if (!user || !isliving(user))
		return
	else
		ui_interact(user)

/**
 *  Display the NanoUI window for the vending machine.
 *
 *  See NanoUI documentation for details.
 */
/obj/structure/vending/ui_actions(ui_key)
	return list("vend", "cancelpurchase", "remove_coin", "togglevoice")

/obj/structure/vending/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE)
	user.set_using_object(src)

	var/list/data = list()
	if (currently_vending)
		data["mode"] = TRUE
		data["product"] = currently_vending.product_name
		data["price"] = currently_vending.price
		data["message_err"] = FALSE
		data["message"] = status_message
		data["message_err"] = status_error
	else
		data["mode"] = FALSE
		var/list/listed_products = list()

		for (var/datum/data/vending_product/I in product_records)

			listed_products.Add(list(list(
				"key" = vending_row_key(I),
				"name" = I.product_name,
				"price" = I.price,
				"color" = I.display_color,
				"amount" = I.amount)))

		data["products"] = listed_products

	open_tgui(user, ui_key, "vending_machine.tmpl", name, 540, 600, data, ui, force_open)

// Resolve the listed row identity, not its current position.
/obj/structure/vending/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	. = TRUE
	var/value = params["value"]
	if (isliving(user))
		if (user.stat || user.restrained())
			return
	else if (isobserver(user))
		if (!check_rights(R_MOD))
			return

	if ((user.contents.Find(src) || (in_range(src, user) && istype(loc, /turf))))
		if ((action == "vend") && (vend_ready) && (!currently_vending))

			var/datum/data/vending_product/R = find_vending_row(value)
			if (!R)
				return

			if (R.price <= 0)
				vend(R, user)

			else
				currently_vending = R
				status_message = "Please insert money to pay for the item."
				status_error = FALSE

		else if (action == "cancelpurchase")
			currently_vending = null

		add_fingerprint(user)
		playsound(user.loc, 'sound/machines/button.ogg', 100, TRUE)
		GLOB.nanomanager.update_uis(src)

/obj/structure/vending/proc/vend(datum/data/vending_product/R, mob/user)
	vend_ready = FALSE //One thing at a time!!
	status_message = "Vending..."
	status_error = FALSE
	GLOB.nanomanager.update_uis(src)

	spawn(vend_delay)
		var/taken = (R in product_records) && !QDELETED(R) && R.get_product(get_turf(src), 1, user)
		playsound(loc, 'sound/machines/vending_drop.ogg', 100, TRUE)
		status_message = ""
		status_error = FALSE
		vend_ready = TRUE
		currently_vending = null
		if (taken && istype(src, /obj/structure/vending/craftable))
			product_records -= R
			qdel(R)
		GLOB.nanomanager.update_uis(src)
		update_icon()

/**
 * Add item to the machine
 *
 * Checks if item is vendable in this machine should be performed before
 * calling. W is the item being inserted, R is the associated vending_product entry.
 */
/obj/structure/vending/proc/stock(obj/item/W, var/datum/data/vending_product/R, var/mob/user)
	if (!user.unEquip(W))
		return

	to_chat(user, "<span class='notice'>You insert \the [W] in \the [src].</span>")
	R.amount++
	qdel(W)

	GLOB.nanomanager.update_uis(src)
	update_icon()

/obj/structure/vending/process()

	if (!active)
		return

	return