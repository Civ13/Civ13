/**
 *  A vending machine / market stall that actually charges per sale.
 */
/obj/structure/vending/sales
	name = "Vending Machine"
	desc = "A generic vending machine."
	icon = 'icons/obj/vending.dmi'
	icon_state = "snack"
	layer = 2.9
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/moneyin = 0
	var/accepted_currency = "standard"
	var/owner = "Global"
	var/max_products = 5
	var/sound_type = 'sound/machines/vending_drop.ogg'
	var/vendor_style = "modern"
	var/tmp/mob/pending_buyer = null // who is paying for currently_vending
	var/tmp/pending_amount = 0

/obj/structure/vending/ex_act(severity)
	return

/** Handles payment insertion, maintenance (wrenching), and product restocking by authorized company members. */
/obj/structure/vending/sales/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/money))
		if (accepted_currency == "standard")
			if (istype(W, /obj/item/stack/money/fiat))
				to_chat(user, "This vending machine does not accept fiat money.")
				return
			var/obj/item/stack/money/M = W
			moneyin += M.amount*M.value
			if (map.ID == MAP_KANDAHAR)
				to_chat(user, "You give \the [W] to the [src].")
			else
				to_chat(user, "You put \the [W] in the [src].")
			qdel(W)
			finish_pending_purchase(user)
			return
		else
			if (!istype(W, /obj/item/stack/money/fiat))
				to_chat(user, "This vending machine only accepts fiat money.")
				return
			var/obj/item/stack/money/fiat/F = W
			if (F.fiat_id != accepted_currency)
				to_chat(user, "This vending machine does not accept this currency.")
				return
			moneyin += F.amount
			if (map.ID == MAP_KANDAHAR)
				to_chat(user, "You give \the [W] to the [src].")
			else
				to_chat(user, "You put \the [W] in the [src].")
			qdel(W)
			finish_pending_purchase(user)
			return
	else if (is_tool(W, TOOL_WRENCH))
		if (owner != "Global" && find_company_member(user,owner))
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

	else
		if (owner != "Global" && find_company_member(user,owner))
			for (var/datum/data/vending_product/R in product_records)
				if (istype(W, R.product_path) && W.name == R.product_name)
					if (istype(W, /obj/item/stack))
						R.amount += W.amount
						qdel(W)
						return TRUE
					else
						stock(W, R, user)
						return TRUE
			//if it isn't in the list yet
			if (!product_slot_free())
				to_chat(user, "<span class='notice'>This [src] has too many different products already!</span>")
				return FALSE
			// Ask the price while the item is still in hand, then stock it only if the
			// seller still holds it and still stands at the stall.
			var/inputp = player_input(user, "What price do you want to set for \the [W]?", "Product Price", null, "num", null, FALSE)
			if (QDELETED(src) || QDELETED(W) || W.loc != user || !in_range(src, user))
				return FALSE
			return add_product(W, inputp, user)

// A free product row, reusing an emptied one when the stall is full.
/obj/structure/vending/sales/proc/product_slot_free()
	if (product_records.len < max_products)
		return TRUE
	for (var/datum/data/vending_product/R in product_records)
		if (R.amount <= 0)
			return TRUE
	return FALSE

// Lists a new product: the item moves into the stall (a stack becomes a count).
/obj/structure/vending/sales/proc/add_product(obj/item/W, price, mob/user)
	if (product_records.len >= max_products)
		var/datum/data/vending_product/free = null
		for (var/datum/data/vending_product/R in product_records)
			if (R.amount <= 0)
				free = R
		if (!free)
			if (user)
				to_chat(user, "<span class='notice'>This [src] has too many different products already!</span>")
			return FALSE
		product_records -= free
		qdel(free)
	if (user && !user.unEquip(W))
		return FALSE
	if (!isnum(price) || price < 0)
		price = 0
	// The record consumes a stack, so read its size first.
	var/stack_amount = 0
	if (istype(W, /obj/item/stack))
		var/obj/item/stack/S = W
		stack_amount = S.amount
	var/datum/data/vending_product/product = new/datum/data/vending_product(src, W.type, W.name, _icon = W.icon, _icon_state = W.icon_state, M = W)
	product.price = price
	if (stack_amount)
		product.amount = stack_amount
		if (!QDELETED(W))
			qdel(W)
	else if (!QDELETED(W) && W.loc != src)
		W.forceMove(src)
	product_records.Add(product)
	if (user)
		to_chat(user, "<span class='notice'>You put \the [product.product_name] up for sale at [price].</span>")
	update_icon()
	GLOB.nanomanager.update_uis(src)
	return TRUE

/** Management menu for owners to change the vendor name, adjust prices, remove stock, or change accepted currency. */
/obj/structure/vending/sales/verb/Manage()
	set category = null
	set src in range(1)

	if (!istype(usr, /mob/living/human))
		return

	if (owner != "Global" && find_company_member(usr,owner))
		show_management_ui(usr)
	else
		to_chat(usr, "You do not have permission to manage this vendor.")

/obj/structure/vending/sales/proc/show_management_ui(mob/user)
	ui_interact(user, "manage")

// The owner's management window: name, prices, stock removal and currency.
/obj/structure/vending/sales/proc/manage_interact(mob/user, ui_key, datum/nanoui/ui, force_open)
	if (owner == "Global" || !find_company_member(user, owner))
		GLOB.nanomanager.close_user_uis(user, src, ui_key)
		return
	var/list/currencies = list(panel_option("standard", "Standard Coins"))
	for (var/cid in fiat.currency_list)
		if (fiat.currency_list[cid][5])
			currencies += list(panel_option(cid, fiat.currency_list[cid][1]))
	var/list/stock = list()
	var/list/prices = list()
	for (var/i = 1 to product_records.len)
		var/datum/data/vending_product/VP = product_records[i]
		stock += list(panel_item(VP.product_name, "Price: [VP.price]", list(panel_button("Remove", "removeproduct", i))))
		prices += list(panel_form(VP.product_name, "changeprice", i, list(panel_field("price", "New price", VP.price)), "Set Price"))
	open_panel(user, "Vendor Management - [name]", 500, 550, list(
		panel_section("Name", forms = list(panel_form("Name", "rename", 1, list(panel_field("value", "New name", name, "text")), "Change Name"))),
		panel_section("Products", items = stock, empty = "No products in this vendor."),
		panel_section("Prices", forms = prices),
		panel_section("Currency", forms = list(panel_form("Accepted currency", "changecurrency", 1, list(panel_field("value", "Paid in", accepted_currency, "choice", currencies)), "Apply")))),
		ui_key = ui_key, ui = ui, force_open = force_open)

// A press in the management window. A product is its row number in product_records.
/obj/structure/vending/sales/proc/manage_act(action, list/params, mob/user)
	if (isliving(user))
		if (user.stat || user.restrained())
			return
	else if (isobserver(user))
		if (!check_rights(R_MOD))
			return
	if (!(user.contents.Find(src) || (in_range(src, user) && istype(loc, /turf))))
		return
	if (owner == "Global" || !find_company_member(user, owner))
		return
	var/value = params["value"]
	var/datum/data/vending_product/VP = null
	if (action == "changeprice" || action == "removeproduct")
		var/index = text2num("[value]")
		if (!isnum(index) || index < 1 || index > product_records.len || index != round(index))
			return
		VP = product_records[index]
	switch (action)
		if ("rename")
			var/new_name = sanitize("[value]", 50)
			if (new_name && new_name != "")
				name = new_name
		if ("changeprice")
			var/new_price = text2num("[params["price"]]")
			if (!isnull(new_price) && new_price >= 0)
				VP.price = new_price
		if ("removeproduct")
			vend(VP, user, VP.amount)
		if ("changecurrency")
			if (moneyin > 0)
				to_chat(user, "<span class='warning'>You must empty the vendor of all funds before changing its accepted currency.</span>")
				return
			var/new_currency = "[value]"
			if (new_currency != "standard" && !((new_currency in fiat.currency_list) && fiat.currency_list[new_currency][5]))
				return
			accepted_currency = new_currency
			to_chat(user, "<span class='notice'>This vendor now accepts [new_currency == "standard" ? "Standard Coins" : fiat.currency_list[new_currency][1]].</span>")

/** Internal procedure to deliver the selected product after successful payment and update the vendor status. */
/obj/structure/vending/sales/vend(datum/data/vending_product/R, mob/user, var/p_amount=1)
	vend_ready = FALSE //One thing at a time!!
	status_message = "Vending..."
	status_error = FALSE
	GLOB.nanomanager.update_uis(src)

	spawn(vend_delay)
		R.get_product(get_turf(src),p_amount,user)
		playsound(loc, sound_type, 100, TRUE)
		status_message = ""
		status_error = FALSE
		vend_ready = TRUE
		currently_vending = null
		update_icon()
		GLOB.nanomanager.update_uis(src)

/**
 * Add item to the machine
 *
 * Checks if item is vendable in this machine should be performed before
 * calling. W is the item being inserted, R is the associated vending_product entry.
 */

/** Displays the NanoUI purchase interface to customers. */
/obj/structure/vending/sales/ui_actions(ui_key)
	if (ui_key == "manage")
		var/list/management = list("rename", "changeprice", "removeproduct", "changecurrency")
		return management
	return list("vend", "cancelpurchase", "remove_money", "togglevoice")

/obj/structure/vending/sales/ui_action_fields(ui_key, action)
	if (ui_key == "manage" && action == "changeprice")
		return list("price")
	return ..()

/obj/structure/vending/sales/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE)
	if (ui_key == "manage")
		manage_interact(user, ui_key, ui, force_open)
		return
	user.set_using_object(src)

	var/list/data = list()
	data["modern"] = (vendor_style == "modern")
	var/cur_name = "silver coins"
	var/cur_short = "sc"
	if (accepted_currency != "standard")
		cur_name = fiat.currency_list[accepted_currency][1]
		cur_short = fiat.currency_list[accepted_currency][2]
	else if (map.ID == MAP_THE_ART_OF_THE_DEAL || map.ID == MAP_KANDAHAR)
		cur_name = "dollars"
		cur_short = "$"
	else if (map.ID == MAP_GULAG13 || map.ID == MAP_PEPELSIBIRSK)
		cur_name = "rubles"
		cur_short = "rubles"
	if (currently_vending)
		data["mode"] = TRUE
		data["company"] = owner
		data["product"] = currently_vending.product_name
		data["currency_name"] = cur_name
		data["currency_short"] = cur_short
		if (map.ID == MAP_THE_ART_OF_THE_DEAL)
			data["price"] = currently_vending.price/4
		else
			data["price"] = currently_vending.price
		data["message_err"] = FALSE
		data["message"] = status_message
		data["message_err"] = status_error
		if (map.ID == MAP_THE_ART_OF_THE_DEAL)
			data["moneyin"] = moneyin/4
		else
			data["moneyin"] = moneyin
	else
		data["mode"] = FALSE
		data["company"] = owner
		data["currency_name"] = cur_name
		data["currency_short"] = cur_short
		if (map.ID == MAP_THE_ART_OF_THE_DEAL)
			data["moneyin"] = moneyin/4
		else
			data["moneyin"] = moneyin
		var/list/listed_products = list()

		for (var/key = TRUE to product_records.len)
			var/datum/data/vending_product/I = product_records[key]
			if (map.ID == MAP_THE_ART_OF_THE_DEAL)
				listed_products.Add(list(list(
					"key" = key,
					"name" = I.product_name,
					"price" = I.price/4,
					"color" = I.display_color,
					"amount" = I.amount)))
			else
				listed_products.Add(list(list(
					"key" = key,
					"name" = I.product_name,
					"price" = I.price,
					"color" = I.display_color,
					"amount" = I.amount)))

		data["products"] = listed_products

	var/template = "vending_machine2.tmpl"
	if (map.ID == MAP_THE_ART_OF_THE_DEAL || map.ID == MAP_KANDAHAR)
		template = "vending_machine_taotd.tmpl"
	else if (map.ID == MAP_GULAG13)
		template = "vending_machine_gulag.tmpl"
	open_tgui(user, ui_key, template, name, 540, 600, data, ui, force_open)

/** Handles the purchase window's buttons: buying, cancelling and withdrawing inserted funds. The product is its row number in product_records. */
/obj/structure/vending/sales/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	. = TRUE
	if (ui && ui.ui_key == "manage")
		manage_act(action, params, user)
		return
	var/value = params["value"]
	if (isliving(user))
		if (user.stat || user.restrained())
			return
	else if (isobserver(user))
		if (!check_rights(R_MOD))
			return

	if ((user.contents.Find(src) || (in_range(src, user) && istype(loc, /turf))))
		if ((action == "vend") && (vend_ready) && (!currently_vending))

			if (find_company_member(user,owner))
				to_chat(user, "<span class='warning'>You can't buy from your own company. Remove the product instead.</span>")
				status_error = FALSE
				currently_vending = null
			else

				var/key = value
				if (!isnum(key) || key != round(key) || key < 1 || key > product_records.len)
					return
				var/datum/data/vending_product/R = product_records[key]

				var/inp = 1
				if (R.amount > 1)
					inp = player_input(user, "How many do you want to buy? (1 to [R.amount])", 1, null, "num", null, FALSE)
					inp = round(inp)
					if (inp>R.amount)
						inp = R.amount
					else if (inp<=1)
						inp = 1

				if (R.price <= 0)
					vend(R, user, inp)

				else
					complete_purchase(R, user, inp)

		else if (action == "cancelpurchase")
			currently_vending = null
			pending_buyer = null
			pending_amount = 0

		else if (action == "remove_money")
			if (accepted_currency != "standard")
				if (moneyin > 0)
					new/obj/item/stack/money/fiat(loc, moneyin, accepted_currency)
			else if (map.ID == MAP_THE_ART_OF_THE_DEAL)
				var/obj/item/stack/money/dollar/D = new/obj/item/stack/money/dollar(loc)
				D.amount = round(moneyin/D.value)
				if (D.amount == 0)
					qdel(D)
			else if (map.ID == MAP_GULAG13)
				var/obj/item/stack/money/rubles/D = new/obj/item/stack/money/rubles(loc)
				D.amount = round(moneyin/D.value)
				if (D.amount == 0)
					qdel(D)
			else if (map.ID == MAP_PEPELSIBIRSK)
				var/obj/item/stack/money/rubles/D = new/obj/item/stack/money/rubles(loc)
				D.amount = round(moneyin/D.value)
				if (D.amount == 0)
					qdel(D)
			else if (map.ID == MAP_KANDAHAR)
				var/obj/item/stack/money/dollar/D = new/obj/item/stack/money/dollar(loc)
				D.amount = round(moneyin/D.value)
				if (D.amount == 0)
					qdel(D)
			else
				var/obj/item/stack/money/goldcoin/GC = new/obj/item/stack/money/goldcoin(loc)
				GC.amount = moneyin/GC.value
				if (GC.amount == 0)
					qdel(GC)
			moneyin = 0
			GLOB.nanomanager.update_uis(src)
			return

		add_fingerprint(user)
		playsound(user.loc, 'sound/machines/button.ogg', 100, TRUE)
		GLOB.nanomanager.update_uis(src)


// A buyer who pressed Buy before depositing enough finishes the purchase by
// depositing the rest.
/obj/structure/vending/sales/proc/finish_pending_purchase(mob/user)
	if (!currently_vending || pending_buyer != user || !vend_ready)
		GLOB.nanomanager.update_uis(src)
		return FALSE
	var/datum/data/vending_product/R = currently_vending
	if (!(R in product_records) || R.amount < pending_amount || pending_amount < 1)
		currently_vending = null
		pending_buyer = null
		pending_amount = 0
		GLOB.nanomanager.update_uis(src)
		return FALSE
	. = complete_purchase(R, user, pending_amount)
	GLOB.nanomanager.update_uis(src)

// Charges a buyer for inp of product R from the money already deposited and
// hands the goods over. Without enough money the purchase waits, and the next
// deposit from the same buyer completes it.
/obj/structure/vending/sales/proc/complete_purchase(datum/data/vending_product/R, mob/user, inp)
	var/mob/living/human/H = ishuman(user) ? user : null
	var/list/civ_entry = null
	if (H && H.civilization && H.civilization != "none" && map.custom_civs)
		civ_entry = map.custom_civs[H.civilization]
	var/salestax = 0
	if (map.ID != MAP_KANDAHAR && islist(civ_entry) && civ_entry.len >= 9 && isnum(civ_entry[9]))
		salestax = (civ_entry[9]/100)*R.price
	var/price_with_tax = R.price+salestax
	currently_vending = R
	pending_buyer = user
	pending_amount = inp
	if (moneyin < price_with_tax*inp)
		status_message = "Please insert [price_with_tax*inp] to pay for the item."
		status_error = FALSE
		return FALSE
	else
		moneyin -= price_with_tax*inp
		// The buyer pays price + sales tax once: the company keeps the
		// price and the buyer's faction treasury gets the tax.
		if (owner != "Global")
			if (accepted_currency == "standard")
				map.custom_company_value[owner] += R.price*inp
				if (islist(civ_entry))
					civ_entry[5] += salestax*inp
			else
				if (!map.custom_company_fiat_value[owner])
					map.custom_company_fiat_value[owner] = list()
				if (!map.custom_company_fiat_value[owner][accepted_currency])
					map.custom_company_fiat_value[owner][accepted_currency] = 0
				map.custom_company_fiat_value[owner][accepted_currency] += R.price*inp
				if (salestax > 0 && islist(civ_entry))
					var/list/civ = civ_entry
					if (civ.len < 11)
						civ.len = 11
					if (!istype(civ[11], /list))
						civ[11] = list()
					civ[11][accepted_currency] = (civ[11][accepted_currency] || 0) + salestax*inp
		if (accepted_currency != "standard")
			if (moneyin > 0)
				new/obj/item/stack/money/fiat(loc, moneyin, accepted_currency)
		else if (map.ID == MAP_THE_ART_OF_THE_DEAL)
			var/obj/item/stack/money/dollar/D = new/obj/item/stack/money/dollar(loc)
			D.amount = round(moneyin/D.value)
			if (D.amount == 0)
				qdel(D)
		else if (map.ID == MAP_GULAG13)
			var/obj/item/stack/money/rubles/D = new/obj/item/stack/money/rubles(loc)
			D.amount = round(moneyin/D.value)
			if (D.amount == 0)
				qdel(D)
		else if (map.ID == MAP_PEPELSIBIRSK)
			var/obj/item/stack/money/rubles/D = new/obj/item/stack/money/rubles(loc)
			D.amount = round(moneyin/D.value)
			if (D.amount == 0)
				qdel(D)
		else if (map.ID == MAP_KANDAHAR)
			var/obj/item/stack/money/dollar/D = new/obj/item/stack/money/dollar(loc)
			D.amount = round(moneyin/D.value)
			if (D.amount == 0)
				qdel(D)
		else
			if (moneyin > 0 && moneyin <= 3)
				var/obj/item/stack/money/coppercoin/NM = new/obj/item/stack/money/coppercoin(loc)
				NM.amount = moneyin/NM.value
				if (NM.amount <= 0)
					qdel(NM)
			else if (moneyin > 3 && moneyin <= 40)
				var/obj/item/stack/money/silvercoin/NM = new/obj/item/stack/money/silvercoin(loc)
				NM.amount = moneyin/NM.value
				if (NM.amount <= 0)
					qdel(NM)
			else
				var/obj/item/stack/money/goldcoin/NM = new/obj/item/stack/money/goldcoin(loc)
				NM.amount = moneyin/NM.value
				if (NM.amount <= 0)
					qdel(NM)
		moneyin = 0
		pending_buyer = null
		pending_amount = 0
		vend(R, user, inp)
		GLOB.nanomanager.update_uis(src)
	return TRUE

//VENDING MACHINES
/obj/structure/vending/sales/food
	name = "food vending machine"
	desc = "Basic food products."
	icon_state = "nutrimat"
	products = list(
		/obj/item/weapon/reagent_containers/food/snacks/grown/apple = 15,
	)
	prices = list(
		/obj/item/weapon/reagent_containers/food/snacks/grown/apple = 0.15,
	)

/obj/structure/vending/sales/food/fruits
	name = "fruit vending machine"
	desc = "Basic food products."
	icon_state = "nutrimat"
	products = list(
		/obj/item/weapon/reagent_containers/food/snacks/grown/apple = 15,
		/obj/item/weapon/reagent_containers/food/snacks/grown/banana = 15,
		/obj/item/weapon/reagent_containers/food/snacks/grown/orange = 15,
		/obj/item/weapon/reagent_containers/food/snacks/grown/cherry = 15,
		/obj/item/weapon/reagent_containers/food/snacks/grown/apricot = 15,
		/obj/item/weapon/reagent_containers/food/snacks/grown/coconut = 15,
	)
	prices = list(
		/obj/item/weapon/reagent_containers/food/snacks/grown/apple = 8,
		/obj/item/weapon/reagent_containers/food/snacks/grown/banana = 8,
		/obj/item/weapon/reagent_containers/food/snacks/grown/orange = 8,
		/obj/item/weapon/reagent_containers/food/snacks/grown/cherry = 8,
		/obj/item/weapon/reagent_containers/food/snacks/grown/apricot = 8,
		/obj/item/weapon/reagent_containers/food/snacks/grown/coconut = 8,
	)
/obj/structure/vending/sales/food/snacks
	name = "baker's vending machine"
	desc = "Basic food products."
	icon_state = "snack"
	products = list(
		/obj/item/weapon/reagent_containers/food/snacks/toastedsandwich = 15,
		/obj/item/weapon/reagent_containers/food/snacks/sandwich = 15,
		/obj/item/weapon/reagent_containers/food/snacks/grilledcheese = 15,
		/obj/item/weapon/reagent_containers/food/snacks/creamcheesebreadslice = 15,
		/obj/item/weapon/reagent_containers/food/snacks/bananabreadslice = 15,
		/obj/item/weapon/reagent_containers/food/snacks/applecakeslice = 15,
	)
	prices = list(
		/obj/item/weapon/reagent_containers/food/snacks/toastedsandwich = 20,
		/obj/item/weapon/reagent_containers/food/snacks/sandwich = 20,
		/obj/item/weapon/reagent_containers/food/snacks/grilledcheese = 20,
		/obj/item/weapon/reagent_containers/food/snacks/creamcheesebreadslice = 16,
		/obj/item/weapon/reagent_containers/food/snacks/bananabreadslice = 16,
		/obj/item/weapon/reagent_containers/food/snacks/applecakeslice = 16,
	)

/obj/structure/vending/sales/food/hot
	name = "hot meal vending machine"
	desc = "Basic food products."
	icon_state = "hotfood"
	products = list(
		/obj/item/weapon/reagent_containers/food/snacks/meatballspagetti = 15,
		/obj/item/weapon/reagent_containers/food/snacks/meatpie = 15,
		/obj/item/weapon/reagent_containers/food/snacks/vegetablesoup = 15,
		/obj/item/weapon/reagent_containers/food/snacks/grilledcheese = 20,
	)
	prices = list(
		/obj/item/weapon/reagent_containers/food/snacks/meatballspagetti = 20,
		/obj/item/weapon/reagent_containers/food/snacks/meatpie = 15,
		/obj/item/weapon/reagent_containers/food/snacks/vegetablesoup = 10,
		/obj/item/weapon/reagent_containers/food/snacks/grilledcheese = 10,
	)

/obj/structure/vending/sales/drinks
	name = "drinks vending machine"
	desc = "Basic beverages."
	icon_state = "soda"
	products = list(
		/obj/item/weapon/reagent_containers/food/drinks/can/cola = 15,
		/obj/item/weapon/reagent_containers/food/drinks/can/tonic = 15,
		/obj/item/weapon/reagent_containers/food/drinks/can/ice_tea = 15,
		/obj/item/weapon/reagent_containers/food/drinks/can/lemonade = 15,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/plastic/water = 10,
	)
	prices = list(
		/obj/item/weapon/reagent_containers/food/drinks/can/cola = 5,
		/obj/item/weapon/reagent_containers/food/drinks/can/tonic = 5,
		/obj/item/weapon/reagent_containers/food/drinks/can/ice_tea = 5,
		/obj/item/weapon/reagent_containers/food/drinks/can/lemonade = 5,
		/obj/item/weapon/reagent_containers/food/drinks/bottle/plastic/water  = 5,
	)
/obj/structure/vending/sales/drinks/cola
	name = "cola vending machine"
	icon_state = "cola"
	products = list(/obj/item/weapon/reagent_containers/food/drinks/can/cola = 30)
	prices = list(/obj/item/weapon/reagent_containers/food/drinks/can/cola = 5)

/obj/structure/vending/sales/drinks/soviet //To be filled with appropriate drink when its added
	icon_state = "sovietsoda"
	products = list()
	prices = list()

/obj/structure/vending/sales/drinks/hot
	name = "hot drinks vending machine"
	desc = "Basic hot beverages."
	icon_state = "coffee"
	products = list(
		/obj/item/weapon/reagent_containers/food/drinks/coffee = 20,
		/obj/item/weapon/reagent_containers/food/drinks/h_chocolate = 20,
		/obj/item/weapon/reagent_containers/food/drinks/tea = 20,
	)
	prices = list(
		/obj/item/weapon/reagent_containers/food/drinks/coffee = 10,
		/obj/item/weapon/reagent_containers/food/drinks/h_chocolate = 10,
		/obj/item/weapon/reagent_containers/food/drinks/tea = 10,
	)

/obj/structure/vending/sales/cigarettes
	name = "cigarette vending machine"
	desc = "Have a break, take a smoke."
	icon_state = "cigs"
	products = list(
		/obj/item/weapon/storage/fancy/cigarettes/marlboro = 10,
		/obj/item/weapon/storage/fancy/cigarettes/luckystrike = 10,
		/obj/item/weapon/storage/fancy/cigarettes/newport = 10,
		/obj/item/weapon/storage/fancy/cigarettes/prima = 10,
		/obj/item/weapon/flame/lighter/random = 15,
		/obj/item/weapon/flame/lighter/zippo = 2,
		/obj/item/weapon/matchbox = 20,
	)
	prices = list(
		/obj/item/weapon/storage/fancy/cigarettes/marlboro = 10,
		/obj/item/weapon/storage/fancy/cigarettes/luckystrike = 10,
		/obj/item/weapon/storage/fancy/cigarettes/newport = 10,
		/obj/item/weapon/storage/fancy/cigarettes/prima = 10,
		/obj/item/weapon/flame/lighter/random = 5,
		/obj/item/weapon/flame/lighter/zippo = 50,
		/obj/item/weapon/matchbox = 5,
	)
// MARKET STALLS//
/obj/structure/vending/sales/market_stall/prepared
	name = "market stall"
	desc = "A market stall selling an assortment of goods."
	icon_state = "market_stall"
	products = list(
		/obj/item/weapon/reagent_containers/food/snacks/grown/apple = 10,
		/obj/item/weapon/reagent_containers/food/snacks/grown/cabbage = 10,
		/obj/item/weapon/reagent_containers/food/snacks/grown/carrot = 10,
		/obj/item/weapon/reagent_containers/food/snacks/sliceable/bread = 10

	)
	prices = list(
		/obj/item/weapon/reagent_containers/food/snacks/grown/apple = 1.5,
		/obj/item/weapon/reagent_containers/food/snacks/grown/cabbage = 1.5,
		/obj/item/weapon/reagent_containers/food/snacks/grown/carrot = 1.5,
		/obj/item/weapon/reagent_containers/food/snacks/sliceable/bread = 3.5
	)
	New()
		..()
		spawn(20)
			update_icon()

/obj/structure/vending/sales/market_stall/prepared/gulag
	name = "apparel comissary"
	desc = "A prison vending stall where prisoners can spend their hard-earned Rubles."
	products = list(
		/obj/item/clothing/gloves/watch/goldwatch = 5,
		/obj/item/clothing/glasses/monocle = 20,
		/obj/item/clothing/glasses/sunglasses = 20,
		/obj/item/clothing/head/bowler_hat = 20,
		/obj/item/clothing/suit/storage/coat/fancy_fur_coat = 5
	)
	prices = list(
		/obj/item/clothing/gloves/watch/goldwatch = 200,
		/obj/item/clothing/glasses/monocle = 50,
		/obj/item/clothing/glasses/sunglasses = 30,
		/obj/item/clothing/head/bowler_hat = 40,
		/obj/item/clothing/suit/storage/coat/fancy_fur_coat = 200
	)

/obj/structure/vending/sales/market_stall/prepared/gulag/food
	name = "food comissary"
	products = list(
		/obj/item/weapon/reagent_containers/food/snacks/sliceable/bread = 50,
		/obj/item/weapon/reagent_containers/food/snacks/cheesewedge = 50,
		/obj/item/weapon/reagent_containers/food/snacks/sausage/salted/salami = 50,
		/obj/item/weapon/reagent_containers/food/snacks/meatpie = 50,
		/obj/item/weapon/reagent_containers/food/snacks/sandwich = 50
	)
	prices = list(
		/obj/item/weapon/reagent_containers/food/snacks/sliceable/bread = 10,
		/obj/item/weapon/reagent_containers/food/snacks/cheesewedge = 5,
		/obj/item/weapon/reagent_containers/food/snacks/sausage/salted/salami = 15,
		/obj/item/weapon/reagent_containers/food/snacks/meatpie = 15,
		/obj/item/weapon/reagent_containers/food/snacks/sandwich = 15
	)

/obj/structure/vending/sales/market_stall/prepared/gulag/consumables
	name = "consumables comissary"
	products = list(
		/obj/item/weapon/reagent_containers/food/drinks/bottle/vodka = 50,
		/obj/item/weapon/storage/fancy/cigarettes/randompack/lighter = 50,
		/obj/item/weapon/storage/fancy/cigar/full = 50,
		/obj/item/weapon/reagent_containers/pill/cocaine = 50,
		/obj/item/clothing/mask/smokable/cigarette/joint = 50
	)
	prices = list(
		/obj/item/weapon/reagent_containers/food/drinks/bottle/vodka = 40,
		/obj/item/weapon/storage/fancy/cigarettes/randompack/lighter = 15,
		/obj/item/weapon/storage/fancy/cigar/full = 180,
		/obj/item/weapon/reagent_containers/pill/cocaine = 200,
		/obj/item/clothing/mask/smokable/cigarette/joint = 70
	)

////MONEY COUNTER

/obj/structure/vending/sales/moneycounter
	name = "currency counter"
	desc = "Useful for easily merging piles of money into one clean stack."
	icon_state = "CurrencyCounter"
	products = list()
	prices = list()

////MARKET STALL AND VENDORS CUSTOM OBJECTS////
// The owning company's colour; a company missing from the colour list (one
// dissolved, or not loaded yet) falls back to the global colours instead of
// a runtime that would leave the stall invisible.
/obj/structure/vending/sales/proc/company_color(index)
	var/list/colors = map && map.custom_company_colors ? map.custom_company_colors[owner] : null
	if (!islist(colors) || colors.len < index)
		return index == 1 ? "#000000" : "#FFFFFF"
	return colors[index]

/obj/structure/vending/sales/market_stall
	name = "market stall"
	desc = "A market stall selling an assortment of goods."
	icon_state = "market_stall"
	vendor_style = "classic"
	var/image/overlay_primary = null
	var/image/overlay_secondary = null

/obj/structure/vending/sales/market_stall/New()
	..()
	invisibility = 101
	spawn(3)
		overlay_primary = image(icon = icon, icon_state = "[icon_state]_overlay_primary")
		overlay_primary.color = company_color(1)
		overlay_secondary = image(icon = icon, icon_state = "[icon_state]_overlay_secondary")
		overlay_secondary.color = company_color(2)
		update_icon()
		invisibility = 0

/obj/structure/vending/sales/market_stall/update_icon()
	overlays.Cut()
	if (overlay_primary && overlay_secondary)
		overlay_primary.color = company_color(1)
		overlay_secondary.color = company_color(2)
		overlays += overlay_primary
		overlays += overlay_secondary
	var/ct1 = 0
	for(var/datum/data/vending_product/VP in product_records)
		if (VP.product_image)
			var/image/NI = VP.product_image
			NI.layer = layer+0.01
			var/matrix/M = matrix()
			M.Scale(0.5)
			NI.transform = M
			NI.pixel_x = -10+ct1
			NI.pixel_y = -4
			overlays += NI
			ct1+=4

/obj/structure/vending/sales/vending
	name = "vending machine"
	desc = "A vending machine selling an assortment of goods."
	icon_state = "custom2"
	var/image/overlay_primary = null
	var/image/overlay_secondary = null
	max_products = 10

/obj/structure/vending/sales/vending/New()
	..()
	invisibility = 101
	spawn(3)
		overlay_primary = image(icon = icon, icon_state = "[icon_state]_overlay_primary")
		overlay_primary.color = company_color(1)
		overlay_secondary = image(icon = icon, icon_state = "[icon_state]_overlay_secondary")
		overlay_secondary.color = company_color(2)
		update_icon()
		invisibility = 0

/obj/structure/vending/sales/vending/update_icon()
	overlays.Cut()
	if (overlay_primary && overlay_secondary)
		overlay_primary.color = company_color(1)
		overlay_secondary.color = company_color(2)
		overlays += overlay_primary
		overlays += overlay_secondary
		overlays += image(icon = icon, icon_state = "[icon_state]_base")

/obj/structure/vending/sales/stock(obj/item/W, var/datum/data/vending_product/R, var/mob/user)
	if (!user.unEquip(W))
		return

	to_chat(user, "<span class='notice'>You insert \the [W] in \the [src].</span>")
	if (istype(W, /obj/item/stack))
		var/obj/item/stack/S = W
		R.amount += S.amount
		qdel(W)
	else
		W.forceMove(src)
		R.product_item += W
		R.amount++
	GLOB.nanomanager.update_uis(src)

/obj/structure/vending/process()

	if (!active)
		return

	return
