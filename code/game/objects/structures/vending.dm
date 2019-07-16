#define CAT_NORMAL TRUE
#define CAT_HIDDEN 2  // also used in corresponding wires/vending.dm
#define CAT_COIN   4

/**
 *  Datum used to hold information about a product in a vending machine
 */
/datum/data/vending_product
	var/product_name = "generic" // Display name for the product
	var/product_path = null
	var/amount = 0            // The original amount held in the vending machine
	var/list/instances
	var/price = 0              // Price to buy one
	var/display_color = null   // Display color for vending machine listing
	var/category = CAT_NORMAL  // CAT_HIDDEN for contraband, CAT_COIN for premium
	var/vending_machine        // The vending machine we belong to


/datum/data/vending_product/New(var/_vending_machine, var/path, var/name = null, var/_amount = 1, var/_price = 0, var/_color = null, var/_category = CAT_NORMAL)
	..()

	product_path = path

	if (!name)
		var/atom/tmp = path
		product_name = initial(tmp.name)
	else
		product_name = name

	amount = _amount
	price = _price
	display_color = _color
	category = _category
	vending_machine = _vending_machine

/datum/data/vending_product/Destroy()
	vending_machine = null
	if (instances)
		for (var/product in instances)
			qdel(product)
		instances.Cut()
	. = ..()

/datum/data/vending_product/proc/get_amount()
	return instances ? instances.len : amount

/datum/data/vending_product/proc/add_product(var/atom/movable/product)
	if (product.type != product_path)
		return FALSE
	init_products()
	product.forceMove(vending_machine)
	instances += product

/datum/data/vending_product/proc/get_product(var/product_location)
	if (!get_amount() || !product_location)
		return
	init_products()

	var/atom/movable/product = instances[instances.len]	// Remove the last added product
	instances -= product
	if (product)
		product.forceMove(product_location)
	return product

/datum/data/vending_product/proc/init_products()
	if (instances)
		return
	instances = list()
	for (var/i = TRUE to amount)
		var/new_product = new product_path(vending_machine)
		instances += new_product

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
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/icon_vend //Icon_state when vending
	var/icon_deny //Icon_state when denying access

	// Power
//	use_power = TRUE
//	idle_power_usage = 10
	var/vend_power_usage = 150 //actuators and stuff

	// Vending-related
	var/active = TRUE //No sales pitches if off!
	var/vend_ready = TRUE //Are we ready to vend?? Is it time??
	var/vend_delay = 5 //How long does it take to vend?
	var/categories = CAT_NORMAL // Bitmask of cats we're currently showing
	var/datum/data/vending_product/currently_vending = null // What we're requesting payment for right now
	var/status_message = "" // Status screen messages like "insufficient funds", displayed in NanoUI
	var/status_error = FALSE // Set to TRUE if status_message is an error

	/*
		Variables used to initialize the product list
		These are used for initialization only, and so are optional if
		product_records is specified
	*/
	var/list/products	= list() // For each, use the following pattern:
	var/list/contraband	= list() // list(/type/path = amount,/type/path2 = amount2)
	var/list/premium 	= list() // No specified amount = only one in stock
	var/list/prices     = list() // Prices for each item, list(/type/path = price), items not in the list don't have a price.

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

	// Things that can go wrong
//	emagged = FALSE //Ignores if somebody doesn't have card access to that machine.
	var/seconds_electrified = FALSE //Shock customers like an airlock.
	var/shoot_inventory = FALSE //Fire items at customers! We're broken!

	var/scan_id = TRUE
	var/obj/item/weapon/coin/coin
	var/datum/wires/vending/wires = null

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
	var/list/all_products = list(
		list(products, CAT_NORMAL),
		list(contraband, CAT_HIDDEN),
		list(premium, CAT_COIN))

	for (var/current_list in all_products)
		var/category = current_list[2]

		for (var/entry in current_list[1])
			var/datum/data/vending_product/product = new/datum/data/vending_product(src, entry)

			product.price = (entry in prices) ? prices[entry] : FALSE
			product.amount = (current_list[1][entry]) ? current_list[1][entry] : TRUE
			product.category = category

			product_records.Add(product)

/obj/structure/vending/Destroy()
//	qdel(wires)
//	wires = null
//	qdel(coin)
//	coin = null
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

	else

		for (var/datum/data/vending_product/R in product_records)
			if (istype(W, R.product_path))
				stock(W, R, user)
				return TRUE
		..()

/**
 *  Receive payment with cashmoney.
 */
/obj/structure/vending/proc/pay_with_cash(var/obj/item/weapon/spacecash/bundle/cashmoney)
	return
	/*
	if (currently_vending.price > cashmoney.worth)
		// This is not a status display message, since it's something the character
		// themselves is meant to see BEFORE putting the money in
		usr << "\icon[cashmoney] <span class='warning'>That is not enough money.</span>"
		return FALSE

	visible_message("<span class='info'>\The [usr] inserts some cash into \the [src].</span>")
	cashmoney.worth -= currently_vending.price

	if (cashmoney.worth <= 0)
		usr.drop_from_inventory(cashmoney)
		qdel(cashmoney)
	else
		cashmoney.update_icon()

	// Vending machines have no idea who paid with cash
	credit_purchase("(cash)")
	return TRUE*/

/**
 * Scan a chargecard and deduct payment from it.
 *
 * Takes payment for whatever is the currently_vending item. Returns TRUE if
 * successful, FALSE if failed.
 */
/obj/structure/vending/proc/pay_with_ewallet(var/obj/item/weapon/spacecash/ewallet/wallet)
	return FALSE
/*	visible_message("<span class='info'>\The [usr] swipes \the [wallet] through \the [src].</span>")
	if (currently_vending.price > wallet.worth)
		status_message = "Insufficient funds on chargecard."
		status_error = TRUE
		return FALSE
	else
		wallet.worth -= currently_vending.price
		credit_purchase("[wallet.owner_name] (chargecard)")
		return TRUE*/

/**
 * Scan a card and attempt to transfer payment from associated account.
 *
 * Takes payment for whatever is the currently_vending item. Returns TRUE if
 * successful, FALSE if failed
 */
/obj/structure/vending/proc/pay_with_card(var/obj/item/weapon/card/id/I, var/obj/item/ID_container)
	return
/*	if (I==ID_container || ID_container == null)
		visible_message("<span class='info'>\The [usr] swipes \the [I] through \the [src].</span>")
	else
		visible_message("<span class='info'>\The [usr] swipes \the [ID_container] through \the [src].</span>")
	var/datum/money_account/customer_account = get_account(I.associated_account_number)
	if (!customer_account)
		status_message = "Error: Unable to access account. Please contact technical support if problem persists."
		status_error = TRUE
		return FALSE

	if (customer_account.suspended)
		status_message = "Unable to access account: account suspended."
		status_error = TRUE
		return FALSE

	// Have the customer punch in the PIN before checking if there's enough money. Prevents people from figuring out acct is
	// empty at high security levels
	if (customer_account.security_level != FALSE) //If card requires pin authentication (ie seclevel TRUE or 2)
		var/attempt_pin = WWinput(usr, "Enter your pin code", "Vendor transaction", 0, "num")
		customer_account = attempt_account_access(I.associated_account_number, attempt_pin, 2)

		if (!customer_account)
			status_message = "Unable to access account: incorrect credentials."
			status_error = TRUE
			return FALSE

	if (currently_vending.price > customer_account.money)
		status_message = "Insufficient funds in account."
		status_error = TRUE
		return FALSE
	else
		// Okay to move the money at this point

		// debit money from the purchaser's account
		customer_account.money -= currently_vending.price

		// create entry in the purchaser's account log
		var/datum/transaction/T = new()
		T.target_name = "[vendor_account.owner_name] (via [name])"
		T.purpose = "Purchase of [currently_vending.product_name]"
		if (currently_vending.price > 0)
			T.amount = "([currently_vending.price])"
		else
			T.amount = "[currently_vending.price]"
		T.source_terminal = name
		T.date = current_date_string
		T.time = stationtime2text()
		customer_account.transaction_log.Add(T)

		// Give the vendor the money. We use the account owner name, which means
		// that purchases made with stolen/borrowed card will look like the card
		// owner made them
		credit_purchase(customer_account.owner_name)
		return TRUE
*/
/**
 *  Add money for current purchase to the vendor account.
 *
 *  Called after the money has already been taken from the customer.
 */
/obj/structure/vending/proc/credit_purchase(var/target as text)
/*	vendor_account.money += currently_vending.price

	var/datum/transaction/T = new()
	T.target_name = target
	T.purpose = "Purchase of [currently_vending.product_name]"
	T.amount = "[currently_vending.price]"
	T.source_terminal = name
	T.date = current_date_string
	T.time = stationtime2text()
	vendor_account.transaction_log.Add(T)*/
	return FALSE

/obj/structure/vending/attack_hand(mob/user as mob)
	if (stat & BROKEN) //|| user.blacklisted == TRUE
		return
/*
	if (seconds_electrified != FALSE)
		if (shock(user, 100))
			return*/

//	wires.Interact(user)
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

			if (!(I.category & categories))
				continue

			listed_products.Add(list(list(
				"key" = key,
				"name" = I.product_name,
				"price" = I.price,
				"color" = I.display_color,
				"amount" = I.get_amount())))

		data["products"] = listed_products

/*	if (coin)
		data["coin"] = coin.name
*/
/*	if (panel_open)
		data["panel"] = TRUE
		data["speaker"] = shut_up ? FALSE : TRUE
	else
		data["panel"] = FALSE*/

	ui = nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "vending_machine.tmpl", name, 440, 600)
		ui.set_initial_data(data)
		ui.open()

/obj/structure/vending/Topic(href, href_list)
	if (stat & BROKEN)
		return

	if (isliving(usr))
		if (usr.stat || usr.restrained())
			return
	else if (isobserver(usr))
		if (!check_rights(R_MOD))
			return
/*
	if (href_list["remove_coin"] && !istype(usr,/mob/living/silicon))
		if (!coin)
			usr << "There is no coin in this machine."
			return

		coin.loc = loc
		if (!usr.get_active_hand())
			usr.put_in_hands(coin)
		usr << "<span class='notice'>You remove the [coin] from the [src]</span>"
		coin = null
		categories &= ~CAT_COIN
*/
	if ((usr.contents.Find(src) || (in_range(src, usr) && istype(loc, /turf))))
		if ((href_list["vend"]) && (vend_ready) && (!currently_vending))
		/*	if (!emagged && scan_id)	//For SECURE VENDING MACHINES YEAH
				usr << "<span class='warning'>Access denied.</span>"	//Unless emagged of course
				flick(icon_deny,src)
				return*/

			var/key = text2num(href_list["vend"])
			var/datum/data/vending_product/R = product_records[key]

			// This should not happen unless the request from NanoUI was bad
			if (!(R.category & categories))
				return

			if (R.price <= 0)
				vend(R, usr)

			else
				currently_vending = R
				status_message = "Please swipe a card or insert cash to pay for the item."
				status_error = FALSE

		else if (href_list["cancelpurchase"])
			currently_vending = null

/*		else if ((href_list["togglevoice"]) && (panel_open))
			shut_up = !shut_up*/

		add_fingerprint(usr)
		playsound(usr.loc, 'sound/machines/button.ogg', 100, TRUE)
		nanomanager.update_uis(src)

/obj/structure/vending/proc/vend(datum/data/vending_product/R, mob/user)
/*	if (!emagged && scan_id)	//For SECURE VENDING MACHINES YEAH
		usr << "<span class='warning'>Access denied.</span>"	//Unless emagged of course
		flick(icon_deny,src)
		return*/
	vend_ready = FALSE //One thing at a time!!
	status_message = "Vending..."
	status_error = FALSE
	nanomanager.update_uis(src)
/*
	if (R.category & CAT_COIN)
		if (!coin)
			user << "<span class='notice'>You need to insert a coin to get this item.</span>"
			return
		if (coin.string_attached)
			if (prob(50))
				user << "<span class='notice'>You successfully pull the coin out before \the [src] could swallow it.</span>"
			else
				user << "<span class='notice'>You weren't able to pull the coin out fast enough, the machine ate it, string and all.</span>"
				qdel(coin)
				categories &= ~CAT_COIN
		else
			qdel(coin)
			categories &= ~CAT_COIN
*/
/*
	if (((last_reply + (vend_delay + 200)) <= world.time) && vend_reply)
		spawn(0)
			speak(vend_reply)
			last_reply = world.time
*/
//	use_power(vend_power_usage)	//actuators and stuff
	if (icon_vend) //Show the vending animation if needed
		flick(icon_vend,src)
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
/obj/structure/vending/proc/stock(obj/item/weapon/W, var/datum/data/vending_product/R, var/mob/user)
	if (!user.unEquip(W))
		return

	user << "<span class='notice'>You insert \the [W] in the rack.</span>"
	R.add_product(W)

	nanomanager.update_uis(src)

/obj/structure/vending/process()
	if (stat & (BROKEN|NOPOWER))
		return

	if (!active)
		return

	if (seconds_electrified > 0)
		seconds_electrified--

	return