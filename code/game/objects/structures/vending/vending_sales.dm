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
	var/max_products = 5

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
			if (product_records.len >= max_products)
				user << "<span class='notice'>This [src] has too many different products already!</span>"
				return FALSE
			var/datum/data/vending_product/product = new/datum/data/vending_product(src, W.type, W.name, _icon = W.icon, _icon_state = W.icon_state)
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
			qdel(W)
			update_icon()
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
		update_icon()
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


//STALLS AND MACHINES
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

/obj/structure/vending/sales/market_stall
	name = "market stall"
	desc = "A market stall selling an assortment of goods."
	icon_state = "market_stall"
	var/image/overlay_primary = null
	var/image/overlay_secondary = null

/obj/structure/vending/sales/market_stall/New()
	..()
	invisibility = 101
	spawn(3)
		overlay_primary = image(icon = icon, icon_state = "[icon_state]_overlay_primary")
		overlay_primary.color = map.custom_company_colors[owner][1]
		overlay_secondary = image(icon = icon, icon_state = "[icon_state]_overlay_secondary")
		overlay_secondary.color = map.custom_company_colors[owner][2]
		update_icon()
		invisibility = 0

/obj/structure/vending/sales/market_stall/update_icon()
	overlays.Cut()
	if (overlay_primary && overlay_secondary)
		overlay_primary.color = map.custom_company_colors[owner][1]
		overlay_secondary.color = map.custom_company_colors[owner][2]
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
	max_capacity = 10

/obj/structure/vending/sales/vending/New()
	..()
	invisibility = 101
	spawn(3)
		overlay_primary = image(icon = icon, icon_state = "[icon_state]_overlay_primary")
		overlay_primary.color = map.custom_company_colors[owner][1]
		overlay_secondary = image(icon = icon, icon_state = "[icon_state]_overlay_secondary")
		overlay_secondary.color = map.custom_company_colors[owner][2]
		update_icon()
		invisibility = 0

/obj/structure/vending/sales/vending/update_icon()
	overlays.Cut()
	if (overlay_primary && overlay_secondary)
		overlay_primary.color = map.custom_company_colors[owner][1]
		overlay_secondary.color = map.custom_company_colors[owner][2]
		overlays += overlay_primary
		overlays += overlay_secondary
		overlays += image(icon = icon, icon_state = "[icon_state]_base")