// Standard payment units are copper; fiat stacks use whole units.
#define STOCK_MARKET_COPPERS_PER_SILVER 10

/obj/structure/stockmarket
	name = "stock market"
	desc = "Use this to buy, sell and check company shares. You can also manage your companies here."
	icon = 'icons/obj/structures.dmi'
	icon_state = "supplybook"
	density = TRUE
	anchored = TRUE
	flammable = FALSE
	not_movable = FALSE

/** Main interaction menu for checking companies, buying/selling stocks, managing your owned companies, and faction treasury access. */
/obj/structure/stockmarket/attack_hand(var/mob/living/human/user as mob)
	show_ui(user)

/obj/structure/stockmarket/proc/show_ui(mob/living/human/user)
	if (!istype(user))
		return
	ui_interact(user)

/obj/structure/stockmarket/ui_actions(ui_key)
	return list("buy", "sell", "viewmembers", "distribute", "withdraw", "setsalestax", "setbusinesstax", "withdrawtaxes", "withdrawfiat")

/obj/structure/stockmarket/ui_action_fields(ui_key, action)
	if (action == "sell")
		return list("amt", "price", "cur")
	return ..()

// The window's buttons run the same checks as before, then every open window refreshes.
/obj/structure/stockmarket/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	var/list/href_list = list()
	for (var/key in params)
		href_list[key == "value" ? action : key] = "[params[key]]"
	market_action(user, href_list)
	return TRUE

// Members of one company, shown in a window of its own.
/obj/structure/stockmarket/proc/members_sections(cmp)
	var/list/rows = list()
	for (var/list/i in map.custom_company[cmp])
		if (i[2] > 0)
			rows += list(panel_row(i[1] ? "[i[1]]" : "Estate of a dead shareholder (for sale)", "[i[2]]%"))
	return list(panel_section("[cmp] Members", rows = rows, empty = "Nobody holds a share."))

/obj/structure/stockmarket/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE)
	var/mob/living/human/H = user
	if (!istype(H))
		return
	// A members window is keyed by the company's position, so it needs no stored state.
	if (findtext(ui_key, "members_") == 1)
		var/cmp = href_company(copytext(ui_key, 9))
		if (!cmp)
			GLOB.nanomanager.close_user_uis(H, src, ui_key)
			return
		open_panel(H, "Company members", 320, 450, members_sections(cmp), ui_key = ui_key, ui = ui, force_open = force_open)
		return
	var/list/sections = list()

	// Company overview
	var/sorted = sortTim(map.custom_company_value, /proc/cmp_numeric_dsc, TRUE)
	var/list/company_rows = list()
	for (var/cmp in map.custom_company_nr)
		var/vm_owned = 0
		for (var/obj/structure/vending/sales/S in vending_machine_list)
			if (S.owner == cmp)
				vm_owned++
		company_rows[++company_rows.len] = list(cmp, sorted[cmp], vm_owned)
	sections += list(panel_section("Companies", table = panel_table(list("Company", "Value", "Points"), company_rows), empty = "No companies have been founded."))

	// Stocks for sale. Each button names the actual listing across market windows.
	var/list/offers = list()
	for (var/list/i in map.sales_registry)
		if (!i[5])
			continue
		var/currency = listing_currency(i)
		var/price_units = listing_price_units(i, currency)
		if (isnull(price_units))
			offers += list(panel_item("[i[2]]% of [i[1]]", "Unavailable: price cannot be paid in its listed currency."))
			continue
		var/curr_name = currency == "standard" ? "sc" : fiat.currency_list[currency][1]
		var/display_price = payment_label(price_units, currency)
		offers += list(panel_item("[i[2]]% of [i[1]]", "[display_price] [curr_name]", list(panel_button("Buy", "buy", listing_token(i)))))
	sections += list(panel_section("Buy Stocks", list("Hold the money in your inactive hand."), items = offers, empty = "No stocks for sale."))

	// Own stocks. A company is named by its position in custom_company_nr, so
	// quotes, & or = in a name cannot break a button.
	var/list/currencies = list(panel_option("standard", "Standard Coins"))
	for (var/fid in fiat.currency_list)
		if (fiat.currency_list[fid][5])
			currencies += list(panel_option(fid, fiat.currency_list[fid][1]))
	var/list/sell_forms = list()
	var/list/manage = list()
	var/list/former_proceeds = list()
	var/cmp_idx = 0
	for (var/cmp in map.custom_company_nr)
		cmp_idx++
		if (find_company_member(H, cmp))
			for (var/list/i in map.custom_company[cmp])
				if (i[1] == H)
					sell_forms += list(panel_form("[cmp] - you own [i[2]]%", "sell", cmp_idx, list(
						panel_field("amt", "Amount", i[2]), panel_field("price", "Price", 10), panel_field("cur", "Currency", "standard", "choice", currencies)), "Sell"))
			manage += list(panel_item(cmp, null, list(panel_button("Members", "viewmembers", cmp_idx), panel_button("Distribute", "distribute", cmp_idx), panel_button("Withdraw", "withdraw", cmp_idx))))
		else if (has_company_proceeds(H, cmp))
			former_proceeds += list(panel_item(cmp, null, list(panel_button("Withdraw", "withdraw", cmp_idx))))
	sections += list(panel_section("Sell Stocks", forms = sell_forms, empty = "You do not own any stocks."))
	sections += list(panel_section("Manage Company", items = manage, empty = "You are not a member of any company."))
	if (former_proceeds.len)
		sections += list(panel_section("Proceeds from Former Holdings", items = former_proceeds))

	// Faction treasury
	if (H.civilization != "none" && map.is_faction_leader(H, H.civilization))
		var/sales_tax = map.custom_civs[H.civilization][9]
		var/business_tax = map.custom_civs[H.civilization][10]
		var/tax_funds = map.custom_civs[H.civilization][5]
		var/obj/structure/closet/crate/faction_strongbox/box = map.faction_strongbox(H.civilization)
		var/list/notes = list()
		var/list/funds = list()
		if (box)
			notes += "Taxes are collected into the faction's strongbox ([tax_funds] sc waiting). Wages and dues are kept there too."
		// With a strongbox the window offers no withdrawal; the Topic refuses one too.
		if (!box)
			funds += list(panel_item("Tax Funds", "[tax_funds] sc", list(panel_button("Withdraw", "withdrawtaxes"))))
			if (map.custom_civs[H.civilization].len >= 11 && istype(map.custom_civs[H.civilization][11], /list))
				var/list/fiat_treasury = map.custom_civs[H.civilization][11]
				for (var/fid in fiat_treasury)
					if (fiat_treasury[fid] > 0)
						funds += list(panel_item("[fiat_treasury[fid]] [fiat.currency_list[fid][1]]", null, list(panel_button("Withdraw", "withdrawfiat", fid))))
		sections += list(panel_section("Faction Treasury", notes, items = funds, forms = list(
			panel_form("Sales Tax: [sales_tax]%", "setsalestax", 0, list(panel_field("value", "0-30%", sales_tax)), "Set"),
			panel_form("Business Tax: [business_tax]%", "setbusinesstax", 0, list(panel_field("value", "0-30%", business_tax)), "Set"))))
	open_panel(H, "Stock Market", 600, 640, sections, ui = ui, force_open = force_open)

// Links name a company by its position in custom_company_nr (companies are
// only ever appended), so quotes, & or = in a name cannot break them.
/obj/structure/stockmarket/proc/href_company(var/value)
	var/idx = text2num(value)
	if (!isnum(idx) || idx != round(idx) || idx < 1 || idx > map.custom_company_nr.len)
		return null
	return map.custom_company_nr[idx]

// Former shareholders can still collect balances on their own retained rows.
/obj/structure/stockmarket/proc/has_company_proceeds(mob/living/human/H, cmp)
	for (var/list/row in map.custom_company[cmp])
		if (row[1] != H)
			continue
		if (row[3] > 0)
			return TRUE
		if (row.len >= 4 && islist(row[4]))
			var/list/balances = row[4]
			for (var/fid in balances)
				if (balances[fid] > 0)
					return TRUE
	return FALSE

/obj/structure/stockmarket/proc/listing_currency(list/listing)
	return listing.len >= 6 ? listing[6] : "standard"

// Keep the saved positional fields intact, including pre-fiat estate rows.
// Mint once per listing. Persist the token with its row, not with a market window.
/obj/structure/stockmarket/proc/listing_token(list/listing)
	if (listing.len >= 7 && istext(listing[7]) && length(listing[7]))
		return listing[7]
	var/static/listing_sequence = 0
	var/token = md5("[world.realtime]-[world.time]-[rand(1, 1000000000)]-[++listing_sequence]")
	if (listing.len < 6)
		listing.len = 6
		listing[6] = "standard"
	listing.len = max(listing.len, 7)
	listing[7] = token
	return token

/obj/structure/stockmarket/proc/live_listing(token)
	if (!istext(token) || length(token) != 32)
		return null
	for (var/list/listing in map.sales_registry)
		if (listing.len >= 7 && listing[5] && listing[7] == token)
			return listing
	return null

/obj/structure/stockmarket/proc/payment_scale(currency)
	return currency == "standard" ? STOCK_MARKET_COPPERS_PER_SILVER : 1

// Format the payable value without rounding the last copper on a large quote.
/obj/structure/stockmarket/proc/payment_label(units, currency)
	if (currency != "standard")
		return num2text(units, 12)
	var/silver = round(units / STOCK_MARKET_COPPERS_PER_SILVER)
	var/copper = units - silver * STOCK_MARKET_COPPERS_PER_SILVER
	if (copper)
		return "[num2text(silver, 12)].[copper]"
	return num2text(silver, 12)

// DM currency values use floats. Tolerate representation noise, not a fractional coin.
/obj/structure/stockmarket/proc/exact_payment_units(amount, scale)
	if (!isnum(amount) || amount < 0)
		return null
	var/scaled = amount * scale
	// Stay within DM's consecutive integer range so subtraction preserves change.
	if (scaled > 16777215)
		return null
	var/units = round(scaled)
	if (scaled - units >= 0.5)
		units++
	// Allow at most the precision lost through DM's float storage and scaling.
	var/tolerance = max(0.0001, min(0.125, scaled * 0.00000012))
	if (abs(scaled - units) > tolerance)
		return null
	return units

/obj/structure/stockmarket/proc/listing_price_units(list/listing, currency)
	if (currency != "standard" && (!currency || !fiat.currency_list[currency]))
		return null
	// New rows carry the exact price as integer units. Preserve the legacy price field for old saves.
	if (listing.len >= 8)
		if (isnum(listing[8]) && listing[8] > 0 && listing[8] == round(listing[8]) && listing[8] <= 16777215)
			return listing[8]
		return null
	if (!isnum(listing[3]))
		return null
	var/price = listing[3] * 10
	var/units = exact_payment_units(price, payment_scale(currency))
	// Valuations generated by the estate process can predate payable prices.
	// Round those down to copper and quote that same effective price to buyers.
	if (isnull(units) && currency == "standard" && isnull(listing[4]) && price >= 0 && price * STOCK_MARKET_COPPERS_PER_SILVER <= 16777215)
		return round(price * STOCK_MARKET_COPPERS_PER_SILVER)
	return units

// This is purchase change, not the whole-silver profit withdrawal policy.
/obj/structure/stockmarket/proc/pay_standard_change(change_units)
	var/silver = round(change_units / STOCK_MARKET_COPPERS_PER_SILVER)
	var/copper = change_units - silver * STOCK_MARKET_COPPERS_PER_SILVER
	if (silver > 0)
		company_pay_coins(loc, silver)
	if (copper > 0)
		var/obj/item/stack/money/coppercoin/C = new(loc)
		C.amount = copper
		C.update_icon()

// Fiat stacks contain whole units; leave any fraction in the treasury.
/obj/structure/stockmarket/proc/withdraw_treasury_fiat(list/treasury, fid, mob/user)
	var/amount = treasury[fid]
	if (!isnum(amount) || amount < 1)
		return FALSE
	var/paid = round(amount)
	new/obj/item/stack/money/fiat(loc, paid, fid)
	treasury[fid] = amount - paid
	to_chat(user, "You withdraw [paid] [fiat.currency_list[fid][1]] in faction funds.")
	return TRUE

/obj/structure/stockmarket/Topic(href, href_list)
	if (!usr || !usr.client)
		return
	market_action(usr, href_list)

// One request from the window or a link, for the person who made it.
/obj/structure/stockmarket/proc/market_action(mob/living/human/H, list/href_list)
	if (!istype(H) || H.stat || get_dist(src, H) > 2)
		return

	if (href_list["close"])
		return

	// Buy stock
	if (href_list["buy"])
		var/list/L = live_listing(href_list["buy"])
		if (!L)
			to_chat(H, "<span class='notice'>That stock listing is no longer available.</span>")
			return
		var/ord = L[1]
		var/ord_perc = L[2]
		var/req_currency = listing_currency(L)
		var/price_units = listing_price_units(L, req_currency)
		if (isnull(price_units))
			to_chat(H, "<span class='notice'>That listing price cannot be paid in its listed currency.</span>")
			return
		var/mob/living/human/SELLER = ishuman(L[4]) ? L[4] : null
		// A listing is only a promise: the seller may have transferred the stake or died since.
		if (!company_has_stake(ord, SELLER, ord_perc))
			map.sales_registry -= list(L)
			to_chat(H, "<span class='notice'>That stock listing is no longer available.</span>")
			return
		var/obj/item/stack/money/M = H.get_inactive_hand()
		if (!istype(M, /obj/item/stack/money))
			to_chat(H, "<span class='notice'>You need to have money in your inactive hand to buy stocks!</span>")
			return
		var/req_name = req_currency == "standard" ? "sc" : fiat.currency_list[req_currency][1]
		var/money_val
		if (req_currency == "standard")
			if (!istype(M, /obj/item/stack/money/fiat))
				money_val = M.amount * M.value
		else if (istype(M, /obj/item/stack/money/fiat))
			var/obj/item/stack/money/fiat/M_fiat = M
			if (M_fiat.fiat_id == req_currency)
				money_val = M_fiat.amount
		if (isnull(money_val))
			to_chat(H, "<span class='notice'>You are not holding the requested currency ([req_name])!</span>")
			return
		var/tender_units = exact_payment_units(money_val, payment_scale(req_currency))
		if (isnull(tender_units))
			to_chat(H, "<span class='notice'>That stack cannot be exchanged for exact change.</span>")
			return
		var/ord_price = price_units / payment_scale(req_currency)
		if (tender_units < price_units)
			to_chat(H, "<span class='notice'>You do not have enough money. Need [payment_label(price_units, req_currency)] [req_name], have [payment_label(tender_units, req_currency)] [req_name].</span>")
			return

		if (SELLER ? !SELLER.transfer_stock_proc(ord, ord_perc, H) : !transfer_stock_nomob(ord, ord_perc, H))
			map.sales_registry -= list(L)
			to_chat(H, "<span class='notice'>That stock listing is no longer available.</span>")
			return
		if (price_units > 0)
			qdel(M)
			var/change_units = tender_units - price_units
			if (change_units > 0)
				if (req_currency == "standard")
					pay_standard_change(change_units)
				else
					new/obj/item/stack/money/fiat(loc, change_units, req_currency)

		if (SELLER)
			for (var/list/j in map.custom_company[ord])
				if (j[1] == SELLER)
					if (j.len < 4 || !islist(j[4]))
						j.len = max(j.len, 4)
						j[4] = list()
					if (req_currency == "standard")
						j[3] += ord_price
					else
						if (!j[4][req_currency])
							j[4][req_currency] = 0
						j[4][req_currency] += ord_price
					break
			L[5] = 0
			map.sales_registry -= list(L)
			for (var/list/LL in map.sales_registry)
				if (LL[1] == ord && LL[4] == SELLER)
					LL[5] = 0
					map.sales_registry -= list(LL)
		else
			// Only this estate listing: an identical one belongs to another
			// dead holder's estate row and stays for sale.
			L[5] = 0
			map.sales_registry -= list(L)
		to_chat(H, "<span class='notice'>You successfully bought [ord_perc]% of [ord].</span>")
		return

	// Sell stock
	if (href_list["sell"])
		var/cmp = href_company(href_list["sell"])
		var/amt = text2num(href_list["amt"])
		var/price = text2num(href_list["price"])
		var/cur = href_list["cur"]
		if (!cmp || !amt || !price || !cur)
			return
		amt = round(amt)
		if (amt < 1 || price <= 0)
			return
		var/requested_currency = cur
		// An unknown currency id would break every buyer's listing page.
		if (requested_currency != "standard" && !(fiat.currency_list[requested_currency] && fiat.currency_list[requested_currency][5]))
			return
		var/price_units = exact_payment_units(price, payment_scale(requested_currency))
		if (!price_units)
			to_chat(H, "<span class='notice'>Set a price payable in whole fiat units or in copper increments for standard coins.</span>")
			return
		price = price_units / payment_scale(requested_currency)
		for (var/list/i in map.custom_company[cmp])
			if (i[1] == H)
				if (amt > i[2])
					amt = i[2]
				if (amt < 1)
					break
				var/list/listing = list(cmp, amt, price / 10, H, 1, requested_currency)
				listing_token(listing)
				listing += price_units
				map.sales_registry += list(listing)
				var/curr_name = "Standard Coins"
				if (requested_currency != "standard" && fiat.currency_list[requested_currency])
					curr_name = fiat.currency_list[requested_currency][1]
				to_chat(H, "<span class='notice'>You put up [amt]% of [cmp] at [payment_label(price_units, requested_currency)] [curr_name].</span>")
				break
		return

	// Manage company - view members
	if (href_list["viewmembers"])
		var/cmp = href_company(href_list["viewmembers"])
		if (!cmp)
			return
		ui_interact(H, "members_[map.custom_company_nr.Find(cmp)]")
		return

	// Manage company - distribute profits
	if (href_list["distribute"])
		var/cmp = href_company(href_list["distribute"])
		if (!find_company_member(H, cmp))
			return
		var/distributed_something = FALSE
		if (map.custom_company_value[cmp] > 0)
			var/tprof = map.custom_company_value[cmp]
			map.custom_company_value[cmp] = 0
			for (var/i in map.custom_company[cmp])
				i[3] += (i[2]/100)*tprof
			distributed_something = TRUE
		if (map.custom_company_fiat_value[cmp])
			for (var/fid in map.custom_company_fiat_value[cmp])
				var/tprof_fiat = map.custom_company_fiat_value[cmp][fid]
				if (tprof_fiat > 0)
					map.custom_company_fiat_value[cmp][fid] = 0
					for (var/list/j in map.custom_company[cmp])
						if (j.len < 4 || !istype(j[4], /list))
							j.len = max(j.len, 4)
							j[4] = list()
						if (!j[4][fid])
							j[4][fid] = 0
						j[4][fid] += (j[2]/100)*tprof_fiat
					distributed_something = TRUE
		if (distributed_something)
			to_chat(H, "<span class='notice'>You distribute the profits of [cmp].</span>")
		else
			to_chat(H, "<span class='notice'>There are no profits to distribute from [cmp].</span>")
		return

	// Manage company - withdraw profits
	if (href_list["withdraw"])
		var/cmp = href_company(href_list["withdraw"])
		if (!cmp)
			return
		// The requesting player can withdraw only from their own retained row.
		for (var/list/j in map.custom_company[cmp])
			if (j[1] == H)
				var/withdrew_something = FALSE
				if (j[3] >= 1)
					var/businesstax = 0
					var/price_without_tax = j[3]
					if (H.civilization != "none" && map.custom_civs[H.civilization])
						businesstax = (map.custom_civs[H.civilization][10]/100)*j[3]
						price_without_tax = j[3]-businesstax
						map.custom_civs[H.civilization][5] += businesstax
					var/paid = company_pay_coins(loc, price_without_tax)
					// Keep the sub-coin fraction for the next withdrawal.
					j[3] = max(0, price_without_tax - paid)
					to_chat(H, "<span class='notice'>You withdraw [paid] silver coins' worth in profit, paying [businesstax] silver coins in Business Tax.</span>")
					withdrew_something = TRUE
				if (j.len >= 4 && istype(j[4], /list))
					var/list/fiat_profits = j[4]
					for (var/fid in fiat_profits)
						if (fiat_profits[fid] > 0)
							var/amt = fiat_profits[fid]
							var/businesstax = 0
							var/price_without_tax = amt
							if (H.civilization != "none" && map.custom_civs[H.civilization])
								businesstax = (map.custom_civs[H.civilization][10]/100)*amt
								price_without_tax = amt - businesstax
							var/paid = round(price_without_tax)
							if (paid < 1)
								continue
							if (businesstax > 0)
								if (map.custom_civs[H.civilization].len < 11)
									map.custom_civs[H.civilization].len = 11
								if (!istype(map.custom_civs[H.civilization][11], /list))
									map.custom_civs[H.civilization][11] = list()
								if (!map.custom_civs[H.civilization][11][fid])
									map.custom_civs[H.civilization][11][fid] = 0
								map.custom_civs[H.civilization][11][fid] += businesstax
							new/obj/item/stack/money/fiat(loc, paid, fid)
							fiat_profits[fid] = 0
							to_chat(H, "<span class='notice'>You withdraw [paid] [fiat.currency_list[fid][1]] in profit, paying [businesstax] [fiat.currency_list[fid][1]] in Business Tax.</span>")
							withdrew_something = TRUE
				if (!withdrew_something)
					to_chat(H, "<span class='notice'>You have no profits to withdraw.</span>")
		return

	// Faction treasury - set sales tax
	if (href_list["setsalestax"])
		if (!map.is_faction_leader(H, H.civilization))
			return
		var/val = text2num(href_list["setsalestax"])
		if (isnull(val))
			return
		val = round(val)
		if (val < 0) val = 0
		if (val > 30) val = 30
		map.custom_civs[H.civilization][9] = val
		to_chat(H, "<b>Sales Tax</b> set to [val]%.")
		return

	// Faction treasury - set business tax
	if (href_list["setbusinesstax"])
		if (!map.is_faction_leader(H, H.civilization))
			return
		var/val = text2num(href_list["setbusinesstax"])
		if (isnull(val))
			return
		val = round(val)
		if (val < 0) val = 0
		if (val > 30) val = 30
		map.custom_civs[H.civilization][10] = val
		to_chat(H, "<b>Business Tax</b> set to [val]%.")
		return

	// Faction treasury - withdraw taxes
	if (href_list["withdrawtaxes"])
		if (map.custom_civs[H.civilization][4] != H)
			to_chat(H, "<span class='warning'>You do not have the permissions to do that!</span>")
			return
		if (map.faction_strongbox(H.civilization))
			to_chat(H, "<span class='notice'>Your faction keeps its treasury in a strongbox; collect taxes there.</span>")
			return
		var/withdrew_something = FALSE
		if (map.custom_civs[H.civilization][5] >= 1)
			var/funds = map.custom_civs[H.civilization][5]
			var/paid = company_pay_coins(loc, funds)
			map.custom_civs[H.civilization][5] = max(0, funds - paid)
			to_chat(H, "You withdraw [paid] silver coins' worth in faction funds.")
			withdrew_something = TRUE
		if (map.custom_civs[H.civilization].len >= 11 && istype(map.custom_civs[H.civilization][11], /list))
			var/list/fiat_treasury = map.custom_civs[H.civilization][11]
			for (var/fid in fiat_treasury)
				if (withdraw_treasury_fiat(fiat_treasury, fid, H))
					withdrew_something = TRUE
		if (!withdrew_something)
			to_chat(H, "<span class='notice'>There is no money to withdraw.</span>")
		return

	// Faction treasury - withdraw fiat tax
	if (href_list["withdrawfiat"])
		if (map.custom_civs[H.civilization][4] != H)
			to_chat(H, "<span class='warning'>You do not have the permissions to do that!</span>")
			return
		if (map.faction_strongbox(H.civilization))
			to_chat(H, "<span class='notice'>Your faction keeps its treasury in a strongbox; collect taxes there.</span>")
			return
		var/fid = href_list["withdrawfiat"]
		if (map.custom_civs[H.civilization].len >= 11 && istype(map.custom_civs[H.civilization][11], /list))
			var/list/fiat_treasury = map.custom_civs[H.civilization][11]
			withdraw_treasury_fiat(fiat_treasury, fid, H)
		return

#undef STOCK_MARKET_COPPERS_PER_SILVER
