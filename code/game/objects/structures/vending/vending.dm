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


	// Variables used to initialize advertising
	var/product_slogans = "" //String of slogans spoken out loud, separated by semicolons
	var/product_ads = "" //String of small ad messages in the vending screen

	var/list/ads_list = list()

	// Stuff relating vocalizations
	var/list/slogan_list = list()
	var/shut_up = FALSE //Let spouting those godawful pitches!
	var/vend_reply //Thank you for shopping!
	var/last_reply = FALSE
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
	if (istype(W, /obj/item/weapon/wrench))
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

	if (istype(W, /obj/item/weapon/hammer))
		visible_message("<span class='warning'>[user] starts to deconstruct \the [src].</span>")
		playsound(src, 'sound/items/Ratchet.ogg', 100, TRUE)
		if (do_after(user,50,src))
			visible_message("<span class='warning'>[user] deconstructs \the [src].</span>")
			qdel(src)
			return
	else
		if (istype(src, /obj/structure/vending/craftable))
			var/obj/structure/vending/craftable/CTB = src
			if (product_records.len >= CTB.max_products)
				user << "<span class='notice'>\The [src] is full!</span>"
				return FALSE
			else
				var/datum/data/vending_product/product = new/datum/data/vending_product(src, W.type, W.name, _icon = W.icon, _icon_state = W.icon_state, M = W)
				product.price = 0
				stock(W,product,user)
				return TRUE
		else
			for (var/datum/data/vending_product/R in product_records)
				if (istype(W, R.product_path))
					stock(W, R, user)
					return TRUE
		..()


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

		for (var/key = TRUE to product_records.len)
			var/datum/data/vending_product/I = product_records[key]

			listed_products.Add(list(list(
				"key" = key,
				"name" = I.product_name,
				"price" = I.price,
				"color" = I.display_color,
				"amount" = I.amount)))

		data["products"] = listed_products

	ui = nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "vending_machine.tmpl", name, 440, 600)
		ui.set_initial_data(data)
		ui.open()

/obj/structure/vending/Topic(href, href_list)
	if (isliving(usr))
		if (usr.stat || usr.restrained())
			return
	else if (isobserver(usr))
		if (!check_rights(R_MOD))
			return

	if ((usr.contents.Find(src) || (in_range(src, usr) && istype(loc, /turf))))
		if ((href_list["vend"]) && (vend_ready) && (!currently_vending))

			var/key = text2num(href_list["vend"])
			var/datum/data/vending_product/R = product_records[key]

			if (R.price <= 0)
				vend(R, usr)

			else
				currently_vending = R
				status_message = "Please insert money to pay for the item."
				status_error = FALSE

		else if (href_list["cancelpurchase"])
			currently_vending = null

		add_fingerprint(usr)
		playsound(usr.loc, 'sound/machines/button.ogg', 100, TRUE)
		nanomanager.update_uis(src)

/obj/structure/vending/proc/vend(datum/data/vending_product/R, mob/user)
	vend_ready = FALSE //One thing at a time!!
	status_message = "Vending..."
	status_error = FALSE
	nanomanager.update_uis(src)

	spawn(vend_delay)
		R.get_product(get_turf(src),1,user)
		playsound(loc, 'sound/machines/vending_drop.ogg', 100, TRUE)
		status_message = ""
		status_error = FALSE
		vend_ready = TRUE
		currently_vending = null
		if (istype(src, /obj/structure/vending/craftable))
			product_records -= R
		nanomanager.update_uis(src)
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

	user << "<span class='notice'>You insert \the [W] in \the [src].</span>"
	R.amount++
	qdel(W)

	nanomanager.update_uis(src)
	update_icon()

/obj/structure/vending/process()

	if (!active)
		return

	return