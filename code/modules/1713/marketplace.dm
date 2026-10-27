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
	if (!user || !user.client)
		return

	// Build company overview
	var/sorted = sortTim(map.custom_company_value, /proc/cmp_numeric_dsc, TRUE)
	var/company_rows = ""
	for (var/cmp in map.custom_company_nr)
		var/vm_owned = 0
		for (var/obj/structure/vending/sales/S in vending_machine_list)
			if (S.owner == cmp)
				vm_owned++
		company_rows += "<tr><td class='cmp-name'>[cmp]</td><td>[sorted[cmp]]</td><td>[vm_owned]</td></tr>"

	// Build buy stocks section
	var/buy_html = ""
	if (isemptylist(map.sales_registry))
		buy_html = "<div class='none'>No stocks for sale.</div>"
	else
		var/sale_id = 1
		for (var/list/i in map.sales_registry)
			if (i[5])
				var/curr_name = "sc"
				if (i.len >= 6 && i[6] != "standard")
					curr_name = fiat.currency_list[i[6]][1]
				buy_html += "<div class='item'><span>[i[2]]% of <b>[i[1]]</b> at [i[3]*10] [curr_name]</span><button class='btn buy' onclick=\"window.location='byond://?src=\ref[src];buy=[sale_id]'\">Buy</button></div>"
				sale_id++

	// Build sell stocks section
	var/sell_html = ""
	var/has_stocks = FALSE
	for (var/cmp in map.custom_company_nr)
		if (find_company_member(user, cmp))
			has_stocks = TRUE
			for (var/list/i in map.custom_company[cmp])
				if (i[1] == user)
					// Build currency dropdown for this company
					var/cur_opts = "<select id='sell_cur_[cmp]'><option value='standard'>Standard Coins</option>"
					for (var/fid in fiat.currency_list)
						if (fiat.currency_list[fid][5])
							cur_opts += "<option value='[fid]'>[fiat.currency_list[fid][1]]</option>"
					cur_opts += "</select>"
					sell_html += "<div class='item'><b>[cmp]</b> &mdash; You own [i[2]]%<br>"
					sell_html += "Amount: <input type='text' id='sell_amt_[cmp]' value='[i[2]]' class='num'> "
					sell_html += "Price: <input type='text' id='sell_price_[cmp]' value='10' class='num'> "
					sell_html += "Currency: [cur_opts] "
					sell_html += "<button class='btn' onclick=\"var a=document.getElementById('sell_amt_[cmp]').value;var p=document.getElementById('sell_price_[cmp]').value;var c=document.getElementById('sell_cur_[cmp]').value;if(a&&!isNaN(a)&&Number(a)>=1&&p&&!isNaN(p)&&Number(p)>0)window.location='byond://?src=\ref[src];sell=[cmp]&amt='+a+'&price='+p+'&cur='+c\">Sell</button></div>"
	if (!has_stocks)
		sell_html = "<div class='none'>You do not own any stocks.</div>"

	// Build manage company section
	var/manage_html = ""
	var/has_manage = FALSE
	for (var/cmp in map.custom_company_nr)
		if (find_company_member(user, cmp))
			has_manage = TRUE
			manage_html += "<div class='item'><b>[cmp]</b>"
			manage_html += " <button class='btn' onclick=\"window.location='byond://?src=\ref[src];viewmembers=[cmp]'\">Members</button>"
			manage_html += " <button class='btn' onclick=\"window.location='byond://?src=\ref[src];distribute=[cmp]'\">Distribute</button>"
			manage_html += " <button class='btn' onclick=\"window.location='byond://?src=\ref[src];withdraw=[cmp]'\">Withdraw</button></div>"
	if (!has_manage)
		manage_html = "<div class='none'>You are not a member of any company.</div>"

	// Build faction treasury section
	var/treasury_html = ""
	if (user.leader && user.civilization != "none")
		var/sales_tax = map.custom_civs[user.civilization][9]
		var/business_tax = map.custom_civs[user.civilization][10]
		var/tax_funds = map.custom_civs[user.civilization][5]
		treasury_html += "<div class='item'><b>Sales Tax:</b> [sales_tax]% <button class='btn' onclick=\"var v=prompt('Sales Tax (0-30%):','[sales_tax]');if(v!==null&&!isNaN(v)&&Number(v)>=0&&Number(v)<=30)window.location='byond://?src=\ref[src];setsalestax='+v\">Set</button></div>"
		treasury_html += "<div class='item'><b>Business Tax:</b> [business_tax]% <button class='btn' onclick=\"var v=prompt('Business Tax (0-30%):','[business_tax]');if(v!==null&&!isNaN(v)&&Number(v)>=0&&Number(v)<=30)window.location='byond://?src=\ref[src];setbusinesstax='+v\">Set</button></div>"
		treasury_html += "<div class='item'><b>Tax Funds:</b> [tax_funds] sc <button class='btn' onclick=\"window.location='byond://?src=\ref[src];withdrawtaxes'\">Withdraw</button></div>"
		if (map.custom_civs[user.civilization].len >= 11 && istype(map.custom_civs[user.civilization][11], /list))
			var/list/fiat_treasury = map.custom_civs[user.civilization][11]
			for (var/fid in fiat_treasury)
				if (fiat_treasury[fid] > 0)
					treasury_html += "<div class='item'>[fiat_treasury[fid]] [fiat.currency_list[fid][1]] <button class='btn' onclick=\"window.location='byond://?src=\ref[src];withdrawfiat=[fid]'\">Withdraw</button></div>"

	var/dat = "<html><head><style>"
	dat += "body{font-family:'Segoe UI',monospace;background:#2b1e0e;color:#f0e0c0;margin:0;padding:20px;}"
	dat += "h2{color:#ffd700;border-bottom:2px solid #5a3a1a;padding-bottom:8px;margin-top:0;}"
	dat += ".section{background:#3d2b14;border:1px solid #5a3a1a;border-radius:4px;padding:12px;margin-bottom:12px;}"
	dat += ".section h3{color:#ffd700;margin:0 0 8px 0;font-size:14px;}"
	dat += "table{width:100%;border-collapse:collapse;font-size:13px;}"
	dat += "td,th{padding:4px 8px;text-align:left;border-bottom:1px solid #5a3a1a;}"
	dat += "th{color:#ffd700;}"
	dat += ".cmp-name{color:#f0e0c0;font-weight:bold;}"
	dat += ".none{color:#807060;font-style:italic;padding:8px 4px;font-size:13px;}"
	dat += ".item{background:#2b1e0e;border:1px solid #5a3a1a;border-radius:3px;padding:6px 10px;margin:4px 0;font-size:13px;}"
	dat += ".num{width:60px;background:#2b1e0e;color:#f0e0c0;border:1px solid #5a3a1a;border-radius:2px;padding:3px 5px;font-family:monospace;font-size:12px;}"
	dat += "select{background:#2b1e0e;color:#f0e0c0;border:1px solid #5a3a1a;border-radius:2px;padding:3px 5px;font-family:monospace;font-size:12px;}"
	dat += ".btn{background:#5a3a1a;color:#ffd700;border:1px solid #5a3a1a;border-radius:3px;padding:4px 10px;cursor:pointer;font-size:12px;text-decoration:none;}"
	dat += ".btn:hover{background:#8a6a3a;}"
	dat += ".buy{background:#2a4e2a;border-color:#4a7e4a;}"
	dat += "</style></head><body>"
	dat += "<h2>Stock Market</h2>"
	dat += "<div class='section'><h3>Companies</h3><table><tr><th>Company</th><th>Value</th><th>Points</th></tr>[company_rows]</table></div>"
	dat += "<div class='section'><h3>Buy Stocks</h3>[buy_html]</div>"
	dat += "<div class='section'><h3>Sell Stocks</h3>[sell_html]</div>"
	dat += "<div class='section'><h3>Manage Company</h3>[manage_html]</div>"
	if (treasury_html)
		dat += "<div class='section'><h3>Faction Treasury</h3>[treasury_html]</div>"
	dat += "<div class='section'><button class='btn' onclick=\"window.location='byond://?src=\ref[src];close'\">Close</button></div>"
	dat += "</body></html>"

	user << browse(dat, "window=stockmarket;size=550x600")

/obj/structure/stockmarket/Topic(href, href_list)
	if (!usr || !usr.client)
		return
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat || get_dist(src, H) > 2)
		return

	if (href_list["close"])
		return

	// Buy stock
	if (href_list["buy"])
		var/sale_id = text2num(href_list["buy"])
		var/found = FALSE
		var/sale_idx = 1
		for (var/list/L in map.sales_registry)
			if (L[5])
				if (sale_idx == sale_id)
					found = TRUE
					var/ord = L[1]
					var/ord_perc = L[2]
					var/ord_price = L[3]*10
					var/req_currency = L.len >= 6 ? L[6] : "standard"

					if (!istype(H.get_inactive_hand(), /obj/item/stack/money))
						to_chat(H, "<span class='notice'>You need to have money in your inactive hand to buy stocks!</span>")
						return
					var/obj/item/stack/money/M = H.get_inactive_hand()
					var/valid_money = FALSE
					var/money_val = 0
					var/money_return = 0

					if (req_currency == "standard")
						if (!istype(M, /obj/item/stack/money/fiat))
							valid_money = TRUE
							money_val = M.amount * M.value
							money_return = money_val - ord_price
					else
						if (istype(M, /obj/item/stack/money/fiat))
							var/obj/item/stack/money/fiat/M_fiat = M
							if (M_fiat.fiat_id == req_currency)
								valid_money = TRUE
								money_val = M_fiat.amount
								money_return = money_val - ord_price

					if (!valid_money)
						var/req_name = req_currency == "standard" ? "sc" : fiat.currency_list[req_currency][1]
						to_chat(H, "<span class='notice'>You are not holding the requested currency ([req_name])!</span>")
						return
					if (money_val < ord_price)
						var/req_name = req_currency == "standard" ? "sc" : fiat.currency_list[req_currency][1]
						to_chat(H, "<span class='notice'>You do not have enough money. Need [ord_price] [req_name], have [money_val] [req_name].</span>")
						return

					qdel(M)
					if (money_return > 0)
						if (req_currency == "standard")
							var/obj/item/stack/money/goldcoin/GC = new/obj/item/stack/money/goldcoin(loc)
							GC.amount = round(money_return/GC.value)
							if (GC.amount <= 0)
								qdel(GC)
						else
							new/obj/item/stack/money/fiat(loc, money_return, req_currency)

					if (ishuman(L[4]))
						var/mob/living/human/SELLER = L[4]
						SELLER.transfer_stock_proc(ord, ord_perc, H)
						for (var/list/j in map.custom_company[ord])
							if (j[1] == SELLER)
								if (j.len < 4)
									j.len = 4
									j[4] = list()
								if (req_currency == "standard")
									j[3] += ord_price
								else
									if (!j[4][req_currency])
										j[4][req_currency] = 0
									j[4][req_currency] += ord_price
								break
						L[5] = 0
						map.sales_registry -= L
						for (var/list/LL in map.sales_registry)
							if (LL[1] == ord && LL[4] == SELLER)
								LL[5] = 0
								map.sales_registry -= LL
					else
						transfer_stock_nomob(ord, ord_perc, H)
						L[5] = 0
						map.sales_registry -= L
						for (var/list/LL in map.sales_registry)
							if (LL[1] == ord && LL[2] == ord_perc && LL[3] == L[3] && LL[4] == null)
								LL[5] = 0
								map.sales_registry -= LL
					to_chat(H, "<span class='notice'>You successfully bought [ord_perc]% of [ord].</span>")
					break
				sale_idx++
		if (!found)
			to_chat(H, "<span class='notice'>That stock listing is no longer available.</span>")
		return

	// Sell stock
	if (href_list["sell"])
		var/cmp = href_list["sell"]
		var/amt = text2num(href_list["amt"])
		var/price = text2num(href_list["price"])
		var/cur = href_list["cur"]
		if (!cmp || !amt || !price || !cur)
			return
		amt = round(amt)
		if (amt < 1 || price <= 0)
			return
		var/requested_currency = cur
		for (var/list/i in map.custom_company[cmp])
			if (i[1] == H)
				if (amt > i[2])
					amt = i[2]
				map.sales_registry += list(list(cmp, amt, price/10, H, 1, requested_currency))
				var/curr_name = "Standard Coins"
				if (requested_currency != "standard" && fiat.currency_list[requested_currency])
					curr_name = fiat.currency_list[requested_currency][1]
				to_chat(H, "<span class='notice'>You put up [amt]% of [cmp] at [price] [curr_name].</span>")
				break
		return

	// Manage company - view members
	if (href_list["viewmembers"])
		var/cmp = href_list["viewmembers"]
		var/body = "<html><head><title>[cmp]</title></head>[common_browser_style]<b>[cmp] Members</b><br><br>"
		for (var/list/i in map.custom_company[cmp])
			body += "<b>[i[1]]</b> owns [i[2]]%.<br>"
		body += "<br></body></html>"
		H << browse(body, "window=stockmembers;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=250x450")
		return

	// Manage company - distribute profits
	if (href_list["distribute"])
		var/cmp = href_list["distribute"]
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
		var/cmp = href_list["withdraw"]
		if (!find_company_member(H, cmp))
			return
		for (var/list/j in map.custom_company[cmp])
			if (j[1] == H)
				var/withdrew_something = FALSE
				if (j[3] > 0)
					var/businesstax = 0
					var/price_without_tax = j[3]
					if (H.civilization != "none" && map.custom_civs[H.civilization])
						businesstax = (map.custom_civs[H.civilization][10]/100)*j[3]
						price_without_tax = j[3]-businesstax
						map.custom_civs[H.civilization][5] += businesstax
					var/obj/item/stack/money/goldcoin/GC = new/obj/item/stack/money/goldcoin(loc)
					GC.amount = round(price_without_tax/4)
					j[3] = 0
					to_chat(H, "<span class='notice'>You withdraw [GC.amount*4] silver coins in profit, paying [businesstax] silver coins in Business Tax.</span>")
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
								if (businesstax > 0)
									if (map.custom_civs[H.civilization].len < 11)
										map.custom_civs[H.civilization].len = 11
									if (!istype(map.custom_civs[H.civilization][11], /list))
										map.custom_civs[H.civilization][11] = list()
									if (!map.custom_civs[H.civilization][11][fid])
										map.custom_civs[H.civilization][11][fid] = 0
									map.custom_civs[H.civilization][11][fid] += businesstax
							new/obj/item/stack/money/fiat(loc, round(price_without_tax), fid)
							fiat_profits[fid] = 0
							to_chat(H, "<span class='notice'>You withdraw [round(price_without_tax)] [fiat.currency_list[fid][1]] in profit, paying [businesstax] [fiat.currency_list[fid][1]] in Business Tax.</span>")
							withdrew_something = TRUE
				if (!withdrew_something)
					to_chat(H, "<span class='notice'>You have no profits to withdraw.</span>")
		return

	// Faction treasury - set sales tax
	if (href_list["setsalestax"])
		if (!H.leader)
			return
		var/val = text2num(href_list["setsalestax"])
		if (isnull(val))
			return
		val = round(val)
		if (val < 0) val = 0
		if (val > 30) val = 10
		map.custom_civs[H.civilization][9] = val
		to_chat(H, "<b>Sales Tax</b> set to [val]%.")
		return

	// Faction treasury - set business tax
	if (href_list["setbusinesstax"])
		if (!H.leader)
			return
		var/val = text2num(href_list["setbusinesstax"])
		if (isnull(val))
			return
		val = round(val)
		if (val < 0) val = 0
		if (val > 30) val = 10
		map.custom_civs[H.civilization][10] = val
		to_chat(H, "<b>Business Tax</b> set to [val]%.")
		return

	// Faction treasury - withdraw taxes
	if (href_list["withdrawtaxes"])
		if (map.custom_civs[H.civilization][4] != H)
			to_chat(H, "<span class='warning'>You do not have the permissions to do that!</span>")
			return
		var/withdrew_something = FALSE
		if (map.custom_civs[H.civilization][5] > 0)
			var/obj/item/stack/money/goldcoin/GC = new/obj/item/stack/money/goldcoin(loc)
			GC.amount = map.custom_civs[H.civilization][5]/4
			map.custom_civs[H.civilization][5] = 0
			to_chat(H, "You withdraw [GC.amount] gold coins in faction funds.")
			withdrew_something = TRUE
		if (map.custom_civs[H.civilization].len >= 11 && istype(map.custom_civs[H.civilization][11], /list))
			var/list/fiat_treasury = map.custom_civs[H.civilization][11]
			for (var/fid in fiat_treasury)
				var/amt = fiat_treasury[fid]
				if (amt > 0)
					new/obj/item/stack/money/fiat(loc, round(amt), fid)
					to_chat(H, "You withdraw [round(amt)] [fiat.currency_list[fid][1]] in faction funds.")
					fiat_treasury[fid] = 0
					withdrew_something = TRUE
		if (!withdrew_something)
			to_chat(H, "<span class='notice'>There is no money to withdraw.</span>")
		return

	// Faction treasury - withdraw fiat tax
	if (href_list["withdrawfiat"])
		if (map.custom_civs[H.civilization][4] != H)
			to_chat(H, "<span class='warning'>You do not have the permissions to do that!</span>")
			return
		var/fid = href_list["withdrawfiat"]
		if (map.custom_civs[H.civilization].len >= 11 && istype(map.custom_civs[H.civilization][11], /list))
			var/list/fiat_treasury = map.custom_civs[H.civilization][11]
			var/amt = fiat_treasury[fid]
			if (amt > 0)
				new/obj/item/stack/money/fiat(loc, round(amt), fid)
				to_chat(H, "You withdraw [round(amt)] [fiat.currency_list[fid][1]] in faction funds.")
				fiat_treasury[fid] = 0
		return
