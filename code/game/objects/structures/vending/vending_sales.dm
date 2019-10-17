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
	var/owner = "Global"

/obj/structure/vending/ex_act(severity)
	return

/obj/structure/vending/sales/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/money))
		var/obj/item/stack/money/M = W
		moneyin += M.amount*M.value
		user << "You put \the [W] in the [src]."
		qdel(W)
		return
	if (istype(W, /obj/item/weapon/wrench))
		if (owner != "Global" && find_company_member(user,owner))
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
		if (owner != "Global" && find_company_member(user,owner))
			for (var/datum/data/vending_product/R in product_records)
				if (istype(W, R.product_path))
					stock(W, R, user)
					return TRUE
			//if it isnt in the list yet
			var/datum/data/vending_product/product = new/datum/data/vending_product(src, W.type, W.name)
			var/inputp = input(user, "What price do you want to set for \the [W]? (in silver coins)") as num
			if (!inputp)
				inputp = 0
			if (inputp < 0)
				inputp = 0
			product.price = inputp/10
			if (istype(W, /obj/item/stack))
				var/obj/item/stack/S = W
				product.amount = S.amount
			product_records.Add(product)
			return TRUE

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

/obj/structure/vending/sales/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE)
	user.set_using_object(src)

	var/list/data = list()
	if (currently_vending)
		data["mode"] = TRUE
		data["company"] = owner
		data["product"] = currently_vending.product_name
		data["price"] = currently_vending.price*10
		data["message_err"] = FALSE
		data["message"] = status_message
		data["message_err"] = status_error
		data["moneyin"] = moneyin*10
	else
		data["mode"] = FALSE
		data["company"] = owner
		data["moneyin"] = moneyin*10
		var/list/listed_products = list()

		for (var/key = TRUE to product_records.len)
			var/datum/data/vending_product/I = product_records[key]

			listed_products.Add(list(list(
				"key" = key,
				"name" = I.product_name,
				"price" = I.price*10,
				"color" = I.display_color,
				"amount" = I.amount)))

		data["products"] = listed_products

	ui = nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "vending_machine2.tmpl", name, 440, 600)
		ui.set_initial_data(data)
		ui.open()

/obj/structure/vending/sales/Topic(href, href_list)
	if (stat & BROKEN)
		return

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
				if (moneyin < R.price)
					status_message = "Please insert money to pay for the item."
					status_error = FALSE
				else
					moneyin -= R.price
					if (owner != "Global")
						map.custom_company_value[owner] += R.price
					var/obj/item/stack/money/goldcoin/GC = new/obj/item/stack/money/goldcoin(loc)
					GC.amount = moneyin/0.4
					moneyin = 0
					vend(R, usr)
					nanomanager.update_uis(src)

		else if (href_list["cancelpurchase"])
			currently_vending = null

		else if (href_list["remove_money"])
			var/obj/item/stack/money/goldcoin/GC = new/obj/item/stack/money/goldcoin(loc)
			GC.amount = moneyin/0.4
			moneyin = 0
			nanomanager.update_uis(src)
			return

		add_fingerprint(usr)
		playsound(usr.loc, 'sound/machines/button.ogg', 100, TRUE)
		nanomanager.update_uis(src)

/obj/structure/vending/sales/food
	name = "Food stall"
	desc = "Basic food products."
	icon_state = "nutrimat"
	products = list(
		/obj/item/weapon/reagent_containers/food/snacks/grown/apple = 15,
	)
	prices = list(
		/obj/item/weapon/reagent_containers/food/snacks/grown/apple = 0.15,
	)