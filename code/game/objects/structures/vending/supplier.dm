// a "reverse" market stall/vending machine, where you put buy orders and people can sell to you.

#define SUPPLY_COPPERS_PER_SILVER 10

/obj/structure/supplier
	name = "supply stall"
	desc = "A market stall where you can fulfill this company supply orders."
	icon = 'icons/obj/vending.dmi'
	icon_state = "supply_stall"
	layer = 2.9
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE

	var/ordertype = null
	var/orderprice = 0
	var/orderamount = 0
	var/ordername = ""
	var/orderfiat_id = null

	var/moneyin = 0
	var/accepted_currency = "standard"
	var/owner = "Global"

	var/image/overlay_primary = null
	var/image/overlay_secondary = null

/** Initializes the supplier stall and sets up company-colored visual overlays. */
/obj/structure/supplier/New()
	..()
	invisibility = 101
	spawn(3)
		overlay_primary = image(icon = icon, icon_state = "[icon_state]_overlay_primary")
		overlay_primary.color = map.custom_company_colors[owner][1]
		overlay_secondary = image(icon = icon, icon_state = "[icon_state]_overlay_secondary")
		overlay_secondary.color = map.custom_company_colors[owner][2]
		overlays += overlay_primary
		overlays += overlay_secondary
		update_icon()
		invisibility = 0

/** Refreshes the visual overlays based on the current company colors of the owner. */
/obj/structure/supplier/update_icon()
	overlays.Cut()
	if (overlay_primary && overlay_secondary)
		overlay_primary.color = map.custom_company_colors[owner][1]
		overlay_secondary.color = map.custom_company_colors[owner][2]
		overlays += overlay_primary
		overlays += overlay_secondary

/** Logic for stall maintenance, adding operating funds, configuring new buy orders, or selling items to the stall. */
/obj/structure/supplier/attackby(obj/item/W as obj, mob/user as mob)
	if (is_tool(W, TOOL_WRENCH))
		if (owner != "Global" && company_may_operate(user,owner))
			playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
			if (anchored)
				user.visible_message("[user] begins unsecuring \the [src] from the floor.", "You start unsecuring \the [src] from the floor.")
			else
				user.visible_message("[user] begins securing \the [src] to the floor.", "You start securing \the [src] to the floor.")

			if (do_after(user, 20, src))
				if (QDELETED(src) || !company_may_operate(user, owner)) return
				to_chat(user, "<span class='notice'>You [anchored? "un" : ""]secured \the [src]!</span>")
				anchored = !anchored
			return
	else if (company_may_operate(user,owner))
		if (istype(W, /obj/item/stack/money))
			var/can_buy = FALSE
			if (istype(W, /obj/item/stack/money/fiat))
				var/obj/item/stack/money/fiat/F = W
				if (F.fiat_id != accepted_currency)
					can_buy = TRUE
			else
				if (accepted_currency != "standard")
					can_buy = TRUE

			if (!ordertype && can_buy)
				var/choice = player_alert(user, "Do you want to add a buying order for [W]?", "Stall Management", list("Yes", "No"))
				if (choice == "Yes")
					var/quoted_currency = accepted_currency
					var/price_unit_label = accepted_currency == "standard" ? "standard coins" : fiat.currency_list[accepted_currency][1]
					var/choice2 = player_input(user, "What price per unit, in [price_unit_label]?", "Stall Management", 1, "num", null, FALSE)
					if (choice2 <= 0)
						return
					if (choice2 > 100000)
						choice2 = 100000
					var/choice3 = player_input(user, "How many units do you want to buy?", "Stall Management", 1, "num", null, FALSE)
					if (choice3 <= 0 || !accept_supply_order_edit(user, W) || quoted_currency != accepted_currency)
						return
					var/checked_price = payable_order_price(user, choice2)
					if (isnull(checked_price))
						return
					orderprice = checked_price
					orderamount = round(choice3)
					if (istype(W, /obj/item/stack/money/fiat))
						var/obj/item/stack/money/fiat/F = W
						ordertype = /obj/item/stack/money/fiat
						ordername = F.name
						orderfiat_id = F.fiat_id
					else
						ordertype = /obj/item/stack/money
						ordername = "standard coins"
						orderfiat_id = null
					to_chat(user, "<span class='notice'>Buy order created: buying [orderamount] [ordername] at [orderprice] [price_unit_label] each.</span>")
					return

			if (accepted_currency == "standard" && istype(W, /obj/item/stack/money/fiat))
				var/obj/item/stack/money/fiat/FI = W
				user.drop_from_inventory(FI)
				FI.forceMove(src)
				to_chat(user, "<span class='notice'>You store the [FI] in the stall's inventory.</span>")
				return
			else if (accepted_currency != "standard" && istype(W, /obj/item/stack/money/fiat))
				var/obj/item/stack/money/fiat/FI = W
				if (FI.fiat_id != accepted_currency)
					user.drop_from_inventory(FI)
					FI.forceMove(src)
					to_chat(user, "<span class='notice'>You store the [FI] in the stall's inventory.</span>")
					return
			else if (accepted_currency != "standard" && !istype(W, /obj/item/stack/money/fiat))
				to_chat(user, "<span class='warning'>This stall only accepts [fiat.currency_list[accepted_currency][1]] as operating funds. Use standard coins to stock inventory.</span>")
				return

			var/obj/item/stack/money/M = W
			if (accepted_currency == "standard")
				moneyin += M.value * M.amount
				to_chat(user, "You add the money to the stall. It now has [moneyin] in standard coin value to fulfill orders.")
			else
				moneyin += M.amount
				to_chat(user, "You add the money to the stall. It now has [moneyin] [fiat.currency_list[accepted_currency][1]] to fulfill orders.")
			qdel(W)
			return
		else if (!ordertype)
			var/choice = player_alert(user, "Do you want to add a buying order for [W]?", "Stall Management", list("Yes", "No"))
			if (choice == "No")
				return
			else
				var/quoted_currency = accepted_currency
				var/price_unit_label = accepted_currency == "standard" ? "standard coins" : fiat.currency_list[accepted_currency][1]
				var/choice2 = player_input(user, "What price per unit, in [price_unit_label]? This stall will keep accepting orders until it runs out of money.", "Stall Management", orderprice, "num", null, FALSE)
				if (choice2 < 0)
					choice2 = 0
				else if (choice2 > 100000)
					choice2 = 100000
				var/choice3 = player_input(user, "How much do you want to buy? This stall will keep accepting orders until it runs out of money.", "Stall Management", moneyin, "num", null, FALSE)
				if (!accept_supply_order_edit(user, W) || quoted_currency != accepted_currency)
					return
				var/checked_price = payable_order_price(user, choice2)
				if (isnull(checked_price))
					return
				orderprice = checked_price
				if (choice3 < 0)
					choice3 = 0
				else if (moneyin < orderamount*choice3)
					orderamount = round(moneyin/choice3)
				else
					orderamount = choice3
				ordertype = W.type
				ordername = W.name
				return
	else
		if (W.type == ordertype || (orderfiat_id == null && ordertype == /obj/item/stack/money && istype(W, /obj/item/stack/money) && !istype(W, /obj/item/stack/money/fiat)))
			if (istype(W, /obj/item/stack/money/fiat))
				var/obj/item/stack/money/fiat/WF = W
				if (WF.fiat_id != orderfiat_id)
					to_chat(user, "<span class='warning'>The [src] is buying [ordername], not [WF.name].</span>")
					return
			// Saved orders may predate price validation. Refuse before touching a seller's item.
			var/standard_payment = accepted_currency == "standard"
			var/price_coppers
			var/funds_coppers
			if (standard_payment)
				price_coppers = exact_order_coppers(orderprice)
				if (!price_coppers)
					to_chat(user, SPAN_WARNING("The stall's order price cannot be paid in whole copper coins. Ask its owner to correct it."))
					return
				funds_coppers = whole_balance_coppers(moneyin)
			var/mob/living/seller = user
			if (!istype(seller) || W.loc != seller || !seller.item_is_in_hands(W))
				return
			if (istype(W, /obj/item/stack))
				if (orderamount < 1)
					to_chat(user, "<span class='warning'>The [src] is not currently buying.</span>")
					return
				var/obj/item/stack/WS = W
				var/max_affordable = standard_payment ? floor(funds_coppers / price_coppers) : (orderprice > 0 ? floor(moneyin / orderprice) : orderamount)
				var/limit_qty = min(orderamount, max_affordable)
				if (limit_qty < 1)
					if (max_affordable < 1)
						to_chat(user, "<span class='warning'>The [src] has no money left to buy from you!</span>")
					else
						to_chat(user, "<span class='warning'>The [src] is not currently buying.</span>")
					return

				var/buy_qty = min(WS.amount, limit_qty)
				if (standard_payment)
					buy_qty = floor(buy_qty)
				if (buy_qty < 1)
					return

				if (buy_qty == WS.amount)
					if (!seller.transfer_held_item_to(WS, src))
						return
				else
					if (WS.nodrop || WS.nodrop_special_check())
						return
					var/obj/item/stack/NST = WS.split(buy_qty)
					if (!NST)
						return
					if (!NST.forceMove(src) || QDELETED(NST) || NST.loc != src)
						if (!QDELETED(WS) && !QDELETED(NST))
							WS.amount += NST.amount
							WS.update_icon()
							WS.update_strings()
							qdel(NST)
						return

				if (standard_payment)
					settle_standard_coppers(price_coppers * buy_qty)
				else
					var/payment = orderprice * buy_qty
					new/obj/item/stack/money/fiat(loc, payment, accepted_currency)
					moneyin -= payment
				orderamount -= buy_qty
				to_chat(user, "<span class='notice'>You sell [buy_qty] [ordername].</span>")
				return
			else
				if (orderamount < 1)
					to_chat(user, "<span class='warning'>The [src] is not currently buying.</span>")
					return
				if (standard_payment ? funds_coppers >= price_coppers : moneyin >= orderprice)
					if (!seller.transfer_held_item_to(W, src))
						return
					if (standard_payment)
						settle_standard_coppers(price_coppers)
					else
						new/obj/item/stack/money/fiat(loc, orderprice, accepted_currency)
						moneyin -= orderprice
					orderamount -= 1
					to_chat(user, "<span class='notice'>You sell the [W].</span>")
					return
				else
					to_chat(user, "<span class='warning'>The [src] has no money left to buy from you!</span>")
					return
	return

// A steward's second dialog must not outlive their authority or active order.
/obj/structure/supplier/proc/accept_supply_order_edit(mob/user, obj/item/W)
	return !QDELETED(src) && !QDELETED(W) && W.loc == user && !ordertype && in_range(src, user) && company_may_operate(user, owner)

// Never round a real fractional balance up; allow only noise around a whole copper.
/obj/structure/supplier/proc/whole_balance_coppers(amount)
	var/scaled = max(0, amount * SUPPLY_COPPERS_PER_SILVER)
	var/whole = floor(scaled)
	if (whole + 1 - scaled <= 0.0001)
		return whole + 1
	return whole

/obj/structure/supplier/proc/exact_order_coppers(amount)
	if (!isnum(amount) || amount <= 0)
		return 0
	var/coppers = whole_balance_coppers(amount)
	if (abs(amount * SUPPLY_COPPERS_PER_SILVER - coppers) > 0.0001)
		return 0
	return coppers

/obj/structure/supplier/proc/payable_order_price(mob/user, amount)
	if (!isnum(amount))
		return null
	if (accepted_currency != "standard")
		return amount
	var/coppers = exact_order_coppers(amount)
	if (!coppers)
		to_chat(user, SPAN_WARNING("Standard buy orders need a positive price in whole copper coins (0.1 silver per copper)."))
		return null
	return coppers / SUPPLY_COPPERS_PER_SILVER

// Both sale and withdrawal pay already-validated integer units and keep the remainder.
/obj/structure/supplier/proc/settle_standard_coppers(coppers)
	pay_standard_coppers(coppers)
	moneyin = max(0, moneyin - coppers / SUPPLY_COPPERS_PER_SILVER)

/obj/structure/supplier/proc/pay_standard_coppers(coppers)
	var/golds = floor(coppers / (4 * SUPPLY_COPPERS_PER_SILVER))
	coppers -= golds * 4 * SUPPLY_COPPERS_PER_SILVER
	var/silvers = floor(coppers / SUPPLY_COPPERS_PER_SILVER)
	coppers -= silvers * SUPPLY_COPPERS_PER_SILVER
	if (golds > 0)
		var/obj/item/stack/money/goldcoin/G = new/obj/item/stack/money/goldcoin(loc)
		G.amount = golds
	if (silvers > 0)
		var/obj/item/stack/money/silvercoin/S = new/obj/item/stack/money/silvercoin(loc)
		S.amount = silvers
	if (coppers > 0)
		var/obj/item/stack/money/coppercoin/C = new/obj/item/stack/money/coppercoin(loc)
		C.amount = coppers

/** Management interface for company members to configure buy orders, name, currency, and withdraw operating funds. */
/obj/structure/supplier/attack_hand(mob/living/human/H as mob)
	if (company_may_operate(H,owner))
		ui_interact(H)
	else
		var/currency_name = accepted_currency == "standard" ? "sc" : fiat.currency_list[accepted_currency][1]
		to_chat(H, "<big>This company is currently buying [orderamount] of [ordername] for [orderprice] [currency_name] per unit.</big>")

/obj/structure/supplier/ui_actions(ui_key)
	return list("rename", "changeprice", "changeamount", "changecurrency", "removeorder", "removeproducts", "removemoney")

/obj/structure/supplier/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = TRUE)
	if (!company_may_operate(user, owner))
		GLOB.nanomanager.close_user_uis(user, src, ui_key)
		return
	var/currency_name = accepted_currency == "standard" ? "standard coins" : fiat.currency_list[accepted_currency][1]
	var/list/currencies = list(panel_option("standard", "Standard Coins"))
	if (fiat)
		for (var/fid in fiat.currency_list)
			if (fiat.currency_list[fid][5])
				currencies += list(panel_option(fid, fiat.currency_list[fid][1]))
	var/has_order = (ordertype != null && orderamount > 0)
	var/list/sections = list(
		panel_section("Current Buy Order", rows = list(
			panel_row("Buying", has_order ? "[orderamount]x [ordername] at [orderprice] [currency_name] each" : "No active buy order", has_order ? null : "muted",
				has_order ? list(panel_button("Remove Order", "removeorder")) : null),
			panel_row("Available funds", "[moneyin] [currency_name]", null, list(panel_button("Remove Money", "removemoney", 1, moneyin <= 0))))),
		panel_section("Order Settings", forms = list(
			panel_form("Price per unit", "changeprice", 1, list(panel_field("value", currency_name, orderprice)), "Change"),
			panel_form("Amount to buy", "changeamount", 1, list(panel_field("value", "Units", orderamount)), "Change"),
			panel_form("Currency", "changecurrency", 1, list(panel_field("value", "Paid in", accepted_currency, "choice", currencies)), "Apply"))),
		panel_section("Stall", notes = list("Removing products ejects every item stored in the stall."),
			forms = list(panel_form("Name", "rename", 1, list(panel_field("value", "New name", name, "text")), "Change Name")),
			buttons = list(panel_button("Remove Products Inside", "removeproducts"))))
	open_panel(user, "Supply Stall - [name]", 520, 520, sections, ui_key = ui_key, ui = ui, force_open = force_open)

// The window's buttons and forms: only a conscious member of the owning company, close by.
/obj/structure/supplier/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	var/mob/living/human/H = user
	if (!istype(H) || H.stat || get_dist(src, H) > 2)
		return TRUE
	if (!company_may_operate(H, owner))
		return TRUE
	var/list/href_list = list("[action]" = "[params["value"]]")

	if (href_list["rename"])
		var/new_name = sanitize(href_list["rename"], 50)
		if (new_name && new_name != "")
			name = new_name
		return TRUE

	if (href_list["changeprice"])
		var/val = text2num(href_list["changeprice"])
		if (isnull(val))
			return TRUE
		if (val < 0) val = 0
		if (val > 100000) val = 100000
		var/checked_price = payable_order_price(H, val)
		if (!isnull(checked_price))
			orderprice = checked_price
		return TRUE

	if (href_list["changeamount"])
		var/val = text2num(href_list["changeamount"])
		if (isnull(val) || val < 0)
			return TRUE
		orderamount = round(val)
		return TRUE

	if (href_list["changecurrency"])
		var/new_cur = href_list["changecurrency"]
		if (new_cur != "standard" && !(fiat && (new_cur in fiat.currency_list) && fiat.currency_list[new_cur][5]))
			return TRUE
		if (moneyin > 0)
			to_chat(H, "<span class='warning'>You must remove all money from the stall before changing the accepted currency!</span>")
			return TRUE
		if (new_cur == "standard" && ordertype && !exact_order_coppers(orderprice))
			to_chat(H, SPAN_WARNING("Set a price payable in whole copper coins, or remove the order, before switching to standard coins."))
			return TRUE
		accepted_currency = new_cur
		return TRUE

	if (href_list["removeorder"])
		ordertype = null
		ordername = ""
		orderprice = 0
		orderamount = 0
		orderfiat_id = null
		to_chat(H, "<span class='notice'>Buy order removed.</span>")
		return TRUE

	if (href_list["removeproducts"])
		for (var/obj/item/I in src)
			I.forceMove(loc)
		to_chat(H, "<span class='notice'>You empty the stall.</span>")
		return TRUE

	if (href_list["removemoney"])
		if (moneyin <= 0)
			return TRUE
		if (accepted_currency == "standard")
			var/coppers = whole_balance_coppers(moneyin)
			if (!coppers)
				to_chat(H, SPAN_NOTICE("The remaining balance is below one copper and stays in the stall."))
				return TRUE
			settle_standard_coppers(coppers)
			if (moneyin > 0)
				to_chat(H, SPAN_NOTICE("Coins removed. The balance below one copper stays in the stall."))
				return TRUE
		else
			new/obj/item/stack/money/fiat(loc, moneyin, accepted_currency)
			moneyin = 0
		to_chat(H, "<span class='notice'>Money removed from stall.</span>")
		return TRUE
	return TRUE

#undef SUPPLY_COPPERS_PER_SILVER
