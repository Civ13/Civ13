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
			return
	else if (istype(W, /obj/item/weapon/wrench))
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
			//if it isnt in the list yet
			if (product_records.len >= max_products)
				var/datum/data/vending_product/free = null
				for (var/datum/data/vending_product/R in product_records)
					if (R.amount <= 0)
						free=R
				if (!free)
					to_chat(user, "<span class='notice'>This [src] has too many different products already!</span>")
					return FALSE
				else
					product_records -= free
			user.unEquip(W)
			var/datum/data/vending_product/product = new/datum/data/vending_product(src, W.type, W.name, _icon = W.icon, _icon_state = W.icon_state, M = W)
			var/inputp = input(user, "What price do you want to set for \the [W]?", "Product Price") as num
			if (!inputp)
				inputp = 0
			if (inputp < 0)
				inputp = 0
			product.price = inputp
			if (istype(W, /obj/item/stack))
				var/obj/item/stack/S = W
				product.amount = S.amount
				qdel(W)
			else
				if (W)
					W.forceMove(src)
			product_records.Add(product)
			update_icon()
			return TRUE

/** Management menu for owners to change the vendor name, adjust prices, remove stock, or change accepted currency. */
/obj/structure/vending/sales/verb/Manage()
	set category = null
	set src in range(1, usr)

	if (!istype(usr, /mob/living/human))
		return

	if (owner != "Global" && find_company_member(usr,owner))
		show_management_ui(usr)
	else
		to_chat(usr, "You do not have permission to manage this vendor.")

/obj/structure/vending/sales/proc/show_management_ui(mob/user)
	if (!user || !user.client)
		return

	// Build currency options
	var/currency_opts_html = ""
	var/selected = (accepted_currency == "standard") ? " selected" : ""
	currency_opts_html += "<option value='standard'[selected]>Standard Coins</option>"
	for (var/cid in fiat.currency_list)
		if (fiat.currency_list[cid][5])
			selected = (accepted_currency == cid) ? " selected" : ""
			currency_opts_html += "<option value='[cid]'[selected]>[fiat.currency_list[cid][1]]</option>"

	// Build products listing
	var/products_html = ""
	for (var/datum/data/vending_product/VP in product_records)
		products_html += "<div class='product-item'><span class='product-name'>[VP.product_name]</span><span class='product-price'>[VP.price]</span>"
		products_html += "<button class='btn' onclick=\"var p=prompt('New price for [VP.product_name]:','[VP.price]');if(p!==null&&!isNaN(p)&&Number(p)>=0)window.location='byond://?src=\ref[src];manage=changeprice&product=\ref[VP]&price='+encodeURIComponent(p)\">Price</button>"
		products_html += "<button class='btn btn-danger' onclick=\"window.location='byond://?src=\ref[src];manage=removeproduct&product=\ref[VP]'\">Remove</button></div>"
	if (!product_records.len)
		products_html = "<div style='color: #707090; font-style: italic; padding: 8px;'>No products in this vendor.</div>"

	var/dat = "<html><head><style>"
	if (vendor_style == "modern")
		dat += "body{font-family:Verdana,Geneva,sans-serif;background:#1a1a1a;color:#ffffff;margin:0;padding:20px;}"
		dat += "h2{color:#aa0000;border-bottom:2px solid #aa0000;padding-bottom:8px;margin-top:0;}"
		dat += ".section{background:#272727;border:1px solid #aa0000;border-radius:4px;padding:12px;margin-bottom:12px;}"
		dat += ".section h3{color:#aa0000;margin:0 0 8px 0;font-size:14px;}"
		dat += ".field { margin: 4px 0; }"
		dat += ".field .ftext { width: 96%; background: #1a1a1a; color: #ffffff; border: 1px solid #aa0000; border-radius: 3px; padding: 6px; font-family: monospace; }"
		dat += ".field select { width: 100%; background: #1a1a1a; color: #ffffff; border: 1px solid #aa0000; border-radius: 3px; padding: 6px; font-family: monospace; }"
		dat += ".btn { background: #aa0000; color: #ffffff; border: 1px solid #770000; border-radius: 3px; padding: 6px 14px; cursor: pointer; font-size: 13px; display: inline-block; margin: 2px; text-decoration: none; }"
		dat += ".btn:hover { background: #ff3333; }"
		dat += ".btn-danger { background: #5e2a2a; color: #ff7070; border: 1px solid #8a3a3a; }"
		dat += ".btn-danger:hover { background: #8a3a3a; }"
		dat += ".product-item { background: #1a1a1a; border: 1px solid #aa0000; border-radius: 3px; padding: 6px 10px; margin: 4px 0; display: flex; justify-content: space-between; align-items: center; font-size: 13px; }"
		dat += ".product-name { color: #ffffff; }"
		dat += ".product-price { color: #ffd700; font-weight: bold; }"
	else
		dat += "body{font-family:'Segoe UI',monospace;background:#2b1e0e;color:#f0e0c0;margin:0;padding:20px;}"
		dat += "h2{color:#ffd700;border-bottom:2px solid #5a3a1a;padding-bottom:8px;margin-top:0;}"
		dat += ".section{background:#3d2b14;border:1px solid #5a3a1a;border-radius:4px;padding:12px;margin-bottom:12px;}"
		dat += ".section h3{color:#ffd700;margin:0 0 8px 0;font-size:14px;}"
		dat += ".field { margin: 4px 0; }"
		dat += ".field .ftext { width: 96%; background: #2b1e0e; color: #f0e0c0; border: 1px solid #5a3a1a; border-radius: 3px; padding: 6px; font-family: monospace; }"
		dat += ".field select { width: 100%; background: #2b1e0e; color: #f0e0c0; border: 1px solid #5a3a1a; border-radius: 3px; padding: 6px; font-family: monospace; }"
		dat += ".btn { background: #5a3a1a; color: #ffd700; border: 1px solid #5a3a1a; border-radius: 3px; padding: 6px 14px; cursor: pointer; font-size: 13px; display: inline-block; margin: 2px; text-decoration: none; }"
		dat += ".btn:hover { background: #8a6a3a; }"
		dat += ".btn-danger { background: #5e2a2a; color: #ff7070; border: 1px solid #8a3a3a; }"
		dat += ".btn-danger:hover { background: #8a3a3a; }"
		dat += ".product-item { background: #2b1e0e; border: 1px solid #5a3a1a; border-radius: 3px; padding: 6px 10px; margin: 4px 0; display: flex; justify-content: space-between; align-items: center; font-size: 13px; }"
		dat += ".product-name { color: #f0e0c0; }"
		dat += ".product-price { color: #ffd700; font-weight: bold; }"
	dat += "</style></head><body>"
	dat += "<h2>Vendor Management - [name]</h2>"
	dat += "<div class='section'><h3>Change Name</h3>"
	dat += "<div class='field'><input type='text' id='new_name' class='ftext' value='[name]' placeholder='Enter new name...'>"
	dat += "<button class='btn' onclick=\"var v=document.getElementById('new_name').value;if(v)window.location='byond://?src=\ref[src];manage=rename&value='+encodeURIComponent(v)\">Change Name</button></div></div>"
	dat += "<div class='section'><h3>Products &amp; Prices</h3>[products_html]</div>"
	dat += "<div class='section'><h3>Change Currency</h3>"
	dat += "<div class='field'><select id='currency_select'>[currency_opts_html]</select>"
	dat += "<button class='btn' onclick=\"window.location='byond://?src=\ref[src];manage=changecurrency&currency='+document.getElementById('currency_select').value\">Apply</button></div></div>"
	dat += "<div class='section'><button class='btn' onclick=\"window.location='byond://?src=\ref[src];manage=close'\">Close</button></div>"
	dat += "</body></html>"

	user << browse(dat, "window=vendor_management;size=500x550")

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
/obj/structure/vending/sales/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE)
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

	ui = GLOB.nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		if (map.ID == MAP_THE_ART_OF_THE_DEAL)
			ui = new(user, src, ui_key, "vending_machine_taotd.tmpl", name, 540, 600)
		else if (map.ID == MAP_GULAG13)
			ui = new(user, src, ui_key, "vending_machine_gulag.tmpl", name, 540, 600)
		else if (map.ID == MAP_KANDAHAR)
			ui = new(user, src, ui_key, "vending_machine_taotd.tmpl", name, 540, 600)
		else
			ui = new(user, src, ui_key, "vending_machine2.tmpl", name, 540, 600)
		ui.set_initial_data(data)
		ui.open()

/** Processes signals from the NanoUI, including purchase requests, cancellations, and withdrawal of inserted funds. */
/obj/structure/vending/sales/Topic(href, href_list)
	if (isliving(usr))
		if (usr.stat || usr.restrained())
			return
	else if (isobserver(usr))
		if (!check_rights(R_MOD))
			return

	if ((usr.contents.Find(src) || (in_range(src, usr) && istype(loc, /turf))))
		if ((href_list["vend"]) && (vend_ready) && (!currently_vending))

			if (find_company_member(usr,owner))
				to_chat(usr, "<span class='warning'>You can't buy from your own company. Remove the product instead.</span>")
				status_error = FALSE
				currently_vending = null
			else

				var/key = text2num(href_list["vend"])
				var/datum/data/vending_product/R = product_records[key]

				var/inp = 1
				if (R.amount > 1)
					inp = input(usr, "How many do you want to buy? (1 to [R.amount])",1) as num
					if (inp>R.amount)
						inp = R.amount
					else if (inp<=1)
						inp = 1

				if (R.price <= 0)
					vend(R, usr, inp)

				else
					var/mob/living/human/H = usr
					var/salestax = 0
					if (map.ID != MAP_KANDAHAR)
						if (H.civilization != "none")
							salestax = (map.custom_civs[H.civilization][9]/100)*R.price
					var/price_with_tax = R.price+salestax
					currently_vending = R
					if (moneyin < price_with_tax*inp)
						status_message = "Please insert money to pay for the item."
						status_error = FALSE
					else
						moneyin -= price_with_tax*inp
						if (owner != "Global")
							if (accepted_currency == "standard")
								map.custom_company_value[owner] += price_with_tax*inp
								if (map.custom_civs[H.civilization])
									map.custom_civs[H.civilization][5] += salestax*inp
							else
								if (!map.custom_company_fiat_value[owner])
									map.custom_company_fiat_value[owner] = list()
								if (!map.custom_company_fiat_value[owner][accepted_currency])
									map.custom_company_fiat_value[owner][accepted_currency] = 0
								map.custom_company_fiat_value[owner][accepted_currency] += price_with_tax*inp
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
						vend(R, usr, inp)
						GLOB.nanomanager.update_uis(src)

		else if (href_list["cancelpurchase"])
			currently_vending = null

		else if (href_list["remove_money"])
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

		else if (href_list["manage"])
			if (owner == "Global" || !find_company_member(usr, owner))
				return
			var/action = href_list["manage"]
			switch(action)
				if ("close")
					return
				if ("rename")
					var/new_name = href_list["value"]
					if (new_name && new_name != "")
						name = new_name
				if ("changeprice")
					var/datum/data/vending_product/VP = locate(href_list["product"])
					var/new_price = text2num(href_list["price"])
					if (VP && !isnull(new_price) && new_price >= 0)
						VP.price = new_price
				if ("removeproduct")
					var/datum/data/vending_product/VP = locate(href_list["product"])
					if (VP)
						vend(VP, usr, VP.amount)
				if ("changecurrency")
					if (moneyin > 0)
						to_chat(usr, "<span class='warning'>You must empty the vendor of all funds before changing its accepted currency.</span>")
						return
					var/new_currency = href_list["currency"]
					if (new_currency)
						accepted_currency = new_currency
						var/curr_name = "Standard Coins"
						if (new_currency != "standard" && fiat.currency_list[new_currency])
							curr_name = fiat.currency_list[new_currency][1]
						to_chat(usr, "<span class='notice'>This vendor now accepts [curr_name].</span>")
			GLOB.nanomanager.update_uis(src)
			return

		add_fingerprint(usr)
		playsound(usr.loc, 'sound/machines/button.ogg', 100, TRUE)
		GLOB.nanomanager.update_uis(src)


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
	max_products = 10

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
